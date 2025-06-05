#!/bin/bash
# harbor-vm-setup-docker.sh
# Full Harbor registry installation script (Ubuntu 22.04 + Docker + SAN support)

set -e

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 函數：從inventory.ini讀取Harbor伺服器IP
get_harbor_server_ip() {
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
    
    # 從[harbor]區段讀取IP
    local harbor_ip=$(awk '/^\[harbor\]/{flag=1; next} /^\[/{flag=0} flag && /^[0-9]/{print $1; exit}' "$inventory_file")
    
    if [[ -z "$harbor_ip" ]]; then
        echo -e "${RED}✗ 無法從inventory.ini中找到Harbor伺服器IP${NC}"
        echo -e "${YELLOW}請檢查inventory.ini中的[harbor]區段${NC}"
        exit 1
    fi
    
    echo "$harbor_ip"
}

# 動態讀取配置
echo -e "${BLUE}正在從inventory.ini讀取Harbor配置...${NC}"
HARBOR_IP=$(get_harbor_server_ip)
HARBOR_HOSTNAME="tungbro.harbor.com"

echo -e "${BLUE}Harbor配置信息:${NC}"
echo -e "${YELLOW}Harbor伺服器IP: ${HARBOR_IP}${NC}"
echo -e "${YELLOW}Harbor域名: ${HARBOR_HOSTNAME}${NC}"

echo -e "\n${BLUE}Step 0: Clean up old Docker apt sources and certs...${NC}"
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo sed -i '/docker/d' /etc/apt/sources.list
sudo rm -f /usr/share/keyrings/docker.gpg
sudo rm -f /etc/apt/trusted.gpg.d/docker.gpg
sudo rm -f /etc/apt/trusted.gpg

echo -e "\n${BLUE}Step 1: Update and install required packages...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget vim apt-transport-https ca-certificates gnupg lsb-release openssl

echo -e "\n${BLUE}Step 2: Install Docker...${NC}"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo systemctl enable docker
sudo systemctl start docker

echo -e "\n${BLUE}Step 3: Set hostname and /etc/hosts...${NC}"
sudo hostnamectl set-hostname ${HARBOR_HOSTNAME}
echo "${HARBOR_IP} ${HARBOR_HOSTNAME}" | sudo tee -a /etc/hosts

echo -e "\n${BLUE}Step 4: Generate self-signed TLS certificate with SAN...${NC}"
sudo mkdir -p /data/cert

# Create OpenSSL config with SAN
cat <<EOF | sudo tee /tmp/harbor-cert.cnf
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = TW
ST = Taipei
L = Taipei
O = Tungbro
OU = IT
CN = ${HARBOR_HOSTNAME}

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${HARBOR_HOSTNAME}
IP.1 = ${HARBOR_IP}
EOF

# Generate cert and key with SAN
sudo openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
  -keyout /data/cert/harbor.key \
  -out /data/cert/harbor.crt \
  -config /tmp/harbor-cert.cnf \
  -extensions v3_req

sudo chmod 600 /data/cert/harbor.*
sudo chown root:root /data/cert/harbor.*

echo -e "\n${BLUE}Step 5: Download and extract Harbor...${NC}"
HARBOR_VERSION=v2.9.4
wget https://github.com/goharbor/harbor/releases/download/${HARBOR_VERSION}/harbor-offline-installer-${HARBOR_VERSION}.tgz
tar -zxvf harbor-offline-installer-${HARBOR_VERSION}.tgz
cd harbor

echo -e "\n${BLUE}Step 6: Configure harbor.yml...${NC}"
cp harbor.yml.tmpl harbor.yml

# Clean out any previously existing https block and re-add the correct one
sed -i '/^https:/,/^[^[:space:]]/d' harbor.yml

# Append corrected https config at end of file
cat <<EOF >> harbor.yml

https:
  port: 443
  certificate: /data/cert/harbor.crt
  private_key: /data/cert/harbor.key
EOF

# Set hostname and password
sed -i "s/^hostname:.*/hostname: ${HARBOR_HOSTNAME}/" harbor.yml
sed -i 's/^harbor_admin_password:.*/harbor_admin_password: Harbor12345/' harbor.yml

echo -e "\n${BLUE}Step 7: Install Harbor...${NC}"
sudo ./install.sh

echo
echo -e "${GREEN}Harbor 安裝完成！${NC}"
echo -e "${BLUE}請訪問: https://${HARBOR_HOSTNAME}${NC}"
echo -e "${BLUE}登入帳號: admin / Harbor12345${NC}"
echo -e "${YELLOW}Harbor伺服器IP: ${HARBOR_IP} (從inventory.ini讀取)${NC}"
