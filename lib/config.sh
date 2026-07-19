#!/bin/bash

# shellcheck disable=SC1090,SC2288
true

# .verbumprc loader. Shell-sourced config file discovered by walking up
# from $PWD toward /. CLI flags always win over env vars, which win over
# the file, which wins over the hard-coded defaults applied below.
#
# Precedence is enforced by call ordering in verbump.sh::main:
#   1. load-config           — sources .verbumprc (env wins over file)
#   2. apply-config-defaults — sets defaults for any still-unset keys
#   3. process-arguments     — CLI flags overwrite anything above
#
# Supported keys (1:1 with existing globals):
#   TAG_PREFIX  REL_PREFIX  PUSH_DEST  COMMIT_MSG_PREFIX  CHANGELOG_STYLE
#   FLAG_BRANCH  PR_BASE  FLAG_NOCHANGELOG  FLAG_CHANGELOG_PAUSE
#   ALLOW_DIRTY (skip the clean-working-tree preflight, R-SAFE-2)
#   NO_FETCH (skip the remote-sync preflight, R-SAFE-8)
#   TAG_SIGN (create a signed tag via `git tag -s`, R-SIGN-1)
#   RELEASE_BRANCHES (space-separated glob allowlist of branches a release
#                     may be cut from; empty = no guard, R-SAFE-10)
#   COMMIT_MSG_TEMPLATE (whole bump-commit message template with literal
#                        ${version}/${prev_version}/${tag}/${files}
#                        placeholders; when set COMMIT_MSG_PREFIX is
#                        ignored; empty = legacy prefix+list, R-TPL-1/2)
#   SOURCE_FILE (version source + primary bump target, mirrors --source;
#                default package.json, R-SRC-1/5)
#   BUMP_FILES (newline-separated multi-format bump-target specs, mirrors
#               --bump; CLI --bump entries append to these; empty = none,
#               R-TGT-1)
#   PRE_BUMP_CMD (release hook before any mutation; empty = no hook, R-HOOK-1)
#   POST_TAG_CMD (release hook after tag, before push; empty = no hook, R-HOOK-2)
#   FLAG_NOBRANCH (deprecated, no-op — tag-in-place is the default as of 2.0)
#
# Safety: shell-sourced files are code. The rc must be owned by the current
# user and not group- or world-writable. Any violation is refused with exit
# code 3.

# Config-able keys, in a plain indexed array so bash 3.2 is happy.
_CONFIG_KEYS=(TAG_PREFIX REL_PREFIX PUSH_DEST COMMIT_MSG_PREFIX \
              COMMIT_MSG_TEMPLATE FLAG_BRANCH PR_BASE CHANGELOG_STYLE \
              FLAG_NOBRANCH FLAG_NOCHANGELOG FLAG_CHANGELOG_PAUSE \
              ALLOW_DIRTY NO_FETCH RELEASE_BRANCHES TAG_SIGN SOURCE_FILE \
              BUMP_FILES PRE_BUMP_CMD POST_TAG_CMD)

# Walk up from $PWD. Echoes the first .verbumprc found; returns 1 if none.
# Never touches stdout on the "not found" path — load-config treats that
# as a silent no-op.
_find-rc-upward() {
  local dir
  dir="$(pwd -P)"
  while :; do
    if [ -f "$dir/.verbumprc" ]; then
      printf '%s' "$dir/.verbumprc"
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
      ".verbumprc at $rc is not owned by the current user — refusing to load." \
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
      ".verbumprc at $rc is $scope — refusing to load." \
      "Restrict permissions: chmod 644 $rc"
  fi
}

# Warn (non-fatal, exit stays 0) on top-level assignments to keys outside the
# supported allowlist — a lint heuristic that catches typos like TAG_PREFX=.
# It reads the file text, so it only sees literal column-0 `NAME=` lines, not
# computed or indented assignments; it is a footgun-catcher, NOT a security
# control (that boundary is _assert-rc-safe). Emits to stderr so it never
# pollutes the completions/--about stdout that main() produces later. R-CFG.
_warn-unknown-rc-keys() {
  local rc=$1 line key k known
  while IFS= read -r line || [ -n "$line" ]; do
    # Only bare column-0 `NAME=...` lines; a leading space (assignment nested
    # in shell control-flow) is skipped so it can't trip a false positive.
    case "$line" in
      [A-Za-z_]*=*) key=${line%%=*} ;;
      *) continue ;;
    esac
    # Reject anything that isn't a plain identifier (e.g. `export X`, `f() { X`).
    case "$key" in
      *[!A-Za-z0-9_]*) continue ;;
    esac
    known=0
    for k in "${_CONFIG_KEYS[@]}"; do
      [ "$key" = "$k" ] && { known=1; break; }
    done
    [ "$known" -eq 0 ] && log_warn "Unknown .verbumprc key '$key' — not a supported setting; it will have no effect." >&2
  done < "$rc"
  return 0  # non-fatal helper: never let the last key-check's status escape (set -e)
}

# Discover and source .verbumprc, preserving env-set values.
# Absent file = silent no-op. World-writable file = exit 3.
# Writes nothing to stdout (must stay clean; other codepaths emit
# completions / help scripts on stdout).
load-config() {
  local rc
  rc=$(_find-rc-upward) || return 0
  _assert-rc-safe "$rc"
  _warn-unknown-rc-keys "$rc"

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
# FLAG_* keys and the boolean safety keys (ALLOW_DIRTY, NO_FETCH)
# intentionally default to unset (false-equivalent under [ "$KEY" = true ]);
# RELEASE_BRANCHES defaults to unset/empty = guard off (R-SAFE-10);
# COMMIT_MSG_TEMPLATE defaults to unset/empty = the legacy
# COMMIT_MSG_PREFIX + generated-list message (R-TPL-1);
# PRE_BUMP_CMD / POST_TAG_CMD default to unset/empty = no hook (R-HOOK-1/2).
apply-config-defaults() {
  TAG_PREFIX="${TAG_PREFIX:-v}"
  REL_PREFIX="${REL_PREFIX:-release-}"
  PUSH_DEST="${PUSH_DEST:-origin}"
  COMMIT_MSG_PREFIX="${COMMIT_MSG_PREFIX:-chore: }"
  # "flat" (default, 1.x-identical) or "grouped" (R-CHLOG-1). Any other
  # value behaves as flat — same lenient contract as the FLAG_* keys.
  CHANGELOG_STYLE="${CHANGELOG_STYLE:-flat}"
  # Signed tags are opt-in (R-SIGN-1). Explicit false default; false and
  # unset behave identically under [ "$TAG_SIGN" = true ].
  TAG_SIGN="${TAG_SIGN:-false}"
  # Tag-in-place is the default as of 2.0 — cutting a release-<v> branch is
  # opt-in via --branch / --pr (or FLAG_BRANCH=true in config). Explicit false
  # default so the tag-in-place behaviour is the documented, canonical one.
  FLAG_BRANCH="${FLAG_BRANCH:-false}"
  # Version source + primary bump target (R-SRC-1/5). VER_FILE derives from
  # it in main() after process-arguments, so --source (CLI) wins per R-CFG-3.
  SOURCE_FILE="${SOURCE_FILE:-package.json}"
}
