#!/bin/bash

# SSH 設定腳本
# 此腳本會執行 SSH 相關設定

set -e

echo "=========================================="
echo "  SSH 設定開始"
echo "=========================================="

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}執行 SSH 設定 Playbook...${NC}"
ansible-playbook -i inventory.ini playbooks/01-ssh-setup.yml

echo -e "\n${GREEN}✅ SSH 設定完成！${NC}"
echo "• SSH 服務已啟用"
echo "• 主機名稱已設定"
echo "• 免密碼登入已設定"
echo "• /etc/hosts 已更新" 