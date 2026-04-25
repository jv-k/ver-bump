#!/bin/bash

# shellcheck disable=SC2288
true

# Dry-run helper: runs $@ if not in dry-run mode, otherwise prints what would run.
dryrun() {
  if [ "$FLAG_DRYRUN" = true ]; then
    echo -e "${S_LIGHT}[dry-run]${RESET} $*" >&2
    return 0
  fi
  "$@"
}

do-branch() {
  [ "$FLAG_NOBRANCH" = true ] && return

  local BRANCH_MSG

  echo -e "\nCreating release branch..."

  if [ "$FLAG_DRYRUN" = true ]; then
    echo -e "${S_LIGHT}[dry-run]${RESET} would run: git branch ${S_VAL}${REL_PREFIX}${V_NEW}${RESET} && git checkout ${S_VAL}${REL_PREFIX}${V_NEW}${RESET}" >&2
    log_success "Switched to (dry-run) branch '${S_VAL}${REL_PREFIX}${V_NEW}${RESET}'"
    return
  fi

  BRANCH_MSG=$(git branch "${REL_PREFIX}${V_NEW}" 2>&1)
  if [ -z "$BRANCH_MSG" ]; then
    BRANCH_MSG=$(git checkout "${REL_PREFIX}${V_NEW}" 2>&1)
    log_success "${BRANCH_MSG}"
  else
    fail 1 \
      "Failed to create release branch: ${BRANCH_MSG}" \
      "Resolve the git branch error above, or pass -b/--no-branch to skip branch creation."
  fi
}

# Stage & commit all files modified by this script
do-commit() {
  [ "$FLAG_NOCOMMIT" = true ] && return

  local COMMIT_MSG COMMIT_RC

  GIT_MSG+="$(get-commit-msg)"
  echo -e "\nCommitting..."

  if [ "$FLAG_DRYRUN" = true ]; then
    echo -e "${S_LIGHT}[dry-run]${RESET} would run: git commit -m '${S_VAL}${COMMIT_MSG_PREFIX}${GIT_MSG}${RESET}'" >&2
    log_success "(dry-run) commit prepared"
    return
  fi

  COMMIT_MSG=$( git commit -m "${COMMIT_MSG_PREFIX}${GIT_MSG}" 2>&1 ); COMMIT_RC=$?
  if [ "$COMMIT_RC" -ne 0 ]; then
    fail 1 \
      "git commit failed: ${COMMIT_MSG}" \
      "Resolve the git commit error above, or pass -n/--no-commit to skip committing."
  else
    log_success "$COMMIT_MSG"
  fi
}

# Create a Git tag using the SemVer
do-tag() {
  # If we skipped committing, the version bumps are not persisted, so tagging
  # would point at the wrong (pre-bump) commit. Skip the tag too.
  [ "$FLAG_NOCOMMIT" = true ] && return

  local tag_msg
  tag_msg="${REL_NOTE:-Tag version ${V_NEW}.}"

  if [ "$FLAG_DRYRUN" = true ]; then
    echo -e "${S_LIGHT}[dry-run]${RESET} would run: git tag -a ${S_VAL}${TAG_PREFIX}${V_NEW}${RESET} -m '${tag_msg}'" >&2
    log_success "Tagged ${S_VAL}${TAG_PREFIX}${V_NEW}${RESET}"
    return
  fi

  git tag -a "${TAG_PREFIX}${V_NEW}" -m "${tag_msg}"
  log_success "Tagged ${S_VAL}${TAG_PREFIX}${V_NEW}${RESET}"
}

# Pushes branch + tag to remote repo. Changes are staged by earlier functions
do-push() {
  [ "$FLAG_NOCOMMIT" = true ] && return

  local CONFIRM PUSH_MSG PUSH_RC REMOTE_REF

  if [ "$FLAG_PUSH" = true ]; then
    CONFIRM="Y"
  else
    echo -ne "\n${S_QUESTION}Push branch + tags to <${S_VAL}${PUSH_DEST}${S_QUESTION}>? [${S_NORM}N/y${S_QUESTION}]:${RESET} "
    read -r CONFIRM
  fi

  case "$CONFIRM" in
    [yY][eE][sS]|[yY] )
      echo -e "\nPushing branch + tag to <${S_VAL}${PUSH_DEST}${RESET}>..."
      if [ "$FLAG_NOBRANCH" = true ]; then
        REMOTE_REF=$(git rev-parse --abbrev-ref HEAD)
      else
        REMOTE_REF="${REL_PREFIX}${V_NEW}"
      fi

      if [ "$FLAG_DRYRUN" = true ]; then
        echo -e "${S_LIGHT}[dry-run]${RESET} would run: git push -u ${S_VAL}${PUSH_DEST}${RESET} ${S_VAL}${REMOTE_REF}${RESET} ${S_VAL}${TAG_PREFIX}${V_NEW}${RESET}" >&2
        log_success "(dry-run) push prepared"
        return
      fi

      PUSH_MSG=$( git push -u "${PUSH_DEST}" "${REMOTE_REF}" "${TAG_PREFIX}${V_NEW}" 2>&1 ); PUSH_RC=$?
      if [ "$PUSH_RC" -ne 0 ]; then
        log_warn "Push failed"
        log_trace "$PUSH_MSG"
      else
        log_success "$PUSH_MSG"
      fi
    ;;
    * )
      fail 5 \
        "push declined" \
        "Re-run and answer 'y' when prompted, or pass -p/--push <remote> to skip the prompt."
    ;;
  esac
}

# do-undo [<version>] — locally undo the artefacts of a prior ver-bump run:
# delete the release branch and tag for <version>. Refuses if the working
# tree is dirty, if the tag/branch were pushed, or if the branch was merged.
# Honours FLAG_DRYRUN (print plan only) and FLAG_YES (skip confirmation).
#
# Resolution order for <version>:
#   1. explicit arg ("--undo 1.2.0")
#   2. derived from current branch if it matches "${REL_PREFIX}X.Y.Z"
#   3. fail with hint
do-undo() {
  local ver="$1" branch tag remote parent_branch reply
  local -a remote_hits=()

  command -v git >/dev/null 2>&1 || fail 3 \
    "git is not installed." "Install git and retry."

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail 3 \
    "Not inside a git repository." "Run --undo from inside the repo."

  if [ -z "$ver" ]; then
    local cur
    cur=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)
    if [[ -n "$cur" && "$cur" == "${REL_PREFIX}"* ]]; then
      ver="${cur#"${REL_PREFIX}"}"
    else
      fail 2 \
        "No version supplied and current branch '${cur:-<detached>}' isn't a '${REL_PREFIX}X.Y.Z' branch." \
        "Pass the version explicitly: ver-bump --undo <version>"
    fi
  fi

  is_semver "$ver" || fail 2 \
    "'$ver' is not a valid SemVer 2.0 version." \
    "Pass MAJOR.MINOR.PATCH, e.g. --undo 1.2.0"

  branch="${REL_PREFIX}${ver}"
  tag="${TAG_PREFIX}${ver}"

  # Refuse on dirty tree — a reset/branch-delete could destroy the user's WIP.
  if [ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ]; then
    fail 3 \
      "Working tree has uncommitted changes." \
      "Stash or commit unrelated work before running --undo (untracked files are ignored)."
  fi

  git rev-parse --verify --quiet "refs/tags/${tag}" >/dev/null || fail 3 \
    "Tag '${tag}' does not exist locally — nothing to undo." \
    "Check 'git tag -l ${TAG_PREFIX}*' for what's available."

  git rev-parse --verify --quiet "refs/heads/${branch}" >/dev/null || fail 3 \
    "Branch '${branch}' does not exist locally — nothing to undo." \
    "Check 'git branch --list ${REL_PREFIX}*' for what's available."

  # Pushed-state check across all remotes. If either the tag or the branch
  # exists on any remote, refuse and print the manual cleanup commands.
  while read -r remote; do
    [ -z "$remote" ] && continue
    if git ls-remote --tags "$remote" "refs/tags/${tag}" 2>/dev/null | grep -q "${tag}$"; then
      remote_hits+=("$remote: tag ${tag}")
    fi
    if git ls-remote --heads "$remote" "refs/heads/${branch}" 2>/dev/null | grep -q "${branch}$"; then
      remote_hits+=("$remote: branch ${branch}")
    fi
  done < <(git remote)

  if (( ${#remote_hits[@]} > 0 )); then
    log_warn "Refusing to undo — release artefacts are present on remote(s):"
    local hit
    for hit in "${remote_hits[@]}"; do
      log_trace "$hit"
    done
    log_info "Undo manually if you really mean it:"
    log_trace "git push origin :refs/tags/${tag}      # delete remote tag"
    log_trace "git push origin --delete ${branch}    # delete remote branch"
    log_trace "git tag -d ${tag} && git branch -D ${branch}"
    exit 3
  fi

  # Refuse if the release branch's tip has already been merged into another
  # branch. At that point an undo is the wrong tool; a revert commit is.
  # `--contains` returns branches whose tip has <branch>'s tip as an
  # ancestor — exactly the "already merged in" relationship we care about.
  local merged_into=()
  local b
  while read -r b; do
    [ -z "$b" ] && continue
    b="${b## }"; b="${b#\* }"
    [[ "$b" == "$branch" ]] && continue
    [[ "$b" == "${REL_PREFIX}"* ]] && continue
    merged_into+=("$b")
  done < <(git branch --contains "$branch" 2>/dev/null)

  if (( ${#merged_into[@]} > 0 )); then
    fail 3 \
      "Branch '${branch}' is already merged into: ${merged_into[*]}" \
      "Use 'git revert' on the merge or bump commit instead — undo would lose history."
  fi

  # Pick a parent branch to switch to before deleting. Strategy:
  #   1. reflog — the branch checked out immediately before 'release-X.Y.Z'
  #   2. fallback — first non-release branch containing the bump's parent
  parent_branch=$(
    git reflog show --pretty='%gs' HEAD 2>/dev/null \
      | awk -v b="$branch" '
          /^checkout: moving from / {
            from=$4; to=$6
            if (to==b && from!=b) { print from; exit }
          }'
  )
  if [ -z "$parent_branch" ] || ! git rev-parse --verify --quiet "refs/heads/${parent_branch}" >/dev/null; then
    local parent_sha
    parent_sha=$(git rev-parse "${branch}^" 2>/dev/null) || parent_sha=""
    if [ -n "$parent_sha" ]; then
      while read -r b; do
        b="${b## }"; b="${b#\* }"
        [[ -z "$b" || "$b" == "$branch" || "$b" == "${REL_PREFIX}"* ]] && continue
        parent_branch="$b"; break
      done < <(git branch --contains "$parent_sha" 2>/dev/null)
    fi
  fi
  if [ -z "$parent_branch" ]; then
    fail 3 \
      "Could not determine which branch to switch to before deleting '${branch}'." \
      "Checkout your intended branch first, then re-run --undo."
  fi

  section "Undo"
  log_info "Plan:"
  log_trace "git checkout ${parent_branch}"
  log_trace "git branch -D ${branch}"
  log_trace "git tag -d ${tag}"

  if [ "${FLAG_DRYRUN:-false}" = true ]; then
    printf '\n%b[dry-run]%b no changes made.\n' "${S_LIGHT-}" "${RESET-}"
    return 0
  fi

  if [ "${FLAG_YES:-false}" != true ]; then
    printf '\n%bProceed?%b [y/N] ' "${S_QUESTION-}" "${RESET-}"
    read -r reply
    case "${reply}" in
      y|Y|yes|YES) ;;
      *) fail 5 "undo declined" "Re-run with --yes to skip the prompt." ;;
    esac
  fi

  git checkout "$parent_branch" >/dev/null 2>&1 || fail 1 \
    "Failed to checkout '${parent_branch}'." \
    "Resolve the issue manually, then re-run --undo."

  git branch -D "$branch" >/dev/null 2>&1 || fail 1 \
    "Failed to delete branch '${branch}'." \
    "Delete it manually with: git branch -D ${branch}"

  git tag -d "$tag" >/dev/null 2>&1 || fail 1 \
    "Failed to delete tag '${tag}'." \
    "Delete it manually with: git tag -d ${tag}"

  log_success "Undid release ${S_VAL}${ver}${RESET-} — back on ${S_VAL}${parent_branch}${RESET-}"
}
