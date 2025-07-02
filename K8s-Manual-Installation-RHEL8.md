# Red Hat Enterprise Linux 8.10 手動安裝 Kubernetes Cluster 完整指南

## 系統環境資訊

### 帳號資訊
- **帳號**：installadm
- **密碼**：FfAaJjDd@05*26
- **權限**：具有sudo權限

### 叢集架構 (共9台VM)

#### Master Nodes (3台 - HA Control Plane)
| 主機名 | IP地址 | 作業系統 | 規格 | 角色 |
|--------|--------|----------|------|------|
| H10LDMP10 | 192.168.39.60 | RHEL 8.10 | 8C/16GB/100GB | Master 1 |
| H10LDMP11 | 192.168.39.61 | RHEL 8.10 | 8C/16GB/100GB | Master 2 |
| H10LDMP12 | 192.168.39.62 | RHEL 8.10 | 8C/16GB/100GB | Master 3 |

#### Worker Nodes (3台)
| 主機名 | IP地址 | 作業系統 | 規格 | 角色 |
|--------|--------|----------|------|------|
| H10LDMP13 | 192.168.39.63 | RHEL 8.10 | 16C/32GB/200GB | Worker 1 |
| H10LDMP14 | 192.168.39.64 | RHEL 8.10 | 16C/32GB/200GB | Worker 2 |
| H10LDMP15 | 192.168.39.65 | RHEL 8.10 | 16C/32GB/200GB | Worker 3 |

#### 支援服務節點 (3台)
| 主機名 | IP地址 | 作業系統 | 規格 | 角色 |
|--------|--------|----------|------|------|
| H10LDMP16 | 192.168.39.66 | RHEL 8.10 | 4C/16GB/80GB | Bastion |
| H10LDMP17 | 192.168.39.67 | RHEL 8.10 | 4C/16GB/500GB | NFS Server |
| H10LDMP18 | 192.168.39.68 | RHEL 8.10 | 4C/16GB/500GB | Harbor Registry |

---

## 階段一：環境準備與系統配置

### 1.1 所有節點基本系統配置

#### 更新系統並安裝必要套件
```bash
# 在所有節點執行
sudo dnf update -y
sudo dnf install -y wget curl net-tools bind-utils yum-utils \
    device-mapper-persistent-data lvm2 git vim htop
```

#### 設定主機名稱和網路
```bash
# Master 節點
sudo hostnamectl set-hostname H10LDMP10  # 在192.168.39.60執行
sudo hostnamectl set-hostname H10LDMP11  # 在192.168.39.61執行
sudo hostnamectl set-hostname H10LDMP12  # 在192.168.39.62執行

# Worker 節點
sudo hostnamectl set-hostname H10LDMP13  # 在192.168.39.63執行
sudo hostnamectl set-hostname H10LDMP14  # 在192.168.39.64執行
sudo hostnamectl set-hostname H10LDMP15  # 在192.168.39.65執行

# 支援節點
sudo hostnamectl set-hostname H10LDMP16  # 在192.168.39.66執行
sudo hostnamectl set-hostname H10LDMP17  # 在192.168.39.67執行
sudo hostnamectl set-hostname H10LDMP18  # 在192.168.39.68執行
```

#### 配置hosts檔案
```bash
# 在所有節點執行
sudo tee -a /etc/hosts << EOF
192.168.39.60  H10LDMP10  master1
192.168.39.61  H10LDMP11  master2
192.168.39.62  H10LDMP12  master3
192.168.39.63  H10LDMP13  worker1
192.168.39.64  H10LDMP14  worker2
192.168.39.65  H10LDMP15  worker3
192.168.39.66  H10LDMP16  bastion
192.168.39.67  H10LDMP17  nfs
192.168.39.68  H10LDMP18  harbor
EOF
```

### 1.2 SSH金鑰配置

#### 在Bastion節點生成SSH金鑰
```bash
# 在H10LDMP16 (Bastion)執行
ssh-keygen -t rsa -b 4096 -C "installadm@bastion" -f ~/.ssh/id_rsa -N ""

# 複製公鑰到所有節點
for host in {60..68}; do
    ssh-copy-id installadm@192.168.39.$host
done
```

### 1.3 防火牆和SELinux設定

#### 配置防火牆規則
```bash
# Master 節點防火牆設定
sudo firewall-cmd --permanent --add-port=6443/tcp    # Kubernetes API server
sudo firewall-cmd --permanent --add-port=2379-2380/tcp  # etcd server client API
sudo firewall-cmd --permanent --add-port=10250/tcp   # Kubelet API
sudo firewall-cmd --permanent --add-port=10251/tcp   # kube-scheduler
sudo firewall-cmd --permanent --add-port=10252/tcp   # kube-controller-manager
sudo firewall-cmd --permanent --add-port=10255/tcp   # Read-only Kubelet API

# Worker 節點防火牆設定
sudo firewall-cmd --permanent --add-port=10250/tcp   # Kubelet API
sudo firewall-cmd --permanent --add-port=30000-32767/tcp  # NodePort Services

# 所有節點通用設定
sudo firewall-cmd --permanent --add-port=8472/udp    # Flannel VXLAN
sudo firewall-cmd --permanent --add-masquerade
sudo firewall-cmd --reload
```

#### SELinux設定
```bash
# 設定SELinux為permissive模式
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
```

### 1.4 核心參數調整

#### 載入必要的核心模組
```bash
# 在所有節點執行
sudo tee /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
```

#### 設定sysctl參數
```bash
# 在所有節點執行
sudo tee /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

#### 禁用swap
```bash
# 在所有節點執行
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab
```

---

## 階段二：容器運行時安裝 (containerd)

### 2.1 安裝containerd

#### 添加Docker官方YUM倉庫
```bash
# 在所有節點執行
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
```

#### 安裝containerd
```bash
# 在所有節點執行
sudo dnf install -y containerd.io

# 生成預設配置
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
```

#### 配置containerd使用systemd cgroup driver
```bash
# 在所有節點執行
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# 重啟containerd服務
sudo systemctl restart containerd
sudo systemctl enable containerd
```

### 2.2 驗證containerd安裝
```bash
# 檢查containerd狀態
sudo systemctl status containerd

# 測試containerd
sudo ctr version
```

---

## 階段三：Kubernetes套件安裝

### 3.1 添加Kubernetes YUM倉庫

```bash
# 在所有節點執行
sudo tee /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
```

### 3.2 安裝Kubernetes套件

```bash
# 在所有節點執行
sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# 啟用kubelet服務
sudo systemctl enable kubelet
```

### 3.3 配置kubelet

```bash
# 在所有節點執行
sudo tee /etc/sysconfig/kubelet << EOF
KUBELET_EXTRA_ARGS=--container-runtime-endpoint=unix:///var/run/containerd/containerd.sock
EOF
```

---

## 階段四：Master節點叢集初始化

### 4.1 初始化第一個Master節點

```bash
# 在H10LDMP10執行
sudo kubeadm init \
  --apiserver-advertise-address=192.168.39.60 \
  --control-plane-endpoint=192.168.39.60:6443 \
  --pod-network-cidr=10.244.0.0/16 \
  --service-cidr=10.96.0.0/16 \
  --upload-certs \
  --v=5

# 設定kubectl for installadm用戶
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

**重要：保存輸出的join命令！**
- Master節點join命令 (包含 --certificate-key)
- Worker節點join命令

### 4.2 安裝Pod網路附加元件 (Flannel)

```bash
# 在H10LDMP10執行
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

### 4.3 驗證第一個Master節點

```bash
# 檢查節點狀態
kubectl get nodes

# 檢查Pod狀態
kubectl get pods -n kube-system

# 檢查叢集資訊
kubectl cluster-info
```

---

## 階段五：添加額外Master節點 (HA設定)

### 5.1 加入第二個Master節點 (H10LDMP11)

```bash
# 使用第一個Master初始化時輸出的join命令
# 格式如下（使用實際輸出的命令）：
sudo kubeadm join 192.168.39.60:6443 --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash> \
    --control-plane --certificate-key <certificate-key>

# 設定kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 5.2 加入第三個Master節點 (H10LDMP12)

```bash
# 重複上述步驟
sudo kubeadm join 192.168.39.60:6443 --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash> \
    --control-plane --certificate-key <certificate-key>

# 設定kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 5.3 驗證HA Master設定

```bash
# 在任一Master節點檢查
kubectl get nodes
kubectl get pods -n kube-system -o wide

# 檢查etcd狀態
kubectl get pods -n kube-system | grep etcd
```

---

## 階段六：添加Worker節點

### 6.1 加入Worker節點

在每個Worker節點執行join命令：

```bash
# H10LDMP13 (Worker 1)
sudo kubeadm join 192.168.39.60:6443 --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash>

# H10LDMP14 (Worker 2)  
sudo kubeadm join 192.168.39.60:6443 --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash>

# H10LDMP15 (Worker 3)
sudo kubeadm join 192.168.39.60:6443 --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash>
```

### 6.2 驗證Worker節點

```bash
# 在Master節點檢查
kubectl get nodes
kubectl get nodes -o wide

# 檢查所有節點狀態
kubectl describe nodes
```

---

## 階段七：配置NFS共享儲存 (H10LDMP17)

### 7.1 安裝和配置NFS Server

```bash
# 在H10LDMP17 (NFS Server)執行
sudo dnf install -y nfs-utils

# 創建共享目錄
sudo mkdir -p /nfs/k8s-storage
sudo chmod 777 /nfs/k8s-storage

# 配置NFS exports
sudo tee /etc/exports << EOF
/nfs/k8s-storage 192.168.39.0/24(rw,sync,no_root_squash,no_subtree_check)
EOF

# 啟動NFS服務
sudo systemctl enable nfs-server
sudo systemctl start nfs-server
sudo exportfs -ra

# 配置防火牆
sudo firewall-cmd --permanent --add-service=nfs
sudo firewall-cmd --permanent --add-service=rpc-bind
sudo firewall-cmd --permanent --add-service=mountd
sudo firewall-cmd --reload
```

### 7.2 在所有K8s節點安裝NFS客戶端

```bash
# 在所有Master和Worker節點執行
sudo dnf install -y nfs-utils

# 測試NFS掛載
sudo mkdir -p /mnt/nfs-test
sudo mount -t nfs 192.168.39.67:/nfs/k8s-storage /mnt/nfs-test
sudo umount /mnt/nfs-test
```

### 7.3 安裝Helm和部署NFS Provisioner

#### 安裝Helm
```bash
# 在Master節點執行
# 下載和安裝Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 驗證Helm安裝
helm version
```

#### 使用Helm部署NFS Subdir External Provisioner
```bash
# 添加NFS Subdir External Provisioner Helm Repository
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm repo update

# 創建專用namespace
kubectl create namespace nfs-provisioner

# 使用Helm安裝NFS Provisioner
helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --namespace nfs-provisioner \
  --set nfs.server=192.168.39.67 \
  --set nfs.path=/nfs/k8s-storage \
  --set storageClass.name=nfs-client \
  --set storageClass.defaultClass=false \
  --set storageClass.archiveOnDelete=false

# 驗證部署
kubectl get pods -n nfs-provisioner
kubectl get storageclass
```

#### 設定NFS StorageClass為預設(可選)
```bash
# 如果希望設定NFS為預設StorageClass
kubectl patch storageclass nfs-client -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

---

## 階段八：配置Harbor私有鏡像倉庫 (H10LDMP18)

### 8.1 安裝Docker和Docker Compose

```bash
# 在H10LDMP18執行
sudo dnf install -y docker-ce docker-ce-cli containerd.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker installadm

# 安裝Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 8.2 安裝Harbor

```bash
# 下載Harbor
cd /opt
sudo wget https://github.com/goharbor/harbor/releases/download/v2.8.0/harbor-offline-installer-v2.8.0.tgz
sudo tar xvf harbor-offline-installer-v2.8.0.tgz
sudo chown -R installadm:installadm harbor

# 配置Harbor
cd harbor
cp harbor.yml.tmpl harbor.yml

# 編輯harbor.yml
sudo vim harbor.yml
```

**Harbor配置要點：**
```yaml
# harbor.yml 主要設定
hostname: 192.168.39.68
http:
  port: 80
# https:
#   port: 443
#   certificate: /your/certificate/path
#   private_key: /your/private/key/path

harbor_admin_password: Harbor12345

database:
  password: root123
  max_idle_conns: 100
  max_open_conns: 900

data_volume: /data

trivy:
  ignore_unfixed: false
  skip_update: false
  offline_scan: false
  security_check: vuln
  insecure: false

jobservice:
  max_job_workers: 10

notification:
  webhook_job_max_retry: 10

chart:
  absolute_url: disabled

log:
  level: info
  local:
    rotate_count: 50
    rotate_size: 200M
    location: /var/log/harbor

_version: 2.8.0
```

### 8.3 啟動Harbor

```bash
# 執行安裝腳本
sudo ./install.sh

# 檢查Harbor狀態
docker-compose ps
```

### 8.4 在所有K8s節點配置Harbor

```bash
# 在所有Master和Worker節點執行
# 配置containerd以信任Harbor私有倉庫
sudo mkdir -p /etc/containerd/certs.d/192.168.39.68

sudo tee /etc/containerd/certs.d/192.168.39.68/hosts.toml << EOF
server = "http://192.168.39.68"

[host."http://192.168.39.68"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
EOF

# 重啟containerd
sudo systemctl restart containerd
```

---

## 叢集驗證

### 基本功能驗證

```bash
# 檢查所有節點狀態
kubectl get nodes -o wide

# 檢查系統Pod
kubectl get pods -n kube-system

# 檢查叢集資訊
kubectl cluster-info

# 檢查StorageClass
kubectl get storageclass
```

---

## 總結

此完整安裝指南涵蓋了：

✅ **高可用Master節點** (3台)  
✅ **Worker節點叢集** (3台)  
✅ **NFS共享儲存** 解決方案  
✅ **Harbor私有鏡像倉庫**  
✅ **網路和安全配置**  

### 重要維護命令

#### 節點維護
```bash
# 標記節點為不可調度
kubectl cordon <node-name>

# 驅逐節點上的Pod
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# 恢復節點為可調度
kubectl uncordon <node-name>
```

#### 叢集備份
```bash
# 備份etcd
sudo ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot-$(date +%Y%m%d).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

#### 證書更新
```bash
# 檢查證書到期時間
kubeadm certs check-expiration

# 更新所有證書
sudo kubeadm certs renew all
```

### 重要提醒

- 定期備份etcd資料
- 監控叢集資源使用狀況
- 保持Kubernetes版本更新
- 實施適當的安全策略

---

**注意事項**：
- 所有IP地址和密碼僅供示範，生產環境請使用適當的安全措施
- 建議在執行前先在測試環境驗證所有步驟
- 根據實際網路環境調整防火牆和網路配置