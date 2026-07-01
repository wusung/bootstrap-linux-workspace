#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/common.sh"

CONFIG_FILE="$REPO_ROOT/config/git.conf"

trim_whitespace() {
  local value="${1-}"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"

  printf '%s\n' "$value"
}

apply_git_config() {
  local key="${1:?git config key is required}"
  local value="${2-}"

  git config --global "$key" "$value"
}

main() {
  require_cmd git

  local line
  local trimmed_line
  local key
  local value

  [[ -f "$CONFIG_FILE" ]] || die "git config file not found: $CONFIG_FILE"

  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed_line="$(trim_whitespace "$line")"

    [[ -z "$trimmed_line" ]] && continue
    [[ "${trimmed_line:0:1}" == "#" ]] && continue
    [[ "$trimmed_line" == *=* ]] || die "invalid git config entry: $line"

    key=${trimmed_line%%=*}
    value=${trimmed_line#*=}
    key="$(trim_whitespace "$key")"
    value="$(trim_whitespace "$value")"

    [[ -n "$key" ]] || die "invalid git config entry: $line"
    apply_git_config "$key" "$value"
  done <"$CONFIG_FILE"
}

main "$@"
