#!/bin/bash

# Cluster 1 NFS Server Setup Script
# 在共用NFS伺服器上為第一座K8s集群添加專用共享目錄
# 此腳本需要在NFS伺服器上執行

set -e

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 函數：從inventory.ini讀取NFS伺服器IP
get_nfs_server_ip() {
    local inventory_file="inventory.ini"
    
    # 檢查inventory.ini是否存在
    if [[ ! -f "$inventory_file" ]]; then
        # 嘗試在上層目錄尋找
        if [[ -f "../$inventory_file" ]]; then
            inventory_file="../$inventory_file"
        elif [[ -f "../../$inventory_file" ]]; then
            inventory_file="../../$inventory_file"
        else
            echo -e "${RED}✗ 找不到inventory.ini文件${NC}"
            echo -e "${YELLOW}請確保inventory.ini文件存在於當前目錄或上層目錄${NC}"
            exit 1
        fi
    fi
    
    # 從[nfs]區段讀取IP
    local nfs_ip=$(awk '/^\[nfs\]/{flag=1; next} /^\[/{flag=0} flag && /^[0-9]/{print $1; exit}' "$inventory_file")
    
    if [[ -z "$nfs_ip" ]]; then
        echo -e "${RED}✗ 無法從inventory.ini中找到NFS伺服器IP${NC}"
        echo -e "${YELLOW}請檢查inventory.ini中的[nfs]區段${NC}"
        exit 1
    fi
    
    echo "$nfs_ip"
}

# 函數：從inventory.ini讀取集群節點IP並生成網段
get_cluster_network_config() {
    local inventory_file="inventory.ini"
    
    # 檢查inventory.ini是否存在
    if [[ ! -f "$inventory_file" ]]; then
        # 嘗試在上層目錄尋找
        if [[ -f "../$inventory_file" ]]; then
            inventory_file="../$inventory_file"
        elif [[ -f "../../$inventory_file" ]]; then
            inventory_file="../../$inventory_file"
        fi
    fi
    
    # 讀取masters和workers的IP
    local master_ips=$(awk '/^\[masters\]/{flag=1; next} /^\[/{flag=0} flag && /^[0-9]/{print $1}' "$inventory_file")
    local worker_ips=$(awk '/^\[workers\]/{flag=1; next} /^\[/{flag=0} flag && /^[0-9]/{print $1}' "$inventory_file")
    
    # 合併所有IP
    local all_ips=$(echo -e "$master_ips\n$worker_ips" | sort -u)
    
    if [[ -z "$all_ips" ]]; then
        echo -e "${RED}✗ 無法從inventory.ini中找到集群節點IP${NC}"
        exit 1
    fi
    
    # 生成單個IP的網段配置 (每個IP/32)
    local network_config=""
    for ip in $all_ips; do
        if [[ -n "$network_config" ]]; then
            network_config="${network_config},${ip}/32"
        else
            network_config="${ip}/32"
        fi
    done
    
    # 同時生成子網配置（假設都在同一個/24網段）
    local first_ip=$(echo "$all_ips" | head -n1)
    local subnet=$(echo "$first_ip" | cut -d'.' -f1-3).0/24
    
    echo "$network_config|$subnet"
}

# 函數：顯示集群信息
get_cluster_info() {
    local inventory_file="inventory.ini"
    
    # 檢查inventory.ini是否存在
    if [[ ! -f "$inventory_file" ]]; then
        # 嘗試在上層目錄尋找
        if [[ -f "../$inventory_file" ]]; then
            inventory_file="../$inventory_file"
        elif [[ -f "../../$inventory_file" ]]; then
            inventory_file="../../$inventory_file"
        fi
    fi
    
    # 讀取masters和workers的IP範圍
    local master_ips=$(awk '/^\[masters\]/{flag=1; next} /^\[/{flag=0} flag && /^[0-9]/{print $1}' "$inventory_file" | tr '\n' ' ')
    local worker_ips=$(awk '/^\[workers\]/{flag=1; next} /^\[/{flag=0} flag && /^[0-9]/{print $1}' "$inventory_file" | tr '\n' ' ')
    
    echo "Masters: $master_ips"
    echo "Workers: $worker_ips"
}

# 動態讀取配置
echo -e "${BLUE}正在從inventory.ini讀取配置...${NC}"
NFS_SERVER_IP=$(get_nfs_server_ip)
NETWORK_CONFIG=$(get_cluster_network_config)
CLUSTER1_NETWORK=$(echo "$NETWORK_CONFIG" | cut -d'|' -f1)
CLUSTER1_SUBNET=$(echo "$NETWORK_CONFIG" | cut -d'|' -f2)
CLUSTER1_SHARE_PATH="/srv/nfs/cluster1-data"

echo "=========================================="
echo "  第一座K8s集群 NFS伺服器設置"
echo "=========================================="
echo -e "${BLUE}為第一座K8s集群添加專用NFS共享${NC}"
echo -e "${BLUE}集群信息:${NC}"
get_cluster_info
echo -e "${BLUE}NFS伺服器: ${NFS_SERVER_IP}${NC}"
echo -e "${BLUE}共享路徑: ${CLUSTER1_SHARE_PATH}${NC}"

# 檢查是否在正確的伺服器上執行
CURRENT_IP=$(hostname -I | awk '{print $1}')
if [[ "$CURRENT_IP" != "$NFS_SERVER_IP" ]]; then
    echo -e "${YELLOW}警告: 當前IP ($CURRENT_IP) 不是預期的NFS伺服器IP ($NFS_SERVER_IP)${NC}"
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
    echo "# Cluster 1 NFS share - Auto-generated from inventory.ini" | sudo tee -a /etc/exports
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
echo -e "${YELLOW}NFS伺服器IP:${NC} ${NFS_SERVER_IP}"
echo -e "${YELLOW}NFS共享路徑:${NC} ${CLUSTER1_SHARE_PATH}"
echo -e "${YELLOW}允許訪問的網段:${NC} ${CLUSTER1_SUBNET}"
echo -e "${YELLOW}權限設置:${NC} rw,sync,no_subtree_check,no_root_squash"

echo -e "\n${BLUE}下一步操作:${NC}"
echo "1. 在第一座集群的所有節點上執行 cluster1-nfs-client.sh"
echo "2. 測試NFS掛載功能"
echo "3. 在Kubernetes中創建PV/PVC使用此NFS共享"

echo -e "\n${BLUE}測試命令 (在集群節點上執行):${NC}"
echo "showmount -e ${NFS_SERVER_IP}"
echo "sudo mount -t nfs ${NFS_SERVER_IP}:${CLUSTER1_SHARE_PATH} /mnt/test"

echo -e "\n${BLUE}注意事項:${NC}"
echo "- 此腳本會自動從inventory.ini讀取集群配置"
echo "- 第一座集群使用: ${CLUSTER1_SHARE_PATH}"
echo "- 第二座集群使用: /srv/nfs/kubedata (已存在)"
echo "- 兩個集群的NFS共享完全分離"
echo "- 確保所有集群節點都能訪問此NFS伺服器" 