# K8s 叢集自動化部署腳本

## 目錄結構
```
ansible/
├── .sh/
│   ├── install-calico.sh
│   ├── join-workers.sh
│   ├── run.sh
│   ├── setup-kubectl-completion.sh
│   ├── setup-ssh.sh
│   ├── setup-worker-kubelet.sh
├── playbooks/
│   ├── 01-ssh-setup.yml
│   ├── 02-container-runtime.yml
│   ├── 03-kubernetes-components.yml
│   ├── 04-system-config.yml
│   ├── 05-master-init.yml
│   ├── 06-worker-join.yml
│   ├── 07-install-calico.yml
│   ├── 08-kubectl-completion.yml
│   └── 09-worker-kubectl-setup.yml
├── deploy.yml
├── inventory.ini
└── README.md
```

## 系統架構圖

### 整體架構概覽
```
┌───────────────────────────────────────────────────────────────┐
│                         Kubernetes  叢集架構                              
├───────────────────────────────────────────────────────────────┤
│                                                               │
│ ┌─────────────────────┐              ┌─────────────────────┐  │
│ │    Master Node      │              │    Worker Node      │  │
│ │  (10.10.7.230)      │              │  (10.10.7.231)      │  │
│ │  hostname: master-1 │              │  hostname: worker-1 │  │
│ │                     │              │                     │  │
│ │ ┌─────────────────┐ │              │ ┌─────────────────┐ │  │
│ │ │   API Server      │              │ │     kubelet     │ │  │
│ │ │   Controller    │ │◄─────────────┤ │   kube-proxy    │ │  │
│ │ │   Scheduler     │ │              │ │   containerd    │ │  │
│ │ │   etcd          │ │              │ └─────────────────┘ │  │
│ │ └─────────────────┘ │              │                     │  │
│ │                     │              │ ┌─────────────────┐ │  │
│ │ ┌─────────────────┐ │              │ │   Application   │ │  │
│ │ │     kubelet     │ │              │ │      Pods       │ │  │
│ │ │   kube-proxy      │              │ │                 │ │  │
│ │ │   containerd    │ │              │ └─────────────────┘ │  │
│ │ └─────────────────┘ │              │                     │  │
│ │                     │              │                     │  │
│ │ ┌─────────────────┐ │              │ ┌─────────────────┐ │  │
│ │ │     kubectl     │ │              │ │     kubectl     │ │  │
│ │ │   （管理工具）                           （管理工具）  
│ │ └─────────────────┘ │              │ └─────────────────┘ │  │
│ └─────────────────────┘              └─────────────────────┘  │
│                                                               │
│                                                               │
│ ┌──────────────────────────────────────────────────────────┐  │ 
│ │                      Calico CNI 網路層                    │  │
│ │                   Pod CIDR: 10.244.0.0/16                │  │
│ │                                                          │  │
│ │   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │  │
│ │   │    Pod      │    │    Pod      │    │    Pod      │  │  │
│ │   │ 10.244.x.x  │    │ 10.244.x.x  │    │ 10.244.x.x  │  │  │
│ │   └─────────────┘    └─────────────┘    └─────────────┘  │  │
│ └──────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
```

### 部署流程架構
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Ansible 自動化部署流程                               
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐                                                        │
│  │   控制節點                                                                
│  │  （執行 Ansible）                                                         
│  └─────────┬───────┘                                                        │
│            │                                                                │
│            ▼                                                                │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                      Playbook 執行順序                                
│  │                                                                      │   │
│  │  01-ssh-setup.yml          ┌─► SSH 設定、主機名稱、免密登入              
│  │           │                │                                         │   │
│  │           ▼                │                                         │   │
│  │  02-container-runtime.yml  ┌─► 安裝 containerd、crictl                
│  │           │                │                                         │   │
│  │           ▼                │                                         │   │
│  │  03-kubernetes-components.yml ► 安裝 kubelet、kubeadm、kubectl        
│  │           │                │                                         │   │
│  │           ▼                │                                         │   │
│  │  04-system-config.yml      ┌─► 關閉 swap、載入模組、網路設定            
│  │           │                │                                         │   │
│  │           ▼                │                                         │   │
│  │  05-master-init.yml        ┌─► 初始化 Master、設定 kubeconfig         
│  │           │                │                                         │   │
│  │           ▼                │                                         │   │
│  │  06-worker-join.yml        ┌─► Worker 節點加入叢集                     
│  │           │                │                                         │   │
│  │           ▼                │                                         │   │
│  │  07-install-calico.yml     ┌─► 安裝 Calico CNI 網路插件                
│  │           │                │                                         │   │
│  │           ▼                │                                         │   │
│  │  08-kubectl-completion.yml ┌─► 設定 kubectl 自動補全和別名              
│  │           │                │                                         │   │
│  │           ▼                │                                         │   │
│  │  09-worker-kubectl-setup.yml ► Worker 節點 kubectl 設定               
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                        輔助腳本工具                                   
│  │                                                                      │   │
│  │  run.sh                    ► 完整自動化部署腳本                         
│  │  setup-ssh.sh              ► SSH 設定腳本                             
│  │  join-workers.sh           ► Worker 節點加入腳本                       │   │
│  │  install-calico.sh         ► Calico 安裝腳本                          
│  │  setup-kubectl-completion.sh ► kubectl 補全設定腳本                    │   │
│  │  setup-worker-kubectl.sh   ► Worker kubectl 設定腳本                  
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 網路架構圖
```
┌────────────────────────────────────────────────────────────────────────────┐
│                              網路架構                                         
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        實體網路層                                         
│  │                                                                     │   │
│  │  Master Node (10.10.7.230) ◄──────────► Worker Node (10.10.7.231)   │   │
│  │       │                                        │                    │   │
│  │       │                                        │                    │   │
│  │  ┌────▼────┐                              ┌────▼────┐               │   │
│  │  │ SSH:22  │                              │ SSH:22  │               │   │
│  │  │ API:6443│                              │         │               │   │
│  │  │ etcd:2379-2380                         │         │               │   │
│  │  └─────────┘                              └─────────┘               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      Kubernetes 服務網路                                  
│  │                                                                     │   │
│  │  Service CIDR: 10.96.0.0/12 (預設)                                        
│  │                                                                     │   │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐              │   │
│  │  │ kubernetes  │    │   Service   │    │   Service   │              │   │
│  │  │ 10.96.0.1   │    │ 10.96.x.x   │    │ 10.96.x.x   │              │   │
│  │  └─────────────┘    └─────────────┘    └─────────────┘              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                       Pod 網路 (Calico CNI)                               
│  │                                                                     │   │
│  │  Pod CIDR: 10.244.0.0/16                                            │   │
│  │                                                                     │   │
│  │  Master Node Pods          Worker Node Pods                         │   │
│  │  ┌─────────────┐           ┌─────────────┐                          │   │
│  │  │ 10.244.0.x  │           │ 10.244.1.x  │                          │   │
│  │  │             │◄─────────►│             │                          │   │
│  │  │ System Pods │           │ App Pods    │                          │   │
│  │  └─────────────┘           └─────────────┘                          │   │
│  │                                                                     │   │
│  │  ┌─────────────────────────────────────────────────────────────┐    │   │
│  │  │              Calico 網路功能                                
│  │  │                                                             │    │   │
│  │  │  • BGP 路由協定                                             
│  │  │  • IPIP 封裝 (可選)                                         
│  │  │  • NetworkPolicy 支援                                        
│  │  │  • 跨節點 Pod 通訊                                          
│  │  │  • 負載平衡                                                 
│  │  └─────────────────────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────────┘
```

### 組件關係圖
```
┌─────────────────────────────────────────────────────────────────────┐
│                           Kubernetes 組件關係                         
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Master Node (Control Plane)                                        │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                                                               │  │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │  │
│  │  │ API Server  │    │ Controller  │    │  Scheduler  │        │  │
│  │  │   (6443)    │◄──►│   Manager   │◄──►│             │        │  │
│  │  └─────┬───────┘    └─────────────┘    └─────────────┘        │  │
│  │        │                                                      │  │
│  │        ▼                                                      │  │
│  │  ┌─────────────┐                                              │  │
│  │  │    etcd     │                                              │  │
│  │  │ (2379-2380) │                                              │  │
│  │  └─────────────┘                                              │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                │                                    │
│                                │ API 通訊                             
│                                ▼                                    │
│  Worker Node                                                        │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                                                               │  │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │  │
│  │  │   kubelet   │◄──►│ kube-proxy  │    │ containerd  │        │  │
│  │  │             │    │             │    │             │        │  │
│  │  └─────┬───────┘    └─────────────┘    └─────┬───────┘        │  │
│  │        │                                     │                │  │
│  │        ▼                                     ▼                │  │
│  │  ┌─────────────────────────────────────────────────────────┐  │  │
│  │  │                    Pod Runtime                          │  │  │
│  │  │                                                         │  │  │
│  │  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐     │  │  │
│  │  │  │  Pod 1  │  │  Pod 2  │  │  Pod 3  │  │  Pod N  │     │  │  │
│  │  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘     │  │  │
│  │  └─────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │ 
│  Container Runtime 層                                                  
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                                                               │  │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │  │
│  │  │ containerd  │◄──►│    crictl   │    │   Docker    │        │  │
│  │  │             │    │  （管理工具） │    │  （相容層） 
│  │  └─────────────┘    └─────────────┘    └─────────────┘        │  │
│  │                                                               │  │
│  │  ┌─────────────────────────────────────────────────────────┐  │  │
│  │  │                   Container Images                      │  │  │
│  │  │                                                         │  │  │
│  │  │  nginx:latest  │  busybox:latest  │  app:v1.0  │  ...   │  │  │
│  │  └─────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## 使用方法

### 完整自動化部署（推薦）
```bash
# 給執行腳本權限
chmod +x run.sh

# 執行完整部署（包含所有功能）
./run.sh
```

### 分步驟執行
```bash
# 1. 執行基礎設定到 Worker Node 加入
ansible-playbook -i inventory.ini playbooks/01-ssh-setup.yml
ansible-playbook -i inventory.ini playbooks/02-container-runtime.yml
ansible-playbook -i inventory.ini playbooks/03-kubernetes-components.yml
ansible-playbook -i inventory.ini playbooks/04-system-config.yml
ansible-playbook -i inventory.ini playbooks/05-master-init.yml
ansible-playbook -i inventory.ini playbooks/06-worker-join.yml

# 2. 安裝 Calico CNI
./install-calico.sh

# 3. 設定 Master Node kubectl completion（可選）
./setup-kubectl-completion.sh

# 4. 設定 Worker Node kubectl（可選）
./setup-worker-kubectl.sh
```

或者直接使用 ansible-playbook：
```bash
ansible-playbook -i inventory.ini deploy.yml
```

## 主機資訊
- **Master 節點**: 10.211.55.87 (master-1)
- **Worker 節點**: 10.211.55.88 (worker-1)
- **使用者**: bbg
- **密碼**: 1qaz@WSX

## 功能說明

### 01-ssh-setup.yml
- 更新套件清單
- 安裝 openssh-server 和 openssh-client
- 啟動並啟用 SSH 服務
- 建立 SSH 金鑰
- 設定 PermitRootLogin 為 yes
- **設定主機名稱 (hostname)**
  - master-1: 10.211.55.87
  - worker-1: 10.211.55.88
- **更新 /etc/hosts 和 /etc/hostname**
- 重新啟動 SSH 服務
- **設定免密碼登入**
  - 複製 SSH 金鑰到一般使用者帳戶
  - 複製 SSH 金鑰到 root 帳戶

### 02-container-runtime.yml
- **設定 Docker GPG 金鑰和 Repository**
  - 安裝 ca-certificates 和 curl
  - 建立 /etc/apt/keyrings 目錄
  - 下載並設定 Docker GPG 金鑰權限
  - 加入 Docker repository 到 apt sources
- **安裝 containerd.io**
  - 安裝 containerd 套件
  - 啟用並啟動 containerd 服務
- **安裝和設定 crictl**
  - 下載 crictl v1.30.0
  - 解壓縮到 /usr/local/bin
  - 設定 runtime endpoint
- **設定 containerd 組態**
  - 建立預設 containerd 設定檔
  - 設定 SystemdCgroup = true
  - 重新啟動 containerd 服務
  - 驗證 SystemdCgroup 設定

### 03-kubernetes-components.yml
- **設定 Kubernetes Repository**
  - 檢查並建立 /etc/apt/keyrings 目錄
  - 安裝必要套件 (apt-transport-https, ca-certificates, curl, gpg)
  - 下載 Kubernetes GPG 金鑰
  - 加入 Kubernetes v1.31 repository
- **安裝 Kubernetes 組件**
  - 查看可用的 kubeadm 版本
  - 安裝 kubelet=1.31.0-1.1
  - 安裝 kubeadm=1.31.0-1.1
  - 安裝 kubectl=1.31.0-1.1
  - 鎖定套件版本 (apt-mark hold)
- **驗證安裝**
  - 檢查 kubeadm 版本
  - 檢查 kubelet 版本
  - 檢查 kubectl 版本

### 04-system-config.yml
- **關閉 Swap**
  - 立即關閉 swap (swapoff -a)
  - 註解 /etc/fstab 中的 swap 項目
- **載入必要模組**
  - 載入 overlay 模組
  - 載入 br_netfilter 模組
  - 建立 /etc/modules-load.d/containerd.conf
- **設定網路參數**
  - 建立 /etc/sysctl.d/kubernetes.conf
  - 設定 net.bridge.bridge-nf-call-ip6tables = 1
  - 設定 net.bridge.bridge-nf-call-iptables = 1
  - 設定 net.ipv4.ip_forward = 1
  - 套用 sysctl 設定
- **驗證設定**
  - 確認 br_netfilter 模組已載入
  - 確認 overlay 模組已載入
  - 確認網路參數設定正確

### 05-master-init.yml
- **初始化 Kubernetes Master Node** (僅在 masters 群組執行)
  - 執行 kubeadm init 初始化叢集
  - 指定 apiserver-advertise-address 為 master node IP
  - 指定 control-plane-endpoint 為 master node IP
  - 設定 pod-network-cidr=10.244.0.0/16
- **設定 kubeconfig**
  - 為一般使用者建立 ~/.kube 目錄
  - 複製 admin.conf 到使用者的 kubeconfig
  - 為 root 使用者設定 kubeconfig
  - 設定正確的檔案權限
- **保存 Worker Node 加入指令**
  - 從 kubeadm init 輸出中提取 join 指令
  - 保存到 /tmp/kubeadm_join_command.sh
  - 顯示 join 指令供後續使用

### 06-worker-join.yml
- **獲取 Join 指令** (從 master 節點)
  - 讀取 master 節點上的 join 指令檔案
  - 設定為 Ansible fact 供其他節點使用
- **加入 Worker Node 到叢集** (僅在 workers 群組執行)
  - 執行從 master 節點獲取的 kubeadm join 指令
  - 顯示加入結果
- **驗證叢集狀態** (在 master 節點執行)
  - 執行 kubectl get nodes 檢查所有節點
  - 顯示叢集節點狀態
  - 提醒節點可能顯示為 NotReady (正常現象)

### 07-install-calico.yml
- **部署 Tigera Operator** (在 master 節點執行)
  - 下載並部署 Tigera Operator v3.27.2
  - 顯示部署結果
- **設定 Calico 網路**
  - 下載 custom-resources.yaml 設定檔
  - 修改 CIDR 設定為 10.244.0.0/16 (符合 kubeadm init 設定)
  - 顯示修改後的設定檔內容
- **部署 Calico CNI**
  - 套用 custom-resources.yaml 部署 Calico
  - 等待 Calico 系統 Pods 變為 Running 狀態 (最多 5 分鐘)
  - 等待所有節點變為 Ready 狀態 (最多 5 分鐘)
- **驗證安裝**
  - 顯示 Calico 系統 Pods 狀態
  - 顯示最終叢集節點狀態
  - 確認所有節點為 Ready 狀態

### 08-kubectl-completion.yml
- **安裝 bash-completion 套件** (在 master 節點執行)
  - 更新套件清單並安裝 bash-completion
- **設定 kubectl bash completion**
  - 為一般使用者 (bbg) 設定 kubectl 自動補全
  - 為 root 使用者設定 kubectl 自動補全
  - 檢查是否已設定，避免重複設定
- **設定 kubectl 別名**
  - 設定 'k' 作為 'kubectl' 的別名
  - 為別名 'k' 設定 bash completion 功能
  - 同時為一般使用者和 root 使用者設定
- **功能驗證**
  - 顯示設定完成訊息
  - 提供使用範例和測試方法

### 09-worker-kubectl-setup.yml
- **設定 Worker Node kubeconfig** (在 worker 節點執行)
  - 為一般使用者建立 ~/.kube 目錄
  - 使用 scp 從 master 節點複製 admin.conf 到 worker 節點
  - 設定正確的檔案權限和擁有者
  - 為 root 使用者複製 kubeconfig
- **安裝 bash-completion 套件**
  - 在 worker 節點安裝 bash-completion
- **設定 kubectl bash completion**
  - 為一般使用者和 root 使用者設定 kubectl 自動補全
  - 設定 kubectl 別名 'k' 和相應的補全功能
  - 檢查是否已設定，避免重複設定
- **測試 kubectl 功能**
  - 執行 kubectl get nodes 測試連線
  - 顯示測試結果和設定完成訊息

## 執行後效果
- 每台 VM 的 hostname 會自動設定為對應名稱
- 可以免密碼 SSH 登入所有節點
- SSH 服務已啟用並設定為開機自動啟動
- **Container Runtime (containerd) 已安裝並正確設定**
- **crictl 工具已安裝並設定完成**
- **SystemdCgroup 已設定為 true**
- **Kubernetes 組件 (kubelet, kubeadm, kubectl) v1.31.0 已安裝**
- **套件版本已鎖定，防止意外更新**
- **Swap 已永久關閉**
- **必要的核心模組已載入並設定為開機自動載入**
- **網路轉發和橋接功能已啟用**
- **Master Node 已初始化並設定完成**
- **kubeconfig 已為管理員和一般使用者設定完成**
- **Worker Node 已成功加入叢集**
- **Calico CNI 網路插件已安裝並設定完成**
- **kubectl bash completion 和別名已設定完成 (所有節點)**
- **Worker Node 可以使用 kubectl 管理叢集**
- **所有節點狀態為 Ready，叢集完全就緒**
- **Pod 之間可以正常通訊**

## kubectl 便利功能
執行完成後，所有節點的 kubectl 都具備以下便利功能：

### Tab 自動補全
```bash
# 指令自動補全
kubectl des<TAB>     → kubectl describe
kubectl get po<TAB>  → kubectl get pods
kubectl apply -f <TAB>  → 顯示檔案清單

# 資源名稱自動補全
kubectl describe pod <TAB>  → 顯示可用的 pod 名稱
kubectl get svc <TAB>       → 顯示可用的 service 名稱
```

### 快速別名
```bash
# 使用 'k' 代替 'kubectl'
k get nodes
k describe pod <pod-name>
k apply -f deployment.yaml

# 別名也支援 Tab 補全
k des<TAB>      → k describe
k get po<TAB>   → k get pods
```

## 檢查叢集狀態
```bash
# 在 Master 節點檢查
ssh bbg@10.211.55.87
kubectl get nodes
k get nodes  # 使用別名

# 在 Worker 節點也可以檢查
ssh bbg@10.211.55.88
kubectl get nodes
k get nodes  # 使用別名

# 查看詳細資訊
kubectl get nodes -o wide

# 查看所有 Pods 狀態
kubectl get pods -A

# 查看 Calico 系統 Pods
kubectl get pods -n calico-system

# 查看叢集資訊
kubectl cluster-info
```

## 測試叢集功能
```bash
# 可在任一節點部署測試應用
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort

# 查看服務
kubectl get services
kubectl get pods

# 測試 Pod 網路連通性
kubectl run test-pod --image=busybox --rm -it -- /bin/sh
# 在 Pod 內測試網路連接
```

## 下一步
執行完成後，您的 Kubernetes 叢集已完全就緒：
1. ✅ **叢集已完全建立並可用**
2. ✅ **所有節點狀態為 Ready**
3. ✅ **Pod 網路已啟用 (Calico CNI)**
4. ✅ **支援 NetworkPolicy 功能**
5. ✅ **kubectl 便利功能已啟用 (所有節點)**
6. ✅ **可在任一節點管理叢集**

現在您可以：
- **在任一節點部署應用程式**
- **設定 Ingress Controller**
- **配置持久化儲存**
- **設定監控和日誌**
- **實施安全策略 (NetworkPolicy)** 