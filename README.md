# bootstrap-linux-workspace

## 專案用途

此專案用來作為 Linux 工作環境 bootstrap repo，目標是在使用者執行一行安裝指令後，自動套用 Git 設定、安裝 `tmux-compass`、安裝 `tpm`，並設定 tmux session 持久化與開機自動回復。

## Scope

- 提供 Linux 專用的 bootstrap 流程
- 套用來自 `config/git.conf` 的 Git 設定
- 安裝 `tmux-compass`
- 安裝 `tpm`
- 安裝 `tmux-resurrect`、`tmux-continuum`，並以 systemd user service 設定開機後自動回復 tmux session
- 供遠端 `install.sh` 下載並執行

## Git 設定來源

`config/git.conf` 是 bootstrap 流程使用的 `key=value` 設定來源，不是 Git 原生使用的 INI 格式設定檔。此檔只放**通用且非機器特定**的設定與別名，不含任何個人身份或主機專屬值。

個人與機器特定的設定不寫死在檔案內，改由 `scripts/git.sh` 於安裝時解析——優先讀環境變數，否則在終端機互動輸入：

| 設定 | 環境變數 | 說明 |
|------|----------|------|
| `user.name` | `GIT_USER_NAME` | 必填 |
| `user.email` | `GIT_USER_EMAIL` | 必填 |
| `user.signingkey` | `GIT_SIGNING_KEY` | 選填；有值才啟用 `commit.gpgsign` / `tag.gpgsign`，留空則關閉簽章 |
| GitHub 憑證輔助 | （自動偵測 `gh`）| 以 `gh auth setup-git` 設定，不寫死 `gh` 絕對路徑 |

非互動（管線）情境範例：

```bash
GIT_USER_NAME="Wusung Peng" GIT_USER_EMAIL="you@example.com" bash scripts/git.sh
```

## Requirements

- Linux 環境
- `bash`
- `git`
- `curl`
- 可連線至 GitHub
- `gh`（選用；存在時用於設定 GitHub 憑證輔助）
- `tmux`（選用；開機自動回復需要，缺少時 systemd 步驟降級為警告）
- systemd user instance（選用；設定 `tmux.service` 開機啟動需要）

## One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/wusung/bootstrap-linux-workspace/main/install.sh | bash
```

安裝過程需要 `user.name` / `user.email`。以 `curl | bash` 執行時，`scripts/git.sh` 會透過 `/dev/tty` 互動詢問；若無控制終端（CI／管線），改用環境變數預先提供：

```bash
curl -fsSL https://raw.githubusercontent.com/wusung/bootstrap-linux-workspace/main/install.sh \
  | GIT_USER_NAME="Wusung Peng" GIT_USER_EMAIL="you@example.com" bash
```

## Local Run

若已 clone 本 repo，可直接在本機執行：

```bash
bash install.sh
```

## 安裝流程

`install.sh` 是唯一進入點，自帶 `log`／`die`／`require_cmd`，不依賴 `scripts/common.sh`。流程如下：

1. 檢查必要命令（`git`、`curl`），任一缺失即中止。
2. 解析 repo 來源，二選一：
   - **本地模式**：從 checkout 執行時，就地使用當前目錄的 `scripts/`。
   - **遠端模式**：以 `curl | bash` 執行、無本地 checkout 時，`git clone --depth 1` 到暫存目錄，結束時經 `trap ... EXIT` 自動清理。
3. 嚴格依序執行模組；任一模組失敗立即中止並回傳非零退出碼：

   | 順序 | 模組 | 作用 | 目標位置 |
   |------|------|------|----------|
   | 1 | `scripts/git.sh` | 套用 `config/git.conf` 全域設定與別名；解析身份／簽章／憑證（見「Git 設定來源」一節） | `~/.gitconfig` |
   | 2 | `scripts/tmux.sh` | clone 或更新 `tmux-compass` | `~/.config/tmux/plugins/tmux-compass` |
   | 3 | `scripts/vim.sh` | 相容包裝，轉呼 `scripts/tpm.sh`；clone 或更新 TPM | `~/.tmux/plugins/tpm` |
   | 4 | `scripts/tmux-persistence.sh` | clone 或更新 `tmux-resurrect`／`tmux-continuum`；注入 tmux.conf managed block；寫入並啟用 systemd user service | `~/.tmux/plugins/tmux-resurrect`、`~/.tmux/plugins/tmux-continuum`、`~/.config/systemd/user/tmux.service` |

流程可重複執行（idempotent）：既有的外掛 repo 會以 `git pull --ff-only` 更新；remote URL 與預期不符時直接失敗，不覆寫。

## tmux Session 持久化與開機自動回復

`scripts/tmux-persistence.sh` 負責讓 tmux session 在重開機後自動回復，設計細節見 `docs/tmux-resurrect-continuum/spec.md`。

行為重點：

- 直接 clone `tmux-resurrect`、`tmux-continuum` 到 `~/.tmux/plugins/`，與 TPM 載入路徑一致。
- 在使用者 tmux.conf（優先 `~/.config/tmux/tmux.conf`，否則 `~/.tmux.conf`）注入一段 **marker 界定、冪等、可還原** 的 managed block：

  ```tmux
  # >>> bootstrap-linux-workspace: tmux persistence >>>
  set -g @plugin 'tmux-plugins/tmux-resurrect'
  set -g @plugin 'tmux-plugins/tmux-continuum'
  set -g @continuum-restore 'on'
  set -g @continuum-boot 'on'
  set -g @continuum-save-interval '5'
  # <<< bootstrap-linux-workspace: tmux persistence <<<
  ```

  此 block 插在 TPM `run '.../tpm/tpm'` 行之前;刪除整段 marker 區間即完全還原。
- 寫入 `~/.config/systemd/user/tmux.service` 並 `systemctl --user enable`（不 start），搭配 `loginctl enable-linger`，使開機（未登入前）即起 tmux server 並由 continuum 還原上次 session。
- **保守降級**：`tmux` 不存在或 systemd user instance 不可用（如 headless `curl | bash`）時，plugin 與 tmux.conf 設定仍完成，systemd 步驟改為輸出警告與後續手動指示，不中斷整體 bootstrap。

> 需求前提：系統已安裝 `tmux`（本 repo 不負責安裝 `tmux`）。managed block 依賴 tmux.conf 底部已有 `run '~/.tmux/plugins/tpm/tpm'` 才能載入 plugin。
