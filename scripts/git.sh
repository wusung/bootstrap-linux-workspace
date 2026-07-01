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

# Resolve a value from a preset (env var) or, when running on a terminal,
# an interactive prompt. Prints nothing but the resolved value on stdout.
prompt_value() {
  local prompt="${1:?prompt text is required}"
  local preset="${2-}"
  local value=""

  if [[ -n "$preset" ]]; then
    printf '%s' "$preset"
    return 0
  fi

  if [[ -t 0 ]]; then
    read -rp "$prompt" value || true
  fi

  printf '%s' "$value"
}

apply_config_file() {
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

configure_identity() {
  local name
  local email

  name="$(trim_whitespace "$(prompt_value 'Git user.name: ' "${GIT_USER_NAME-}")")"
  email="$(trim_whitespace "$(prompt_value 'Git user.email: ' "${GIT_USER_EMAIL-}")")"

  [[ -n "$name" ]] || die "user.name is required (set GIT_USER_NAME or run interactively)"
  [[ -n "$email" ]] || die "user.email is required (set GIT_USER_EMAIL or run interactively)"

  apply_git_config user.name "$name"
  apply_git_config user.email "$email"
  log_info "Set user.name=$name user.email=$email"
}

configure_signing() {
  local key

  key="$(trim_whitespace "$(prompt_value 'GPG signing key (blank to disable commit/tag signing): ' "${GIT_SIGNING_KEY-}")")"

  if [[ -n "$key" ]]; then
    apply_git_config user.signingkey "$key"
    apply_git_config commit.gpgsign true
    apply_git_config tag.gpgsign true
    log_info "Enabled GPG signing with key $key"
  else
    git config --global --unset user.signingkey 2>/dev/null || true
    apply_git_config commit.gpgsign false
    apply_git_config tag.gpgsign false
    log_info "GPG signing disabled"
  fi
}

configure_credentials() {
  if ! command -v gh >/dev/null 2>&1; then
    log_warn "gh not found; skipping GitHub credential helper setup"
    return 0
  fi

  log_info "Configuring GitHub credential helper via gh"
  gh auth setup-git 2>/dev/null \
    || apply_git_config credential.https://github.com.helper '!gh auth git-credential'
}

main() {
  require_cmd git

  apply_config_file
  configure_identity
  configure_signing
  configure_credentials
}

main "$@"
