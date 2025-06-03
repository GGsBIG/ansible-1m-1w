#!/bin/bash
# harbor-client-setup.sh
# Configure Docker client to trust and log in to Harbor registry

set -euo pipefail

HARBOR_HOST="tungbro.harbor.com"
HARBOR_IP="10.6.4.224"
CERT_REMOTE_PATH="/data/cert/harbor.crt"

echo "Step 0: Install required packages..."
sudo apt update -y
sudo apt install -y docker.io ca-certificates openssh-client

echo "Enabling and starting Docker if available..."
if systemctl list-unit-files | grep -q docker.service; then
  sudo systemctl enable docker
  sudo systemctl start docker
else
  echo "❌ docker.service not found, please check Docker installation manually."
  exit 1
fi

echo "Step 1: Ensure Harbor domain resolves correctly..."
if ! grep -q "$HARBOR_HOST" /etc/hosts; then
  echo "$HARBOR_IP $HARBOR_HOST" | sudo tee -a /etc/hosts > /dev/null
  echo "✅ Added $HARBOR_HOST to /etc/hosts"
else
  echo "✅ $HARBOR_HOST already present in /etc/hosts"
fi

echo "Step 2: Create Docker cert directory..."
sudo mkdir -p /etc/docker/certs.d/$HARBOR_HOST

echo "Step 3: Copy TLS certificate from Harbor server..."
if ! scp root@10.10.7.5:$CERT_REMOTE_PATH ./harbor.crt; then
  echo "❌ Failed to copy harbor.crt. Make sure Harbor server allows read access."
  echo "Try running on Harbor VM: sudo chmod 644 $CERT_REMOTE_PATH"
  exit 1
fi

sudo cp harbor.crt /etc/docker/certs.d/$HARBOR_HOST/ca.crt
sudo chown root:root /etc/docker/certs.d/$HARBOR_HOST/ca.crt
sudo chmod 644 /etc/docker/certs.d/$HARBOR_HOST/ca.crt
echo "✅ Certificate copied and permissions set"

echo "Step 4: Restart Docker..."
sudo systemctl restart docker

echo "Step 5: Login to Harbor Registry..."
docker login $HARBOR_HOST

echo "🎉 Setup complete. Docker is now trusted and authenticated with $HARBOR_HOST."
