#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/common.sh
source "$SCRIPT_DIR/common.sh"

# tmux-resurrect / tmux-continuum are cloned directly into TPM's plugin dir so
# they load through the existing `run '~/.tmux/plugins/tpm/tpm'` line and are
# also recognised by TPM as already-installed.
TMUX_RESURRECT_REPO="https://github.com/tmux-plugins/tmux-resurrect"
TMUX_RESURRECT_DIR="${HOME}/.tmux/plugins/tmux-resurrect"
TMUX_CONTINUUM_REPO="https://github.com/tmux-plugins/tmux-continuum"
TMUX_CONTINUUM_DIR="${HOME}/.tmux/plugins/tmux-continuum"

BLOCK_BEGIN="# >>> bootstrap-linux-workspace: tmux persistence >>>"
BLOCK_END="# <<< bootstrap-linux-workspace: tmux persistence <<<"

# The managed block. Kept between the markers above so it can be replaced
# idempotently and fully reverted by deleting the marked region.
read -r -d '' MANAGED_BLOCK <<BLOCK || true
${BLOCK_BEGIN}
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @continuum-restore 'on'
set -g @continuum-boot 'on'
set -g @continuum-save-interval '5'
${BLOCK_END}
BLOCK

# resolve_tmux_conf and inject_managed_block are shared helpers from common.sh.
# The persistence @plugin declarations must be registered before TPM
# initialises, so the block is anchored to the TPM `run '.../tpm/tpm'` line.

# Write and enable a systemd user service that starts a detached tmux server on
# boot; combined with @continuum-restore this restores the last saved session.
# Upstream's handle_tmux_automatic_start.sh cannot be reused here because it
# reads @continuum-boot from a *running* tmux server (absent during bootstrap)
# and would disable the unit. Degrades to a warning when tmux or the systemd
# user instance is unavailable, without failing the whole bootstrap.
setup_systemd_boot() {
  local tmux_bin
  local unit_dir="${HOME}/.config/systemd/user"
  local unit_file="${unit_dir}/tmux.service"
  local resurrect_save="${TMUX_RESURRECT_DIR}/scripts/save.sh"

  if ! tmux_bin="$(command -v tmux 2>/dev/null)"; then
    log_warn "tmux not found; skipping systemd boot integration."
    log_warn "Install tmux, then launch it once: @continuum-boot will self-install the service."
    return 0
  fi

  if ! systemctl --user show-environment >/dev/null 2>&1; then
    log_warn "systemd user instance unavailable (no user D-Bus); skipping systemd boot integration."
    log_warn "Later, in a normal login session, run: systemctl --user enable tmux.service"
    return 0
  fi

  ensure_dir "$unit_dir"

  cat > "$unit_file" <<EOF
[Unit]
Description=tmux default session (detached)
Documentation=man:tmux(1)

[Service]
Type=forking
ExecStart=${tmux_bin} new-session -d
ExecStop=${resurrect_save}
ExecStop=${tmux_bin} kill-server
KillMode=control-group
RestartSec=2

[Install]
WantedBy=default.target
EOF
  log_info "Wrote systemd unit: $unit_file"

  if ! systemctl --user daemon-reload; then
    log_warn "systemctl --user daemon-reload failed; enable the unit manually later."
    return 0
  fi
  if ! systemctl --user enable tmux.service >/dev/null 2>&1; then
    log_warn "failed to enable tmux.service; run: systemctl --user enable tmux.service"
    return 0
  fi
  log_info "Enabled tmux.service (starts on next boot; not started now)"

  if loginctl enable-linger "$USER" >/dev/null 2>&1; then
    log_info "Linger enabled for $USER"
  else
    log_warn "Could not enable linger for $USER; boot-before-login start may not work."
    log_warn "Run: loginctl enable-linger $USER"
  fi
}

main() {
  require_cmd git
  clone_or_update_repo "$TMUX_RESURRECT_REPO" "$TMUX_RESURRECT_DIR"
  clone_or_update_repo "$TMUX_CONTINUUM_REPO" "$TMUX_CONTINUUM_DIR"

  local conf_file
  conf_file="$(resolve_tmux_conf)"
  if ! inject_managed_block "$conf_file" "$BLOCK_BEGIN" "$BLOCK_END" "$MANAGED_BLOCK" "tpm/tpm"; then
    log_warn "No TPM 'run .../tpm/tpm' line found in $conf_file; appended managed block at end."
    log_warn "Ensure the bottom of tmux.conf has: run '~/.tmux/plugins/tpm/tpm' so the plugins load."
  fi
  log_info "Injected tmux persistence block into $conf_file"

  setup_systemd_boot
}

main "$@"
