# Bootstrap Linux Workspace Design

## 目標

建立一個 Linux 專用的 git repo，讓使用者可透過單一指令：

```bash
curl -fsSL https://raw.githubusercontent.com/wusung/bootstrap-linux-workspace/main/install.sh | bash
```

完成個人工作環境的設定初始化。

本 repo 只負責：

- 套用個人 `git` 設定
- 安裝 `tmux-compass`
- 安裝 `tpm`

本 repo 不負責：

- 安裝 `git`
- 安裝 `curl`
- 安裝 `bash`
- 安裝 `tmux`
- 安裝 `vim`
- 管理其他未明確列入需求的 dotfiles

## 前提與限制

- 僅支援 Linux
- 預設系統已安裝 `git`、`curl`、`bash`
- 使用者具備可寫入 `$HOME` 的權限
- 腳本必須可重複執行
- 腳本不得未經確認覆蓋不屬於本 repo 管理範圍的使用者設定

## 推薦方案

採用「單一遠端入口 + 模組化腳本」。

原因：

- 對使用者維持最簡單的 `curl | bash` 體驗
- 內部可將 `git`、`tmux`、`vim` 設定拆分，降低維護成本
- 後續若要擴充更多 bootstrap 模組，不需要重寫整體流程

不採用單檔腳本方案，因為功能成長後會快速失去可維護性。

不採用 `Makefile` 作為主入口，因為它不是遠端 bootstrap 的合適介面，且會增加不必要依賴。

## Repo 結構

```text
.
├── .gitignore
├── README.md
├── install.sh
└── scripts
    ├── common.sh
    ├── git.sh
    ├── tmux.sh
    └── vim.sh
```

### 檔案責任

- `install.sh`
  - 唯一對外入口
  - 負責前置檢查、取得 repo、呼叫各模組
- `scripts/common.sh`
  - 共用函式
  - 包含 log、依賴檢查、git repo 驗證、clone/update helper
- `scripts/git.sh`
  - 套用明確管理的全域 git 設定鍵值
- `scripts/tmux.sh`
  - 安裝或更新 `tmux-compass`
- `scripts/vim.sh`
  - 安裝或更新 `tpm`
- `README.md`
  - 說明使用方式、前提、安裝目標與行為

## 執行流程

```mermaid
flowchart TD
    A[使用者執行 curl -fsSL ... | bash] --> B[install.sh 啟動]
    B --> C[檢查 git curl bash]
    C --> D[建立暫存目錄]
    D --> E[下載或 clone 本 repo]
    E --> F[執行 scripts/git.sh]
    F --> G[執行 scripts/tmux.sh]
    G --> H[執行 scripts/vim.sh]
    H --> I[輸出完成訊息]
```

### install.sh 行為

`install.sh` 必須：

- 使用 `set -euo pipefail`
- 在腳本開始時檢查必要命令
- 建立暫存工作目錄並在結束時清理
- 取得 repo 內容後，以本地檔案路徑執行模組腳本
- 嚴格依序執行 `git.sh`、`tmux.sh`、`vim.sh`
- 任一模組失敗時立即中止並回傳非零退出碼

## 模組設計

### 1. git.sh

用途：寫入個人工作環境所需的全域 git 設定。

設計原則：

- 使用 `git config --global <key> <value>`
- 僅管理明確列出的 key
- 不覆蓋整份 `~/.gitconfig`
- 可重複執行且結果一致

此模組的責任只限於全域 git 設定，不處理：

- ssh key
- credential manager 安裝
- repo-local config

### 2. tmux.sh

用途：安裝或更新 `tmux-compass`。

目標位置：

```text
~/.config/tmux/plugins/tmux-compass
```

來源：

```text
https://github.com/wusung/tmux-compass.git
```

行為規則：

- 若目標目錄不存在：執行 clone
- 若目標目錄存在且為 git repo，且 remote URL 符合預期：可更新或保留
- 若目標目錄存在但不是預期 repo：直接報錯並停止

### 3. vim.sh

用途：安裝或更新 TPM。

目標位置：

```text
~/.tmux/plugins/tpm
```

來源：

```text
https://github.com/tmux-plugins/tpm
```

行為規則：

- 若目標目錄不存在：執行 clone
- 若目標目錄存在且為 git repo，且 remote URL 符合預期：可更新或保留
- 若目標目錄存在但不是預期 repo：直接報錯並停止

註記：需求原文將其描述為「vim tpm」，但 TPM 實際上是 tmux plugin manager。此處依工具實體行為設計，安裝路徑使用 `~/.tmux/plugins/tpm`。

## 共用函式設計

`scripts/common.sh` 至少提供以下能力：

- `log_info`、`log_warn`、`log_error`
- `require_cmd`
- `ensure_dir`
- `is_git_repo`
- `get_remote_url`
- `clone_or_update_repo`

`clone_or_update_repo` 的規則：

1. 目標不存在時 clone
2. 目標存在且為 git repo 時驗證 remote URL
3. remote URL 符合預期時允許 update 或 skip
4. remote URL 不符合預期時直接失敗

此函式不得：

- 強制刪除既有目錄
- 強制覆蓋非預期 repo
- 嘗試自動修復使用者的本地衝突

## 可重跑性要求

所有步驟必須具備 idempotent 行為：

- `mkdir -p` 可安全重複執行
- `git config --global` 重複寫入相同鍵值不造成額外副作用
- plugin repo 已存在時不得重複 clone 到同一路徑
- 遇到錯誤狀態時應明確失敗，而非靜默略過

## 錯誤處理

失敗條件包括：

- 缺少 `git`、`curl`、`bash`
- repo 下載失敗
- plugin clone 失敗
- 目標路徑存在但不是預期 git repo
- remote URL 與預期不符

錯誤處理原則：

- 立即失敗
- 輸出具體原因
- 回傳非零退出碼
- 不自動執行破壞性修復

## README 內容要求

`README.md` 應包含：

- 專案目的
- 支援範圍與限制
- 一鍵安裝指令
- 本地執行方式
- 各模組職責
- 安裝目標位置
- 可重跑性與衝突處理說明

若實際 GitHub repo 名稱與 `bootstrap-linux-workspace` 不同，README 中的一鍵安裝 URL 必須同步修正。

## 測試與驗證策略

此階段至少要求：

- `shellcheck` 友善的 shell 結構
- 可在乾淨 Linux 環境中重複執行安裝腳本
- 第二次執行不應重複 clone 或破壞既有設定
- 衝突路徑情境下應正確失敗

若環境中沒有 `shellcheck`，不把安裝 `shellcheck` 納入 bootstrap 範圍。

## 非目標

以下不在本次範圍內：

- dotfiles 全量管理
- 跨平台支援
- 套件管理器整合
- 自動安裝 `tmux`、`vim`
- 使用互動式選單
- 秘密資訊或憑證管理

## 後續實作原則

- 保持 shell 腳本小而單責任
- 所有寫入行為明確可審計
- 預設保守，不覆蓋未知使用者資料
- 對外介面維持單一入口 `install.sh`
