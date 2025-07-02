# RHEL 8.10 Kubernetes 叢集超簡化安裝指南

## 節點配置

| 節點名 | IP | 角色 | 規格 |
|-------|-----|------|------|
| master-01 | 192.168.39.60 | Master | 8C/16GB |
| master-02 | 192.168.39.61 | Master | 8C/16GB |
| master-03 | 192.168.39.62 | Master | 8C/16GB |
| worker-01 | 192.168.39.63 | Worker | 16C/32GB |
| worker-02 | 192.168.39.64 | Worker | 16C/32GB |
| worker-03 | 192.168.39.65 | Worker | 16C/32GB |
| nfs | 192.168.39.67 | Storage | 4C/16GB |
| harbor | 192.168.39.68 | Registry | 4C/16GB |

---

## 第一步：基礎環境設定 (所有節點)

### 1.1 系統更新
```bash
sudo dnf update -y
```

### 1.2 關閉防火牆和SELinux
```bash
sudo systemctl stop firewalld && sudo systemctl disable firewalld && sudo setenforce 0 && sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
```

### 1.3 設定主機名稱
```bash
# master-01 (192.168.39.60)
sudo hostnamectl set-hostname master-01

# master-02 (192.168.39.61) 
sudo hostnamectl set-hostname master-02

# master-03 (192.168.39.62)
sudo hostnamectl set-hostname master-03

# worker-01 (192.168.39.63)
sudo hostnamectl set-hostname worker-01

# worker-02 (192.168.39.64)
sudo hostnamectl set-hostname worker-02

# worker-03 (192.168.39.65)
sudo hostnamectl set-hostname worker-03

# nfs (192.168.39.67)
sudo hostnamectl set-hostname nfs

# harbor (192.168.39.68)
sudo hostnamectl set-hostname harbor
```

### 1.4 配置hosts檔案 (所有節點)
```bash
cat >> /etc/hosts << EOF
192.168.39.60 master-01
192.168.39.61 master-02
192.168.39.62 master-03
192.168.39.63 worker-01
192.168.39.64 worker-02
192.168.39.65 worker-03
192.168.39.67 nfs
192.168.39.68 harbor
EOF
```

### 1.5 系統參數設定 (所有K8s節點)
```bash
swapoff -a && sed -i '/swap/d' /etc/fstab && modprobe overlay && modprobe br_netfilter
```

```bash
cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system
```

---

## 第二步：安裝容器運行時 (所有K8s節點)

### 2.1 添加Docker倉庫
```bash
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
```

### 2.2 安裝containerd
```bash
dnf install -y containerd.io && systemctl enable containerd && systemctl start containerd
```

### 2.3 配置containerd
```bash
mkdir -p /etc/containerd && containerd config default > /etc/containerd/config.toml && sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml && systemctl restart containerd
```

---

## 第三步：安裝Kubernetes (所有K8s節點)

### 3.1 添加Kubernetes倉庫
```bash
cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
```

### 3.2 安裝K8s套件
```bash
dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes && systemctl enable kubelet
```

---

## 第四步：初始化叢集

### 4.1 初始化第一個Master節點 (master-01)
```bash
kubeadm init --apiserver-advertise-address=192.168.39.60 --control-plane-endpoint=192.168.39.60:6443 --pod-network-cidr=10.244.0.0/16 --upload-certs
```

### 4.2 設定kubectl (master-01)
```bash
mkdir -p $HOME/.kube && cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && chown $(id -u):$(id -g) $HOME/.kube/config
```

### 4.3 安裝網路插件 (master-01)
```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

---

## 第五步：加入其他Master節點

**使用步驟4.1輸出的Master join命令**

### 5.1 加入master-02
```bash
# 執行kubeadm init輸出的Master join命令 (包含--control-plane --certificate-key)
kubeadm join 192.168.39.60:6443 --token xxx --discovery-token-ca-cert-hash sha256:xxx --control-plane --certificate-key xxx
```

### 5.2 設定kubectl (master-02)
```bash
mkdir -p $HOME/.kube && cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && chown $(id -u):$(id -g) $HOME/.kube/config
```

### 5.3 加入master-03
```bash
# 執行相同的Master join命令
kubeadm join 192.168.39.60:6443 --token xxx --discovery-token-ca-cert-hash sha256:xxx --control-plane --certificate-key xxx
```

### 5.4 設定kubectl (master-03)
```bash
mkdir -p $HOME/.kube && cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && chown $(id -u):$(id -g) $HOME/.kube/config
```

---

## 第六步：加入Worker節點

**使用步驟4.1輸出的Worker join命令**

### 6.1 加入worker-01
```bash
kubeadm join 192.168.39.60:6443 --token xxx --discovery-token-ca-cert-hash sha256:xxx
```

### 6.2 加入worker-02
```bash
kubeadm join 192.168.39.60:6443 --token xxx --discovery-token-ca-cert-hash sha256:xxx
```

### 6.3 加入worker-03
```bash
kubeadm join 192.168.39.60:6443 --token xxx --discovery-token-ca-cert-hash sha256:xxx
```

---

## 第七步：設定NFS儲存

### 7.1 安裝NFS Server (nfs節點)
```bash
dnf install -y nfs-utils && mkdir -p /nfs/k8s-storage && chmod 777 /nfs/k8s-storage
```

### 7.2 配置NFS (nfs節點)
```bash
echo "/nfs/k8s-storage 192.168.39.0/24(rw,sync,no_root_squash)" >> /etc/exports && systemctl enable nfs-server && systemctl start nfs-server && exportfs -ra
```

### 7.3 安裝NFS客戶端 (所有K8s節點)
```bash
dnf install -y nfs-utils
```

### 7.4 安裝Helm (master-01)
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 7.5 部署NFS Provisioner (master-01)
```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/ && helm repo update && kubectl create namespace nfs-provisioner
```

```bash
helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner --namespace nfs-provisioner --set nfs.server=192.168.39.67 --set nfs.path=/nfs/k8s-storage --set storageClass.name=nfs-client
```

---

## 第八步：設定Harbor鏡像倉庫

### 8.1 安裝Docker (harbor節點)
```bash
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && dnf install -y docker-ce docker-ce-cli && systemctl start docker && systemctl enable docker
```

### 8.2 安裝Docker Compose (harbor節點)
```bash
curl -L "https://github.com/docker/compose/releases/download/2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose
```

### 8.3 下載Harbor (harbor節點)
```bash
cd /opt && wget https://github.com/goharbor/harbor/releases/download/v2.8.0/harbor-offline-installer-v2.8.0.tgz && tar xvf harbor-offline-installer-v2.8.0.tgz && cd harbor
```

### 8.4 配置Harbor (harbor節點)
```bash
cp harbor.yml.tmpl harbor.yml
```

**編輯harbor.yml檔案**，修改以下項目：
- hostname: 192.168.39.68
- harbor_admin_password: Harbor12345
- 註解掉https相關設定

### 8.5 安裝Harbor (harbor節點)
```bash
./install.sh
```

### 8.6 配置containerd信任Harbor (所有K8s節點)
```bash
mkdir -p /etc/containerd/certs.d/192.168.39.68
```

```bash
cat > /etc/containerd/certs.d/192.168.39.68/hosts.toml << EOF
server = "http://192.168.39.68"
[host."http://192.168.39.68"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
EOF
```

```bash
systemctl restart containerd
```

---

## 第九步：驗證叢集

### 9.1 檢查節點狀態 (任一Master節點)
```bash
kubectl get nodes
```

---

## 完成！

### 🎉 叢集資訊：
- **API Server**: https://192.168.39.60:6443
- **Harbor管理介面**: http://192.168.39.68 (admin/Harbor12345)
- **儲存類別**: nfs-client
- **網路插件**: Flannel

### 📝 重要提醒：
1. 防火牆已完全關閉，請在生產環境中重新評估安全設定
2. 所有憑證有效期為1年，請定期更新
3. Harbor使用HTTP協定，生產環境建議啟用HTTPS
4. 定期備份etcd資料

### 🔧 基本維護：
```bash
# 查看叢集狀態
kubectl get nodes

# 查看所有Pod
kubectl get pods --all-namespaces

# 重新生成join token (24小時後過期)
kubeadm token create --print-join-command
```