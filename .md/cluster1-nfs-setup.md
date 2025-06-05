# 第一座K8s集群 NFS設置指南

## 概述
此指南說明如何為第一座Kubernetes集群設置專用的NFS存儲，與第二座集群完全分離。

## 🖥 環境配置

### 第一座集群 (本指南適用)
| 角色         | IP範圍           | 具體IP                    |
|--------------|------------------|---------------------------|
| Master節點   | 10.6.4.213-215  | 10.6.4.213, 214, 215     |
| Worker節點   | 10.6.4.217-219  | 10.6.4.217, 218, 219     |
| NFS伺服器    | 10.6.4.220       | 共用NFS伺服器             |

### 第二座集群 (參考)
| 角色         | IP範圍           | NFS路徑                   |
|--------------|------------------|---------------------------|
| 集群節點     | 10.6.4.8-9       | /srv/nfs/kubedata         |
| NFS伺服器    | 10.6.4.220       | 共用NFS伺服器             |

## 📁 NFS目錄結構

```
/srv/nfs/
├── cluster1-data/          # 第一座集群專用 (本指南)
│   ├── cluster1-test.txt
│   └── [應用數據]
└── kubedata/              # 第二座集群專用 (已存在)
    ├── [第二座集群數據]
    └── testfile.txt
```

## 🚀 設置步驟

### 步驟1: 在NFS伺服器上設置第一座集群共享

在NFS伺服器 (10.6.4.220) 上執行：

```bash
# 下載並執行伺服器設置腳本
chmod +x cluster1-nfs-server-setup.sh
./cluster1-nfs-server-setup.sh
```

這個腳本會：
- 創建 `/srv/nfs/cluster1-data` 目錄
- 更新 `/etc/exports` 配置
- 重啟NFS服務
- 設置防火牆規則

### 步驟2: 在集群節點上設置NFS客戶端

在第一座集群的所有節點 (10.6.4.213-219) 上執行：

```bash
# 下載並執行客戶端設置腳本
chmod +x cluster1-nfs-client.sh
./cluster1-nfs-client.sh
```

這個腳本會：
- 安裝NFS客戶端工具
- 測試NFS連接
- 驗證讀寫功能
- 可選配置永久掛載

### 步驟3: 在Kubernetes中部署NFS存儲

```bash
# 部署PV/PVC和測試應用
kubectl apply -f cluster1-nfs-pv-pvc.yaml

# 檢查PV狀態
kubectl get pv

# 檢查PVC狀態
kubectl get pvc

# 檢查測試Pod
kubectl get pods
```

## 📋 配置詳情

### NFS伺服器配置
- **伺服器IP**: 10.6.4.220
- **共享路徑**: `/srv/nfs/cluster1-data`
- **權限**: `rw,sync,no_subtree_check,no_root_squash`
- **允許網段**: `10.6.4.0/24`

### Kubernetes存儲配置
- **PV名稱**: `cluster1-nfs-pv`
- **PVC名稱**: `cluster1-nfs-pvc`
- **StorageClass**: `cluster1-nfs`
- **容量**: `10Gi`
- **訪問模式**: `ReadWriteMany`

## 🧪 測試驗證

### 1. 手動測試NFS掛載
```bash
# 在任一集群節點上
sudo mkdir -p /mnt/test
sudo mount -t nfs 10.6.4.220:/srv/nfs/cluster1-data /mnt/test

# 測試寫入
echo "Test from $(hostname)" | sudo tee /mnt/test/test.txt

# 測試讀取
cat /mnt/test/test.txt

# 卸載
sudo umount /mnt/test
```

### 2. Kubernetes中測試
```bash
# 檢查測試Pod
kubectl exec -it cluster1-nfs-test-pod -- sh

# 在Pod內測試
echo "Hello from Kubernetes" > /mnt/nfs/k8s-test.txt
cat /mnt/nfs/k8s-test.txt
ls -la /mnt/nfs/
```

### 3. 驗證數據持久性
```bash
# 刪除測試Pod
kubectl delete pod cluster1-nfs-test-pod

# 重新創建Pod
kubectl apply -f cluster1-nfs-pv-pvc.yaml

# 檢查數據是否仍存在
kubectl exec -it cluster1-nfs-test-pod -- cat /mnt/nfs/k8s-test.txt
```

## 🔧 故障排除

### 常見問題

1. **無法掛載NFS**
   ```bash
   # 檢查NFS服務
   systemctl status nfs-kernel-server
   
   # 檢查exports
   showmount -e 10.6.4.220
   
   # 檢查網路連通性
   ping 10.6.4.220
   ```

2. **PVC處於Pending狀態**
   ```bash
   # 檢查PV狀態
   kubectl describe pv cluster1-nfs-pv
   
   # 檢查PVC事件
   kubectl describe pvc cluster1-nfs-pvc
   ```

3. **權限問題**
   ```bash
   # 在NFS伺服器上檢查權限
   ls -la /srv/nfs/cluster1-data
   
   # 修正權限
   sudo chown nobody:nogroup /srv/nfs/cluster1-data
   sudo chmod 755 /srv/nfs/cluster1-data
   ```

### 重要端口
- **NFS**: 2049
- **RPC**: 111
- **其他**: 動態分配的端口

## 🔒 安全考量

### 生產環境建議
1. **權限設置**: 避免使用 `no_root_squash`
2. **網路限制**: 使用更嚴格的IP範圍限制
3. **加密**: 考慮使用NFSv4.1的加密功能
4. **備份**: 定期備份NFS數據

### 範例安全配置
```bash
# 更安全的exports配置
/srv/nfs/cluster1-data 10.6.4.213(rw,sync,no_subtree_check,root_squash) 10.6.4.214(rw,sync,no_subtree_check,root_squash) 10.6.4.215(rw,sync,no_subtree_check,root_squash)
```

## 📚 相關文件

- `cluster1-nfs-server-setup.sh` - NFS伺服器設置腳本
- `cluster1-nfs-client.sh` - NFS客戶端設置腳本
- `cluster1-nfs-pv-pvc.yaml` - Kubernetes存儲配置
- `cluster2-nfs-server.md` - 第二座集群NFS配置參考

## 🔄 維護操作

### 清理資源
```bash
# 刪除Kubernetes資源
kubectl delete -f cluster1-nfs-pv-pvc.yaml

# 在NFS伺服器上清理
sudo rm -rf /srv/nfs/cluster1-data/*
```

### 備份數據
```bash
# 在NFS伺服器上
sudo tar -czf /backup/cluster1-nfs-$(date +%Y%m%d).tar.gz /srv/nfs/cluster1-data/
```

## 📞 支援

如果遇到問題：
1. 檢查所有節點的網路連通性
2. 驗證NFS服務狀態
3. 檢查防火牆設置
4. 查看Kubernetes事件日誌
5. 參考第二座集群的工作配置作為對比 