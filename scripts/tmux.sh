#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/common.sh"

TMUX_COMPASS_REPO="https://github.com/wusung/tmux-compass.git"
TMUX_COMPASS_DIR="${HOME}/.config/tmux/plugins/tmux-compass"

main() {
  require_cmd git
  clone_or_update_repo "$TMUX_COMPASS_REPO" "$TMUX_COMPASS_DIR"
}

main "$@"
