#run.sh
#!/bin/bash

set -e  # Stop execution on error

echo "=========================================="
echo "  K8s Cluster Automated Deployment Start"
echo "=========================================="

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function: Display step
show_step() {
    echo -e "\n${BLUE}=========================================="
    echo -e "  Step $1: $2"
    echo -e "==========================================${NC}\n"
}

# Function: Display success message
show_success() {
    echo -e "\n${GREEN}$1${NC}\n"
}

# Function: Display warning message
show_warning() {
    echo -e "\n${YELLOW}$1${NC}\n"
}

# Function: Display error message
show_error() {
    echo -e "\n${RED}❌ $1${NC}\n"
}

# Function: Install Ansible
install_ansible() {
    echo -e "${BLUE}Installing Ansible...${NC}"
    
    # Detect operating system
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    
    echo -e "${BLUE}Detected OS: $OS $VER${NC}"
    
    case $OS in
        "Ubuntu"*)
            echo -e "${BLUE}Installing Ansible on Ubuntu...${NC}"
            sudo apt update
            sudo apt install -y software-properties-common
            sudo add-apt-repository --yes --update ppa:ansible/ansible
            sudo apt install -y ansible
            ;;
        "Debian"*)
            echo -e "${BLUE}Installing Ansible on Debian...${NC}"
            sudo apt update
            sudo apt install -y ansible
            ;;
        "CentOS"*|"Red Hat"*|"Rocky"*|"AlmaLinux"*)
            echo -e "${BLUE}Installing Ansible on RHEL/CentOS...${NC}"
            sudo yum install -y epel-release
            sudo yum install -y ansible
            ;;
        "Fedora"*)
            echo -e "${BLUE}Installing Ansible on Fedora...${NC}"
            sudo dnf install -y ansible
            ;;
        *)
            show_error "Unsupported operating system: $OS"
            echo "Please install Ansible manually:"
            echo "Ubuntu/Debian: sudo apt update && sudo apt install ansible"
            echo "CentOS/RHEL: sudo yum install epel-release && sudo yum install ansible"
            echo "Fedora: sudo dnf install ansible"
            echo "macOS: brew install ansible"
            exit 1
            ;;
    esac
    
    # Verify installation
    if command -v ansible-playbook &> /dev/null; then
        show_success "Ansible installed successfully!"
        echo -e "${BLUE}Ansible version:${NC}"
        ansible --version | head -1
    else
        show_error "Ansible installation failed!"
        exit 1
    fi
}

# Check if inventory.ini exists
if [ ! -f "inventory.ini" ]; then
    show_error "inventory.ini file not found! Please make sure you are running this script in the correct directory."
    exit 1
fi

# Check if Ansible is installed, if not, install it automatically
if ! command -v ansible-playbook &> /dev/null; then
    show_warning "Ansible not installed, installing automatically..."
    install_ansible
else
    echo -e "${GREEN}Ansible is already installed${NC}"
    echo -e "${BLUE}Ansible version:${NC}"
    ansible --version | head -1
fi

show_step "1" "SSH Setup and Hostname Configuration"
ansible-playbook -i inventory.ini playbooks/01-ssh-setup.yml
show_success "SSH setup completed"

show_step "2" "Install Container Runtime (containerd)"
ansible-playbook -i inventory.ini playbooks/02-container-runtime.yml
show_success "Container Runtime installation completed"

show_step "3" "Install Kubernetes Components"
ansible-playbook -i inventory.ini playbooks/03-kubernetes-components.yml
show_success "Kubernetes components installation completed"

show_step "4" "System Configuration (disable swap, load modules, etc.)"
ansible-playbook -i inventory.ini playbooks/04-system-config.yml
show_success "System configuration completed"

show_step "5" "Setup HAProxy Load Balancer"
ansible-playbook -i inventory.ini playbooks/05-setup-haproxy.yml
show_success "HAProxy setup completed"

show_step "6" "Initialize Master Node"
ansible-playbook -i inventory.ini playbooks/06-master-init.yml
show_success "Master Node initialization completed"

show_step "7" "Worker Node Join Cluster"
ansible-playbook -i inventory.ini playbooks/07-worker-join.yml
show_success "Worker Node joined cluster successfully"

show_step "8" "Install Calico CNI Network Plugin"
ansible-playbook -i inventory.ini playbooks/08-install-calico.yml
show_success "Calico CNI installation completed"

show_step "9" "Setup kubectl Auto-completion and Aliases (Master Node)"
ansible-playbook -i inventory.ini playbooks/09-kubectl-completion.yml
show_success "kubectl auto-completion setup completed"

show_step "10" "Setup Worker Node kubectl"
ansible-playbook -i inventory.ini playbooks/10-worker-kubectl-setup.yml
show_success "Worker Node kubectl setup completed"

echo -e "\n${GREEN}=========================================="
echo -e "  K8s Cluster Deployment Completed!"
echo -e "==========================================${NC}\n"

echo -e "${BLUE}Cluster Information:${NC}"
echo "• HAProxy Load Balancer: Configured for HA masters"
echo "• Master Node: Initialized and configured"
echo "• Worker Node: Joined cluster"
echo "• CNI Network: Calico (Pod CIDR: 10.244.0.0/16)"
echo "• kubectl: Configured on all nodes"

echo -e "\n${BLUE}Convenience Features:${NC}"
echo "• kubectl auto-completion: Tab completion support"
echo "• kubectl alias: Use 'k' instead of 'kubectl'"
echo "• All nodes: Can manage cluster using kubectl"
echo "• HAProxy: High availability for master nodes"

echo -e "\n${BLUE}Check Cluster Status:${NC}"
echo "ssh $User@$ip  # Login to Master Node"
echo "kubectl get nodes     # Check node status"
echo "kubectl get pods -A   # Check all pods"
echo "k get nodes           # Use alias"

echo -e "\n${BLUE}Test Cluster Functionality:${NC}"
echo "kubectl create deployment nginx --image=nginx"
echo "kubectl expose deployment nginx --port=80 --type=NodePort"
echo "kubectl get services"

echo -e "\n${GREEN}Your Kubernetes cluster is fully ready!${NC}" 