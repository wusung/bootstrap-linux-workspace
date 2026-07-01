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

`config/git.conf` 是 bootstrap 流程使用的 `key=value` 設定來源，不是 Git 原生使用的 INI 格式設定檔。

執行安裝前應先編輯個人身份資料，至少確認：

- `user.name`
- `user.email`

其中 `user.email` 目前是 placeholder，使用前必須改成自己的信箱。

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
