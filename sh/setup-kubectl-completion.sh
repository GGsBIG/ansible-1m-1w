#!/bin/bash

# kubectl Auto-completion Setup Script
# This script will setup kubectl auto-completion and aliases on Master node

set -e

echo "=========================================="
echo "  Setup kubectl Auto-completion and Aliases"
echo "=========================================="

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Executing kubectl completion setup playbook...${NC}"
ansible-playbook -i inventory.ini playbooks/08-kubectl-completion.yml

echo -e "\n${GREEN}kubectl auto-completion setup completed!${NC}"
echo "• bash-completion installed"
echo "• kubectl Tab completion enabled"
echo "• kubectl alias 'k' configured"
echo "• Alias 'k' also supports Tab completion"

echo -e "\n${BLUE}Usage:${NC}"
echo "kubectl des<TAB>     → kubectl describe"
echo "kubectl get po<TAB>  → kubectl get pods"
echo "k get nodes          → Use alias"
echo "k des<TAB>           → k describe"

echo -e "\n${BLUE}Test auto-completion:${NC}"
echo "ssh bbg@10.211.55.87"
echo "kubectl get <TAB><TAB>  # Show available resources"
echo "k get <TAB><TAB>        # Test using alias" 