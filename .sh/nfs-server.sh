#!/bin/bash
# setup-nfs-server.sh

set -e

echo "[Step 1] Installing NFS server..."
sudo apt update
sudo apt install -y nfs-kernel-server

echo "[Step 2] Creating shared directory..."
sudo mkdir -p /srv/nfs/kubedata
sudo chown nobody:nogroup /srv/nfs/kubedata
sudo chmod 777 /srv/nfs/kubedata

echo "[Step 3] Configuring /etc/exports..."
echo "/srv/nfs/kubedata 10.6.4.0/24(rw,sync,no_subtree_check,no_root_squash)" | sudo tee /etc/exports

echo "[Step 4] Applying export settings..."
sudo exportfs -rav
sudo systemctl restart nfs-kernel-server
sudo systemctl enable nfs-kernel-server

echo "[Step 5] Configuring firewall if ufw is enabled..."
if command -v ufw &>/dev/null; then
  sudo ufw allow from 10.6.4.0/24 to any port nfs
  sudo ufw allow from 10.6.4.0/24 to any port 111 proto tcp
  sudo ufw reload
fi

echo "NFS server setup completed!"