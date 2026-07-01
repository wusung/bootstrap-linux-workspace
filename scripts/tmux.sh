#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/common.sh"

TMUX_COMPASS_REPO="https://github.com/wusung/tmux-compass.git"
TMUX_COMPASS_DIR="${HOME}/.config/tmux/plugins/tmux-compass"

TMUX_FZF_REPO="https://github.com/sainnhe/tmux-fzf.git"
TMUX_FZF_DIR="${HOME}/.config/tmux/plugins/tmux-fzf"

TMUX_CLAUDE_CODE_REPO="https://github.com/MaxGhenis/tmux-claude-code.git"
TMUX_CLAUDE_CODE_DIR="${HOME}/.config/tmux/plugins/tmux-claude-code"

BLOCK_BEGIN="# >>> bootstrap-linux-workspace: tmux plugins >>>"
BLOCK_END="# <<< bootstrap-linux-workspace: tmux plugins <<<"

# tmux-fzf and tmux-claude-code are cloned outside TPM's plugin dir, so they
# cannot be registered via @plugin. Instead their entry scripts are executed
# with run-shell. Absolute paths are used because a leading ~ inside the
# single-quoted run-shell argument would not be expanded by tmux.
read -r -d '' MANAGED_BLOCK <<BLOCK || true
${BLOCK_BEGIN}
run-shell '${TMUX_FZF_DIR}/main.tmux'
run-shell '${TMUX_CLAUDE_CODE_DIR}/claude-code.tmux'
${BLOCK_END}
BLOCK

main() {
  require_cmd git
  clone_or_update_repo "$TMUX_COMPASS_REPO" "$TMUX_COMPASS_DIR"
  clone_or_update_repo "$TMUX_FZF_REPO" "$TMUX_FZF_DIR"
  clone_or_update_repo "$TMUX_CLAUDE_CODE_REPO" "$TMUX_CLAUDE_CODE_DIR"

  local conf_file
  conf_file="$(resolve_tmux_conf)"
  # Anchor before the TPM `run '.../tpm/tpm'` line when present so TPM stays
  # last; these plugins do not depend on TPM, so a missing anchor (block
  # appended) is fine and needs no warning.
  inject_managed_block "$conf_file" "$BLOCK_BEGIN" "$BLOCK_END" "$MANAGED_BLOCK" "tpm/tpm" || true
  log_info "Injected tmux plugins block into $conf_file"
}

main "$@"
