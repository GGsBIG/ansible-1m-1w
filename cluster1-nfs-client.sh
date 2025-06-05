#!/bin/bash

# Cluster 1 NFS Client Setup Script
# 第一座K8s集群專用的NFS客戶端設置腳本
# 集群範圍: 10.6.4.213-219 (Masters: 213-215, Workers: 217-219)
# NFS Server: 10.6.4.220

set -e

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 配置變數
NFS_SERVER="10.6.4.220"
NFS_SHARE_PATH="/srv/nfs/cluster1-data"
LOCAL_MOUNT_POINT="/mnt/cluster1-nfs"
CLUSTER_NAME="cluster1"

echo "=========================================="
echo "  第一座K8s集群 NFS客戶端設置"
echo "=========================================="
echo -e "${BLUE}集群範圍: 10.6.4.213-219${NC}"
echo -e "${BLUE}NFS伺服器: ${NFS_SERVER}${NC}"
echo -e "${BLUE}共享路徑: ${NFS_SHARE_PATH}${NC}"

# 步驟1: 安裝NFS客戶端工具
echo -e "\n${BLUE}步驟1: 安裝NFS客戶端工具...${NC}"
sudo apt update
sudo apt install -y nfs-common

# 步驟2: 創建本地掛載點
echo -e "\n${BLUE}步驟2: 創建本地掛載點...${NC}"
sudo mkdir -p ${LOCAL_MOUNT_POINT}

# 步驟3: 測試NFS連接
echo -e "\n${BLUE}步驟3: 測試NFS伺服器連接...${NC}"
if ping -c 3 ${NFS_SERVER} > /dev/null 2>&1; then
    echo -e "${GREEN}✓ NFS伺服器 ${NFS_SERVER} 連接正常${NC}"
else
    echo -e "${RED}✗ 無法連接到NFS伺服器 ${NFS_SERVER}${NC}"
    exit 1
fi

# 步驟4: 檢查NFS服務可用性
echo -e "\n${BLUE}步驟4: 檢查NFS服務可用性...${NC}"
if showmount -e ${NFS_SERVER} > /dev/null 2>&1; then
    echo -e "${GREEN}✓ NFS服務運行正常${NC}"
    echo -e "${YELLOW}可用的NFS共享:${NC}"
    showmount -e ${NFS_SERVER}
else
    echo -e "${RED}✗ NFS服務不可用或無共享目錄${NC}"
    echo -e "${YELLOW}請確認NFS伺服器已正確配置${NC}"
    exit 1
fi

# 步驟5: 掛載NFS共享
echo -e "\n${BLUE}步驟5: 掛載NFS共享...${NC}"
if sudo mount -t nfs ${NFS_SERVER}:${NFS_SHARE_PATH} ${LOCAL_MOUNT_POINT}; then
    echo -e "${GREEN}✓ NFS共享掛載成功${NC}"
else
    echo -e "${RED}✗ NFS共享掛載失敗${NC}"
    echo -e "${YELLOW}嘗試創建共享目錄...${NC}"
    
    # 嘗試在NFS伺服器上創建目錄（如果有SSH訪問權限）
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no gravity@${NFS_SERVER} "sudo mkdir -p ${NFS_SHARE_PATH} && sudo chown nobody:nogroup ${NFS_SHARE_PATH} && sudo chmod 755 ${NFS_SHARE_PATH}" 2>/dev/null; then
        echo -e "${GREEN}✓ 在NFS伺服器上創建了共享目錄${NC}"
        
        # 重新嘗試掛載
        if sudo mount -t nfs ${NFS_SERVER}:${NFS_SHARE_PATH} ${LOCAL_MOUNT_POINT}; then
            echo -e "${GREEN}✓ NFS共享掛載成功${NC}"
        else
            echo -e "${RED}✗ 仍然無法掛載NFS共享${NC}"
            exit 1
        fi
    else
        echo -e "${RED}✗ 無法創建共享目錄，請手動在NFS伺服器上執行:${NC}"
        echo "sudo mkdir -p ${NFS_SHARE_PATH}"
        echo "sudo chown nobody:nogroup ${NFS_SHARE_PATH}"
        echo "sudo chmod 755 ${NFS_SHARE_PATH}"
        exit 1
    fi
fi

# 步驟6: 測試讀寫功能
echo -e "\n${BLUE}步驟6: 測試NFS讀寫功能...${NC}"
TEST_FILE="${LOCAL_MOUNT_POINT}/test-$(hostname)-$(date +%s).txt"
TEST_CONTENT="Hello from ${CLUSTER_NAME} cluster node $(hostname) at $(date)"

if echo "${TEST_CONTENT}" | sudo tee ${TEST_FILE} > /dev/null; then
    echo -e "${GREEN}✓ 寫入測試成功${NC}"
    
    if cat ${TEST_FILE} > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 讀取測試成功${NC}"
        echo -e "${YELLOW}測試內容: $(cat ${TEST_FILE})${NC}"
    else
        echo -e "${RED}✗ 讀取測試失敗${NC}"
    fi
    
    # 清理測試文件
    sudo rm -f ${TEST_FILE}
else
    echo -e "${RED}✗ 寫入測試失敗${NC}"
fi

# 步驟7: 配置永久掛載（可選）
echo -e "\n${BLUE}步驟7: 配置永久掛載...${NC}"
FSTAB_ENTRY="${NFS_SERVER}:${NFS_SHARE_PATH} ${LOCAL_MOUNT_POINT} nfs defaults,_netdev 0 0"

if grep -q "${NFS_SERVER}:${NFS_SHARE_PATH}" /etc/fstab; then
    echo -e "${YELLOW}⚠ /etc/fstab中已存在此NFS掛載項目${NC}"
else
    read -p "是否要將NFS掛載添加到/etc/fstab以實現開機自動掛載? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "${FSTAB_ENTRY}" | sudo tee -a /etc/fstab
        echo -e "${GREEN}✓ 已添加到/etc/fstab${NC}"
    else
        echo -e "${YELLOW}跳過永久掛載配置${NC}"
    fi
fi

# 步驟8: 卸載測試掛載
echo -e "\n${BLUE}步驟8: 清理測試掛載...${NC}"
if mountpoint -q ${LOCAL_MOUNT_POINT}; then
    sudo umount ${LOCAL_MOUNT_POINT}
    echo -e "${GREEN}✓ 已卸載NFS共享${NC}"
fi

# 步驟9: 顯示使用說明
echo -e "\n${GREEN}=========================================="
echo "  第一座K8s集群 NFS客戶端設置完成!"
echo "==========================================${NC}"

echo -e "\n${BLUE}使用說明:${NC}"
echo -e "${YELLOW}手動掛載:${NC}"
echo "sudo mount -t nfs ${NFS_SERVER}:${NFS_SHARE_PATH} ${LOCAL_MOUNT_POINT}"

echo -e "\n${YELLOW}手動卸載:${NC}"
echo "sudo umount ${LOCAL_MOUNT_POINT}"

echo -e "\n${YELLOW}檢查掛載狀態:${NC}"
echo "df -h | grep nfs"
echo "mount | grep nfs"

echo -e "\n${YELLOW}在Kubernetes中使用:${NC}"
echo "可以創建PV/PVC使用此NFS共享"
echo "NFS伺服器: ${NFS_SERVER}"
echo "共享路徑: ${NFS_SHARE_PATH}"

echo -e "\n${BLUE}注意事項:${NC}"
echo "- 此腳本專為第一座K8s集群(10.6.4.213-219)設計"
echo "- NFS共享路徑為: ${NFS_SHARE_PATH}"
echo "- 與第二座集群的NFS共享完全分離"
echo "- 確保所有集群節點都執行此腳本" 