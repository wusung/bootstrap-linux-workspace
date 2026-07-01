# tmux Session 持久化與開機自動回復 Implementation Plan

> **For agentic workers:** 依 superpowers:executing-plans 逐 task 實作。步驟用 checkbox (`- [ ]`) 追蹤。

**Goal:** 在既有 bootstrap 加入 `tmux-resurrect` + `tmux-continuum`，並以 systemd user service 達成開機後自動回復上次 tmux session。

**Architecture:** 新增單責任模組 `scripts/tmux-persistence.sh`，沿用 `scripts/common.sh` 的 `clone_or_update_repo`。plugin 直接 clone 到 `~/.tmux/plugins/`（與使用者 TPM 載入路徑一致）。tmux.conf 以 marker 界定的 managed block 注入 continuum 設定。systemd unit 由 bootstrap deterministic 寫入並 enable（原因見 spec：上游 installer 需執行中 tmux server）。`install.sh` 的 `MODULES` 於 `vim.sh` 後加入本模組。

**Tech Stack:** Bash、git、tmux、systemd (user)、loginctl。

---

## File Structure

### New files

- `scripts/tmux-persistence.sh` — clone resurrect/continuum、注入 tmux.conf managed block、寫入並 enable systemd unit
- `docs/tmux-resurrect-continuum/spec.md` — 設計決策（已建立）
- `docs/tmux-resurrect-continuum/plan.md` — 本檔

### Modified files

- `install.sh` — `MODULES` 陣列加入 `tmux-persistence.sh`
- `README.md` — 新模組職責、systemd 行為、安裝目標、可還原說明

---

### Task 1: 新增 scripts/tmux-persistence.sh

**Files:** Create `scripts/tmux-persistence.sh`

- [ ] **Step 1: plugin 常數與 clone**
  - `TMUX_RESURRECT_REPO=https://github.com/tmux-plugins/tmux-resurrect`
    → `${HOME}/.tmux/plugins/tmux-resurrect`
  - `TMUX_CONTINUUM_REPO=https://github.com/tmux-plugins/tmux-continuum`
    → `${HOME}/.tmux/plugins/tmux-continuum`
  - 沿用 `clone_or_update_repo`
- [ ] **Step 2: 定位 tmux.conf**
  - 優先 `~/.config/tmux/tmux.conf`，否則 `~/.tmux.conf`，皆無則建立 `~/.tmux.conf`
- [ ] **Step 3: 冪等注入 managed block**
  - marker：`# >>> bootstrap-linux-workspace: tmux persistence >>>` / `# <<< ... <<<`
  - 內容：resurrect/continuum `@plugin` + `@continuum-restore on` + `@continuum-boot on` + `@continuum-save-interval 5`
  - 既有 block 整段替換;插在 `run '.../tpm'` 行前;無 tpm 行則附加檔尾並 `log_warn`
- [ ] **Step 4: systemd unit（保守降級）**
  - 前置：`command -v tmux` 且 `systemctl --user show-environment` 成功;否則 `log_warn` 跳過
  - 寫入 `~/.config/systemd/user/tmux.service`（absolute tmux 路徑、`ExecStop` 為 resurrect `save.sh`、`Type=forking`、`WantedBy=default.target`）
  - `systemctl --user daemon-reload` → `enable tmux.service`（不 start）
  - `loginctl enable-linger "$USER"` best-effort（失敗僅 `log_warn`）

**驗收：** `bash -n scripts/tmux-persistence.sh` exit 0。

### Task 2: 串接 install.sh

**Files:** Modify `install.sh`

- [ ] `MODULES=(git.sh tmux.sh vim.sh tmux-persistence.sh)`
- [ ] 表格文件同步（README 安裝流程表）

**驗收：** `bash -n install.sh` exit 0;`rg tmux-persistence install.sh` 命中。

### Task 3: 更新 README.md

**Files:** Modify `README.md`

- [ ] 新增模組 4 職責列（clone resurrect/continuum + systemd unit）
- [ ] 說明開機自動回復行為、systemd 降級、marker block 可還原

### Task 4: 驗證

- [ ] 全 shell `bash -n`
- [ ] `shellcheck`（若在場）
- [ ] 本機執行 `bash scripts/tmux-persistence.sh`：
  - plugin dir 存在
  - tmux.conf 有且僅有一份 managed block（二次執行不重複）
  - `~/.config/systemd/user/tmux.service` 存在且 `systemctl --user is-enabled tmux.service` == enabled
- [ ] 二次執行冪等（marker block 數量不變、`git pull --ff-only`）

## Self-Review

### Spec coverage

- resurrect/continuum 安裝：Task 1 Step 1
- tmux.conf managed block 冪等：Task 1 Step 3、Task 4
- systemd 開機自動回復（deterministic unit + enable + linger）：Task 1 Step 4、Task 4
- 保守降級（無 tmux／無 user bus）：Task 1 Step 4
- install.sh 串接：Task 2
- 文件：Task 3

### 邊界擴張記錄

- 主 spec non-goal「不管理 dotfiles」受控擴張為「僅注入 marker 界定、冪等、可還原的 managed block」，已於 `spec.md` 記錄。
