#!/bin/bash

# 手動Worker Node設置腳本
# 如果自動腳本遇到問題，可以使用此腳本手動設置

set -e

echo "=========================================="
echo "  手動Worker Node設置指南"
echo "=========================================="

echo "步驟1: 系統準備"
echo "sudo apt update && sudo apt upgrade -y"
echo "sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release"
echo ""

echo "步驟2: 禁用swap"
echo "sudo swapoff -a"
echo "sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab"
echo ""

echo "步驟3: 配置內核模組"
echo "cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf"
echo "overlay"
echo "br_netfilter"
echo "EOF"
echo "sudo modprobe overlay"
echo "sudo modprobe br_netfilter"
echo ""

echo "步驟4: 配置sysctl"
echo "cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf"
echo "net.bridge.bridge-nf-call-iptables  = 1"
echo "net.bridge.bridge-nf-call-ip6tables = 1"
echo "net.ipv4.ip_forward                 = 1"
echo "EOF"
echo "sudo sysctl --system"
echo ""

echo "步驟5: 安裝containerd"
echo "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
echo "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
echo "sudo apt update"
echo "sudo apt install -y containerd.io"
echo "sudo mkdir -p /etc/containerd"
echo "containerd config default | sudo tee /etc/containerd/config.toml"
echo "sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml"
echo "sudo systemctl restart containerd"
echo "sudo systemctl enable containerd"
echo ""

echo "步驟6: 安裝Kubernetes"
echo "curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg"
echo "echo \"deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /\" | sudo tee /etc/apt/sources.list.d/kubernetes.list"
echo "sudo apt update"
echo "sudo apt install -y kubelet kubeadm kubectl"
echo "sudo apt-mark hold kubelet kubeadm kubectl"
echo "sudo systemctl enable kubelet"
echo ""

echo "步驟7: 獲取join命令"
echo "在任一master node (10.6.4.213, 10.6.4.214, 或 10.6.4.215) 上執行:"
echo "sudo kubeadm token create --print-join-command"
echo ""

echo "步驟8: 加入集群"
echo "複製上面命令的輸出，然後在此worker node上執行該命令"
echo ""

echo "步驟9: 驗證"
echo "在master node上執行: kubectl get nodes"
echo ""

echo "注意事項:"
echo "- 確保所有節點之間可以互相通信"
echo "- 節點可能顯示NotReady直到安裝CNI插件"
echo "- 如果遇到問題，檢查防火牆設置" 