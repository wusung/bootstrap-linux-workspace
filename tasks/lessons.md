# Lessons

## tmux-continuum systemd boot 整合不可在 bootstrap 直接複用上游 installer

**Pattern:** tmux-continuum 的 `scripts/handle_tmux_automatic_start.sh` 沒有 `install/uninstall` 參數;它從**執行中的 tmux server** 讀 `@continuum-boot`（`tmux show-option -gqv`）來決定 enable 或 disable。bootstrap 情境沒有執行中的 server，選項回 default `off`，直接呼叫會反而 `systemd_disable`。

**Rule:** 整合第三方 tmux plugin 的「開機自動啟動」時，先讀該 plugin 的 `scripts/` 實際實作，確認它是 runtime-coupled（依賴執行中的 tmux）還是可離線呼叫。runtime-coupled 者在 headless bootstrap 要改為自行 deterministic 產生 unit（語意對齊上游 template），並用 plugin 自身的 `@*-boot on` 讓它日後自維護（unit 已存在則不覆寫、已 enabled 則跳過，冪等共存）。

**Rule:** 對有 `ExecStop=tmux kill-server` 的 tmux systemd unit，若目標機器已有運作中的 tmux server（default socket），**不要**做 service start/stop 煙霧測試——會終止使用者整個 server。改以程式碼審查 + `systemd-analyze verify` 確認。
