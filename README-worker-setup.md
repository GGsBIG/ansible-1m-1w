# Kubernetes Worker Node 設置指南

## 概述
此指南提供了將乾淨的VM加入現有Kubernetes集群作為worker node的完整步驟。

## 集群配置
- **Master Nodes**: 10.6.4.213, 10.6.4.214, 10.6.4.215
- **Worker Nodes**: 10.6.4.217, 10.6.4.218, 10.6.4.219
- **Kubernetes版本**: 1.28
- **容器運行時**: containerd

## 使用方法

### 方法1: 自動安裝腳本 (推薦)

1. 將 `setup-worker-node.sh` 複製到新的VM上
2. 給腳本執行權限：
   ```bash
   chmod +x setup-worker-node.sh
   ```
3. 執行腳本：
   ```bash
   ./setup-worker-node.sh
   ```

### 方法2: 手動安裝

如果自動腳本遇到問題，可以使用手動方式：

1. 查看手動安裝指南：
   ```bash
   chmod +x manual-worker-setup.sh
   ./manual-worker-setup.sh
   ```
2. 按照輸出的步驟逐一執行

## 前置條件

1. **網路連通性**: 確保新VM可以連接到master nodes
2. **SSH訪問**: 確保可以SSH到master nodes (使用bbg用戶)
3. **系統要求**: Ubuntu 20.04+ 或相容的Linux發行版
4. **權限**: 新VM上需要sudo權限

## 腳本功能

### setup-worker-node.sh
- 自動更新系統
- 安裝和配置containerd
- 安裝Kubernetes套件 (kubelet, kubeadm, kubectl)
- 自動從master node獲取join命令
- 加入Kubernetes集群
- 驗證安裝結果

### manual-worker-setup.sh
- 提供手動安裝的詳細步驟
- 適用於需要自定義配置的情況
- 故障排除時的參考指南

## 驗證安裝

安裝完成後，在任一master node上執行：

```bash
kubectl get nodes
```

您應該看到新的worker node列在輸出中。

**注意**: 新節點可能顯示為 `NotReady` 狀態，這是正常的。節點需要等待CNI網路插件安裝後才會變為 `Ready` 狀態。

## 故障排除

### 常見問題

1. **無法獲取join命令**
   - 檢查SSH連接到master nodes
   - 手動在master node上執行: `sudo kubeadm token create --print-join-command`

2. **節點顯示NotReady**
   - 這是正常的，等待CNI插件安裝
   - 檢查kubelet狀態: `sudo systemctl status kubelet`

3. **網路問題**
   - 確保防火牆允許Kubernetes所需端口
   - 檢查節點間網路連通性

### 重要端口

Worker nodes需要開放以下端口：
- 10250: kubelet API
- 30000-32767: NodePort服務範圍

## 清理

如果需要從集群中移除worker node：

1. 在master node上：
   ```bash
   kubectl drain <node-name> --ignore-daemonsets
   kubectl delete node <node-name>
   ```

2. 在worker node上：
   ```bash
   sudo kubeadm reset
   sudo rm -rf /etc/kubernetes/
   sudo rm -rf /var/lib/kubelet/
   ```

## 支援

如果遇到問題，請檢查：
- 系統日誌: `sudo journalctl -u kubelet`
- 容器運行時狀態: `sudo systemctl status containerd`
- 網路配置和防火牆設置 