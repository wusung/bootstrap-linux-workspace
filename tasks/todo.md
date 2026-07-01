# TODO: tmux 持久化與開機自動回復

Spec/Plan: `docs/tmux-resurrect-continuum/{spec,plan}.md`

## 實作

- [x] 新增 `scripts/tmux-persistence.sh`
  - [x] clone/update tmux-resurrect → `~/.tmux/plugins/tmux-resurrect`
  - [x] clone/update tmux-continuum → `~/.tmux/plugins/tmux-continuum`
  - [x] 定位 tmux.conf（`~/.config/tmux/tmux.conf` → `~/.tmux.conf`）
  - [x] 冪等注入 marker managed block（continuum 設定），插在 tpm run 行前
  - [x] deterministic 寫入 `~/.config/systemd/user/tmux.service` + `daemon-reload` + `enable`
  - [x] `loginctl enable-linger` best-effort;無 tmux／無 user bus 則降級 warning
- [x] `install.sh` `MODULES` 加入 `tmux-persistence.sh`
- [x] 更新 `README.md`

## 驗證

- [x] 全 shell `bash -n` 通過（install.sh + scripts/*.sh）
- [x] `shellcheck` clean（加 `source=` directive 後無警告）
- [x] 本機執行:兩 plugin dir 存在、`~/.tmux.conf` 單一 managed block 且插在 `run` 行前、`tmux.service` `is-enabled == enabled` 且 `is-active == inactive`（未 start）
- [x] 二次執行冪等（19 行不變、marker pair 各 1、plugin `git pull` already up to date）
- [x] `systemd-analyze --user verify tmux.service` clean

## Review

已完成並實測套用於本機。

**驗證結果**
- 全 shell 語法 + shellcheck clean。
- 模組冪等:run1 clone + 注入 + enable;run2 pull + block 整段替換（不重複）+ enable 冪等。
- unit 檔案內容正確（absolute tmux 路徑、resurrect save.sh 為 ExecStop、`WantedBy=default.target`），`systemd-analyze verify` clean，enabled 但未 start。
- linger 本機已 `yes`。

**未做的驗證與原因**
- 未做 service start/stop 即時還原煙霧測試:使用者當下有 12 個運作中的 tmux session（default socket），unit 的 `ExecStop=tmux kill-server` 會終止整個 server。為避免波及既有工作階段，還原鏈改以程式碼審查（`continuum.tmux` 的 `start_auto_restore_in_background` + `@continuum-restore on` gate）與 unit 正確性確認，未即時執行。

**使用者後續注意事項**
- 目前運作中的 tmux server 於 continuum 安裝前啟動，尚未載入 continuum，因此還不會自動存檔。需在任一 server 內 `tmux source-file ~/.tmux.conf`（或 prefix + r）載入 continuum 後，才會依 5 分鐘間隔存檔，首次重開機才有內容可還原。
- `systemctl --user stop tmux.service` 會終止 default socket 上整個 tmux server（continuum-boot 設計行為）。
- 備份留於 `~/.tmux.conf.bak.bootstrap`，確認無誤後可自行刪除。
