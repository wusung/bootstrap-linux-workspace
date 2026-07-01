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

# Prefer the XDG config if the user already keeps tmux.conf there, otherwise the
# legacy ~/.tmux.conf. When neither exists, target the legacy path.
resolve_tmux_conf() {
  local xdg="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
  local legacy="${HOME}/.tmux.conf"

  if [[ -f "$xdg" ]]; then
    printf '%s' "$xdg"
  elif [[ -f "$legacy" ]]; then
    printf '%s' "$legacy"
  else
    printf '%s' "$legacy"
  fi
}

# Idempotently inject a managed block into a config file, delimited by the given
# begin/end markers. Any existing region between the markers is stripped first,
# so repeated runs replace rather than duplicate. When anchor is non-empty and a
# line containing it is found, the block is inserted immediately before that
# line; otherwise the block is appended at the end of the file.
#
# Returns 0 when the block was inserted before the anchor, or when no anchor was
# requested and the block was appended. Returns 1 when a non-empty anchor was
# requested but not found (block appended) so callers can warn if they need to.
inject_managed_block() {
  local conf_file="${1:?config file is required}"
  local begin_marker="${2:?begin marker is required}"
  local end_marker="${3:?end marker is required}"
  local block="${4?block content is required}"
  local anchor="${5:-}"
  local tmp
  local line
  local in_block=0
  local inserted=0
  local anchor_found=0

  tmp="$(mktemp)" || die "failed to create temp file"

  if [[ -f "$conf_file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" == "$begin_marker" ]]; then
        in_block=1
        continue
      fi
      if [[ "$in_block" -eq 1 ]]; then
        [[ "$line" == "$end_marker" ]] && in_block=0
        continue
      fi
      if [[ "$inserted" -eq 0 && -n "$anchor" && "$line" == *"$anchor"* ]]; then
        printf '%s\n' "$block" >> "$tmp"
        inserted=1
        anchor_found=1
      fi
      printf '%s\n' "$line" >> "$tmp"
    done < "$conf_file"
  fi

  if [[ "$inserted" -eq 0 ]]; then
    printf '%s\n' "$block" >> "$tmp"
  fi

  mv "$tmp" "$conf_file" || die "failed to write $conf_file"

  [[ -n "$anchor" && "$anchor_found" -eq 0 ]] && return 1
  return 0
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
