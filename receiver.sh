#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script path
SCRIPT_PATH="$0"
SCRIPT_NAME=$(basename "$0")

# Function to check OS compatibility
check_os_compatibility() {
    # Check if lsb_release command exists
    if ! command -v lsb_release &> /dev/null; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS_ID="$ID"
        else
            echo -e "${RED}Cannot determine operating system. This script supports only Debian and Ubuntu.${NC}"
            exit 1
        fi
    else
        OS_ID=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
    fi

    # Check if OS is supported
    if [[ "$OS_ID" != "debian" && "$OS_ID" != "ubuntu" ]]; then
        echo -e "${RED}Unsupported operating system: $OS_ID${NC}"
        echo -e "${YELLOW}This script is designed for Debian and Ubuntu systems only.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Detected operating system: $OS_ID${NC}"
    return 0
}

show_ascii_logo() {
    echo -e "${BLUE}"
    echo "  ___                   ___ ____  _"
    echo " / _ \ _ __   ___ _ __ |_ _|  _ \| |"
    echo "| | | | '_ \ / _ \ '_ \ | || |_) | |"
    echo "| |_| | |_) |  __/ | | || ||  _ <| |___"
    echo " \___/| .__/ \___|_| |_|___|_| \_\_____|"
    echo "      |_|"
    echo -e "${NC}"
}

# Function to display help
show_help() {
    show_ascii_logo

    echo -e "${BLUE}SRTla-Receiver Script${NC}"
    echo
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  install              Install/update Docker and configure SRTla-Receiver"
    echo "                       (only installs missing components, preserves existing config)"
    echo "  start                Start SRTla-Receiver"
    echo "  stop                 Stop SRTla-Receiver"
    echo "  update               Update SRTla-Receiver container"
    echo "  updateself           Update this script"
    echo "  remove               Remove SRTla-Receiver container"
    echo "  status               Show status of SRTla-Receiver"
    echo "  reset                Reset system (deletes all data!)"
    echo "  help                 Show this help"
    echo
}

# Function to check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed.${NC}"
        echo -e "Please run '${YELLOW}$0 install${NC}' first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${RED}Docker Compose is not installed.${NC}"
        echo -e "Please run '${YELLOW}$0 install${NC}' first."
        exit 1
    fi
    
    echo -e "${GREEN}Docker and Docker Compose are installed.${NC}"
}

# Function to check if user is in docker group
check_docker_group() {
    if groups | grep -q docker; then
        return 0  # User is in docker group
    else
        return 1  # User is not in docker group
    fi
}

# Function to check Docker installation status
check_docker_status() {
    local docker_installed=false
    local compose_installed=false
    local user_in_group=false
    
    # Check Docker
    if command -v docker &> /dev/null; then
        docker_installed=true
    fi
    
    # Check Docker Compose
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null 2>&1; then
        compose_installed=true
    fi
    
    # Check if user is in docker group
    if check_docker_group; then
        user_in_group=true
    fi
    
    echo "$docker_installed,$compose_installed,$user_in_group"
}

# Function to install Docker (only missing components)
install_docker() {
    # Check OS compatibility first
    check_os_compatibility
    
    # Get current Docker status
    IFS=',' read -r docker_installed compose_installed user_in_group <<< "$(check_docker_status)"
    
    local needs_restart=false
    
    echo -e "${BLUE}Checking Docker installation status...${NC}"
    
    if [ "$docker_installed" = "true" ]; then
        echo -e "${GREEN}✓ Docker is already installed${NC}"
    else
        echo -e "${YELLOW}→ Installing Docker on $OS_ID...${NC}"
        
        # Install dependencies
        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg

        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/$OS_ID/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

        # Add Docker repository - using the detected OS
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$OS_ID $(lsb_release -cs) stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        # Install Docker
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        echo -e "${GREEN}✓ Docker has been installed${NC}"
        needs_restart=true
    fi
    
    if [ "$compose_installed" = "true" ]; then
        echo -e "${GREEN}✓ Docker Compose is already installed${NC}"
    else
        echo -e "${YELLOW}→ Installing Docker Compose...${NC}"
        sudo apt-get update
        sudo apt-get install -y docker-compose-plugin
        echo -e "${GREEN}✓ Docker Compose has been installed${NC}"
        needs_restart=true
    fi
    
    if [ "$user_in_group" = "true" ]; then
        echo -e "${GREEN}✓ User is already in docker group${NC}"
    else
        echo -e "${YELLOW}→ Adding user to docker group...${NC}"
        sudo usermod -aG docker $USER
        echo -e "${GREEN}✓ User added to docker group${NC}"
        needs_restart=true
    fi
    
    if [ "$needs_restart" = "true" ]; then
        echo -e "${YELLOW}Please restart your shell or run 'newgrp docker' to activate the Docker group.${NC}"
    else
        echo -e "${GREEN}All Docker components are already properly installed and configured.${NC}"
    fi
}

# Function to get public IPv4 address
get_public_ip() {
    local ip=""
    
    # Try different methods to get the public IP
    if command -v curl &> /dev/null; then
        ip=$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 icanhazip.com 2>/dev/null || curl -s --max-time 5 ipecho.net/plain 2>/dev/null)
    fi
    
    # Fallback to local IP if public IP cannot be determined
    if [ -z "$ip" ]; then
        ip=$(hostname -I | awk '{print $1}')
    fi
    
    echo "$ip"
}

# Function to extract API key from Docker logs
extract_api_key() {
    echo -e "${BLUE}Extracting API key from container logs...${NC}"
    
    # Check if containers already exist (indicating they were started before)
    local container_exists=false
    if docker compose version &> /dev/null; then
        if docker compose ps -a | grep -q "receiver"; then
            container_exists=true
        fi
    else
        if docker-compose ps -a | grep -q "receiver"; then
            container_exists=true
        fi
    fi
    
    # First, try to extract from existing logs
    local api_key=""
    if docker compose version &> /dev/null; then
        api_key=$(docker compose logs receiver 2>/dev/null | grep "Generated default admin API key:" | sed 's/.*Generated default admin API key: \([A-Za-z0-9]*\).*/\1/' | tail -1)
    else
        api_key=$(docker-compose logs receiver 2>/dev/null | grep "Generated default admin API key:" | sed 's/.*Generated default admin API key: \([A-Za-z0-9]*\).*/\1/' | tail -1)
    fi
    
    if [ -n "$api_key" ]; then
        echo "$api_key" > .apikey
        echo -e "${GREEN}API key successfully extracted and saved to .apikey${NC}"
        echo -e "${BLUE}Your API key: $api_key${NC}"
        return 0
    fi
    
    # If container already exists but no API key found, it means the system was already initialized
    if [ "$container_exists" = true ]; then
        echo -e "${YELLOW}Container was already started before. API key is only generated on the very first start.${NC}"
        echo -e "${YELLOW}Possible solutions:${NC}"
        if docker compose version &> /dev/null; then
            echo -e "${BLUE}1. Check all container logs: docker compose logs receiver | grep 'Generated default admin API key'${NC}"
        else
            echo -e "${BLUE}1. Check all container logs: docker-compose logs receiver | grep 'Generated default admin API key'${NC}"
        fi
        echo -e "${BLUE}2. If you need a new API key, use:${NC}"
        echo -e "${BLUE}   ./receiver.sh reset${NC}"
        echo -e "${RED}WARNING: Resetting will delete all stored data!${NC}"
        return 1
    fi
    
    # If this is a fresh start, wait for API key generation
    local max_attempts=30
    local attempt=0
    
    echo -e "${BLUE}Waiting for API key generation on first start...${NC}"
    
    while [ $attempt -lt $max_attempts ] && [ -z "$api_key" ]; do
        sleep 2
        
        # Extract API key from logs
        if docker compose version &> /dev/null; then
            api_key=$(docker compose logs receiver 2>/dev/null | grep "Generated default admin API key:" | sed 's/.*Generated default admin API key: \([A-Za-z0-9]*\).*/\1/' | tail -1)
        else
            api_key=$(docker-compose logs receiver 2>/dev/null | grep "Generated default admin API key:" | sed 's/.*Generated default admin API key: \([A-Za-z0-9]*\).*/\1/' | tail -1)
        fi
        
        attempt=$((attempt + 1))
        
        if [ -n "$api_key" ]; then
            echo "$api_key" > .apikey
            echo -e "${GREEN}API key successfully extracted and saved to .apikey${NC}"
            echo -e "${BLUE}Your API key: $api_key${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}Waiting for API key generation... (attempt $attempt/$max_attempts)${NC}"
    done
    
    echo -e "${YELLOW}API key could not be automatically extracted.${NC}"
    echo -e "${YELLOW}Please check the container logs manually:${NC}"
    if docker compose version &> /dev/null; then
        echo -e "${BLUE}docker compose logs receiver | grep 'Generated default admin API key'${NC}"
    else
        echo -e "${BLUE}docker-compose logs receiver | grep 'Generated default admin API key'${NC}"
    fi
    return 1
}

# Function to reset system for new API key
reset_system() {
    echo -e "${YELLOW}WARNING: This action will delete all stored data and generate a new API key!${NC}"
    echo -e "${RED}All streams, users and settings will be lost!${NC}"
    echo
    read -p "Are you sure you want to reset the system? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo -e "${BLUE}Reset cancelled.${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Resetting system...${NC}"
    
    # Stop and remove containers
    if [ -f "docker-compose.yml" ]; then
        if docker compose version &> /dev/null; then
            docker compose down --volumes --remove-orphans
        else
            docker-compose down --volumes --remove-orphans
        fi
    fi
    
    # Remove data directory
    if [ -d "data" ]; then
        sudo rm -rf data
        echo -e "${GREEN}data directory removed.${NC}"
    fi
    
    # Remove API key file
    if [ -f ".apikey" ]; then
        rm -f .apikey
        echo -e "${GREEN}.apikey file removed.${NC}"
    fi
    
    # Recreate data directory
    create_data_directory
    
    echo -e "${GREEN}System successfully reset.${NC}"
    echo -e "${BLUE}You can now run './receiver.sh start' to generate a new API key.${NC}"
}

# Function to download Docker Compose file
download_compose_file() {
    local version="$1"
    local compose_url="https://raw.githubusercontent.com/OpenIRL/srtla-receiver/refs/heads/$version/docker-compose.prod.yml"
    
    echo -e "${BLUE}Downloading Docker Compose file...${NC}"
    
    if curl -s -o "docker-compose.yml" "$compose_url"; then
        echo -e "${GREEN}Docker Compose file successfully downloaded.${NC}"
        return 0
    else
        echo -e "${RED}Error downloading Docker Compose file.${NC}"
        return 1
    fi
}

# Function to create .env file
create_env_file() {
    local app_url="$1"
    local sls_mgnt_port="$2"
    local srt_player_port="$3"
    local srt_sender_port="$4"
    local sls_stats_port="$5"
    local srtla_port="$6"
    
    cat > .env << EOF
# Base URL for the application
APP_URL=$app_url

# Management UI Port
SLS_MGNT_PORT=$sls_mgnt_port

# SRT Player Port
SRT_PLAYER_PORT=$srt_player_port

# SRT Sender Port
SRT_SENDER_PORT=$srt_sender_port

# SLS Statistics Port
SLS_STATS_PORT=$sls_stats_port

# SRTla Port
SRTLA_PORT=$srtla_port
EOF
    
    echo -e "${GREEN}.env file created.${NC}"
}

# Function to create data directory
create_data_directory() {
    if [ ! -d "data" ]; then
        mkdir -p data
        echo -e "${BLUE}→ data directory created.${NC}"
        
        # Try to set owner to nobody:nobody
        if sudo chown nobody:nobody data 2>/dev/null; then
            echo -e "${GREEN}✓ data directory ownership set to nobody:nobody.${NC}"
        else
            echo -e "${YELLOW}Warning: Could not change data directory ownership. This is normal on some systems.${NC}"
        fi
    else
        echo -e "${GREEN}✓ data directory already exists${NC}"
        
        # Check and fix ownership if needed
        local current_owner=$(stat -c "%U:%G" data 2>/dev/null || echo "unknown")
        if [ "$current_owner" != "nobody:nobody" ]; then
            echo -e "${YELLOW}→ Fixing data directory ownership...${NC}"
            if sudo chown nobody:nobody data 2>/dev/null; then
                echo -e "${GREEN}✓ data directory ownership corrected to nobody:nobody.${NC}"
            else
                echo -e "${YELLOW}Warning: Could not change data directory ownership. This is normal on some systems.${NC}"
            fi
        else
            echo -e "${GREEN}✓ data directory ownership is correct${NC}"
        fi
    fi
}

# Function to start SRTla-Receiver
start_receiver() {
    check_docker
    
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${RED}docker-compose.yml file not found.${NC}"
        echo -e "Please run '${YELLOW}$0 install${NC}' first."
        exit 1
    fi
    
    if [ ! -f ".env" ]; then
        echo -e "${RED}.env file not found.${NC}"
        echo -e "Please run '${YELLOW}$0 install${NC}' first."
        exit 1
    fi
    
    echo -e "${BLUE}Starting SRTla-Receiver...${NC}"
    
    # Use Docker Compose (new or old syntax)
    if docker compose version &> /dev/null; then
        docker compose up -d
    else
        docker-compose up -d
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}SRTla-Receiver successfully started.${NC}"
        
        # Extract API key if not present
        if [ ! -f ".apikey" ]; then
            echo -e "${BLUE}Trying to extract API key...${NC}"
            extract_api_key
        else
            echo -e "${GREEN}API key already present in .apikey${NC}"
        fi
        
        # Show status
        echo -e "${BLUE}Available services:${NC}"
        if [ -f ".env" ]; then
            source .env
            echo -e "${GREEN}Management UI: http://$(get_public_ip):${SLS_MGNT_PORT:-3000}${NC}"
            echo -e "${GREEN}SRTla Port: ${SRTLA_PORT:-5000}/udp${NC}"
            echo -e "${GREEN}SRT Sender Port: ${SRT_SENDER_PORT:-4001}/udp${NC}"
            echo -e "${GREEN}SRT Player Port: ${SRT_PLAYER_PORT:-4000}/udp${NC}"
            echo -e "${GREEN}Statistics Port: ${SLS_STATS_PORT:-8080}/tcp${NC}"
        fi
    else
        echo -e "${RED}Error starting SRTla-Receiver.${NC}"
        exit 1
    fi
}

# Function to stop SRTla-Receiver
stop_receiver() {
    check_docker
    
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${YELLOW}docker-compose.yml file not found. No containers to stop.${NC}"
        return
    fi
    
    echo -e "${BLUE}Stopping SRTla-Receiver...${NC}"
    
    # Use Docker Compose (new or old syntax)
    if docker compose version &> /dev/null; then
        docker compose down
    else
        docker-compose down
    fi
    
    echo -e "${GREEN}SRTla-Receiver stopped.${NC}"
}

# Function to update SRTla-Receiver
update_receiver() {
    check_docker
    
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${RED}docker-compose.yml file not found.${NC}"
        echo -e "Please run '${YELLOW}$0 install${NC}' first."
        exit 1
    fi
    
    echo -e "${BLUE}Updating SRTla-Receiver (Version: next)...${NC}"
    
    # Download new Docker Compose file
    download_compose_file "next"
    
    # Update images
    if docker compose version &> /dev/null; then
        docker compose pull
        docker compose down
        docker compose up -d
    else
        docker-compose pull
        docker-compose down
        docker-compose up -d
    fi
    
    echo -e "${GREEN}SRTla-Receiver successfully updated.${NC}"
}

# Function to update script
update_self() {
    echo -e "${BLUE}Updating script...${NC}"

    # Create temporary backup
    local backup_file="${SCRIPT_PATH}.backup"
    cp "$SCRIPT_PATH" "$backup_file"
    echo -e "${YELLOW}Backup of current script created: $backup_file${NC}"

    # Download latest version from GitHub
    local repo_url="https://raw.githubusercontent.com/OpenIRL/srtla-receiver/refs/heads/next/receiver.sh"
    echo -e "${BLUE}Downloading latest version...${NC}"

    if curl -s -o "${SCRIPT_PATH}.new" "$repo_url"; then
        chmod +x "${SCRIPT_PATH}.new"
        mv "${SCRIPT_PATH}.new" "$SCRIPT_PATH"
        echo -e "${GREEN}Script successfully updated.${NC}"
        echo -e "${YELLOW}Please restart the script to apply the changes.${NC}"
    else
        echo -e "${RED}Error downloading the script.${NC}"
        echo -e "${YELLOW}Restoring backup...${NC}"
        mv "$backup_file" "$SCRIPT_PATH"
        echo -e "${GREEN}Backup restored.${NC}"
        exit 1
    fi
}

# Function to remove SRTla-Receiver
remove_container() {
    check_docker
    echo -e "${BLUE}Removing SRTla-Receiver containers...${NC}"

    if [ -f "docker-compose.yml" ]; then
        # Use Docker Compose (new or old syntax)
        if docker compose version &> /dev/null; then
            docker compose down --volumes --remove-orphans
        else
            docker-compose down --volumes --remove-orphans
        fi
        echo -e "${GREEN}SRTla-Receiver containers removed.${NC}"
    else
        echo -e "${YELLOW}docker-compose.yml file not found. No containers to remove.${NC}"
    fi
}

# Function to show status
show_status() {
    check_docker
    echo -e "${BLUE}SRTla-Receiver status:${NC}"

    if [ -f "docker-compose.yml" ]; then
        echo -e "${GREEN}Docker Compose file found.${NC}"
        
        # Use Docker Compose (new or old syntax)
        if docker compose version &> /dev/null; then
            docker compose ps
        else
            docker-compose ps
        fi
    else
        echo -e "${YELLOW}docker-compose.yml file not found.${NC}"
    fi

    if [ -f ".env" ]; then
        echo -e "${BLUE}Environment settings:${NC}"
        source .env
        echo -e "Base URL: ${APP_URL}"
        echo -e "Management UI Port: ${SLS_MGNT_PORT}"
        echo -e "SRTla Port: ${SRTLA_PORT}"
        echo -e "SRT Sender Port: ${SRT_SENDER_PORT}"
        echo -e "SRT Player Port: ${SRT_PLAYER_PORT}"
        echo -e "Statistics Port: ${SLS_STATS_PORT}"
    fi
    
    if [ -f ".apikey" ]; then
        echo -e "${BLUE}API Key:${NC}"
        cat .apikey
    else
        echo -e "${YELLOW}No API key found. Will be automatically extracted on next start.${NC}"
    fi
}

# Interactive installation
interactive_install() {
    # Show logo
    show_ascii_logo
    
    # Check OS compatibility first
    check_os_compatibility

    # Install Docker (only missing components)
    install_docker

    # Automatically use next version
    echo -e "${GREEN}Development version (next) will be used.${NC}"

    # Check existing installation
    echo -e "${BLUE}Checking existing installation...${NC}"
    
    local compose_exists=false
    local env_exists=false
    local data_exists=false
    local apikey_exists=false
    
    if [ -f "docker-compose.yml" ]; then
        compose_exists=true
        echo -e "${GREEN}✓ docker-compose.yml already exists${NC}"
    fi
    
    if [ -f ".env" ]; then
        env_exists=true
        echo -e "${GREEN}✓ .env file already exists${NC}"
    fi
    
    if [ -d "data" ]; then
        data_exists=true
        echo -e "${GREEN}✓ data directory already exists${NC}"
    fi
    
    if [ -f ".apikey" ]; then
        apikey_exists=true
        echo -e "${GREEN}✓ .apikey file already exists${NC}"
    fi
    
    # Handle docker-compose.yml
    if [ "$compose_exists" = "true" ]; then
        echo -e "${YELLOW}Docker Compose file already exists.${NC}"
        read -p "Do you want to update it? (y/n): " update_compose
        if [[ "$update_compose" =~ ^[Yy]$ ]]; then
            if ! download_compose_file "next"; then
                echo -e "${RED}Installation cancelled.${NC}"
                exit 1
            fi
        else
            echo -e "${BLUE}Using existing docker-compose.yml${NC}"
        fi
    else
        # Download Docker Compose file
        if ! download_compose_file "next"; then
            echo -e "${RED}Installation cancelled.${NC}"
            exit 1
        fi
    fi

    # Handle .env configuration
    if [ "$env_exists" = "true" ]; then
        echo -e "${YELLOW}.env file already exists.${NC}"
        echo -e "${BLUE}Current configuration:${NC}"
        if [ -f ".env" ]; then
            source .env
            echo -e "  ${GREEN}APP_URL:${NC} ${APP_URL}"
            echo -e "  ${GREEN}Management UI Port:${NC} ${SLS_MGNT_PORT}"
            echo -e "  ${GREEN}SRTla Port:${NC} ${SRTLA_PORT}"
            echo -e "  ${GREEN}SRT Sender Port:${NC} ${SRT_SENDER_PORT}"
            echo -e "  ${GREEN}SRT Player Port:${NC} ${SRT_PLAYER_PORT}"
            echo -e "  ${GREEN}Statistics Port:${NC} ${SLS_STATS_PORT}"
        fi
        echo
        read -p "Do you want to reconfigure? (y/n): " reconfigure
        if [[ "$reconfigure" =~ ^[Yy]$ ]]; then
            configure_environment
        else
            echo -e "${BLUE}Using existing .env configuration${NC}"
        fi
    else
        configure_environment
    fi

    # Handle data directory
    if [ "$data_exists" = "false" ]; then
        create_data_directory
    else
        echo -e "${GREEN}Using existing data directory${NC}"
    fi

    # Start services
    echo -e "${BLUE}Starting SRTla-Receiver...${NC}"
    start_receiver
    
    # Handle API key
    if [ "$apikey_exists" = "false" ]; then
        # Extract API key from logs
        extract_api_key
    else
        echo -e "${GREEN}Using existing API key from .apikey${NC}"
    fi
    
    echo -e "${BLUE}Installation/Update successfully completed!${NC}"
    if [ -f ".env" ]; then
        source .env
        echo -e "${GREEN}Management UI: http://$(get_public_ip):${SLS_MGNT_PORT:-3000}${NC}"
        echo -e "${GREEN}Backend API: ${APP_URL}${NC}"
    fi
    echo -e "${YELLOW}Use the API key from .apikey for authentication.${NC}"
}

# Function to configure environment variables
configure_environment() {
    # Get public IP
    public_ip=$(get_public_ip)
    
    # Ask for URL
    echo -e "${YELLOW}Under which address should the management interface be reachable?${NC}"
    echo -e "${BLUE}Default: $public_ip${NC}"
    read -p "Enter URL/IP (or press Enter for default): " user_input
    if [ -z "$user_input" ]; then
        user_input="$public_ip"
    fi

    # Ask for ports
    echo -e "${YELLOW}Port configuration:${NC}"
    
    read -p "Management UI Port (default: 3000): " sls_mgnt_port
    sls_mgnt_port=${sls_mgnt_port:-3000}
    
    read -p "SRTla Port (default: 5000): " srtla_port
    srtla_port=${srtla_port:-5000}
    
    read -p "SRT Sender Port (default: 4001): " srt_sender_port
    srt_sender_port=${srt_sender_port:-4001}
    
    read -p "SRT Player Port (default: 4000): " srt_player_port
    srt_player_port=${srt_player_port:-4000}
    
    read -p "Statistics Port (default: 8080): " sls_stats_port
    sls_stats_port=${sls_stats_port:-8080}

    # Create APP_URL based on user input
    # Check if user already provided a port
    if [[ "$user_input" == *":"* ]]; then
        # Port already included
        app_url="http://$user_input"
    else
        # No port provided, use statistics port (backend API)
        app_url="http://$user_input:$sls_stats_port"
    fi

    # Create .env file
    create_env_file "$app_url" "$sls_mgnt_port" "$srt_player_port" "$srt_sender_port" "$sls_stats_port" "$srtla_port"
}

# Main logic with positional parameters
case "$1" in
    install)
        interactive_install
        ;;
    start)
        start_receiver
        ;;
    stop)
        stop_receiver
        ;;
    update)
        update_receiver
        ;;
    updateself)
        update_self
        ;;
    remove)
        remove_container
        ;;
    status)
        show_status
        ;;
    reset)
        check_docker
        reset_system
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac

exit 0