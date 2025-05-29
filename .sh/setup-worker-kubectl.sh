#!/bin/bash

# Worker 節點 kubectl 設定腳本
# 此腳本會在 Worker 節點設定 kubectl 和自動補全

set -e

echo "=========================================="
echo "  設定 Worker 節點 kubectl"
echo "=========================================="

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}執行 Worker kubectl 設定 Playbook...${NC}"
ansible-playbook -i inventory.ini playbooks/09-worker-kubectl-setup.yml

echo -e "\n${GREEN}✅ Worker 節點 kubectl 設定完成！${NC}"
echo "• kubeconfig 已從 Master 節點複製"
echo "• kubectl 已可在 Worker 節點使用"
echo "• bash-completion 已安裝"
echo "• kubectl Tab 補全已啟用"
echo "• kubectl 別名 'k' 已設定"

echo -e "\n${BLUE}測試 Worker 節點 kubectl：${NC}"
echo "ssh bbg@10.211.55.88"
echo "kubectl get nodes"
echo "k get pods -A"

echo -e "\n${BLUE}現在所有節點都可以管理叢集！${NC}" 