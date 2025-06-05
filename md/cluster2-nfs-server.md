
# Kubernetes 使用的 NFS 伺服器設定指南

本指南詳細說明如何設定一台 NFS 伺服器，並在整合進 Kubernetes 叢集前先手動測試其運作情況。

---

## 🖥 環境說明

| 角色         | IP 位址       |
|--------------|----------------|
| NFS 伺服器   | 10.6.4.220     |
| Master 節點  | 10.6.4.9       |
| Worker 節點  | 10.6.4.8       |

---

## 📦 第一部分：設定 NFS Server（在 10.6.4.220）

### 1. 安裝 NFS Server
```bash
sudo apt update
sudo apt install -y nfs-kernel-server
```

### 2. 建立共享資料夾
```bash
sudo mkdir -p /srv/nfs/kubedata
sudo chown nobody:nogroup /srv/nfs/kubedata
sudo chmod 777 /srv/nfs/kubedata
```

- `nobody:nogroup`：匿名存取時會映射為最低權限的使用者。
- `chmod 777`：所有使用者都可讀寫執行（僅建議在測試環境使用）。

### 3. 編輯 `/etc/exports` 設定共享規則
```bash
sudo nano /etc/exports
```

新增以下內容：
```
/srv/nfs/kubedata 10.6.4.0/24(rw,sync,no_subtree_check,no_root_squash)
```

- `rw`：允許讀寫。
- `sync`：同步寫入硬碟，更安全。
- `no_subtree_check`：避免子目錄檢查，提升效能。
- `no_root_squash`：允許 client 端以 root 身份存取（僅限測試使用）。

### 4. 套用設定並啟動服務
```bash
sudo exportfs -rav
sudo systemctl restart nfs-kernel-server
sudo systemctl enable nfs-kernel-server
```

### 5. （選用）設定防火牆允許 NFS 連線
若你使用 UFW：
```bash
sudo ufw allow from 10.6.4.0/24 to any port nfs
sudo ufw allow from 10.6.4.0/24 to any port 111 proto tcp
sudo ufw reload
```

---

## 🧪 第二部分：從 Master/Worker 測試 NFS 掛載功能

### 1. 安裝 NFS 客戶端
```bash
sudo apt update
sudo apt install -y nfs-common
```

### 2. 掛載 NFS 資料夾
```bash
sudo mkdir -p /mnt/nfs-test
sudo mount 10.6.4.220:/srv/nfs/kubedata /mnt/nfs-test
```

### 3. 寫入與讀取測試檔案
```bash
echo "Hello from $(hostname)" | sudo tee /mnt/nfs-test/testfile.txt
cat /mnt/nfs-test/testfile.txt
```

### 4. 卸載掛載點
```bash
sudo umount /mnt/nfs-test
```

---

## ✅ 備註說明

- 生產環境請勿使用 `chmod 777` 或 `no_root_squash`，除非非常必要。
- 確認防火牆已開放 TCP port `2049`（NFS）與 `111`（RPC）。
- 此設定可支援 Kubernetes 的 `ReadWriteMany` 模式。

---

若需整合進 Kubernetes（包含 PV/PVC），請參考後續的 `nfs-pv.yaml`、`nfs-pvc.yaml`、`nfs-test-pod.yaml`。
