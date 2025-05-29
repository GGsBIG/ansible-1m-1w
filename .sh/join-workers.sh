#!/bin/bash

# Worker 節點加入腳本
# 此腳本會讓 Worker 節點加入 Kubernetes 叢集

set -e

echo "=========================================="
echo "  Worker 節點加入叢集"
echo "=========================================="

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}執行 Worker 節點加入 Playbook...${NC}"
ansible-playbook -i inventory.ini playbooks/06-worker-join.yml

echo -e "\n${GREEN}✅ Worker 節點加入完成！${NC}"
echo -e "${YELLOW}注意：節點可能顯示為 NotReady，這是正常現象。${NC}"
echo "需要安裝 CNI 網路插件後節點才會變為 Ready 狀態。"

echo -e "\n${BLUE}檢查節點狀態：${NC}"
echo "ssh bbg@10.211.55.87"
echo "kubectl get nodes" 