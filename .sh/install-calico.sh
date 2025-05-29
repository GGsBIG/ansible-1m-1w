#!/bin/bash

# Calico CNI 安裝腳本
# 此腳本會安裝 Calico 網路插件

set -e

echo "=========================================="
echo "  安裝 Calico CNI 網路插件"
echo "=========================================="

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}執行 Calico 安裝 Playbook...${NC}"
ansible-playbook -i inventory.ini playbooks/07-install-calico.yml

echo -e "\n${GREEN}✅ Calico CNI 安裝完成！${NC}"
echo "• Tigera Operator 已部署"
echo "• Calico CNI 已安裝"
echo "• Pod CIDR: 10.244.0.0/16"
echo "• 支援 NetworkPolicy 功能"

echo -e "\n${BLUE}檢查 Calico 狀態：${NC}"
echo "kubectl get pods -n calico-system"
echo "kubectl get nodes"

echo -e "\n${YELLOW}等待所有節點變為 Ready 狀態...${NC}" 