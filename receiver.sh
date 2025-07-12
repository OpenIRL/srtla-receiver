#!/bin/bash

# Branch configuration - can be overridden by command line flag
DEFAULT_BRANCH="main"
SELECTED_BRANCH="$DEFAULT_BRANCH"

# (Function removed - replaced with inline parsing)

# Function to get the selected branch
get_branch() {
    echo "$SELECTED_BRANCH"
}

# Function to get branch display name
get_branch_display_name() {
    case "$SELECTED_BRANCH" in
        "main")
            echo "Stable (main)"
            ;;
        "next")
            echo "Beta (next)"
            ;;
        *)
            echo "Custom ($SELECTED_BRANCH)"
            ;;
    esac
}

# Color detection and setup
setup_colors() {
    # Check if stdout is a terminal and supports colors
    if [[ -t 1 ]] && command -v tput &> /dev/null && tput colors &> /dev/null && [ $(tput colors) -ge 8 ]; then
        # Bright and more readable colors
        ERROR='\033[1;31m'      # Bright Red - for errors
        SUCCESS='\033[1;32m'    # Bright Green - for success messages  
        WARNING='\033[1;33m'    # Bright Yellow - for warnings
        INFO='\033[1;36m'       # Bright Cyan - for information
        HEADER='\033[1;34m'     # Bright Blue - for headers/titles
        HIGHLIGHT='\033[1;35m'  # Bright Magenta - for highlighting important text
        MUTED='\033[0;37m'      # Light Gray - for less important text
        BOLD='\033[1m'          # Bold text
        NC='\033[0m'            # No Color/Reset
    else
        # No color support or non-terminal output
        ERROR=''
        SUCCESS=''
        WARNING=''
        INFO=''
        HEADER=''
        HIGHLIGHT=''
        MUTED=''
        BOLD=''
        NC=''
    fi
}

# Initialize colors
setup_colors

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
            echo -e "${ERROR}Cannot determine operating system. This script supports only Debian and Ubuntu.${NC}"
            exit 1
        fi
    else
        OS_ID=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
    fi

    # Check if OS is supported
    if [[ "$OS_ID" != "debian" && "$OS_ID" != "ubuntu" ]]; then
        echo -e "${ERROR}Unsupported operating system: ${HIGHLIGHT}$OS_ID${NC}"
        echo -e "${WARNING}This script is designed for Debian and Ubuntu systems only.${NC}"
        exit 1
    fi
    
    echo -e "${SUCCESS}Detected operating system: ${HIGHLIGHT}$OS_ID${NC}"
    return 0
}

show_ascii_logo() {
    echo -e "${HEADER}"
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

    echo -e "${HEADER}${BOLD}SRTla-Receiver Script${NC}"
    echo
    echo "Usage: $0 [BRANCH_OPTIONS] [COMMAND]"
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
    echo "Branch Options:"
    echo "  --use-main           Use stable version (default)"
    echo "  --use-next           Use beta version"
    echo "  --branch=BRANCH      Use specific branch"
    echo
    echo "Examples:"
    echo "  $0 install                    # Install using stable version"
    echo "  $0 --use-next install         # Install using beta version"
    echo "  $0 --branch=custom-branch update"
    echo
}

# Function to check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${ERROR}Docker is not installed.${NC}"
        echo -e "Please run '${HIGHLIGHT}$0 install${NC}' first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${ERROR}Docker Compose is not installed.${NC}"
        echo -e "Please run '${HIGHLIGHT}$0 install${NC}' first."
        exit 1
    fi
    
    echo -e "${SUCCESS}Docker and Docker Compose are installed.${NC}"
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
    
    echo -e "${INFO}Checking Docker installation status...${NC}"
    
    if [ "$docker_installed" = "true" ]; then
        echo -e "${SUCCESS}✓ Docker is already installed${NC}"
    else
        echo -e "${INFO}→ Installing Docker on ${HIGHLIGHT}$OS_ID${NC}..."
        
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
        
        echo -e "${SUCCESS}✓ Docker has been installed${NC}"
        needs_restart=true
    fi
    
    if [ "$compose_installed" = "true" ]; then
        echo -e "${SUCCESS}✓ Docker Compose is already installed${NC}"
    else
        echo -e "${INFO}→ Installing Docker Compose...${NC}"
        sudo apt-get update
        sudo apt-get install -y docker-compose-plugin
        echo -e "${SUCCESS}✓ Docker Compose has been installed${NC}"
        needs_restart=true
    fi
    
    if [ "$user_in_group" = "true" ]; then
        echo -e "${SUCCESS}✓ User is already in docker group${NC}"
    else
        echo -e "${INFO}→ Adding user to docker group...${NC}"
        sudo usermod -aG docker $USER
        echo -e "${SUCCESS}✓ User added to docker group${NC}"
        needs_restart=true
    fi
    
    if [ "$needs_restart" = "true" ]; then
        echo -e "${WARNING}Please restart your shell or run ${HIGHLIGHT}'newgrp docker'${NC}${WARNING} to activate the Docker group.${NC}"
    else
        echo -e "${SUCCESS}All Docker components are already properly installed and configured.${NC}"
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
    echo -e "${INFO}Extracting API key from container logs...${NC}"
    
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
        echo -e "${SUCCESS}API key successfully extracted and saved to .apikey${NC}"
        echo -e "${INFO}Your API key: $api_key${NC}"
        return 0
    fi
    
    # If container already exists but no API key found, it means the system was already initialized
    if [ "$container_exists" = true ]; then
        echo -e "${WARNING}Container was already started before. API key is only generated on the very first start.${NC}"
        echo -e "${WARNING}Possible solutions:${NC}"
        if docker compose version &> /dev/null; then
            echo -e "${INFO}1. Check all container logs: docker compose logs receiver | grep 'Generated default admin API key'${NC}"
        else
            echo -e "${INFO}1. Check all container logs: docker-compose logs receiver | grep 'Generated default admin API key'${NC}"
        fi
        echo -e "${INFO}2. If you need a new API key, use:${NC}"
        echo -e "${INFO}   ./receiver.sh reset${NC}"
        echo -e "${ERROR}WARNING: Resetting will delete all stored data!${NC}"
        return 1
    fi
    
    # If this is a fresh start, wait for API key generation
    local max_attempts=30
    local attempt=0
    
    echo -e "${INFO}Waiting for API key generation on first start...${NC}"
    
    # First, ensure the container is actually running
    echo -e "${INFO}Checking if container is running...${NC}"
    local container_running=false
    local startup_attempts=0
    
    while [ $startup_attempts -lt 10 ] && [ "$container_running" = false ]; do
        if docker compose version &> /dev/null; then
            if docker compose ps | grep -q "running"; then
                container_running=true
            fi
        else
            if docker-compose ps | grep -q "running"; then
                container_running=true
            fi
        fi
        
        if [ "$container_running" = false ]; then
            echo -e "${WARNING}Container still starting up... (${startup_attempts}/10)${NC}"
            sleep 2
            startup_attempts=$((startup_attempts + 1))
        fi
    done
    
    if [ "$container_running" = false ]; then
        echo -e "${ERROR}Container is not running. Cannot extract API key.${NC}"
        return 1
    fi
    
    echo -e "${SUCCESS}Container is running. Looking for API key...${NC}"
    
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
            echo -e "${SUCCESS}API key successfully extracted and saved to .apikey${NC}"
            echo -e "${INFO}Your API key: $api_key${NC}"
            return 0
        fi
        
        echo -e "${WARNING}Waiting for API key generation... (attempt $attempt/$max_attempts)${NC}"
    done
    
    echo -e "${WARNING}API key could not be automatically extracted.${NC}"
    echo -e "${WARNING}Please check the container logs manually:${NC}"
    if docker compose version &> /dev/null; then
        echo -e "${INFO}docker compose logs receiver | grep 'Generated default admin API key'${NC}"
    else
        echo -e "${INFO}docker-compose logs receiver | grep 'Generated default admin API key'${NC}"
    fi
    return 1
}

# Function to reset system for new API key
reset_system() {
    echo -e "${WARNING}WARNING: This action will delete all stored data and generate a new API key!${NC}"
    echo -e "${ERROR}All streams, users and settings will be lost!${NC}"
    echo
    read -p "Are you sure you want to reset the system? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo -e "${INFO}Reset cancelled.${NC}"
        return 1
    fi
    
    echo -e "${INFO}Resetting system...${NC}"
    
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
        echo -e "${SUCCESS}data directory removed.${NC}"
    fi
    
    # Remove API key file
    if [ -f ".apikey" ]; then
        rm -f .apikey
        echo -e "${SUCCESS}.apikey file removed.${NC}"
    fi
    
    # Recreate data directory
    create_data_directory
    
    echo -e "${SUCCESS}System successfully reset.${NC}"
    echo -e "${INFO}You can now run './receiver.sh start' to generate a new API key.${NC}"
}

# Function to download Docker Compose file
download_compose_file() {
    local compose_url="https://raw.githubusercontent.com/OpenIRL/srtla-receiver/refs/heads/$(get_branch)/docker-compose.prod.yml"
    
    echo -e "${INFO}Downloading Docker Compose file ($(get_branch_display_name))...${NC}"
    
    if curl -s -o "docker-compose.yml" "$compose_url"; then
        echo -e "${SUCCESS}Docker Compose file successfully downloaded.${NC}"
        return 0
    else
        echo -e "${ERROR}Error downloading Docker Compose file.${NC}"
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
    
    echo -e "${SUCCESS}.env file created.${NC}"
}

# Function to create data directory
create_data_directory() {
    local sls_uid=3001
    
    if [ ! -d "data" ]; then
        if mkdir -p data 2>/dev/null; then
            echo -e "${INFO}→ data directory created${NC}"
        else
            echo -e "${ERROR}ERROR: Could not create data directory${NC}"
            return 1
        fi

        if sudo chown "$sls_uid" data 2>/dev/null; then
            echo -e "${SUCCESS}✓ data directory ownership set to UID $sls_uid${NC}"
        else
            echo -e "${ERROR}ERROR: Could not change ownership to UID $sls_uid${NC}"
            return 1
        fi
        
        # Set permissions
        if chmod 755 data 2>/dev/null; then
            echo -e "${SUCCESS}✓ data directory permissions set to 755${NC}"
        fi
        
        echo -e "${SUCCESS}✓ data directory is ready${NC}"
        return 0
    else
        echo -e "${SUCCESS}✓ data directory already exists${NC}"
        
        # Check current ownership
        local current_owner=$(stat -c "%u" data 2>/dev/null || echo "unknown")
        if [ "$current_owner" != "unknown" ]; then
            echo -e "${INFO}Current owner (UID): $current_owner${NC}"

            # Fix ownership if needed
            if [ "$current_owner" != "$sls_uid" ]; then
                echo -e "${WARNING}→ Fixing data directory ownership...${NC}"
                if sudo chown "$sls_uid" data 2>/dev/null; then
                    echo -e "${SUCCESS}✓ data directory ownership corrected to UID $sls_uid${NC}"
                else
                    echo -e "${ERROR}ERROR: Could not change ownership. Current UID: $current_owner${NC}"
                    return 1
                fi
            else
                echo -e "${SUCCESS}✓ data directory ownership is correct (UID $sls_uid)${NC}"
            fi
        fi
    fi
}

# Function to start SRTla-Receiver
start_receiver() {
    check_docker
    
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${ERROR}docker-compose.yml file not found.${NC}"
        echo -e "Please run '${WARNING}$0 install${NC}' first."
        exit 1
    fi
    
    if [ ! -f ".env" ]; then
        echo -e "${ERROR}.env file not found.${NC}"
        echo -e "Please run '${WARNING}$0 install${NC}' first."
        exit 1
    fi
    
    echo -e "${INFO}Starting SRTla-Receiver...${NC}"
    
    # Use Docker Compose (new or old syntax)
    if docker compose version &> /dev/null; then
        docker compose up -d
    else
        docker-compose up -d
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${SUCCESS}SRTla-Receiver successfully started.${NC}"
        
        # Extract API key if not present
        if [ ! -f ".apikey" ]; then
            echo -e "${INFO}Waiting for containers to fully initialize...${NC}"
            sleep 5
            echo -e "${INFO}Trying to extract API key...${NC}"
            extract_api_key
        else
            echo -e "${SUCCESS}API key already present in .apikey${NC}"
        fi
        
        # Show status
        echo -e "${HEADER}Available services:${NC}"
        if [ -f ".env" ]; then
            source .env
            echo -e "${SUCCESS}Management UI: http://$(get_public_ip):${SLS_MGNT_PORT:-3000}${NC}"
            echo -e "${SUCCESS}Backend API: ${APP_URL}${NC}"
            echo -e "${SUCCESS}SRTla Port: ${SRTLA_PORT:-5000}/udp${NC}"
            echo -e "${SUCCESS}SRT Sender Port: ${SRT_SENDER_PORT:-4001}/udp${NC}"
            echo -e "${SUCCESS}SRT Player Port: ${SRT_PLAYER_PORT:-4000}/udp${NC}"
            echo -e "${SUCCESS}Statistics Port: ${SLS_STATS_PORT:-8080}/tcp${NC}"
        fi
    else
        echo -e "${ERROR}Error starting SRTla-Receiver.${NC}"
        exit 1
    fi
}

# Function to stop SRTla-Receiver
stop_receiver() {
    check_docker
    
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${WARNING}docker-compose.yml file not found. No containers to stop.${NC}"
        return
    fi
    
    echo -e "${INFO}Stopping SRTla-Receiver...${NC}"
    
    # Use Docker Compose (new or old syntax)
    if docker compose version &> /dev/null; then
        docker compose down
    else
        docker-compose down
    fi
    
    echo -e "${SUCCESS}SRTla-Receiver stopped.${NC}"
}

# Function to update SRTla-Receiver
update_receiver() {
    check_docker
    
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${ERROR}docker-compose.yml file not found.${NC}"
        echo -e "Please run '${WARNING}$0 install${NC}' first."
        exit 1
    fi
    
    echo -e "${INFO}Updating SRTla-Receiver ($(get_branch_display_name))...${NC}"
    
    # Download new Docker Compose file
    download_compose_file
    
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
    
    echo -e "${SUCCESS}SRTla-Receiver successfully updated.${NC}"
}

# Function to update script
update_self() {
    echo -e "${INFO}Updating script...${NC}"

    # Create temporary backup
    local backup_file="${SCRIPT_PATH}.backup"
    cp "$SCRIPT_PATH" "$backup_file"
    echo -e "${WARNING}Backup of current script created: $backup_file${NC}"

    # Download latest version from GitHub
    local repo_url="https://raw.githubusercontent.com/OpenIRL/srtla-receiver/refs/heads/$(get_branch)/receiver.sh"
    echo -e "${INFO}Downloading script from $(get_branch_display_name) branch...${NC}"

    if curl -s -o "${SCRIPT_PATH}.new" "$repo_url"; then
        chmod +x "${SCRIPT_PATH}.new"
        mv "${SCRIPT_PATH}.new" "$SCRIPT_PATH"
        echo -e "${SUCCESS}Script successfully updated.${NC}"
        echo -e "${WARNING}Please restart the script to apply the changes.${NC}"
    else
        echo -e "${ERROR}Error downloading the script.${NC}"
        echo -e "${WARNING}Restoring backup...${NC}"
        mv "$backup_file" "$SCRIPT_PATH"
        echo -e "${SUCCESS}Backup restored.${NC}"
        exit 1
    fi
}

# Function to remove SRTla-Receiver
remove_container() {
    check_docker
    echo -e "${INFO}Removing SRTla-Receiver containers...${NC}"

    if [ -f "docker-compose.yml" ]; then
        # Use Docker Compose (new or old syntax)
        if docker compose version &> /dev/null; then
            docker compose down --volumes --remove-orphans
        else
            docker-compose down --volumes --remove-orphans
        fi
        echo -e "${SUCCESS}SRTla-Receiver containers removed.${NC}"
    else
        echo -e "${WARNING}docker-compose.yml file not found. No containers to remove.${NC}"
    fi
}

# Function to show status
show_status() {
    check_docker
    echo -e "${HEADER}SRTla-Receiver status:${NC}"

    if [ -f "docker-compose.yml" ]; then
        echo -e "${SUCCESS}Docker Compose file found.${NC}"
        
        # Use Docker Compose (new or old syntax)
        if docker compose version &> /dev/null; then
            docker compose ps
        else
            docker-compose ps
        fi
    else
        echo -e "${WARNING}docker-compose.yml file not found.${NC}"
    fi

    if [ -f ".env" ]; then
        echo -e "${HEADER}Environment settings:${NC}"
        source .env
        echo -e "Base URL: ${APP_URL}"
        echo -e "Management UI Port: ${SLS_MGNT_PORT}"
        echo -e "SRTla Port: ${SRTLA_PORT}"
        echo -e "SRT Sender Port: ${SRT_SENDER_PORT}"
        echo -e "SRT Player Port: ${SRT_PLAYER_PORT}"
        echo -e "Statistics Port: ${SLS_STATS_PORT}"
    fi
    
    if [ -f ".apikey" ]; then
        echo -e "${HEADER}API Key:${NC}"
        cat .apikey
    else
        echo -e "${WARNING}No API key found. Will be automatically extracted on next start.${NC}"
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

    # Show selected version
    echo -e "${SUCCESS}Using $(get_branch_display_name) version.${NC}"

    # Check existing installation
    echo -e "${INFO}Checking existing installation...${NC}"
    
    local compose_exists=false
    local env_exists=false
    local data_exists=false
    local apikey_exists=false
    
    if [ -f "docker-compose.yml" ]; then
        compose_exists=true
        echo -e "${SUCCESS}✓ docker-compose.yml already exists${NC}"
    fi
    
    if [ -f ".env" ]; then
        env_exists=true
        echo -e "${SUCCESS}✓ .env file already exists${NC}"
    fi
    
    if [ -d "data" ]; then
        data_exists=true
        echo -e "${SUCCESS}✓ data directory already exists${NC}"
    fi
    
    if [ -f ".apikey" ]; then
        apikey_exists=true
        echo -e "${SUCCESS}✓ .apikey file already exists${NC}"
    fi
    
    # Handle docker-compose.yml
    if [ "$compose_exists" = "true" ]; then
        echo -e "${WARNING}Docker Compose file already exists.${NC}"
        read -p "Do you want to update it? (y/n): " update_compose
        if [[ "$update_compose" =~ ^[Yy]$ ]]; then
            if ! download_compose_file; then
                echo -e "${ERROR}Installation cancelled.${NC}"
                exit 1
            fi
        else
            echo -e "${INFO}Using existing docker-compose.yml${NC}"
        fi
    else
        # Download Docker Compose file
        if ! download_compose_file; then
            echo -e "${ERROR}Installation cancelled.${NC}"
            exit 1
        fi
    fi

    # Handle .env configuration
    if [ "$env_exists" = "true" ]; then
        echo -e "${WARNING}.env file already exists.${NC}"
        echo -e "${INFO}Current configuration:${NC}"
        if [ -f ".env" ]; then
            source .env
            echo -e "  ${SUCCESS}APP_URL:${NC} ${APP_URL}"
            echo -e "  ${SUCCESS}Management UI Port:${NC} ${SLS_MGNT_PORT}"
            echo -e "  ${SUCCESS}SRTla Port:${NC} ${SRTLA_PORT}"
            echo -e "  ${SUCCESS}SRT Sender Port:${NC} ${SRT_SENDER_PORT}"
            echo -e "  ${SUCCESS}SRT Player Port:${NC} ${SRT_PLAYER_PORT}"
            echo -e "  ${SUCCESS}Statistics Port:${NC} ${SLS_STATS_PORT}"
        fi
        echo
        read -p "Do you want to reconfigure? (y/n): " reconfigure
        if [[ "$reconfigure" =~ ^[Yy]$ ]]; then
            configure_environment
        else
            echo -e "${INFO}Using existing .env configuration${NC}"
        fi
    else
        configure_environment
    fi

    # Handle data directory
    if [ "$data_exists" = "false" ]; then
        if ! create_data_directory; then
            echo -e "${ERROR}Failed to create data directory properly.${NC}"
            echo -e "${WARNING}Docker might create it automatically when starting, but permissions may be incorrect.${NC}"
            read -p "Do you want to continue anyway? (y/n): " continue_anyway
            if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                echo -e "${ERROR}Installation cancelled.${NC}"
                exit 1
            fi
        fi
    else
        echo -e "${SUCCESS}Using existing data directory${NC}"
        # Still check and potentially fix ownership
        create_data_directory >/dev/null 2>&1 || true
    fi

    # Start services
    echo -e "${INFO}Starting SRTla-Receiver...${NC}"
    start_receiver
    
    # API key is automatically extracted by start_receiver if needed
    if [ -f ".apikey" ]; then
        echo -e "${SUCCESS}API key is ready in .apikey file${NC}"
    else
        echo -e "${WARNING}API key could not be extracted automatically.${NC}"
        echo -e "${WARNING}Check container logs or try manually: './receiver.sh status'${NC}"
    fi
    
    echo -e "${INFO}Installation/Update successfully completed!${NC}"
    echo -e "${WARNING}Use the API key from .apikey for authentication.${NC}"
}

# Function to configure environment variables
configure_environment() {
    # Get public IP
    public_ip=$(get_public_ip)
    
    # Ask for URL
    echo -e "${WARNING}Under which address should the management interface be reachable?${NC}"
    echo -e "${INFO}Default: $public_ip${NC}"
    read -p "Enter URL/IP (or press Enter for default): " user_input
    if [ -z "$user_input" ]; then
        user_input="$public_ip"
    fi

    # Ask for ports
    echo -e "${WARNING}Port configuration:${NC}"
    
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

# Parse branch arguments and get filtered command line arguments
filtered_args=()
for arg in "$@"; do
    case "$arg" in
        --branch=*)
            SELECTED_BRANCH="${arg#*=}"
            ;;
        --use-next)
            SELECTED_BRANCH="next"
            ;;
        --use-main)
            SELECTED_BRANCH="main"
            ;;
        *)
            filtered_args+=("$arg")
            ;;
    esac
done

# Set positional parameters to filtered arguments
set -- "${filtered_args[@]}"

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
        if [ -n "$1" ]; then
            echo -e "${ERROR}Unknown command: ${HIGHLIGHT}$1${NC}"
        else
            echo -e "${INFO}No command specified.${NC}"
        fi
        show_help
        exit 1
        ;;
esac

exit 0