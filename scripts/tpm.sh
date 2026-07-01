#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common.sh"

TPM_REPO="https://github.com/tmux-plugins/tpm"
TPM_DIR="${HOME}/.tmux/plugins/tpm"

main() {
  require_cmd git
  clone_or_update_repo "$TPM_REPO" "$TPM_DIR"
}

main "$@"
