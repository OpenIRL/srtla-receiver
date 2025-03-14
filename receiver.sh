#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration file
CONFIG_FILE="$HOME/.srtla_receiver_config"

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
    echo "  install              Install Docker and choose SRTla-Receiver version"
    echo "  start                Start SRTla-Receiver"
    echo "  stop                 Stop SRTla-Receiver"
    echo "  update               Update SRTla-Receiver container"
    echo "  updateself           Update this script"
    echo "  remove               Remove SRTla-Receiver container"
    echo "  status               Show status of SRTla-Receiver"
    echo "  help                 Show this help"
    echo
}

# Function to check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker is not installed.${NC}"
        echo -e "Please run '${YELLOW}$0 install${NC}' first."
        exit 1
    else
        echo -e "${GREEN}Docker is installed.${NC}"
    fi
}

# Function to install Docker
install_docker() {
    # Check OS compatibility first
    check_os_compatibility
    
    echo -e "${BLUE}Installing Docker on $OS_ID...${NC}"
    
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
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io

    # Add current user to Docker group
    sudo usermod -aG docker $USER

    echo -e "${GREEN}Docker has been installed.${NC}"
    echo -e "${YELLOW}Please restart your shell or run 'newgrp docker' to activate the Docker group.${NC}"
}

# Function to write configuration
write_config() {
    local version="$1"
    echo "VERSION=$version" > "$CONFIG_FILE"
    echo -e "${GREEN}Configuration saved in $CONFIG_FILE${NC}"
}

# Function to read configuration
read_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo -e "${GREEN}Configuration loaded from $CONFIG_FILE${NC}"
        echo -e "${BLUE}Selected version: $VERSION${NC}"
    else
        echo -e "${YELLOW}No configuration file found.${NC}"
        VERSION="latest"
        echo -e "${BLUE}Using default version: $VERSION${NC}"
    fi
}

# Function to start the SRTla-Receiver
start_receiver() {
    check_docker
    read_config

    echo -e "${BLUE}Starting SRTla-Receiver (Version: $VERSION)...${NC}"

    # Check if container already exists
    if docker ps -a --format '{{.Names}}' | grep -q "^srtla-receiver$"; then
        # Check if container is running
        if docker ps --format '{{.Names}}' | grep -q "^srtla-receiver$"; then
            echo -e "${YELLOW}SRTla-Receiver container is already running.${NC}"
            return
        else
            echo -e "${YELLOW}SRTla-Receiver container exists but is not running. Restarting...${NC}"
            docker start srtla-receiver
            echo -e "${GREEN}SRTla-Receiver container has been started.${NC}"
            return
        fi
    fi

    # Create and start container
    docker run -d --restart unless-stopped --name srtla-receiver \
        -p 5000:5000/udp \
        -p 4001:4001/udp \
        -p 8080:8080 \
        ghcr.io/openirl/srtla-receiver:$VERSION

    echo -e "${GREEN}SRTla-Receiver (Version: $VERSION) has been installed and started.${NC}"
}

# Function to stop the SRTla-Receiver
stop_receiver() {
    check_docker
    echo -e "${BLUE}Stopping SRTla-Receiver...${NC}"

    if docker ps --format '{{.Names}}' | grep -q "^srtla-receiver$"; then
        docker stop srtla-receiver
        echo -e "${GREEN}SRTla-Receiver container has been stopped.${NC}"
    else
        echo -e "${YELLOW}SRTla-Receiver container is not running.${NC}"
    fi
}

# Function to remove old Docker images
remove_old_images() {
    echo -e "${BLUE}Checking for old SRTla-Receiver images...${NC}"

    # Get list of images excluding the current one we're using
    local current_image_id=$(docker images ghcr.io/openirl/srtla-receiver:$VERSION -q)
    local old_images=$(docker images ghcr.io/openirl/srtla-receiver --format "{{.ID}} {{.Repository}}:{{.Tag}}" | grep -v "$current_image_id" || true)

    if [ -n "$old_images" ]; then
        echo -e "${YELLOW}Found old SRTla-Receiver images:${NC}"
        echo "$old_images"

        # Remove old images
        echo -e "${BLUE}Removing old images...${NC}"
        docker images ghcr.io/openirl/srtla-receiver --format "{{.ID}}" | grep -v "$current_image_id" | xargs -r docker rmi

        echo -e "${GREEN}Old images have been removed.${NC}"
    else
        echo -e "${GREEN}No old images found.${NC}"
    fi
}

# Function to update the SRTla-Receiver
update_receiver() {
    check_docker
    read_config

    echo -e "${BLUE}Updating SRTla-Receiver (Version: $VERSION)...${NC}"

    # Update Docker image
    docker pull ghcr.io/openirl/srtla-receiver:$VERSION

    # Stop and remove container if it exists
    if docker ps -a --format '{{.Names}}' | grep -q "^srtla-receiver$"; then
        echo -e "${YELLOW}Stopping existing SRTla-Receiver container...${NC}"
        docker stop srtla-receiver
        docker rm srtla-receiver
        echo -e "${GREEN}Existing container has been removed.${NC}"
    fi

    # Start container using the start_receiver function
    start_receiver

    # Remove old images
    remove_old_images
}

# Function to update the script
update_self() {
    echo -e "${BLUE}Updating the script...${NC}"

    # Create a temporary backup
    local backup_file="${SCRIPT_PATH}.backup"
    cp "$SCRIPT_PATH" "$backup_file"
    echo -e "${YELLOW}Backup of current script created: $backup_file${NC}"

    # Download the latest version from GitHub (This is an example - please replace with the actual URL)
    # The following is a placeholder and must be adapted
    local repo_url="https://raw.githubusercontent.com/OpenIRL/srtla-receiver/refs/heads/$VERSION/receiver.sh"
    echo -e "${BLUE}Downloading latest version...${NC}"

    if curl -s -o "${SCRIPT_PATH}.new" "$repo_url"; then
        chmod +x "${SCRIPT_PATH}.new"
        mv "${SCRIPT_PATH}.new" "$SCRIPT_PATH"
        echo -e "${GREEN}Script has been successfully updated.${NC}"
        echo -e "${YELLOW}Please restart the script to apply the changes.${NC}"
    else
        echo -e "${RED}Error downloading the script.${NC}"
        echo -e "${YELLOW}Restoring backup...${NC}"
        mv "$backup_file" "$SCRIPT_PATH"
        echo -e "${GREEN}Backup restored.${NC}"
        exit 1
    fi
}

# Function to remove the SRTla-Receiver
remove_container() {
    check_docker
    echo -e "${BLUE}Removing SRTla-Receiver container...${NC}"

    if docker ps -a --format '{{.Names}}' | grep -q "^srtla-receiver$"; then
        docker rm -f srtla-receiver
        echo -e "${GREEN}SRTla-Receiver container has been removed.${NC}"
    else
        echo -e "${YELLOW}SRTla-Receiver container does not exist.${NC}"
    fi
}

# Function to display status
show_status() {
    check_docker
    echo -e "${BLUE}Status of SRTla-Receiver:${NC}"

    if docker ps -a --format '{{.Names}}' | grep -q "^srtla-receiver$"; then
        echo -e "${GREEN}SRTla-Receiver container exists.${NC}"
        docker ps -a --filter "name=srtla-receiver" --format "Status: {{.Status}}\nImage: {{.Image}}\nPorts: {{.Ports}}"
    else
        echo -e "${YELLOW}SRTla-Receiver container does not exist.${NC}"
    fi

    if [ -f "$CONFIG_FILE" ]; then
        read_config
    fi
}

# Interactive installation
interactive_install() {
    # Show logo
    show_ascii_logo
    
    # Check OS compatibility first
    check_os_compatibility

    # Install Docker
    install_docker

    # Ask for version
    echo -e "${YELLOW}Which version of SRTla-Receiver would you like to install?${NC}"
    echo "1) Stable version (latest)"
    echo "2) Development version (next)"
    echo "3) Cancel"
    read -p "Please choose (1-3): " choice

    case $choice in
        1)
            write_config "latest"
            echo -e "${GREEN}Configuration for stable version saved.${NC}"
            ;;
        2)
            write_config "next"
            echo -e "${GREEN}Configuration for development version saved.${NC}"
            ;;
        3)
            echo -e "${BLUE}Installation cancelled.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid selection.${NC}"
            show_help
            exit 1
            ;;
    esac

    # Ask if the receiver should be started immediately
    echo -e "${YELLOW}Would you like to start the SRTla-Receiver now?${NC}"
    echo "1) Yes"
    echo "2) No"
    read -p "Please choose (1-2): " start_choice

    if [ "$start_choice" = "1" ]; then
        start_receiver
    else
        echo -e "${BLUE}You can start the SRTla-Receiver later with '$0 start'.${NC}"
    fi
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