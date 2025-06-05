#!/bin/bash
# harbor-client-setup.sh
# Configure Docker client to trust and log in to Harbor registry

set -euo pipefail

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
HARBOR_HOST="tungbro.harbor.com"
CERT_REMOTE_PATH="/data/cert/harbor.crt"
CERT_LOCAL="./harbor.crt"
CERT_DEST="/etc/docker/certs.d/$HARBOR_HOST/ca.crt"

echo -e "${BLUE}Harbor配置信息:${NC}"
echo -e "${YELLOW}Harbor伺服器IP: ${HARBOR_IP}${NC}"
echo -e "${YELLOW}Harbor域名: ${HARBOR_HOST}${NC}"

echo -e "\n${BLUE}Step 0: Remove conflicting packages and install prerequisites...${NC}"
sudo apt remove -y docker.io containerd || true
sudo apt install -y ca-certificates curl gnupg lsb-release openssh-client

echo -e "\n${BLUE}Step 1: Set up Docker official repository...${NC}"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io

echo -e "\n${BLUE}Step 2: Enable and start Docker...${NC}"
sudo systemctl enable docker
sudo systemctl start docker

echo -e "\n${BLUE}Step 3: Ensure Harbor domain resolves...${NC}"
if ! grep -q "$HARBOR_HOST" /etc/hosts; then
  echo "$HARBOR_IP $HARBOR_HOST" | sudo tee -a /etc/hosts > /dev/null
  echo -e "${GREEN}Added $HARBOR_HOST to /etc/hosts${NC}"
else
  echo -e "${YELLOW}$HARBOR_HOST already in /etc/hosts${NC}"
fi

echo -e "\n${BLUE}Step 4: Set up Docker cert directory...${NC}"
sudo mkdir -p "/etc/docker/certs.d/$HARBOR_HOST"

echo -e "\n${BLUE}Step 5: Copy Harbor certificate...${NC}"
if ! scp "root@${HARBOR_IP}:$CERT_REMOTE_PATH" "$CERT_LOCAL"; then
  echo -e "${RED}Failed to SCP $CERT_REMOTE_PATH from Harbor server.${NC}"
  echo -e "${YELLOW}🛠️  Try: sudo chmod 644 $CERT_REMOTE_PATH on Harbor VM${NC}"
  exit 1
fi

sudo cp "$CERT_LOCAL" "$CERT_DEST"
sudo chown root:root "$CERT_DEST"
sudo chmod 644 "$CERT_DEST"
echo -e "${GREEN}Certificate installed at $CERT_DEST${NC}"

echo -e "\n${BLUE}Step 6: Restart Docker...${NC}"
sudo systemctl restart docker

echo -e "\n${BLUE}Step 7: Docker login to Harbor Registry...${NC}"
docker login "$HARBOR_HOST"

echo -e "\n${GREEN}Done! Docker is now configured to trust and access $HARBOR_HOST${NC}"
echo -e "${BLUE}Harbor伺服器IP: ${HARBOR_IP}${NC}"
echo -e "${BLUE}此配置從inventory.ini自動讀取${NC}"