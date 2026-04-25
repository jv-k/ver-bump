#!/bin/bash

# shellcheck disable=SC2288
true

get-commit-msg() {
  local CMD
  CMD=$([ ! "${V_PREV}" = "${V_NEW}" ] && echo "${V_PREV} ->" || echo "to")
  echo bumped "$CMD" "$V_NEW"
}

capitalise() {
  echo "$(tr '[:lower:]' '[:upper:]' <<< "${1:0:1}")${1:1}"
}

# Dump git log history to CHANGELOG.md
do-changelog() {
  [ "$FLAG_NOCHANGELOG" = true ] && return
  local ACTION_MSG COMMITS_MSG LOG_MSG LOG_RC RANGE TMP

  RANGE=$([ "$(git tag -l "${TAG_PREFIX}${V_PREV}")" ] && echo "${TAG_PREFIX}${V_PREV}..HEAD")
  # shellcheck disable=SC2086
  COMMITS_MSG=$( git log --pretty=format:"- %s" ${RANGE} 2>&1 ); LOG_RC=$?
  if [ "$LOG_RC" -ne 0 ]; then
    fail 1 \
      "Error getting commit history since last version bump for logging to CHANGELOG: ${COMMITS_MSG}" \
      "Verify the previous tag exists (git tag -l) and that 'git log ${RANGE}' runs successfully, or pass -c/--no-changelog to skip."
  fi

  if [ -f CHANGELOG.md ]; then
    ACTION_MSG="updated"
  else
    ACTION_MSG="created"
  fi
  # Add info to commit message for later:
  GIT_MSG+="${ACTION_MSG} CHANGELOG.md, "

  # Build new CHANGELOG content in a temp file next to the target, so a
  # partial write can't leave garbage in the repo root.
  TMP=$(mktemp "./CHANGELOG.md.XXXXXX")
  # Heading
  echo "## $V_NEW ($NOW)" > "$TMP"

  # Log the bumping commit:
  # - The final commit is done after do-changelog(), so we need to create the log entry for it manually:
  LOG_MSG="${GIT_MSG}$(get-commit-msg)"
  echo "- ${COMMIT_MSG_PREFIX}${LOG_MSG}" >> "$TMP"
  # Add previous commits
  [ -n "$COMMITS_MSG" ] && echo "$COMMITS_MSG" >> "$TMP"

  printf '\n' >> "$TMP"

  if [ -f CHANGELOG.md ]; then
    # Append existing log
    cat CHANGELOG.md >> "$TMP"
  else
    printf '\nNo existing [%bCHANGELOG.md%b] found — creating one.\n' "${S_VAL}" "${RESET}"
  fi

  if [ "$FLAG_DRYRUN" = true ]; then
    printf '%b[dry-run]%b would replace CHANGELOG.md with:\n' "${S_LIGHT}" "${RESET}" >&2
    cat "$TMP" >&2
    rm -f "$TMP"
  else
    mv -f "$TMP" CHANGELOG.md
  fi

  log_success "$( capitalise "${ACTION_MSG}" ) [${S_VAL}CHANGELOG.md${RESET}]."

  # Optionally pause & allow user to open and edit the file:
  if [ "$FLAG_CHANGELOG_PAUSE" = true ] && [ "$FLAG_DRYRUN" != true ]; then
    printf '\n%bMake adjustments to [%bCHANGELOG.md%b] if required now. Press <enter> to continue.%b' "${S_QUESTION}" "${S_VAL}" "${S_QUESTION}" "${RESET}"
    read -r
  fi

  # Stage log file, to commit later
  dryrun git add CHANGELOG.md
}
