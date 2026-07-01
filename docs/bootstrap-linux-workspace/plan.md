# Bootstrap Linux Workspace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立一個 Linux 專用 bootstrap repo，支援 `curl -fsSL https://raw.githubusercontent.com/wusung/bootstrap-linux-workspace/main/install.sh | bash`，並自動套用 git 設定、安裝 `tmux-compass`、安裝 `tpm`。

**Architecture:** 以 `install.sh` 作為唯一遠端入口，腳本先檢查前置條件，再用 `curl` 下載目前 repo 的 tarball 到暫存目錄，最後依序執行 `scripts/git.sh`、`scripts/tmux.sh`、`scripts/vim.sh`。共用邏輯集中在 `scripts/common.sh`，所有 clone/update 操作統一透過單一 helper，保證可重跑與保守失敗行為。

**Tech Stack:** Bash、git、curl、tar

---

## File Structure

### New files

- `.gitignore`
  - 忽略暫存、作業系統垃圾檔與本地測試輸出
- `README.md`
  - 專案用途、限制、安裝方式、模組說明、驗證方式
- `install.sh`
  - 遠端 bootstrap 入口，下載 repo tarball 後執行模組
- `scripts/common.sh`
  - log、錯誤處理、依賴檢查、repo clone/update helper
- `scripts/git.sh`
  - 讀取 repo 內的 git config 清單並寫入 `git config --global`
- `scripts/tmux.sh`
  - 安裝或更新 `tmux-compass`
- `scripts/vim.sh`
  - 安裝或更新 `tpm`
- `config/git.conf`
  - 受版本控制的個人 git key/value 設定來源

### Notes

- `git` 個人值未提供，不能在 plan 中虛構姓名與 email，因此改為受版本控制的 `config/git.conf`。
- `config/git.conf` 由 repo 擁有者自行填寫，bootstrap 只負責讀取與套用。
- 這個調整不違反 spec，因為 `git.sh` 仍然只寫入明確管理的 key，且不覆蓋整份 `~/.gitconfig`。

### Task 1: Scaffold Repo Skeleton

**Files:**
- Create: `.gitignore`
- Create: `README.md`
- Create: `config/git.conf`

- [ ] **Step 1: Create `.gitignore`**

```gitignore
.DS_Store
Thumbs.db
*.tmp
*.swp
*.swo
tmp/
.tmp/
```

- [ ] **Step 2: Create `config/git.conf` with managed keys**

```ini
user.name=Wu Sung
user.email=your-email@example.com
init.defaultBranch=main
pull.rebase=false
core.editor=vim
```

Expected result:
- `config/git.conf` 存在
- 每行都是 `key=value`
- 沒有 section header，便於 shell 逐行解析

- [ ] **Step 3: Create initial `README.md` skeleton**

```md
# bootstrap-linux-workspace

Linux 專用的個人工作環境 bootstrap repo。

## Scope

- 套用 `config/git.conf` 內定義的全域 git 設定
- 安裝或更新 `tmux-compass`
- 安裝或更新 `tpm`

## Requirements

- Linux
- `bash`
- `curl`
- `git`

## One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/wusung/bootstrap-linux-workspace/main/install.sh | bash
```

## Local Run

```bash
bash install.sh
```
```

- [ ] **Step 4: Verify scaffold files**

Run: `fd -H -d 2 . .`
Expected:
- 顯示 `.gitignore`
- 顯示 `README.md`
- 顯示 `config/git.conf`

- [ ] **Step 5: Commit scaffold**

Run:

```bash
git add .gitignore README.md config/git.conf
git commit -m "chore: scaffold bootstrap repo"
```

Expected:
- 產生一筆只包含骨架檔案的 commit

### Task 2: Build Shared Shell Utilities

**Files:**
- Create: `scripts/common.sh`
- Test: `scripts/common.sh`

- [ ] **Step 1: Create `scripts/common.sh`**

```bash
#!/usr/bin/env bash

set -euo pipefail

log_info() {
  printf '[INFO] %s\n' "$*"
}

log_warn() {
  printf '[WARN] %s\n' "$*" >&2
}

log_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

die() {
  log_error "$*"
  exit 1
}

require_cmd() {
  local cmd=$1
  command -v "$cmd" >/dev/null 2>&1 || die "Missing required command: $cmd"
}

ensure_dir() {
  local dir=$1
  mkdir -p "$dir"
}

is_git_repo() {
  local dir=$1
  git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

get_remote_url() {
  local dir=$1
  git -C "$dir" remote get-url origin
}

clone_or_update_repo() {
  local repo_url=$1
  local dest_dir=$2

  if [[ ! -e "$dest_dir" ]]; then
    ensure_dir "$(dirname "$dest_dir")"
    log_info "Cloning $repo_url -> $dest_dir"
    git clone "$repo_url" "$dest_dir"
    return
  fi

  if [[ ! -d "$dest_dir" ]]; then
    die "Path exists but is not a directory: $dest_dir"
  fi

  if ! is_git_repo "$dest_dir"; then
    die "Path exists but is not a git repository: $dest_dir"
  fi

  local current_url
  current_url=$(get_remote_url "$dest_dir")

  if [[ "$current_url" != "$repo_url" ]]; then
    die "Repository remote mismatch at $dest_dir: expected $repo_url, got $current_url"
  fi

  log_info "Updating $dest_dir"
  git -C "$dest_dir" pull --ff-only
}
```

- [ ] **Step 2: Verify shell syntax**

Run: `bash -n scripts/common.sh`
Expected: no output, exit code `0`

- [ ] **Step 3: Review helper coverage against spec**

Check that `scripts/common.sh` contains:
- `log_info`
- `log_warn`
- `log_error`
- `require_cmd`
- `ensure_dir`
- `is_git_repo`
- `get_remote_url`
- `clone_or_update_repo`

Run: `rg -n "log_info|log_warn|log_error|require_cmd|ensure_dir|is_git_repo|get_remote_url|clone_or_update_repo" scripts/common.sh`
Expected: all helper names found

- [ ] **Step 4: Commit shared utilities**

Run:

```bash
git add scripts/common.sh
git commit -m "feat: add shared bootstrap shell helpers"
```

Expected:
- 產生一筆只包含共用 shell helper 的 commit

### Task 3: Implement Module Scripts

**Files:**
- Create: `scripts/git.sh`
- Create: `scripts/tmux.sh`
- Create: `scripts/vim.sh`
- Modify: `scripts/common.sh`
- Test: `scripts/git.sh`
- Test: `scripts/tmux.sh`
- Test: `scripts/vim.sh`

- [ ] **Step 1: Create `scripts/git.sh`**

```bash
#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

CONFIG_FILE="$REPO_ROOT/config/git.conf"

apply_git_config() {
  local key=$1
  local value=$2
  log_info "Setting git config: $key"
  git config --global "$key" "$value"
}

main() {
  require_cmd git

  [[ -f "$CONFIG_FILE" ]] || die "Missing git config file: $CONFIG_FILE"

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue

    local key=${line%%=*}
    local value=${line#*=}

    [[ -n "$key" ]] || die "Invalid git config line: $line"
    apply_git_config "$key" "$value"
  done < "$CONFIG_FILE"
}

main "$@"
```

- [ ] **Step 2: Create `scripts/tmux.sh`**

```bash
#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

TMUX_COMPASS_REPO="https://github.com/wusung/tmux-compass.git"
TMUX_COMPASS_DIR="${HOME}/.config/tmux/plugins/tmux-compass"

main() {
  require_cmd git
  clone_or_update_repo "$TMUX_COMPASS_REPO" "$TMUX_COMPASS_DIR"
}

main "$@"
```

- [ ] **Step 3: Create `scripts/vim.sh`**

```bash
#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

TPM_REPO="https://github.com/tmux-plugins/tpm"
TPM_DIR="${HOME}/.tmux/plugins/tpm"

main() {
  require_cmd git
  clone_or_update_repo "$TPM_REPO" "$TPM_DIR"
}

main "$@"
```

- [ ] **Step 4: Verify shell syntax for module scripts**

Run:

```bash
bash -n scripts/git.sh
bash -n scripts/tmux.sh
bash -n scripts/vim.sh
```

Expected:
- no output
- all commands exit with code `0`

- [ ] **Step 5: Smoke-check git config parser**

Run:

```bash
rg -n "CONFIG_FILE|apply_git_config|git config --global" scripts/git.sh
```

Expected:
- parser uses `config/git.conf`
- settings are applied via `git config --global`

- [ ] **Step 6: Commit module scripts**

Run:

```bash
git add scripts/common.sh scripts/git.sh scripts/tmux.sh scripts/vim.sh
git commit -m "feat: add bootstrap module scripts"
```

Expected:
- 產生一筆包含三個模組與共用 helper 整合的 commit

### Task 4: Implement Remote Entry Script

**Files:**
- Create: `install.sh`
- Test: `install.sh`

- [ ] **Step 1: Create `install.sh`**

```bash
#!/usr/bin/env bash

set -euo pipefail

REPO_OWNER="wusung"
REPO_NAME="bootstrap-linux-workspace"
REPO_REF="${BOOTSTRAP_REPO_REF:-main}"
TARBALL_URL="https://codeload.github.com/${REPO_OWNER}/${REPO_NAME}/tar.gz/${REPO_REF}"

log() {
  printf '[BOOTSTRAP] %s\n' "$*"
}

die() {
  printf '[BOOTSTRAP][ERROR] %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  local cmd=$1
  command -v "$cmd" >/dev/null 2>&1 || die "Missing required command: $cmd"
}

main() {
  require_cmd bash
  require_cmd curl
  require_cmd git
  require_cmd tar

  local workdir
  workdir=$(mktemp -d)
  trap 'rm -rf "$workdir"' EXIT

  log "Downloading ${REPO_OWNER}/${REPO_NAME}@${REPO_REF}"
  curl -fsSL "$TARBALL_URL" -o "$workdir/repo.tar.gz"

  log "Extracting repository"
  tar -xzf "$workdir/repo.tar.gz" -C "$workdir"

  local repo_dir="$workdir/${REPO_NAME}-${REPO_REF}"
  [[ -d "$repo_dir" ]] || repo_dir=$(find "$workdir" -mindepth 1 -maxdepth 1 -type d | head -n 1)
  [[ -d "$repo_dir" ]] || die "Failed to locate extracted repository"

  log "Running git bootstrap"
  bash "$repo_dir/scripts/git.sh"

  log "Running tmux bootstrap"
  bash "$repo_dir/scripts/tmux.sh"

  log "Running vim bootstrap"
  bash "$repo_dir/scripts/vim.sh"

  log "Bootstrap completed"
}

main "$@"
```

- [ ] **Step 2: Verify shell syntax**

Run: `bash -n install.sh`
Expected: no output, exit code `0`

- [ ] **Step 3: Review dependency contract**

Run:

```bash
rg -n "require_cmd bash|require_cmd curl|require_cmd git|require_cmd tar" install.sh
```

Expected:
- `install.sh` 明確檢查必要命令

- [ ] **Step 4: Commit remote entry script**

Run:

```bash
git add install.sh
git commit -m "feat: add curl-to-bash bootstrap entrypoint"
```

Expected:
- 產生一筆只包含入口腳本的 commit

### Task 5: Finalize Docs And Verification

**Files:**
- Modify: `README.md`
- Test: `.gitignore`
- Test: `README.md`
- Test: `install.sh`
- Test: `scripts/common.sh`
- Test: `scripts/git.sh`
- Test: `scripts/tmux.sh`
- Test: `scripts/vim.sh`

- [ ] **Step 1: Expand `README.md` with complete usage and behavior**

```md
# bootstrap-linux-workspace

Linux 專用的個人工作環境 bootstrap repo。

## Scope

- 套用 `config/git.conf` 內定義的全域 git 設定
- 安裝或更新 `~/.config/tmux/plugins/tmux-compass`
- 安裝或更新 `~/.tmux/plugins/tpm`

## Non-Goals

- 不安裝 `git`
- 不安裝 `curl`
- 不安裝 `bash`
- 不安裝 `tmux`
- 不安裝 `vim`
- 不管理其他 dotfiles

## Requirements

- Linux
- `bash`
- `curl`
- `git`
- `tar`

## Configure Your Git Identity

Edit `config/git.conf` before publishing or using this repo:

```ini
user.name=Wu Sung
user.email=your-email@example.com
init.defaultBranch=main
pull.rebase=false
core.editor=vim
```

## One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/wusung/bootstrap-linux-workspace/main/install.sh | bash
```

## Local Run

```bash
bash install.sh
```

## Behavior

- 可重跑
- 既有 repo remote 不符時直接失敗
- 不自動刪除或覆蓋未知資料
```

- [ ] **Step 2: Run syntax verification for all shell files**

Run:

```bash
bash -n install.sh
bash -n scripts/common.sh
bash -n scripts/git.sh
bash -n scripts/tmux.sh
bash -n scripts/vim.sh
```

Expected:
- no output
- all commands exit with code `0`

- [ ] **Step 3: Run a static content review**

Run:

```bash
rg -n "your-email@example.com|tmux-compass|tpm|curl -fsSL|remote 不符|可重跑" README.md config/git.conf install.sh scripts
```

Expected:
- README includes install command and behavior notes
- `config/git.conf` still has editable personal values
- script references match spec

- [ ] **Step 4: Inspect final file layout**

Run: `fd -H -d 3 . .`
Expected:
- `.gitignore`
- `README.md`
- `install.sh`
- `config/git.conf`
- `scripts/common.sh`
- `scripts/git.sh`
- `scripts/tmux.sh`
- `scripts/vim.sh`

- [ ] **Step 5: Commit final docs and verification pass**

Run:

```bash
git add README.md .gitignore config/git.conf install.sh scripts
git commit -m "docs: finalize bootstrap usage and safeguards"
```

Expected:
- 產生最終整備 commit

## Self-Review

### Spec coverage

- `curl | bash` 單一入口：Task 4
- 模組化 `scripts/` 結構：Task 2、Task 3
- `git` 設定僅寫入指定 key：Task 1、Task 3
- `tmux-compass` 安裝位置與 repo：Task 3
- `tpm` 安裝位置與 repo：Task 3
- Linux only 與前提說明：Task 1、Task 5
- 錯誤處理與保守失敗：Task 2、Task 4、Task 5
- 可重跑性：Task 2、Task 3、Task 5

### Placeholder scan

- 無 `TBD`
- 無 `TODO`
- 無「implement later」
- 所有 shell code steps 都提供完整內容

### Type consistency

- 共用 helper 名稱在 `common.sh`、`tmux.sh`、`vim.sh` 一致
- `config/git.conf` 路徑在 `README.md` 與 `scripts/git.sh` 一致
- `bootstrap-linux-workspace` repo 名稱在 `README.md` 與 `install.sh` 一致
