#!/bin/bash

# shellcheck disable=SC2288
true

# Refuse to release from a dirty working tree (R-SAFE-1..4). do-commit runs a
# bare `git commit -m …`, so anything staged before ver-bump ran — and any
# modified tracked file `git add`-ed along the way — would be silently swept
# into the release commit. Untracked files are ignored (same contract as
# --undo's dirty check). Skipped under -n/--no-commit (nothing is committed,
# nothing can be swept) and under --allow-dirty / ALLOW_DIRTY=true. The check
# still runs under --dry-run (read-only) so the preview is honest about what
# a real run would do.
check-worktree-clean() {
  [ "${FLAG_NOCOMMIT:-false}" = true ] && return 0
  [ "${ALLOW_DIRTY:-false}" = true ] && return 0

  local dirty count preview line
  dirty=$(git status --porcelain --untracked-files=no 2>/dev/null)
  [ -z "$dirty" ] && return 0

  # Name the first few offending paths (+ total), so the error is actionable
  # without the user re-running git status themselves. Porcelain lines are
  # "XY <path>" — strip the two status columns and the separator space.
  count=$(printf '%s\n' "$dirty" | grep -c .)
  preview=""
  local shown=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    (( shown >= 3 )) && { preview+=", …"; break; }
    preview+="${preview:+, }${line:3}"
    shown=$((shown + 1))
  done <<< "$dirty"

  fail 3 \
    "Working tree has uncommitted changes to tracked files (${count}): ${preview}" \
    "Commit or stash them first, or pass --allow-dirty / set ALLOW_DIRTY=true to release anyway (untracked files are ignored)."
}

# Optional release-branch guard (R-SAFE-10..13). RELEASE_BRANCHES (config/env
# key, no flag) is a space-separated glob list, e.g. "main develop release/*".
# Unset/empty (the default) = no guard, zero behaviour change. When set, a
# release from a non-matching branch — or from a detached HEAD — exits 3.
# Deliberately NOT bypassed by --yes: this is a guard, not a prompt. The
# one-shot bypass is an empty env override (RELEASE_BRANCHES= ver-bump …),
# which beats the rc value per R-CFG-3. Release flow only: --undo,
# --completions, --about, and --help all exit before the Verify section.
check-release-branch() {
  [ -n "${RELEASE_BRANCHES:-}" ] || return 0

  local branch pat matched=false
  branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)
  if [ -z "$branch" ]; then
    fail 3 \
      "RELEASE_BRANCHES is set (${RELEASE_BRANCHES}) but HEAD is detached — a release must be cut from a named branch." \
      "Checkout an allowed branch first, or clear the guard for one run: RELEASE_BRANCHES= ver-bump …"
  fi

  # Glob-match against each pattern. Word-splitting of the unquoted list and
  # the unquoted case pattern are both intentional (space-separated globs).
  # shellcheck disable=SC2254
  for pat in $RELEASE_BRANCHES; do
    case "$branch" in
      $pat) matched=true; break ;;
    esac
  done

  if [ "$matched" != true ]; then
    fail 3 \
      "Branch '${branch}' is not a release branch (RELEASE_BRANCHES: ${RELEASE_BRANCHES})." \
      "Checkout an allowed branch, adjust RELEASE_BRANCHES in .ver-bumprc, or clear the guard for one run: RELEASE_BRANCHES= ver-bump …"
  fi
}

# If there are no commits in repo, quit, because you can't tag with zero commits.
check-commits-exist() {
  if ! git rev-parse HEAD &> /dev/null; then
    fail 3 \
      "Your current branch doesn't have any commits yet. Can't tag without at least one commit." \
      "Make an initial commit first: git commit --allow-empty -m 'initial commit'."
  fi
}

#
check-branch-notexist() {
  [ "$FLAG_BRANCH" = true ] || return 0
  if git rev-parse --verify "${REL_PREFIX}${V_NEW}" &> /dev/null; then
    fail 3 \
      "Branch <${REL_PREFIX}${V_NEW}> already exists." \
      "Delete the existing branch (git branch -D ${REL_PREFIX}${V_NEW}), pick a different version, or drop --branch/--pr to tag in place instead."
  fi
}

# Only tag if tag doesn't already exist
check-tag-exists() {
  local TAG_MSG
  TAG_MSG=$( git tag -l "${TAG_PREFIX}${V_NEW}" )
  if [ -n "$TAG_MSG" ]; then
    fail 3 \
      "A release with that tag version number already exists: ${TAG_MSG}" \
      "Delete the existing tag with: git tag -d ${TAG_MSG}, or pick a different version."
  fi
}
