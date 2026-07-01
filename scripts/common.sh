#!/usr/bin/env bash

__common_sh_restore_errexit=0
__common_sh_restore_nounset=0
__common_sh_restore_pipefail=0

[[ $- == *e* ]] && __common_sh_restore_errexit=1
[[ $- == *u* ]] && __common_sh_restore_nounset=1
[[ ":${SHELLOPTS-}:" == *":pipefail:"* ]] && __common_sh_restore_pipefail=1

set -euo pipefail

log_info() {
  printf '[INFO] %s\n' "$*" >&2
}

log_warn() {
  printf '[WARN] %s\n' "$*" >&2
}

log_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

die() {
  log_error "$*"
  exit 1
}

require_cmd() {
  local cmd="${1:?command name is required}"

  command -v "$cmd" >/dev/null 2>&1 || die "required command not found: $cmd"
}

ensure_dir() {
  local dir_path="${1:?directory path is required}"

  if [[ -e "$dir_path" && ! -d "$dir_path" ]]; then
    die "path exists and is not a directory: $dir_path"
  fi

  mkdir -p "$dir_path" || die "failed to create directory: $dir_path"
}

is_git_repo() {
  local repo_dir="${1:?repository path is required}"

  require_cmd git

  [[ -d "$repo_dir" ]] || return 1
  git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

get_remote_url() {
  local repo_dir="${1:?repository path is required}"
  local remote_names
  local remote_url

  require_cmd git
  is_git_repo "$repo_dir" || die "not a git repository: $repo_dir"

  if remote_url="$(git -C "$repo_dir" config --get remote.origin.url 2>/dev/null)"; then
    printf '%s\n' "$remote_url"
    return 0
  fi

  remote_names="$(git -C "$repo_dir" remote 2>/dev/null)" || die "failed to inspect git remotes: $repo_dir"

  if [[ -z "$remote_names" ]]; then
    die "git repository has no origin remote: $repo_dir"
  fi

  if [[ $'\n'"$remote_names"$'\n' == *$'\n'"origin"$'\n'* ]]; then
    die "failed to read origin remote URL: $repo_dir"
  fi

  die "git repository has no origin remote: $repo_dir"
}

clone_or_update_repo() {
  local expected_url="${1:?repository URL is required}"
  local dest_dir="${2:?destination directory is required}"
  local parent_dir
  local current_branch
  local current_url

  require_cmd git

  if [[ ! -e "$dest_dir" ]]; then
    parent_dir="$(dirname "$dest_dir")"
    ensure_dir "$parent_dir"
    log_info "Cloning $expected_url into $dest_dir"
    git clone "$expected_url" "$dest_dir" || die "failed to clone $expected_url into $dest_dir"
    return 0
  fi

  [[ -d "$dest_dir" ]] || die "destination exists and is not a directory: $dest_dir"
  is_git_repo "$dest_dir" || die "destination exists but is not a git repository: $dest_dir"

  current_url="$(get_remote_url "$dest_dir")"
  [[ "$current_url" == "$expected_url" ]] || die "origin URL mismatch for $dest_dir: expected $expected_url, got $current_url"

  current_branch="$(git -C "$dest_dir" symbolic-ref --quiet --short HEAD 2>/dev/null)" || die "repository is in detached HEAD state: $dest_dir"
  git -C "$dest_dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1 || die "current branch has no upstream configured: $dest_dir ($current_branch)"

  log_info "Updating $dest_dir from $expected_url"
  git -C "$dest_dir" pull --ff-only || die "failed to update repository: $dest_dir"
}

if [[ $__common_sh_restore_errexit -eq 1 ]]; then
  set -e
else
  set +e
fi

if [[ $__common_sh_restore_nounset -eq 1 ]]; then
  set -u
else
  set +u
fi

if [[ $__common_sh_restore_pipefail -eq 1 ]]; then
  set -o pipefail
else
  set +o pipefail
fi

unset __common_sh_restore_errexit
unset __common_sh_restore_nounset
unset __common_sh_restore_pipefail
