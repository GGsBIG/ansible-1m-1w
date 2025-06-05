#!/bin/bash

# Worker Node Join Script
# This script will join worker nodes to the Kubernetes cluster

set -e

echo "=========================================="
echo "  Worker Node Join Cluster"
echo "=========================================="

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Executing worker node join playbook...${NC}"
ansible-playbook -i inventory.ini playbooks/06-worker-join.yml

echo -e "\n${GREEN}Worker node join completed!${NC}"
echo -e "${YELLOW}Note: Nodes may show as NotReady, this is normal.${NC}"
echo "CNI network plugin needs to be installed for nodes to become Ready."

echo -e "\n${BLUE}Check node status:${NC}"
echo "ssh bbg@10.6.4.213"
echo "kubectl get nodes" 