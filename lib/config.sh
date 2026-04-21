#!/bin/bash

# shellcheck disable=SC1090,SC2288
true

# .ver-bumprc loader. Shell-sourced config file discovered by walking up
# from $PWD toward /. CLI flags always win over env vars, which win over
# the file, which wins over the hard-coded defaults applied below.
#
# Precedence is enforced by call ordering in ver-bump.sh::main:
#   1. load-config           — sources .ver-bumprc (env wins over file)
#   2. apply-config-defaults — sets defaults for any still-unset keys
#   3. process-arguments     — CLI flags overwrite anything above
#
# Supported keys (1:1 with existing globals):
#   TAG_PREFIX  REL_PREFIX  PUSH_DEST  COMMIT_MSG_PREFIX
#   FLAG_NOBRANCH  FLAG_NOCHANGELOG  FLAG_CHANGELOG_PAUSE
#
# Safety: shell-sourced files are code. The rc must be owned by the current
# user and not group- or world-writable. Any violation is refused with exit
# code 3.

# Config-able keys, in a plain indexed array so bash 3.2 is happy.
_CONFIG_KEYS=(TAG_PREFIX REL_PREFIX PUSH_DEST COMMIT_MSG_PREFIX \
              FLAG_NOBRANCH FLAG_NOCHANGELOG FLAG_CHANGELOG_PAUSE)

# Walk up from $PWD. Echoes the first .ver-bumprc found; returns 1 if none.
# Never touches stdout on the "not found" path — load-config treats that
# as a silent no-op.
_find-rc-upward() {
  local dir
  dir="$(pwd -P)"
  while :; do
    if [ -f "$dir/.ver-bumprc" ]; then
      printf '%s' "$dir/.ver-bumprc"
      return 0
    fi
    [ "$dir" = "/" ] && return 1
    dir="$(dirname "$dir")"
  done
}

# Refuse to load an rc that isn't owned by the current user, or that is
# writable by group or other. Exits 3 via fail() if any check fails.
_assert-rc-safe() {
  local rc=$1

  # Ownership: must match the effective uid. An attacker-owned rc in a dir
  # we have write-access to would otherwise be silently sourced. `-uid` is
  # numeric and portable across BSD + GNU find.
  if ! find "$rc" -uid "$(id -u)" -type f 2>/dev/null | grep -q .; then
    fail 3 \
      ".ver-bumprc at $rc is not owned by the current user — refusing to load." \
      "Take ownership: chown $(id -un) $rc"
  fi

  # Permissions: reject any write bit for group or other. `-perm -NNNN`
  # requires ALL bits in the mask to be set, so g+w and o+w must be checked
  # separately. Using if-blocks (not $(... | grep -c)) keeps us safe under
  # `set -e`: a zero-match pipeline exits 1 and would fail the assignment.
  local is_world=0 is_group=0
  if find "$rc" -perm -0002 -type f 2>/dev/null | grep -q .; then
    is_world=1
  fi
  if find "$rc" -perm -0020 -type f 2>/dev/null | grep -q .; then
    is_group=1
  fi
  if [ "$is_world" -eq 1 ] || [ "$is_group" -eq 1 ]; then
    local scope
    if [ "$is_world" -eq 1 ] && [ "$is_group" -eq 1 ]; then
      scope="group- and world-writable"
    elif [ "$is_world" -eq 1 ]; then
      scope="world-writable"
    else
      scope="group-writable"
    fi
    fail 3 \
      ".ver-bumprc at $rc is $scope — refusing to load." \
      "Restrict permissions: chmod 644 $rc"
  fi
}

# Discover and source .ver-bumprc, preserving env-set values.
# Absent file = silent no-op. World-writable file = exit 3.
# Writes nothing to stdout (must stay clean; other codepaths emit
# completions / help scripts on stdout).
load-config() {
  local rc
  rc=$(_find-rc-upward) || return 0
  _assert-rc-safe "$rc"

  # Snapshot env-exported values BEFORE sourcing, so env wins over file.
  # We only snapshot variables that were inherited from the environment
  # (declared with -x) — NOT internal script globals set elsewhere, which
  # would let source-time defaults masquerade as env values and beat the
  # file. Parallel indexed arrays (bash 3.2 has no associative arrays).
  local saved_keys=() saved_vals=()
  local var
  for var in "${_CONFIG_KEYS[@]}"; do
    if declare -p "$var" 2>/dev/null | grep -q '^declare -x'; then
      saved_keys+=("$var")
      saved_vals+=("${!var}")
    fi
  done

  # shellcheck source=/dev/null
  source "$rc"

  # Restore env-set values on top of anything the file set.
  local i
  for (( i = 0; i < ${#saved_keys[@]}; i++ )); do
    printf -v "${saved_keys[$i]}" '%s' "${saved_vals[$i]}"
  done
}

# Apply built-in defaults for any config key still unset after load-config.
# FLAG_* keys intentionally default to unset (false-equivalent under
# [ "$FLAG_X" = true ]).
apply-config-defaults() {
  TAG_PREFIX="${TAG_PREFIX:-v}"
  REL_PREFIX="${REL_PREFIX:-release-}"
  PUSH_DEST="${PUSH_DEST:-origin}"
  COMMIT_MSG_PREFIX="${COMMIT_MSG_PREFIX:-chore: }"
}
