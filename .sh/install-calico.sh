#!/bin/bash

# Calico CNI Installation Script
# This script will install Calico network plugin

set -e

echo "=========================================="
echo "  Install Calico CNI Network Plugin"
echo "=========================================="

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Executing Calico installation playbook...${NC}"
ansible-playbook -i inventory.ini playbooks/07-install-calico.yml

echo -e "\n${GREEN}✅ Calico CNI installation completed!${NC}"
echo "• Tigera Operator deployed"
echo "• Calico CNI installed"
echo "• Pod CIDR: 10.244.0.0/16"
echo "• NetworkPolicy support enabled"

echo -e "\n${BLUE}Check Calico status:${NC}"
echo "kubectl get pods -n calico-system"
echo "kubectl get nodes"

echo -e "\n${YELLOW}Waiting for all nodes to become Ready...${NC}" 