# bootstrap-linux-workspace

## 專案用途

此專案用來作為 Linux 工作環境 bootstrap repo，目標是在使用者執行一行安裝指令後，自動套用 Git 設定、安裝 `tmux-compass`、安裝 `tpm`。

## Scope

- 提供 Linux 專用的 bootstrap 流程
- 套用來自 `config/git.conf` 的 Git 設定
- 安裝 `tmux-compass`
- 安裝 `tpm`
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
- `curl`
- 可連線至 GitHub

## One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/wusung/bootstrap-linux-workspace/main/install.sh | bash
```

## Local Run

若要在本機直接執行 bootstrap 腳本，可使用：

```bash
bash install.sh
```
