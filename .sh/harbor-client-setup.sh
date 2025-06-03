#!/bin/bash
# harbor-client-setup.sh
# Configure Docker client to trust and log in to Harbor registry

set -euo pipefail

HARBOR_HOST="tungbro.harbor.com"
HARBOR_IP="10.6.4.224"
CERT_REMOTE_PATH="/data/cert/harbor.crt"
CERT_LOCAL="./harbor.crt"
CERT_DEST="/etc/docker/certs.d/$HARBOR_HOST/ca.crt"

echo "Step 0: Remove conflicting packages and install prerequisites..."
sudo apt remove -y docker.io containerd || true
sudo apt install -y ca-certificates curl gnupg lsb-release openssh-client

echo "Step 1: Set up Docker official repository..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io

echo "Step 2: Enable and start Docker..."
sudo systemctl enable docker
sudo systemctl start docker

echo "Step 3: Ensure Harbor domain resolves..."
if ! grep -q "$HARBOR_HOST" /etc/hosts; then
  echo "$HARBOR_IP $HARBOR_HOST" | sudo tee -a /etc/hosts > /dev/null
  echo "Added $HARBOR_HOST to /etc/hosts"
else
  echo "$HARBOR_HOST already in /etc/hosts"
fi

echo "Step 4: Set up Docker cert directory..."
sudo mkdir -p "/etc/docker/certs.d/$HARBOR_HOST"

echo "Step 5: Copy Harbor certificate..."
if ! scp "root@10.10.7.5:$CERT_REMOTE_PATH" "$CERT_LOCAL"; then
  echo "Failed to SCP $CERT_REMOTE_PATH from Harbor server."
  echo "🛠️  Try: sudo chmod 644 $CERT_REMOTE_PATH on Harbor VM"
  exit 1
fi

sudo cp "$CERT_LOCAL" "$CERT_DEST"
sudo chown root:root "$CERT_DEST"
sudo chmod 644 "$CERT_DEST"
echo "Certificate installed at $CERT_DEST"

echo "Step 6: Restart Docker..."
sudo systemctl restart docker

echo "Step 7: Docker login to Harbor Registry..."
docker login "$HARBOR_HOST"

echo "Done! Docker is now configured to trust and access $HARBOR_HOST"