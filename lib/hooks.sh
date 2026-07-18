#!/bin/bash

# shellcheck disable=SC2288
true

# Release hooks (R-HOOK-1..6, issue #62). Two fixed hook points — deliberately
# not a plugin system (PRD §3.1):
#
#   PRE_BUMP_CMD  — after ALL Verify preflights pass, before any file mutation.
#                   Non-zero → exit 4, nothing mutated.
#   POST_TAG_CMD  — after tag creation, before push / --pr / --release.
#                   Non-zero → exit 4; the commit + tag are kept (recover with
#                   --undo).
#
# Both keys come from the environment or .verbumprc only (R-HOOK-3, same
# trust domain: the rc is already shell-sourced behind the R-CFG-4 permission
# checks). There is no CLI flag to *set* a hook; `--no-hooks` (R-HOOK-5)
# skips both for a single run. Empty/unset key = no hook.

# _run-hook <name> <cmd> — shared runner for both hook points (R-HOOK-4/6).
#   Logs the resolved command, then runs it via `bash -c` with the release
#   context exported for the child only:
#     VERBUMP_VERSION       new version (V_NEW)
#     VERBUMP_PREV_VERSION  previous version (V_PREV)
#     VERBUMP_TAG           full tag name (TAG_PREFIX + V_NEW)
#   stdout/stderr are NOT captured — they stream through to the user, so
#   test runners and build tools keep their progress output. Under --dry-run
#   the command is printed with the [dry-run] prefix (stderr, R-DRY-2) and
#   not executed. Returns the hook's exit status; callers translate non-zero
#   into `fail 4` with hook-specific recovery copy.
_run-hook() {
  local name=$1 cmd=$2

  if [ "${FLAG_DRYRUN:-false}" = true ]; then
    echo -e "${S_LIGHT-}[dry-run]${RESET-} would run ${name} hook: bash -c '${cmd}'" >&2
    return 0
  fi

  echo -e "\nRunning ${name} hook: ${S_VAL-}${cmd}${RESET-}"
  VERBUMP_VERSION="${V_NEW-}" \
  VERBUMP_PREV_VERSION="${V_PREV-}" \
  VERBUMP_TAG="${TAG_PREFIX-}${V_NEW-}" \
    bash -c "$cmd"
}

# run-pre-bump-hook — PRE_BUMP_CMD (R-HOOK-1). Called from main() after the
# entire Verify section (V_NEW/V_PREV are resolved by then) and immediately
# before the Release section's first mutation (do-packagefile-bump), so a
# failing hook leaves the working tree byte-identical.
run-pre-bump-hook() {
  [ "${FLAG_NOHOOKS:-false}" = true ] && return 0
  [ -n "${PRE_BUMP_CMD:-}" ] || return 0

  local rc=0
  _run-hook "pre-bump" "$PRE_BUMP_CMD" || rc=$?
  [ "$rc" -eq 0 ] && return 0
  fail 4 \
    "pre-bump hook failed (exit ${rc}): ${PRE_BUMP_CMD}" \
    "Nothing was changed. Fix the PRE_BUMP_CMD command, or skip hooks for one run with --no-hooks."
}

# run-post-tag-hook — POST_TAG_CMD (R-HOOK-2). Called from main() between
# do-tag and do-push, so a failing hook stops the release before anything
# leaves the machine. The bump commit + tag already exist and are
# intentionally kept — --undo is the recovery path, and rolling back
# automatically could destroy hook side-effects the user wants to inspect.
run-post-tag-hook() {
  [ "${FLAG_NOHOOKS:-false}" = true ] && return 0
  [ -n "${POST_TAG_CMD:-}" ] || return 0
  # Under -n / --no-commit no tag was created — nothing to hook onto
  # (mirrors do-tag's own skip).
  [ "${FLAG_NOCOMMIT:-false}" = true ] && return 0

  local rc=0
  _run-hook "post-tag" "$POST_TAG_CMD" || rc=$?
  [ "$rc" -eq 0 ] && return 0
  fail 4 \
    "post-tag hook failed (exit ${rc}): ${POST_TAG_CMD}" \
    "The release commit and tag ${TAG_PREFIX-}${V_NEW-} were kept (nothing was pushed). Recover with 'VerBump --undo ${V_NEW-}', or fix the hook and push manually."
}
