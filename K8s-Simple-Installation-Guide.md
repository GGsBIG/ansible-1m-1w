# Red Hat Enterprise Linux 8.10 - Kubernetes Cluster 簡化安裝指南

## 節點資訊

| 主機名 | IP地址 | 角色 | 規格 |
|--------|--------|------|------|
| master-01 | 192.168.39.60 | Master 1 | 8C/16GB/100GB |
| master-02 | 192.168.39.61 | Master 2 | 8C/16GB/100GB |
| master-03 | 192.168.39.62 | Master 3 | 8C/16GB/100GB |
| worker-01 | 192.168.39.63 | Worker 1 | 16C/32GB/200GB |
| worker-02 | 192.168.39.64 | Worker 2 | 16C/32GB/200GB |
| worker-03 | 192.168.39.65 | Worker 3 | 16C/32GB/200GB |
| nfs | 192.168.39.67 | NFS Server | 4C/16GB/500GB |
| harbor | 192.168.39.68 | Harbor Registry | 4C/16GB/500GB |

**登入帳號**: installadm  
**密碼**: FfAaJjDd@05*26

---

## 步驟一：所有節點基礎配置

### 1.1 系統更新和套件安裝
```bash
# 在所有節點執行
sudo dnf update -y && sudo dnf install -y wget curl net-tools bind-utils yum-utils device-mapper-persistent-data lvm2
```

### 1.2 設定主機名稱

```bash
# 在192.168.39.60執行
sudo hostnamectl set-hostname master-01
```

```bash
# 在192.168.39.61執行
sudo hostnamectl set-hostname master-02
```

```bash
# 在192.168.39.62執行
sudo hostnamectl set-hostname master-03
```

```bash
# 在192.168.39.63執行
sudo hostnamectl set-hostname worker-01
```

```bash
# 在192.168.39.64執行
sudo hostnamectl set-hostname worker-02
```

```bash
# 在192.168.39.65執行
sudo hostnamectl set-hostname worker-03
```

```bash
# 在192.168.39.67執行
sudo hostnamectl set-hostname nfs
```

```bash
# 在192.168.39.68執行
sudo hostnamectl set-hostname harbor
```

### 1.3 配置hosts檔案
```bash
# 在所有節點執行
sudo tee -a /etc/hosts << EOF
192.168.39.60  master-01
192.168.39.61  master-02
192.168.39.62  master-03
192.168.39.63  worker-01
192.168.39.64  worker-02
192.168.39.65  worker-03
192.168.39.67  nfs
192.168.39.68  harbor
EOF
```

### 1.4 防火牆配置
```bash
# Master節點防火牆設定
sudo firewall-cmd --permanent --add-port=6443/tcp --add-port=2379-2380/tcp --add-port=10250/tcp --add-port=10251/tcp --add-port=10252/tcp --add-port=8472/udp --add-masquerade && sudo firewall-cmd --reload
```

```bash
# Worker節點防火牆設定
sudo firewall-cmd --permanent --add-port=10250/tcp --add-port=30000-32767/tcp --add-port=8472/udp --add-masquerade && sudo firewall-cmd --reload
```

### 1.5 系統設定
```bash
# 在所有K8s節點執行
sudo setenforce 0 && sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config && sudo tee /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
EOF
sudo modprobe overlay && sudo modprobe br_netfilter && sudo tee /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system && sudo swapoff -a && sudo sed -i '/swap/d' /etc/fstab
```

---

## 步驟二：安裝容器運行時 (containerd)

### 2.1 安裝containerd
```bash
# 在所有K8s節點執行
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && sudo dnf install -y containerd.io && sudo mkdir -p /etc/containerd && sudo containerd config default | sudo tee /etc/containerd/config.toml && sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml && sudo systemctl restart containerd && sudo systemctl enable containerd
```

---

## 步驟三：安裝Kubernetes

### 3.1 添加Kubernetes YUM倉庫
```bash
# 在所有K8s節點執行
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
# 在所有K8s節點執行
sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes && sudo systemctl enable kubelet && sudo tee /etc/sysconfig/kubelet << EOF
KUBELET_EXTRA_ARGS=--container-runtime-endpoint=unix:///var/run/containerd/containerd.sock
EOF
```

---

## 步驟四：初始化Master節點

### 4.1 初始化第一個Master節點
```bash
# 在master-01 (192.168.39.60)執行
sudo kubeadm init --apiserver-advertise-address=192.168.39.60 --control-plane-endpoint=192.168.39.60:6443 --pod-network-cidr=10.244.0.0/16 --service-cidr=10.96.0.0/16 --upload-certs && mkdir -p $HOME/.kube && sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

**⚠️ 重要：保存輸出的join命令！**

### 4.2 安裝網路插件
```bash
# 在master-01執行
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

---

## 步驟五：加入其他Master節點

### 5.1 加入master-02
```bash
# 在master-02 (192.168.39.61)執行 - 使用步驟4.1輸出的Master join命令
sudo kubeadm join 192.168.39.60:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash> --control-plane --certificate-key <certificate-key> && mkdir -p $HOME/.kube && sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 5.2 加入master-03
```bash
# 在master-03 (192.168.39.62)執行 - 使用步驟4.1輸出的Master join命令
sudo kubeadm join 192.168.39.60:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash> --control-plane --certificate-key <certificate-key> && mkdir -p $HOME/.kube && sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

---

## 步驟六：加入Worker節點

### 6.1 加入worker-01
```bash
# 在worker-01 (192.168.39.63)執行 - 使用步驟4.1輸出的Worker join命令
sudo kubeadm join 192.168.39.60:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

### 6.2 加入worker-02
```bash
# 在worker-02 (192.168.39.64)執行 - 使用步驟4.1輸出的Worker join命令
sudo kubeadm join 192.168.39.60:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

### 6.3 加入worker-03
```bash
# 在worker-03 (192.168.39.65)執行 - 使用步驟4.1輸出的Worker join命令
sudo kubeadm join 192.168.39.60:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

---

## 步驟七：配置NFS儲存

### 7.1 設定NFS Server
```bash
# 在nfs (192.168.39.67)執行
sudo dnf install -y nfs-utils && sudo mkdir -p /nfs/k8s-storage && sudo chmod 777 /nfs/k8s-storage && sudo tee /etc/exports << EOF
/nfs/k8s-storage 192.168.39.0/24(rw,sync,no_root_squash,no_subtree_check)
EOF
sudo systemctl enable nfs-server && sudo systemctl start nfs-server && sudo exportfs -ra && sudo firewall-cmd --permanent --add-service=nfs --add-service=rpc-bind --add-service=mountd && sudo firewall-cmd --reload
```

### 7.2 安裝NFS客戶端
```bash
# 在所有K8s節點執行
sudo dnf install -y nfs-utils
```

### 7.3 部署NFS Provisioner
```bash
# 在master-01執行
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash && helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/ && helm repo update && kubectl create namespace nfs-provisioner && helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner --namespace nfs-provisioner --set nfs.server=192.168.39.67 --set nfs.path=/nfs/k8s-storage --set storageClass.name=nfs-client --set storageClass.defaultClass=false --set storageClass.archiveOnDelete=false
```

---

## 步驟八：配置Harbor鏡像倉庫

### 8.1 安裝Docker和Docker Compose
```bash
# 在harbor (192.168.39.68)執行
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && sudo dnf install -y docker-ce docker-ce-cli containerd.io && sudo systemctl start docker && sudo systemctl enable docker && sudo usermod -aG docker installadm && sudo curl -L "https://github.com/docker/compose/releases/download/2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose
```

### 8.2 安裝Harbor
```bash
# 在harbor節點執行
cd /opt && sudo wget https://github.com/goharbor/harbor/releases/download/v2.8.0/harbor-offline-installer-v2.8.0.tgz && sudo tar xvf harbor-offline-installer-v2.8.0.tgz && sudo chown -R installadm:installadm harbor && cd harbor && cp harbor.yml.tmpl harbor.yml
```

**編輯harbor.yml檔案：**
```bash
vim harbor.yml
```

**主要修改項目：**
```yaml
hostname: 192.168.39.68
http:
  port: 80
harbor_admin_password: Harbor12345
```

### 8.3 啟動Harbor
```bash
# 在harbor目錄執行
sudo ./install.sh
```

### 8.4 配置K8s節點信任Harbor
```bash
# 在所有K8s節點執行
sudo mkdir -p /etc/containerd/certs.d/192.168.39.68 && sudo tee /etc/containerd/certs.d/192.168.39.68/hosts.toml << EOF
server = "http://192.168.39.68"

[host."http://192.168.39.68"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
EOF
sudo systemctl restart containerd
```

---

## 步驟九：驗證叢集

### 9.1 基本驗證
```bash
# 在任一Master節點執行
kubectl get nodes
```

---

## 完成！

🎉 **Kubernetes叢集已成功建置**

### 叢集組成：
- ✅ 3台HA Master節點
- ✅ 3台Worker節點  
- ✅ NFS共享儲存
- ✅ Harbor私有鏡像倉庫

### 重要資訊：
- **Kubernetes API**: https://192.168.39.60:6443
- **Harbor UI**: http://192.168.39.68 (admin / Harbor12345)
- **NFS Storage**: nfs-client StorageClass
- **Pod網段**: 10.244.0.0/16
- **Service網段**: 10.96.0.0/16

### 基本維護命令：
```bash
# 節點維護
kubectl cordon <node-name> && kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data && kubectl uncordon <node-name>

# 備份etcd
sudo ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot-$(date +%Y%m%d).db --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key

# 更新證書
kubeadm certs check-expiration && sudo kubeadm certs renew all
```