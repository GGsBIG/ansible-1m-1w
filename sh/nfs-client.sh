#!/bin/bash
# nfs-client.sh

set -e

echo "[Step 1] Installing NFS client tools..."
sudo apt update
sudo apt install -y nfs-common

echo "[Step 2] Creating mount point..."
sudo mkdir -p /mnt/nfs-test

echo "[Step 3] Mounting NFS shared folder..."
sudo mount 10.6.4.220:/srv/nfs/kubedata /mnt/nfs-test

echo "[Step 4] Writing test file..."
echo "Hello from $(hostname)" | sudo tee /mnt/nfs-test/testfile.txt

echo "[Step 5] Reading back content..."
cat /mnt/nfs-test/testfile.txt

echo "[Step 6] Unmounting NFS share..."
sudo umount /mnt/nfs-test

echo "NFS client test completed!"
