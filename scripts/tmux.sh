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

main() {
  require_cmd git
  clone_or_update_repo "$TMUX_COMPASS_REPO" "$TMUX_COMPASS_DIR"
  clone_or_update_repo "$TMUX_FZF_REPO" "$TMUX_FZF_DIR"
  clone_or_update_repo "$TMUX_CLAUDE_CODE_REPO" "$TMUX_CLAUDE_CODE_DIR"
}

main "$@"
