#!/bin/bash

# SSH Setup Script for RHEL 8.10
# This script will execute SSH related configurations

set -e

echo "=========================================="
echo "  SSH Setup Start (RHEL 8.10)"
echo "=========================================="

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function: Display success message
show_success() {
    echo -e "\n${GREEN}$1${NC}\n"
}

# Function: Display warning message
show_warning() {
    echo -e "\n${YELLOW}$1${NC}\n"
}

# Function: Display error message
show_error() {
    echo -e "\n${RED}$1${NC}\n"
}

# Function: Install Ansible for RHEL 8.10
install_ansible() {
    echo -e "${BLUE}Installing Ansible on RHEL 8.10...${NC}"

    # Enable EPEL and install Ansible
    sudo dnf install -y epel-release
    sudo dnf install -y ansible

    # Verify installation
    if command -v ansible-playbook &> /dev/null; then
        show_success "Ansible installed successfully!"
        echo -e "${BLUE}Ansible version:${NC}"
        ansible --version | head -1
    else
        show_error "Ansible installation failed!"
        exit 1
    fi
}

# Check if inventory.ini exists
if [ ! -f "inventory.ini" ]; then
    show_error "inventory.ini file not found! Please make sure you are running this script in the correct directory."
    exit 1
fi

# Check if Ansible is installed, if not, install it automatically
if ! command -v ansible-playbook &> /dev/null; then
    show_warning "Ansible not installed, installing automatically..."
    install_ansible
else
    echo -e "${GREEN}Ansible is already installed${NC}"
    echo -e "${BLUE}Ansible version:${NC}"
    ansible --version | head -1
fi

echo -e "${BLUE}Executing SSH setup playbook...${NC}"
ansible-playbook -i inventory.ini playbooks/01-ssh-setup.yml

echo -e "\n${GREEN}SSH setup completed!${NC}"
echo "• SSH service enabled"
echo "• Hostname configured"
echo "• Passwordless login configured"
echo "• /etc/hosts updated"
