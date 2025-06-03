#!/bin/bash
# harbor-vm-setup-docker.sh
# Full Harbor registry installation script (Ubuntu 22.04 + Docker + SAN support)

set -e

echo "Step 0: Clean up old Docker apt sources and certs..."
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo sed -i '/docker/d' /etc/apt/sources.list
sudo rm -f /usr/share/keyrings/docker.gpg
sudo rm -f /etc/apt/trusted.gpg.d/docker.gpg
sudo rm -f /etc/apt/trusted.gpg

echo "Step 1: Update and install required packages..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget vim apt-transport-https ca-certificates gnupg lsb-release openssl

echo "Step 2: Install Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo systemctl enable docker
sudo systemctl start docker

echo "Step 3: Set hostname and /etc/hosts..."
sudo hostnamectl set-hostname tungbro.harbor.com
echo "10.6.4.224 tungbro.harbor.com" | sudo tee -a /etc/hosts

echo "Step 4: Generate self-signed TLS certificate with SAN..."
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
CN = tungbro.harbor.com

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = tungbro.harbor.com
IP.1 = 10.6.4.224
EOF

# Generate cert and key with SAN
sudo openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
  -keyout /data/cert/harbor.key \
  -out /data/cert/harbor.crt \
  -config /tmp/harbor-cert.cnf \
  -extensions v3_req

sudo chmod 600 /data/cert/harbor.*
sudo chown root:root /data/cert/harbor.*

echo "Step 5: Download and extract Harbor..."
HARBOR_VERSION=v2.9.4
wget https://github.com/goharbor/harbor/releases/download/${HARBOR_VERSION}/harbor-offline-installer-${HARBOR_VERSION}.tgz
tar -zxvf harbor-offline-installer-${HARBOR_VERSION}.tgz
cd harbor

echo "Step 6: Configure harbor.yml..."
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
sed -i 's/^hostname:.*/hostname: tungbro.harbor.com/' harbor.yml
sed -i 's/^harbor_admin_password:.*/harbor_admin_password: Harbor12345/' harbor.yml

echo "Step 7: Install Harbor..."
sudo ./install.sh

echo
echo "✅ Harbor 安裝完成！"
echo "🌐 請訪問: https://tungbro.harbor.com"
echo "🔐 登入帳號: admin / Harbor12345"
