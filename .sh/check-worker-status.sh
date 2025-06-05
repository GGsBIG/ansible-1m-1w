#!/bin/bash

# Worker Node狀態檢查腳本
# 用於檢查worker node的健康狀態和配置

set -e

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo "  Worker Node 狀態檢查"
echo "=========================================="

# 檢查系統基本信息
echo -e "\n${BLUE}系統信息:${NC}"
echo "主機名: $(hostname)"
echo "IP地址: $(hostname -I | awk '{print $1}')"
echo "作業系統: $(lsb_release -d | cut -f2)"
echo "內核版本: $(uname -r)"

# 檢查swap狀態
echo -e "\n${BLUE}Swap狀態:${NC}"
if [[ $(swapon --show | wc -l) -eq 0 ]]; then
    echo -e "${GREEN}✓ Swap已禁用${NC}"
else
    echo -e "${RED}✗ Swap仍然啟用${NC}"
    swapon --show
fi

# 檢查內核模組
echo -e "\n${BLUE}內核模組:${NC}"
if lsmod | grep -q overlay; then
    echo -e "${GREEN}✓ overlay模組已載入${NC}"
else
    echo -e "${RED}✗ overlay模組未載入${NC}"
fi

if lsmod | grep -q br_netfilter; then
    echo -e "${GREEN}✓ br_netfilter模組已載入${NC}"
else
    echo -e "${RED}✗ br_netfilter模組未載入${NC}"
fi

# 檢查sysctl設置
echo -e "\n${BLUE}網路設置:${NC}"
bridge_iptables=$(sysctl -n net.bridge.bridge-nf-call-iptables 2>/dev/null || echo "0")
ip_forward=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "0")

if [[ "$bridge_iptables" == "1" ]]; then
    echo -e "${GREEN}✓ bridge-nf-call-iptables = 1${NC}"
else
    echo -e "${RED}✗ bridge-nf-call-iptables = $bridge_iptables${NC}"
fi

if [[ "$ip_forward" == "1" ]]; then
    echo -e "${GREEN}✓ ip_forward = 1${NC}"
else
    echo -e "${RED}✗ ip_forward = $ip_forward${NC}"
fi

# 檢查containerd狀態
echo -e "\n${BLUE}Containerd狀態:${NC}"
if systemctl is-active --quiet containerd; then
    echo -e "${GREEN}✓ containerd服務運行中${NC}"
    echo "版本: $(containerd --version | awk '{print $3}')"
else
    echo -e "${RED}✗ containerd服務未運行${NC}"
fi

# 檢查Kubernetes套件
echo -e "\n${BLUE}Kubernetes套件:${NC}"
if command -v kubelet &> /dev/null; then
    echo -e "${GREEN}✓ kubelet已安裝${NC}"
    echo "版本: $(kubelet --version | awk '{print $2}')"
else
    echo -e "${RED}✗ kubelet未安裝${NC}"
fi

if command -v kubeadm &> /dev/null; then
    echo -e "${GREEN}✓ kubeadm已安裝${NC}"
    echo "版本: $(kubeadm version -o short)"
else
    echo -e "${RED}✗ kubeadm未安裝${NC}"
fi

if command -v kubectl &> /dev/null; then
    echo -e "${GREEN}✓ kubectl已安裝${NC}"
    echo "版本: $(kubectl version --client -o yaml | grep gitVersion | awk '{print $2}')"
else
    echo -e "${RED}✗ kubectl未安裝${NC}"
fi

# 檢查kubelet狀態
echo -e "\n${BLUE}Kubelet狀態:${NC}"
if systemctl is-active --quiet kubelet; then
    echo -e "${GREEN}✓ kubelet服務運行中${NC}"
else
    echo -e "${YELLOW}⚠ kubelet服務未運行 (加入集群前這是正常的)${NC}"
fi

# 檢查是否已加入集群
echo -e "\n${BLUE}集群狀態:${NC}"
if [[ -f /etc/kubernetes/kubelet.conf ]]; then
    echo -e "${GREEN}✓ 節點已加入集群${NC}"
    if [[ -f /etc/kubernetes/pki/ca.crt ]]; then
        echo -e "${GREEN}✓ 集群CA證書存在${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 節點尚未加入集群${NC}"
fi

# 檢查網路連通性
echo -e "\n${BLUE}網路連通性檢查:${NC}"
MASTER_NODES=("10.6.4.213" "10.6.4.214" "10.6.4.215")

for master in "${MASTER_NODES[@]}"; do
    if ping -c 1 -W 2 "$master" &> /dev/null; then
        echo -e "${GREEN}✓ 可以連接到master node $master${NC}"
    else
        echo -e "${RED}✗ 無法連接到master node $master${NC}"
    fi
done

# 檢查重要端口
echo -e "\n${BLUE}端口檢查:${NC}"
if ss -tuln | grep -q ":10250"; then
    echo -e "${GREEN}✓ kubelet API端口 (10250) 已開啟${NC}"
else
    echo -e "${YELLOW}⚠ kubelet API端口 (10250) 未開啟${NC}"
fi

# 系統資源檢查
echo -e "\n${BLUE}系統資源:${NC}"
echo "CPU: $(nproc) 核心"
echo "記憶體: $(free -h | awk '/^Mem:/ {print $2}') 總計, $(free -h | awk '/^Mem:/ {print $7}') 可用"
echo "磁碟空間: $(df -h / | awk 'NR==2 {print $4}') 可用"

# 檢查日誌中的錯誤
echo -e "\n${BLUE}最近的系統錯誤:${NC}"
if journalctl --since "1 hour ago" --priority=err --no-pager -q | head -5 | grep -q .; then
    echo -e "${YELLOW}發現系統錯誤，最近5條:${NC}"
    journalctl --since "1 hour ago" --priority=err --no-pager -q | head -5
else
    echo -e "${GREEN}✓ 最近一小時內無系統錯誤${NC}"
fi

echo -e "\n${GREEN}狀態檢查完成!${NC}"
echo -e "${YELLOW}如果發現問題，請參考README-worker-setup.md進行故障排除${NC}" 