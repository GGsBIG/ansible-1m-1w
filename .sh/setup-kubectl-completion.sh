#!/bin/bash

# kubectl 自動補全設定腳本
# 此腳本會在 Master 節點設定 kubectl 自動補全和別名

set -e

echo "=========================================="
echo "  設定 kubectl 自動補全和別名"
echo "=========================================="

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}執行 kubectl 補全設定 Playbook...${NC}"
ansible-playbook -i inventory.ini playbooks/08-kubectl-completion.yml

echo -e "\n${GREEN}✅ kubectl 自動補全設定完成！${NC}"
echo "• bash-completion 已安裝"
echo "• kubectl Tab 補全已啟用"
echo "• kubectl 別名 'k' 已設定"
echo "• 別名 'k' 也支援 Tab 補全"

echo -e "\n${BLUE}使用方法：${NC}"
echo "kubectl des<TAB>     → kubectl describe"
echo "kubectl get po<TAB>  → kubectl get pods"
echo "k get nodes          → 使用別名"
echo "k des<TAB>           → k describe"

echo -e "\n${BLUE}測試自動補全：${NC}"
echo "ssh bbg@10.211.55.87"
echo "kubectl get <TAB><TAB>  # 顯示可用資源"
echo "k get <TAB><TAB>        # 使用別名測試" 