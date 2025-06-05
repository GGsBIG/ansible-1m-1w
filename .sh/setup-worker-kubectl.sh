#!/bin/bash

# Worker Node kubectl Setup Script
# This script will setup kubectl and auto-completion on worker nodes

set -e

echo "=========================================="
echo "  Setup Worker Node kubectl"
echo "=========================================="

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Executing worker kubectl setup playbook...${NC}"
ansible-playbook -i inventory.ini playbooks/09-worker-kubectl-setup.yml

echo -e "\n${GREEN}Worker node kubectl setup completed!${NC}"
echo "• kubeconfig copied from Master node"
echo "• kubectl available on worker node"
echo "• bash-completion installed"
echo "• kubectl Tab completion enabled"
echo "• kubectl alias 'k' configured"

echo -e "\n${BLUE}Test worker node kubectl:${NC}"
echo "ssh bbg@10.211.55.88"
echo "kubectl get nodes"
echo "k get pods -A"

echo -e "\n${BLUE}Now all nodes can manage the cluster!${NC}" 