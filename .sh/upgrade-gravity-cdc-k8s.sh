#!/bin/bash

# Kubernetes Node Upgrade Script for gravity-cdc
# 將gravity-cdc節點從v1.28.15升級到v1.31.0
# 此腳本需要在gravity-cdc節點上執行

set -e

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 配置變數
TARGET_VERSION="1.31.0-1.1"
CURRENT_NODE=$(hostname)

echo "=========================================="
echo "  Kubernetes節點升級腳本"
echo "=========================================="
echo -e "${BLUE}目標節點: ${CURRENT_NODE}${NC}"
echo -e "${BLUE}目標版本: v1.31.0${NC}"
echo -e "${BLUE}當前時間: $(date)${NC}"

# 檢查是否為gravity-cdc節點
if [[ "$CURRENT_NODE" != "gravity-cdc" ]]; then
    echo -e "${RED}錯誤: 此腳本只能在gravity-cdc節點上執行${NC}"
    echo -e "${YELLOW}當前節點: $CURRENT_NODE${NC}"
    exit 1
fi

# 檢查是否有sudo權限
if ! sudo -n true 2>/dev/null; then
    echo -e "${RED}錯誤: 需要sudo權限執行此腳本${NC}"
    exit 1
fi

# 步驟1: 檢查當前版本
echo -e "\n${BLUE}步驟1: 檢查當前Kubernetes版本...${NC}"
CURRENT_KUBELET_VERSION=$(kubelet --version | awk '{print $2}')
CURRENT_KUBEADM_VERSION=$(kubeadm version -o short)
CURRENT_KUBECTL_VERSION=$(kubectl version --client -o yaml | grep gitVersion | awk '{print $2}')

echo -e "${YELLOW}當前版本:${NC}"
echo -e "  kubelet: ${CURRENT_KUBELET_VERSION}"
echo -e "  kubeadm: ${CURRENT_KUBEADM_VERSION}"
echo -e "  kubectl: ${CURRENT_KUBECTL_VERSION}"

# 步驟2: 檢查套件hold狀態
echo -e "\n${BLUE}步驟2: 檢查套件hold狀態...${NC}"
HOLD_STATUS=$(apt-mark showhold | grep -E "(kubelet|kubeadm|kubectl)" || true)
if [[ -n "$HOLD_STATUS" ]]; then
    echo -e "${YELLOW}當前hold的套件:${NC}"
    echo "$HOLD_STATUS"
else
    echo -e "${GREEN}沒有套件被hold${NC}"
fi

# 步驟3: Unhold Kubernetes套件
echo -e "\n${BLUE}步驟3: 解除Kubernetes套件的hold狀態...${NC}"
sudo apt-mark unhold kubelet kubeadm kubectl
echo -e "${GREEN}✓ 已解除hold狀態${NC}"

# 步驟4: 更新套件列表
echo -e "\n${BLUE}步驟4: 更新套件列表...${NC}"
sudo apt update
echo -e "${GREEN}✓ 套件列表已更新${NC}"

# 步驟5: 檢查可用版本
echo -e "\n${BLUE}步驟5: 檢查可用的Kubernetes版本...${NC}"
echo -e "${YELLOW}可用的kubeadm版本:${NC}"
apt-cache madison kubeadm | grep -E "1\.31\." | head -5

# 動態檢測正確版本格式
detect_correct_version

# 步驟6: 升級kubeadm
echo -e "\n${BLUE}步驟6: 升級kubeadm到v1.31.0...${NC}"
echo -e "${YELLOW}使用版本: ${TARGET_VERSION}${NC}"
sudo apt install -y kubeadm=${TARGET_VERSION}
echo -e "${GREEN}✓ kubeadm升級完成${NC}"

# 驗證kubeadm版本
NEW_KUBEADM_VERSION=$(kubeadm version -o short)
echo -e "${YELLOW}新的kubeadm版本: ${NEW_KUBEADM_VERSION}${NC}"

# 步驟7: 驗證升級計劃
echo -e "\n${BLUE}步驟7: 驗證升級計劃...${NC}"
echo -e "${YELLOW}檢查升級計劃:${NC}"
sudo kubeadm upgrade plan

# 步驟8: 執行節點升級
echo -e "\n${BLUE}步驟8: 執行節點升級...${NC}"
echo -e "${YELLOW}正在升級節點配置...${NC}"
sudo kubeadm upgrade node
echo -e "${GREEN}✓ 節點配置升級完成${NC}"

# 步驟9: 升級kubelet和kubectl
echo -e "\n${BLUE}步驟9: 升級kubelet和kubectl...${NC}"
sudo apt install -y kubelet=${TARGET_VERSION} kubectl=${TARGET_VERSION}
echo -e "${GREEN}✓ kubelet和kubectl升級完成${NC}"

# 步驟10: 重啟kubelet服務
echo -e "\n${BLUE}步驟10: 重啟kubelet服務...${NC}"
sudo systemctl daemon-reload
sudo systemctl restart kubelet
echo -e "${GREEN}✓ kubelet服務已重啟${NC}"

# 步驟11: 檢查kubelet狀態
echo -e "\n${BLUE}步驟11: 檢查kubelet服務狀態...${NC}"
if systemctl is-active --quiet kubelet; then
    echo -e "${GREEN}✓ kubelet服務運行正常${NC}"
else
    echo -e "${RED}✗ kubelet服務異常${NC}"
    echo -e "${YELLOW}檢查服務狀態:${NC}"
    systemctl status kubelet --no-pager
fi

# 步驟12: 重新hold套件
echo -e "\n${BLUE}步驟12: 重新hold Kubernetes套件...${NC}"
sudo apt-mark hold kubelet kubeadm kubectl
echo -e "${GREEN}✓ 已重新hold套件${NC}"

# 步驟13: 驗證升級結果
echo -e "\n${BLUE}步驟13: 驗證升級結果...${NC}"
NEW_KUBELET_VERSION=$(kubelet --version | awk '{print $2}')
NEW_KUBEADM_VERSION=$(kubeadm version -o short)
NEW_KUBECTL_VERSION=$(kubectl version --client -o yaml | grep gitVersion | awk '{print $2}')

echo -e "${YELLOW}升級後版本:${NC}"
echo -e "  kubelet: ${NEW_KUBELET_VERSION}"
echo -e "  kubeadm: ${NEW_KUBEADM_VERSION}"
echo -e "  kubectl: ${NEW_KUBECTL_VERSION}"

# 步驟14: 等待節點就緒
echo -e "\n${BLUE}步驟14: 等待節點重新加入集群...${NC}"
echo -e "${YELLOW}請稍等，節點正在重新註冊到集群...${NC}"

# 等待一段時間讓節點重新註冊
sleep 30

# 完成升級
echo -e "\n${GREEN}=========================================="
echo "  Kubernetes節點升級完成!"
echo "==========================================${NC}"

echo -e "\n${BLUE}升級摘要:${NC}"
echo -e "${YELLOW}節點名稱:${NC} ${CURRENT_NODE}"
echo -e "${YELLOW}升級前版本:${NC} ${CURRENT_KUBELET_VERSION}"
echo -e "${YELLOW}升級後版本:${NC} ${NEW_KUBELET_VERSION}"

echo -e "\n${BLUE}下一步操作:${NC}"
echo "1. 在master節點上檢查節點狀態:"
echo "   kubectl get nodes"
echo ""
echo "2. 檢查節點詳細信息:"
echo "   kubectl describe node gravity-cdc"
echo ""
echo "3. 如果節點狀態異常，可能需要:"
echo "   kubectl drain gravity-cdc --ignore-daemonsets"
echo "   kubectl uncordon gravity-cdc"

echo -e "\n${BLUE}注意事項:${NC}"
echo "- 升級過程中節點可能暫時不可用"
echo "- 請在master節點上驗證集群狀態"
echo "- 如有問題，請檢查kubelet日誌: journalctl -u kubelet"
echo "- 套件已重新設置為hold狀態，防止意外升級"

echo -e "\n${YELLOW}建議執行的驗證命令:${NC}"
echo "kubectl get nodes -o wide"
echo "kubectl get pods --all-namespaces"
echo "systemctl status kubelet"

# 動態檢測正確的版本格式
detect_correct_version() {
    echo -e "${BLUE}檢測正確的版本格式...${NC}"
    
    # 檢查可用的1.31.0版本
    AVAILABLE_VERSIONS=$(apt-cache madison kubeadm 2>/dev/null | grep -E "1\.31\.0" | head -5)
    
    if [[ -z "$AVAILABLE_VERSIONS" ]]; then
        echo -e "${RED}錯誤: 找不到1.31.0版本${NC}"
        echo -e "${YELLOW}可用版本:${NC}"
        apt-cache madison kubeadm | head -10
        exit 1
    fi
    
    # 提取第一個可用的1.31.0版本
    DETECTED_VERSION=$(echo "$AVAILABLE_VERSIONS" | head -1 | awk '{print $3}')
    
    if [[ -n "$DETECTED_VERSION" ]]; then
        TARGET_VERSION="$DETECTED_VERSION"
        echo -e "${GREEN}✓ 檢測到版本: ${TARGET_VERSION}${NC}"
    else
        echo -e "${RED}錯誤: 無法檢測版本格式${NC}"
        exit 1
    fi
} 