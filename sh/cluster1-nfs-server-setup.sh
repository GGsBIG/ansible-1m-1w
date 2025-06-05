#!/bin/bash

# Cluster 1 NFS Server Setup Script
# 在共用NFS伺服器(10.6.4.220)上為第一座K8s集群添加專用共享目錄
# 此腳本需要在NFS伺服器上執行

set -e

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 配置變數
CLUSTER1_SHARE_PATH="/srv/nfs/cluster1-data"
CLUSTER1_NETWORK="10.6.4.213/32,10.6.4.214/32,10.6.4.215/32,10.6.4.217/32,10.6.4.218/32,10.6.4.219/32"
CLUSTER1_SUBNET="10.6.4.0/24"

echo "=========================================="
echo "  第一座K8s集群 NFS伺服器設置"
echo "=========================================="
echo -e "${BLUE}為第一座K8s集群添加專用NFS共享${NC}"
echo -e "${BLUE}集群節點: 10.6.4.213-215 (masters), 10.6.4.217-219 (workers)${NC}"
echo -e "${BLUE}共享路徑: ${CLUSTER1_SHARE_PATH}${NC}"

# 檢查是否在正確的伺服器上執行
CURRENT_IP=$(hostname -I | awk '{print $1}')
if [[ "$CURRENT_IP" != "10.6.4.220" ]]; then
    echo -e "${YELLOW}警告: 當前IP ($CURRENT_IP) 不是預期的NFS伺服器IP (10.6.4.220)${NC}"
    read -p "是否繼續執行? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}腳本已取消${NC}"
        exit 0
    fi
fi

# 步驟1: 檢查NFS服務狀態
echo -e "\n${BLUE}步驟1: 檢查NFS服務狀態...${NC}"
if systemctl is-active --quiet nfs-kernel-server; then
    echo -e "${GREEN}✓ NFS服務運行中${NC}"
else
    echo -e "${RED}✗ NFS服務未運行${NC}"
    echo -e "${YELLOW}嘗試啟動NFS服務...${NC}"
    sudo systemctl start nfs-kernel-server
    sudo systemctl enable nfs-kernel-server
    
    if systemctl is-active --quiet nfs-kernel-server; then
        echo -e "${GREEN}✓ NFS服務已啟動${NC}"
    else
        echo -e "${RED}✗ 無法啟動NFS服務${NC}"
        exit 1
    fi
fi

# 步驟2: 創建第一座集群專用共享目錄
echo -e "\n${BLUE}步驟2: 創建第一座集群專用共享目錄...${NC}"
if [[ -d "${CLUSTER1_SHARE_PATH}" ]]; then
    echo -e "${YELLOW}⚠ 目錄 ${CLUSTER1_SHARE_PATH} 已存在${NC}"
else
    sudo mkdir -p ${CLUSTER1_SHARE_PATH}
    echo -e "${GREEN}✓ 已創建目錄 ${CLUSTER1_SHARE_PATH}${NC}"
fi

# 設置目錄權限
sudo chown nobody:nogroup ${CLUSTER1_SHARE_PATH}
sudo chmod 755 ${CLUSTER1_SHARE_PATH}
echo -e "${GREEN}✓ 已設置目錄權限${NC}"

# 步驟3: 備份現有的exports配置
echo -e "\n${BLUE}步驟3: 備份現有的exports配置...${NC}"
if [[ -f /etc/exports ]]; then
    sudo cp /etc/exports /etc/exports.backup.$(date +%Y%m%d_%H%M%S)
    echo -e "${GREEN}✓ 已備份 /etc/exports${NC}"
fi

# 步驟4: 更新exports配置
echo -e "\n${BLUE}步驟4: 更新exports配置...${NC}"
CLUSTER1_EXPORT_ENTRY="${CLUSTER1_SHARE_PATH} ${CLUSTER1_SUBNET}(rw,sync,no_subtree_check,no_root_squash)"

if grep -q "${CLUSTER1_SHARE_PATH}" /etc/exports; then
    echo -e "${YELLOW}⚠ /etc/exports中已存在第一座集群的配置${NC}"
else
    echo "# Cluster 1 (10.6.4.213-219) NFS share" | sudo tee -a /etc/exports
    echo "${CLUSTER1_EXPORT_ENTRY}" | sudo tee -a /etc/exports
    echo -e "${GREEN}✓ 已添加第一座集群的exports配置${NC}"
fi

# 步驟5: 顯示當前exports配置
echo -e "\n${BLUE}步驟5: 當前exports配置:${NC}"
echo -e "${YELLOW}$(cat /etc/exports)${NC}"

# 步驟6: 重新載入exports配置
echo -e "\n${BLUE}步驟6: 重新載入exports配置...${NC}"
sudo exportfs -rav
echo -e "${GREEN}✓ exports配置已重新載入${NC}"

# 步驟7: 重啟NFS服務
echo -e "\n${BLUE}步驟7: 重啟NFS服務...${NC}"
sudo systemctl restart nfs-kernel-server
echo -e "${GREEN}✓ NFS服務已重啟${NC}"

# 步驟8: 驗證配置
echo -e "\n${BLUE}步驟8: 驗證NFS配置...${NC}"
echo -e "${YELLOW}當前NFS exports:${NC}"
sudo exportfs -v

echo -e "\n${YELLOW}可用的NFS共享:${NC}"
showmount -e localhost

# 步驟9: 檢查防火牆設置
echo -e "\n${BLUE}步驟9: 檢查防火牆設置...${NC}"
if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
    echo -e "${YELLOW}檢測到UFW防火牆已啟用${NC}"
    
    # 檢查是否已有NFS規則
    if ufw status | grep -q "2049"; then
        echo -e "${GREEN}✓ NFS端口規則已存在${NC}"
    else
        echo -e "${YELLOW}添加NFS防火牆規則...${NC}"
        sudo ufw allow from ${CLUSTER1_SUBNET} to any port nfs
        sudo ufw allow from ${CLUSTER1_SUBNET} to any port 111 proto tcp
        sudo ufw reload
        echo -e "${GREEN}✓ 已添加NFS防火牆規則${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 未檢測到活動的UFW防火牆${NC}"
fi

# 步驟10: 創建測試文件
echo -e "\n${BLUE}步驟10: 創建測試文件...${NC}"
TEST_FILE="${CLUSTER1_SHARE_PATH}/cluster1-test.txt"
echo "This is a test file for Cluster 1 NFS share - Created at $(date)" | sudo tee ${TEST_FILE}
echo -e "${GREEN}✓ 已創建測試文件: ${TEST_FILE}${NC}"

# 完成設置
echo -e "\n${GREEN}=========================================="
echo "  第一座K8s集群 NFS伺服器設置完成!"
echo "==========================================${NC}"

echo -e "\n${BLUE}配置摘要:${NC}"
echo -e "${YELLOW}NFS共享路徑:${NC} ${CLUSTER1_SHARE_PATH}"
echo -e "${YELLOW}允許訪問的網段:${NC} ${CLUSTER1_SUBNET}"
echo -e "${YELLOW}權限設置:${NC} rw,sync,no_subtree_check,no_root_squash"

echo -e "\n${BLUE}下一步操作:${NC}"
echo "1. 在第一座集群的所有節點上執行 cluster1-nfs-client.sh"
echo "2. 測試NFS掛載功能"
echo "3. 在Kubernetes中創建PV/PVC使用此NFS共享"

echo -e "\n${BLUE}測試命令 (在集群節點上執行):${NC}"
echo "showmount -e 10.6.4.220"
echo "sudo mount -t nfs 10.6.4.220:${CLUSTER1_SHARE_PATH} /mnt/test"

echo -e "\n${BLUE}注意事項:${NC}"
echo "- 第一座集群使用: ${CLUSTER1_SHARE_PATH}"
echo "- 第二座集群使用: /srv/nfs/kubedata (已存在)"
echo "- 兩個集群的NFS共享完全分離"
echo "- 確保所有集群節點都能訪問此NFS伺服器" 