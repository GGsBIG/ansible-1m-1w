#!/bin/bash

# SSH Setup Script
# This script will execute SSH related configurations

set -e

echo "=========================================="
echo "  SSH Setup Start"
echo "=========================================="

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Executing SSH setup playbook...${NC}"
ansible-playbook -i inventory.ini playbooks/01-ssh-setup.yml

echo -e "\n${GREEN}✅ SSH setup completed!${NC}"
echo "• SSH service enabled"
echo "• Hostname configured"
echo "• Passwordless login configured"
echo "• /etc/hosts updated" 