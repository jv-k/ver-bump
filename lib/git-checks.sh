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

# Remote-sync preflight (R-SAFE-5..9). ver-bump otherwise never talks to the
# remote before mutating: check-tag-exists consults local tags only, and a
# stale local HEAD happily tags code that's already superseded on the remote.
# Fetch (with tags) from the configured remote so (a) a behind-upstream HEAD
# is refused here, and (b) check-tag-exists — which runs AFTER this in main()
# — sees remote tags and catches collisions preflight instead of at push time.
# Air-gapped use keeps working: no configured remote → silent skip; fetch
# failure (offline, auth) → warn and continue. The fetch is read-only, so it
# also runs under --dry-run (same reasoning as R-REL-5's notes command).
# --no-fetch / NO_FETCH=true skips the whole preflight explicitly.
check-remote-sync() {
  [ "${NO_FETCH:-false}" = true ] && return 0

  # PUSH_DEST may be a bare URL/path (e.g. -p /tmp/remote.git) rather than a
  # configured remote — nothing to fetch state for, so skip silently.
  git remote get-url "$PUSH_DEST" >/dev/null 2>&1 || return 0

  # Fetch WITHOUT --quiet — that flag suppresses git's own rejection report, so
  # a bare failure could never say why. Capture stderr instead (stdout is
  # discarded); on success it's thrown away, so there's no terminal noise. The
  # most common non-network failure is local tags that diverge from the
  # remote's (rewritten history / re-created tags): git refuses to move them
  # ("would clobber existing tag") and the whole fetch exits non-zero even
  # though nothing is wrong for this run — hence warn-and-continue, not fail.
  local fetch_err reason
  if ! fetch_err=$(git fetch "$PUSH_DEST" --tags 2>&1 1>/dev/null); then
    log_warn "Could not fetch from <${S_VAL}${PUSH_DEST}${RESET-}> — continuing with local refs only."
    if printf '%s\n' "$fetch_err" | grep -q 'would clobber existing tag'; then
      log_trace "local tags differ from <${PUSH_DEST}>'s — git won't overwrite them (rewritten history / re-created tags)."
      log_trace "reconcile with 'git fetch ${PUSH_DEST} --tags --force', or pass --no-fetch to skip this preflight."
    else
      # Offline / auth / bad URL: surface git's own error line verbatim.
      reason=$(printf '%s\n' "$fetch_err" | grep -Em1 '^(fatal|error):')
      [ -z "$reason" ] && reason=$(printf '%s\n' "$fetch_err" | grep -Ev '^[[:space:]]*$' | tail -n1)
      [ -n "$reason" ] && log_trace "${reason}"
    fi
    return 0
  fi

  # Behind-upstream check: only meaningful when the current branch has an
  # upstream configured. rev-list HEAD..@{upstream} counts commits the
  # upstream has that we don't — anything > 0 means we'd tag a stale HEAD.
  local upstream behind
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null) || return 0
  behind=$(git rev-list --count 'HEAD..@{upstream}' 2>/dev/null) || return 0
  if [ "${behind:-0}" -gt 0 ]; then
    fail 3 \
      "Current branch is ${behind} commit(s) behind ${upstream} — releasing now would tag a stale HEAD." \
      "Run 'git pull --rebase' first, or pass --no-fetch / set NO_FETCH=true to skip the remote-sync preflight."
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

# Nothing-to-release no-op (R-SAFE-14..18). When the previous version's tag
# exists and HEAD has no commits since it, cutting a release would produce an
# empty one — patch+1 with an empty changelog range. Print a notice and exit 0
# instead: a clean no-op is success (semantic-release semantics), which makes
# the release step safe to run unconditionally in CI. The notice includes a
# stable stdout line beginning `no-release` so scripts can branch on outcome
# without parsing prose. Applies even with -v/--major/--minor/--patch — an
# explicit version is not evidence you meant to release zero commits;
# --allow-empty is the explicit signal (deliberate re-tags / empty releases).
# Must run AFTER process-version (needs V_PREV read from VER_FILE). No
# previous matching tag (first release) → proceeds as today (R-BUMP-3).
check-releasable-commits() {
  [ "${ALLOW_EMPTY:-false}" = true ] && return 0
  # V_PREV may be empty only with -v when the source file is unreadable AND
  # no matching tag exists (process-version's tag-derived fallback, R-SRC-2,
  # otherwise fills it in) — then there is nothing to compare against. A
  # tag-derived V_PREV by definition has a tag, so the guard applies to
  # source-less repos exactly like package.json ones.
  [ -n "${V_PREV:-}" ] || return 0

  local prev_tag count
  prev_tag="${TAG_PREFIX}${V_PREV}"
  git rev-parse --verify --quiet "refs/tags/${prev_tag}" >/dev/null || return 0

  count=$(git rev-list --count "${prev_tag}..HEAD" 2>/dev/null) || return 0
  [ "${count:-1}" -gt 0 ] && return 0

  log_info "Nothing to release — no new commits since ${S_VAL}${prev_tag}${RESET-}."
  # Stable, greppable outcome token (R-SAFE-15): line begins `no-release`.
  printf 'no-release: no commits since %s\n' "${prev_tag}"
  exit 0
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
