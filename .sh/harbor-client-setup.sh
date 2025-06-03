#!/bin/bash
# harbor-client-setup.sh
# Configure Docker client to trust and log in to Harbor registry

set -e

echo "Step 0: Install required packages..."
sudo apt update
sudo apt install -y docker.io ca-certificates openssh-client

echo "Enabling and starting Docker if available..."
if systemctl list-unit-files | grep -q docker.service; then
  sudo systemctl enable docker
  sudo systemctl start docker
else
  echo "docker.service not found, please check Docker installation manually."
  exit 1
fi

echo "Step 1: Create Docker cert directory..."
sudo mkdir -p /etc/docker/certs.d/tungbro.harbor.com

echo "Step 2: Copy TLS certificate from Harbor server..."
if ! scp root@10.10.7.5:/data/cert/harbor.crt ./harbor.crt; then
  echo "Failed to copy harbor.crt. Make sure Harbor server allows read access."
  echo "Try: sudo chmod 644 /data/cert/harbor.crt on Harbor VM"
  exit 1
fi

sudo cp harbor.crt /etc/docker/certs.d/tungbro.harbor.com/ca.crt

echo "Step 3: Restart Docker..."
sudo systemctl restart docker

echo "Step 4: Login to Harbor..."
docker login tungbro.harbor.com
# User manually enters: admin / Harbor12345

echo "Done!"
