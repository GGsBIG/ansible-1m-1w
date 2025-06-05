#!/bin/bash

# Kubernetes Worker Node Setup Script
# 此腳本將設置乾淨的VM並加入Kubernetes集群作為worker node

set -e

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 配置變數
MASTER_NODES=("10.6.4.213" "10.6.4.214" "10.6.4.215")
WORKER_NODES=("10.6.4.217" "10.6.4.218" "10.6.4.219")
KUBERNETES_VERSION="1.28"
CONTAINERD_VERSION="1.7.2"

echo "=========================================="
echo "  Kubernetes Worker Node 設置腳本"
echo "=========================================="

# 檢查是否為root用戶
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}請不要以root用戶執行此腳本${NC}"
   exit 1
fi

# 步驟1: 系統更新和基本設置
echo -e "\n${BLUE}步驟1: 更新系統並安裝基本套件...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# 步驟2: 禁用swap
echo -e "\n${BLUE}步驟2: 禁用swap...${NC}"
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 步驟3: 配置內核模組
echo -e "\n${BLUE}步驟3: 配置內核模組...${NC}"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# 步驟4: 配置sysctl參數
echo -e "\n${BLUE}步驟4: 配置sysctl參數...${NC}"
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# 步驟5: 安裝containerd
echo -e "\n${BLUE}步驟5: 安裝containerd...${NC}"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y containerd.io

# 配置containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# 啟用SystemdCgroup
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

# 步驟6: 安裝Kubernetes套件
echo -e "\n${BLUE}步驟6: 安裝Kubernetes套件...${NC}"
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl enable kubelet

# 步驟7: 從master node獲取join命令
echo -e "\n${BLUE}步驟7: 從master node獲取join命令...${NC}"
MASTER_IP="${MASTER_NODES[0]}"
echo -e "${YELLOW}嘗試從master node ${MASTER_IP} 獲取join命令...${NC}"

# 嘗試從master node獲取join命令
JOIN_COMMAND=""
for master in "${MASTER_NODES[@]}"; do
    echo -e "${YELLOW}嘗試連接到master node: ${master}${NC}"
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no bbg@${master} "test -f /tmp/kubeadm_join_command.sh" 2>/dev/null; then
        JOIN_COMMAND=$(ssh -o StrictHostKeyChecking=no bbg@${master} "cat /tmp/kubeadm_join_command.sh" 2>/dev/null)
        if [[ -n "$JOIN_COMMAND" ]]; then
            echo -e "${GREEN}成功從 ${master} 獲取join命令${NC}"
            break
        fi
    fi
done

# 如果無法獲取join命令，生成新的
if [[ -z "$JOIN_COMMAND" ]]; then
    echo -e "${YELLOW}無法從現有文件獲取join命令，嘗試生成新的...${NC}"
    for master in "${MASTER_NODES[@]}"; do
        echo -e "${YELLOW}嘗試在master node ${master} 上生成join命令...${NC}"
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no bbg@${master} "sudo kubeadm token create --print-join-command" 2>/dev/null > /tmp/new_join_command.sh; then
            JOIN_COMMAND=$(cat /tmp/new_join_command.sh)
            if [[ -n "$JOIN_COMMAND" ]]; then
                echo -e "${GREEN}成功從 ${master} 生成新的join命令${NC}"
                break
            fi
        fi
    done
fi

if [[ -z "$JOIN_COMMAND" ]]; then
    echo -e "${RED}錯誤: 無法獲取join命令${NC}"
    echo -e "${YELLOW}請手動在master node上執行以下命令獲取join命令:${NC}"
    echo "sudo kubeadm token create --print-join-command"
    echo -e "${YELLOW}然後手動執行該命令加入集群${NC}"
    exit 1
fi

# 步驟8: 加入集群
echo -e "\n${BLUE}步驟8: 加入Kubernetes集群...${NC}"
echo -e "${YELLOW}執行join命令: ${JOIN_COMMAND}${NC}"
sudo ${JOIN_COMMAND}

# 步驟9: 驗證節點狀態
echo -e "\n${BLUE}步驟9: 驗證節點狀態...${NC}"
sleep 10

echo -e "\n${GREEN}Worker node設置完成!${NC}"
echo -e "${YELLOW}注意: 節點可能顯示為NotReady狀態，這是正常的。${NC}"
echo -e "${YELLOW}需要安裝CNI網路插件後節點才會變為Ready狀態。${NC}"

echo -e "\n${BLUE}檢查節點狀態，請在master node上執行:${NC}"
echo "kubectl get nodes"

echo -e "\n${BLUE}如果需要檢查節點詳細信息:${NC}"
echo "kubectl describe node $(hostname)"

echo -e "\n${GREEN}腳本執行完成!${NC}" 