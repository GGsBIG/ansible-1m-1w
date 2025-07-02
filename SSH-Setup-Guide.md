# SSH 設定腳本使用指南

## 概述

`setup-ssh.sh` 是一個專為 Ubuntu 22.04 設計的自動化 SSH 配置腳本。此腳本會自動安裝 Ansible（如果尚未安裝）並執行 SSH 相關的配置任務。

## 功能特色

- ✅ **自動檢測環境**：確認 Ubuntu 22.04 系統
- ✅ **智能安裝 Ansible**：僅在需要時自動安裝
- ✅ **彩色輸出**：友好的用戶界面和清晰的狀態顯示
- ✅ **錯誤處理**：完整的錯誤檢查和處理機制
- ✅ **安全執行**：使用 `set -e` 確保執行安全性

## 腳本功能詳解

### 1. 顏色定義系統
腳本定義了四種顏色用於不同類型的輸出：
- 🔴 **紅色 (RED)**：錯誤訊息
- 🟢 **綠色 (GREEN)**：成功訊息  
- 🟡 **黃色 (YELLOW)**：警告訊息
- 🔵 **藍色 (BLUE)**：一般資訊

### 2. 核心功能函數

#### `show_success()` - 成功訊息顯示
顯示綠色的成功訊息，用於確認操作完成

#### `show_warning()` - 警告訊息顯示  
顯示黃色的警告訊息，提醒用戶注意事項

#### `show_error()` - 錯誤訊息顯示
顯示紅色的錯誤訊息，並可能終止腳本執行

#### `install_ansible()` - Ansible 自動安裝
- 更新系統套件清單
- 安裝必要的軟體套件
- 添加 Ansible 官方 PPA 來源
- 安裝最新版本的 Ansible
- 驗證安裝是否成功

### 3. 執行流程

1. **環境檢查**：檢查 `inventory.ini` 文件是否存在
2. **Ansible 檢測**：檢查系統是否已安裝 Ansible
3. **自動安裝**：如未安裝則自動安裝 Ansible
4. **執行配置**：運行 `playbooks/01-ssh-setup.yml` playbook
5. **完成確認**：顯示配置完成的詳細資訊

## 使用前準備

### 系統需求
- **作業系統**：Ubuntu 22.04 LTS
- **權限**：需要 sudo 權限以安裝套件和修改系統配置
- **網路**：需要網路連線以下載 Ansible 和相關套件

### 必要文件
確保以下文件存在於腳本執行目錄中：

1. **inventory.ini** - Ansible 主機清單文件
   ```ini
   [servers]
   server1 ansible_host=192.168.1.10
   server2 ansible_host=192.168.1.11
   ```

2. **playbooks/01-ssh-setup.yml** - SSH 配置 playbook
   - 此文件應包含所有 SSH 相關的配置任務

## 使用方法

### 步驟 1：準備環境
```bash
# 確保在正確的目錄中
cd /path/to/your/ansible-project

# 檢查必要文件是否存在
ls inventory.ini
ls playbooks/01-ssh-setup.yml
```

### 步驟 2：賦予執行權限
```bash
chmod +x sh/setup-ssh.sh
```

### 步驟 3：執行腳本
```bash
./sh/setup-ssh.sh
```

## 執行過程說明

### 正常執行流程
1. **開始訊息**：顯示 SSH 設定開始的標題
2. **Ansible 檢查**：
   - 如已安裝：顯示版本資訊
   - 如未安裝：自動安裝並顯示進度
3. **Playbook 執行**：運行 SSH 配置任務
4. **完成確認**：列出已完成的配置項目

### 預期輸出範例
```
==========================================
  SSH Setup Start (Ubuntu 22.04)
==========================================

Ansible is already installed
Ansible version:
ansible [core 2.14.1]

Executing SSH setup playbook...
[Ansible playbook execution output...]

SSH setup completed!
• SSH service enabled
• Hostname configured  
• Passwordless login configured
• /etc/hosts updated
```

## 完成後的配置項目

腳本成功執行後，將完成以下 SSH 相關配置：

1. **SSH 服務啟用**：確保 SSH 服務正常運行
2. **主機名稱配置**：設定系統主機名稱
3. **免密碼登入配置**：配置 SSH 金鑰認證
4. **/etc/hosts 更新**：更新主機解析文件

## 故障排除

### 常見錯誤及解決方案

#### 錯誤：`inventory.ini file not found!`
**原因**：在錯誤的目錄中執行腳本
**解決方案**：
```bash
# 確認當前目錄
pwd
# 移動到正確目錄
cd /path/to/correct/directory
```

#### 錯誤：`Ansible installation failed!`
**原因**：網路連線問題或套件來源問題
**解決方案**：
```bash
# 檢查網路連線
ping google.com
# 手動更新套件清單
sudo apt update
# 重新執行腳本
./sh/setup-ssh.sh
```

#### 錯誤：權限不足
**原因**：沒有 sudo 權限
**解決方案**：
```bash
# 確認用戶有 sudo 權限
sudo whoami
# 如果沒有權限，請聯繫系統管理員
```

### 手動驗證安裝

執行完成後可手動驗證：
```bash
# 檢查 Ansible 版本
ansible --version

# 檢查 SSH 服務狀態
sudo systemctl status ssh

# 測試主機連通性
ansible -i inventory.ini all -m ping
```

## 進階使用

### 自訂配置
如需修改配置內容，請編輯：
- `inventory.ini`：修改目標主機
- `playbooks/01-ssh-setup.yml`：修改 SSH 配置任務

### 整合到自動化流程
此腳本可整合到更大的自動化部署流程中：
```bash
#!/bin/bash
./sh/setup-ssh.sh
./sh/setup-docker.sh  
./sh/setup-k8s.sh
```

## 安全注意事項

1. **權限控制**：僅在受信任的環境中執行
2. **網路安全**：確保下載來源的安全性
3. **備份重要**：執行前備份重要的 SSH 配置
4. **日誌檢查**：執行後檢查系統日誌確認無異常

## 支援與維護

- **適用版本**：Ubuntu 22.04 LTS
- **Ansible 版本**：支援最新穩定版本
- **更新方式**：定期檢查腳本和 playbook 更新

---

**注意**：此腳本專為 Ubuntu 22.04 設計，在其他版本或發行版上可能需要調整。使用前請確保了解腳本的所有操作內容。