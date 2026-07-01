#!/usr/bin/env bash
#
# bootstrap-linux-workspace entry point.
#
# Usage:
#   Remote:  curl -fsSL https://raw.githubusercontent.com/wusung/bootstrap-linux-workspace/main/install.sh | bash
#   Local:   bash install.sh
#
# When piped from curl there is no local checkout, so the repo is cloned into a
# temporary directory and the module scripts are run from there. When run from a
# checkout, the modules are run in place. Modules run strictly in order and any
# failure aborts immediately with a non-zero exit code.
set -euo pipefail

REPO_URL="https://github.com/wusung/bootstrap-linux-workspace.git"
REPO_BRANCH="main"
MODULES=(git.sh tmux.sh vim.sh)

# Self-contained helpers: install.sh must stand alone before the repo (and thus
# scripts/common.sh) is available.
log_info()  { printf '[INFO] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }
die()       { log_error "$*"; exit 1; }

require_cmd() {
  local cmd="${1:?command name is required}"
  command -v "$cmd" >/dev/null 2>&1 || die "required command not found: $cmd"
}

TMP_DIR=""
cleanup() {
  [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Resolve the directory of this script when it is a real file (local run).
resolve_self_dir() {
  local source="${BASH_SOURCE[0]:-}"
  [[ -n "$source" && -f "$source" ]] || return 1
  cd "$(dirname "$source")" && pwd
}

# Print the repo root to run modules from, cloning into a temp dir if needed.
resolve_repo_root() {
  local self_dir
  if self_dir="$(resolve_self_dir)" && [[ -f "$self_dir/scripts/${MODULES[0]}" ]]; then
    log_info "Running from local checkout: $self_dir"
    printf '%s' "$self_dir"
    return 0
  fi

  log_info "No local checkout detected; cloning $REPO_URL ($REPO_BRANCH)"
  TMP_DIR="$(mktemp -d)"
  git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$TMP_DIR/repo" \
    || die "failed to clone $REPO_URL"
  printf '%s' "$TMP_DIR/repo"
}

main() {
  require_cmd git
  require_cmd curl

  local repo_root
  repo_root="$(resolve_repo_root)"

  local module
  local module_path
  for module in "${MODULES[@]}"; do
    module_path="$repo_root/scripts/$module"
    [[ -f "$module_path" ]] || die "module not found: $module_path"
    log_info "Running module: $module"
    bash "$module_path" || die "module failed: $module"
  done

  log_info "Bootstrap complete."
}

main "$@"
