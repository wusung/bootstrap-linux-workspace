# tmux Session 持久化與開機自動回復 Design

## 目標

在既有 bootstrap 流程中，加入 tmux session 的持久化與開機自動回復能力：

- 安裝 `tmux-resurrect`（手動／自動存檔與還原 tmux session）
- 安裝 `tmux-continuum`（週期性自動存檔，並提供 systemd 開機整合）
- 配合 systemd user service，讓機器開機後自動起 tmux server 並還原上次 session

達成後，使用者重開機不需手動重建 session；上次的 windows／panes／工作目錄自動回復。

## Scope

本 feature 負責：

- 直接 clone／更新 `tmux-resurrect` 至 `~/.tmux/plugins/tmux-resurrect`
- 直接 clone／更新 `tmux-continuum` 至 `~/.tmux/plugins/tmux-continuum`
- 在使用者 tmux 設定檔注入一段受控、marker 界定、冪等的 managed block（plugin 宣告 + continuum 設定）
- 透過 tmux-continuum 內建 `scripts/handle_tmux_automatic_start.sh install` 生成並啟用 systemd user service
- 冪等確保 `loginctl enable-linger`，使 user manager 於開機（未登入前）即啟動

本 feature 不負責：

- 安裝 `tmux`（沿用主 repo 前提，系統須已備妥）
- 安裝 `git`、`curl`、`bash`
- 全量管理 dotfiles 或覆寫使用者整份 tmux.conf
- 管理其他 tmux plugin（compass、tpm 由既有模組負責）

## 對現行主 spec 的受控邊界擴張

`docs/bootstrap-linux-workspace/spec.md` 的非目標明列「不管理其他 dotfiles」與「不覆蓋不屬於本 repo 管理範圍的使用者設定」。

「開機後自動回復」的前提是 continuum 的設定（`@continuum-restore`、`@continuum-boot`）必須在 tmux 載入設定時生效，因此無法完全不碰 tmux.conf。

折衷原則（維持保守與可審計）：

- 只注入 **marker 界定** 的 managed block，不改動 block 以外任何一行：

  ```text
  # >>> bootstrap-linux-workspace: tmux persistence >>>
  ...
  # <<< bootstrap-linux-workspace: tmux persistence <<<
  ```

- **冪等**：block 已存在則整段替換，不重複堆疊。
- **可還原**：使用者刪除 marker block 即完全復原。
- 注入位置在 TPM 初始化行 `run '.../tpm'` **之前**，確保 `@plugin` 宣告先於 TPM 載入被註冊。
- 不建立、不覆寫使用者未持有的檔案結構;僅編輯既有 tmux.conf，或在皆不存在時建立 `~/.tmux.conf`。

## 前提與限制

- 僅支援 Linux（沿用主 repo）
- 需 `git`
- systemd 步驟需 `tmux` 在場且 `systemctl --user`（user D-Bus / user systemd instance）可用
- 使用者具備寫入 `$HOME` 與 `~/.config/systemd/user/` 的權限
- 腳本必須可重複執行（idempotent）

## systemd 開機自動回復機制

**為何不複用上游 installer**：tmux-continuum 的 `scripts/handle_tmux_automatic_start.sh` 不接受 `install` 參數,而是從**執行中的 tmux server** 讀 `@continuum-boot`（`tmux show-option -gqv`）來決定 enable 或 disable。bootstrap 情境沒有執行中的 tmux server，該選項會回傳 default `off`，導致腳本執行 `systemd_disable.sh`——與需求相反。故不可在 bootstrap 直接呼叫它。

**採「bootstrap 自行 deterministic 寫入 unit」**：

- bootstrap 直接寫入 `~/.config/systemd/user/tmux.service`（absolute tmux 路徑、resurrect `save.sh` 作為 `ExecStop`），`systemctl --user daemon-reload` 後 `enable`（不 start）。
- 語意對齊上游 `systemd_enable.sh` 產生的 unit（`Type=forking`、`ExecStart=<tmux> new-session -d`、`WantedBy=default.target`），差異僅省略非必要的 `Environment=DISPLAY=:0`。
- tmux.conf 設 `@continuum-boot 'on'`，使 continuum 日後每次載入設定時自維護該 unit：`write_unit_file_unless_exists` 見檔案已存在則不覆寫，`enable` 見已 enabled 則跳過——與 bootstrap 寫入的 unit 冪等共存、彼此不衝突。
- 分工：bootstrap 負責「首次開機即可用，不需先手動啟動一次 tmux」;continuum 負責「日後自我修復」。

還原鏈：

```mermaid
flowchart TD
    A[開機] --> B[systemd user manager 啟動<br/>因 linger=yes 不需登入]
    B --> C[tmux.service 啟動 detached tmux server]
    C --> D[tmux server 載入 tmux.conf]
    D --> E[TPM 載入 continuum plugin]
    E --> F{@continuum-restore on?}
    F -->|是| G[continuum 讀取最近存檔<br/>還原 windows/panes/cwd]
    F -->|否| H[空 server]
```

存檔鏈：continuum 依 `@continuum-save-interval` 週期性呼叫 resurrect 存檔至 resurrect 資料目錄，供開機時還原。

managed block 內容：

```tmux
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @continuum-restore 'on'
set -g @continuum-boot 'on'
set -g @continuum-save-interval '5'
```

`@continuum-boot 'on'` 使 tmux 下次載入設定時亦會自動安裝 unit;bootstrap 期間額外主動呼叫 installer，讓「不需先手動啟動一次 tmux」即完成 enable。兩者冪等，不衝突。

## 執行流程

新模組 `scripts/tmux-persistence.sh`：

1. `require_cmd git`
2. `clone_or_update_repo` tmux-resurrect
3. `clone_or_update_repo` tmux-continuum
4. 定位使用者 tmux.conf（優先 `~/.config/tmux/tmux.conf`，否則 `~/.tmux.conf`，皆無則建立 `~/.tmux.conf`）
5. 冪等注入 managed block（插在 tpm `run` 行前;無 tpm 行則附加於檔尾並警告）
6. 若 `tmux` 在場且 `systemctl --user` 可用：
   - deterministic 寫入 `~/.config/systemd/user/tmux.service`（冪等替換）
   - `systemctl --user daemon-reload` 後 `systemctl --user enable tmux.service`
   - `loginctl enable-linger "$USER"`（best-effort）
   - **不** start service（僅 enable，供下次開機）
7. 否則：輸出 warning 與後續手動指示，但不使整體 bootstrap 失敗

`install.sh` 的 `MODULES` 陣列在 `vim.sh`（tpm）之後加入 `tmux-persistence.sh`。

## 錯誤處理

- `git` 缺失、plugin clone 失敗、目標路徑非預期 repo／remote 不符：沿用 `clone_or_update_repo` 立即失敗語意。
- tmux 不存在或 user bus 不可用：systemd 步驟降級為 warning，plugins 與 tmux.conf 設定仍完成。
- tmux.conf 注入：marker block 偵測失敗或寫入失敗才報錯;既有 block 一律整段替換。

## 可重跑性要求

- 二次執行不重複插入 managed block（marker 冪等替換）。
- plugin repo 已存在時走 `git pull --ff-only`，不重複 clone。
- `handle_tmux_automatic_start.sh install` 與 `loginctl enable-linger` 重複執行不產生額外副作用。

## 測試與驗證策略

- 全部 shell 檔 `bash -n` 通過。
- 若 `shellcheck` 在場，維持 shellcheck 友善結構。
- managed block 二次注入後檔案僅有一份 block。
- 本機（tmux 3.x + systemd user + linger）實測：unit 生成於 `~/.config/systemd/user/tmux.service` 且 `systemctl --user is-enabled tmux.service` 回報 enabled。

## 非目標

- 跨平台（macOS launchd）支援
- 自動安裝 tmux
- 互動式選單
- 管理 resurrect 存檔內容或還原策略細節
