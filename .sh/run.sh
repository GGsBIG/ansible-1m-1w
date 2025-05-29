#!/bin/bash

# K8s 叢集自動化部署腳本
# 此腳本會執行完整的 Kubernetes 叢集部署流程

set -e  # 遇到錯誤時停止執行

echo "=========================================="
echo "  K8s 叢集自動化部署開始"
echo "=========================================="

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函數：顯示步驟
show_step() {
    echo -e "\n${BLUE}=========================================="
    echo -e "  步驟 $1: $2"
    echo -e "==========================================${NC}\n"
}

# 函數：顯示成功訊息
show_success() {
    echo -e "\n${GREEN}✅ $1${NC}\n"
}

# 函數：顯示警告訊息
show_warning() {
    echo -e "\n${YELLOW}⚠️  $1${NC}\n"
}

# 函數：顯示錯誤訊息
show_error() {
    echo -e "\n${RED}❌ $1${NC}\n"
}

# 檢查 inventory.ini 是否存在
if [ ! -f "inventory.ini" ]; then
    show_error "找不到 inventory.ini 檔案！請確認您在正確的目錄中執行此腳本。"
    exit 1
fi

# 檢查 Ansible 是否已安裝
if ! command -v ansible-playbook &> /dev/null; then
    show_error "Ansible 未安裝！請先安裝 Ansible。"
    echo "Ubuntu/Debian: sudo apt update && sudo apt install ansible"
    echo "CentOS/RHEL: sudo yum install ansible"
    echo "macOS: brew install ansible"
    exit 1
fi

show_step "1" "SSH 設定和主機名稱設定"
ansible-playbook -i inventory.ini playbooks/01-ssh-setup.yml
show_success "SSH 設定完成"

show_step "2" "安裝 Container Runtime (containerd)"
ansible-playbook -i inventory.ini playbooks/02-container-runtime.yml
show_success "Container Runtime 安裝完成"

show_step "3" "安裝 Kubernetes 組件"
ansible-playbook -i inventory.ini playbooks/03-kubernetes-components.yml
show_success "Kubernetes 組件安裝完成"

show_step "4" "系統設定 (關閉 swap、載入模組等)"
ansible-playbook -i inventory.ini playbooks/04-system-config.yml
show_success "系統設定完成"

show_step "5" "初始化 Master Node"
ansible-playbook -i inventory.ini playbooks/05-master-init.yml
show_success "Master Node 初始化完成"

show_step "6" "Worker Node 加入叢集"
ansible-playbook -i inventory.ini playbooks/06-worker-join.yml
show_success "Worker Node 加入叢集完成"

show_step "7" "安裝 Calico CNI 網路插件"
ansible-playbook -i inventory.ini playbooks/07-install-calico.yml
show_success "Calico CNI 安裝完成"

show_step "8" "設定 kubectl 自動補全和別名 (Master Node)"
ansible-playbook -i inventory.ini playbooks/08-kubectl-completion.yml
show_success "kubectl 自動補全設定完成"

show_step "9" "設定 Worker Node kubectl"
ansible-playbook -i inventory.ini playbooks/09-worker-kubectl-setup.yml
show_success "Worker Node kubectl 設定完成"

echo -e "\n${GREEN}=========================================="
echo -e "  🎉 K8s 叢集部署完成！"
echo -e "==========================================${NC}\n"

echo -e "${BLUE}叢集資訊：${NC}"
echo "• Master Node: 已初始化並設定完成"
echo "• Worker Node: 已加入叢集"
echo "• CNI 網路: Calico (Pod CIDR: 10.244.0.0/16)"
echo "• kubectl: 已在所有節點設定完成"

echo -e "\n${BLUE}便利功能：${NC}"
echo "• kubectl 自動補全: 支援 Tab 補全"
echo "• kubectl 別名: 可使用 'k' 代替 'kubectl'"
echo "• 所有節點: 都可以使用 kubectl 管理叢集"

echo -e "\n${BLUE}檢查叢集狀態：${NC}"
echo "ssh bbg@10.211.55.87  # 登入 Master Node"
echo "kubectl get nodes     # 查看節點狀態"
echo "kubectl get pods -A   # 查看所有 Pods"
echo "k get nodes           # 使用別名"

echo -e "\n${BLUE}測試叢集功能：${NC}"
echo "kubectl create deployment nginx --image=nginx"
echo "kubectl expose deployment nginx --port=80 --type=NodePort"
echo "kubectl get services"

echo -e "\n${GREEN}🚀 您的 Kubernetes 叢集已完全就緒！${NC}" 