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

# Resolve the https base URL of the GitHub remote, e.g.
# https://github.com/owner/repo — used by the grouped changelog to build
# commit and compare links (R-CHLOG-3). Prefers PUSH_DEST (where the
# release lands), falling back to origin. Handles the SSH scp form
# (git@github.com:o/r.git), ssh:// and https:// forms. Non-GitHub remote
# or no remote → return 1; callers must render plain text instead of
# links, never fail (R-CHLOG-4).
_forge-base-url() {
  local url owner_repo
  url=$(git remote get-url "${PUSH_DEST:-origin}" 2>/dev/null) \
    || url=$(git remote get-url origin 2>/dev/null) \
    || return 1

  case "$url" in
    git@github.com:*)       owner_repo="${url#git@github.com:}" ;;
    ssh://git@github.com/*) owner_repo="${url#ssh://git@github.com/}" ;;
    https://github.com/*)   owner_repo="${url#https://github.com/}" ;;
    http://github.com/*)    owner_repo="${url#http://github.com/}" ;;
    *) return 1 ;;
  esac

  owner_repo="${owner_repo%.git}"
  owner_repo="${owner_repo%/}"
  [ -n "$owner_repo" ] || return 1
  printf 'https://github.com/%s' "$owner_repo"
}

# Minimal URL-encoding for a git ref used as a path segment of a GitHub
# compare URL: "%" first (so the escapes below aren't double-encoded),
# then "/" — TAG_PREFIX may legitimately contain one (e.g. rel/), which
# would otherwise break the compare path. Other ref-legal characters are
# URL-safe in this position.
_url-encode-ref() {
  local ref=$1
  ref=${ref//%/%25}
  ref=${ref//\//%2F}
  printf '%s' "$ref"
}

# Render one subject line for the grouped changelog. A Conventional Commit
# "type(scope)!?:" prefix is stripped — the section heading already carries
# the type — and the scope becomes a bold "**scope:**" prefix (R-CHLOG-2).
# Anything that doesn't parse as a Conventional Commit renders verbatim, so
# no message is ever dropped or truncated.
_changelog-render-subject() {
  local subject=$1 scope desc
  local re='^[a-zA-Z]+(\(([^)]*)\))?!?:[[:space:]]*(.+)$'
  if [[ "$subject" =~ $re ]]; then
    scope="${BASH_REMATCH[2]}"
    desc="${BASH_REMATCH[3]}"
    if [ -n "$scope" ]; then
      printf '**%s:** %s' "$scope" "$desc"
    else
      printf '%s' "$desc"
    fi
  else
    printf '%s' "$subject"
  fi
}

# Emit the grouped (Conventional-Commit-aware) section for V_NEW on stdout.
#   $1 = git log records ("%h RS %s RS %b US" — the same RS/US record
#        discipline as suggest-bump-level, so a body that quotes a subject
#        can't split a record)
#   $2 = synthetic entry for the tool's own bump commit (that commit is
#        created after this write, so it has no SHA to link yet — same
#        manual-entry behaviour as the flat format)
#   $3 = the git-log range; non-empty exactly when the previous version's
#        tag exists, which is also the compare-link condition (R-CHLOG-3)
#
# Sections render in fixed order — Breaking Changes, Features, Fixes,
# Other — and empty sections are omitted. "Other" is the catch-all: any
# commit that isn't breaking/feat/fix lands there, including
# non-conventional messages, so nothing is ever dropped (R-CHLOG-2).
_changelog-grouped-section() {
  local records=$1 bump_entry=$2 range=$3
  local base_url record sha subject body rest entry
  local breaking="" feats="" fixes="" others=""

  base_url=$(_forge-base-url) || base_url=""

  # Version heading: link the prev...new compare view when both a previous
  # tag and a recognised forge exist; otherwise the same text as flat.
  if [ -n "$range" ] && [ -n "$base_url" ]; then
    printf '## [%s](%s/compare/%s...%s) (%s)\n' \
      "$V_NEW" "$base_url" \
      "$(_url-encode-ref "${TAG_PREFIX}${V_PREV}")" \
      "$(_url-encode-ref "${TAG_PREFIX}${V_NEW}")" "$NOW"
  else
    printf '## %s (%s)\n' "$V_NEW" "$NOW"
  fi

  # The bump commit is classified like any other commit (its section
  # follows COMMIT_MSG_PREFIX — "chore: " lands in Other by default).
  entry="- $(_changelog-render-subject "$bump_entry")"$'\n'
  case "$(classify-commit "$bump_entry" "")" in
    breaking) breaking+="$entry" ;;
    feat)     feats+="$entry" ;;
    fix)      fixes+="$entry" ;;
    *)        others+="$entry" ;;
  esac

  while IFS= read -r -d $'\x1f' record; do
    # Trim the newline git inserts between format records.
    record="${record#$'\n'}"
    [ -z "$record" ] && continue
    sha="${record%%$'\x1e'*}"
    rest="${record#*$'\x1e'}"
    subject="${rest%%$'\x1e'*}"
    if [[ "$rest" == *$'\x1e'* ]]; then
      body="${rest#*$'\x1e'}"
    else
      body=""
    fi

    entry="- $(_changelog-render-subject "$subject")"
    if [ -n "$base_url" ]; then
      # Short SHA linked to its commit. "(#N)" PR refs stay verbatim in
      # the subject — GitHub auto-links them in rendered markdown.
      entry+=" ([${sha}](${base_url}/commit/${sha}))"
    else
      entry+=" (${sha})"
    fi
    entry+=$'\n'

    case "$(classify-commit "$subject" "$body")" in
      breaking) breaking+="$entry" ;;
      feat)     feats+="$entry" ;;
      fix)      fixes+="$entry" ;;
      *)        others+="$entry" ;;
    esac
  done <<< "$records"

  [ -n "$breaking" ] && printf '\n### Breaking Changes\n\n%s' "$breaking"
  [ -n "$feats" ]    && printf '\n### Features\n\n%s' "$feats"
  [ -n "$fixes" ]    && printf '\n### Fixes\n\n%s' "$fixes"
  [ -n "$others" ]   && printf '\n### Other\n\n%s' "$others"
  return 0
}

# Dump git log history to CHANGELOG.md
#
# Two styles (R-CHLOG-1): the default "flat" bullet dump, byte-identical
# to the 1.x output, and the opt-in CHANGELOG_STYLE=grouped Conventional-
# Commit sections. Both share the same temp-file build, prepend, dry-run,
# pause and staging behaviour (R-CHLOG-5).
do-changelog() {
  [ "$FLAG_NOCHANGELOG" = true ] && return
  local ACTION_MSG COMMITS_MSG LOG_MSG LOG_RC RANGE TMP

  RANGE=$([ "$(git tag -l "${TAG_PREFIX}${V_PREV}")" ] && echo "${TAG_PREFIX}${V_PREV}..HEAD")
  if [ "${CHANGELOG_STYLE-}" = "grouped" ]; then
    # SHA + subject + body records for grouping — see
    # _changelog-grouped-section for the separator discipline.
    # shellcheck disable=SC2086
    COMMITS_MSG=$( git log --format='%h%x1e%s%x1e%b%x1f' ${RANGE} 2>&1 ); LOG_RC=$?
  else
    # shellcheck disable=SC2086
    COMMITS_MSG=$( git log --pretty=format:"- %s" ${RANGE} 2>&1 ); LOG_RC=$?
  fi
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

  # The bump commit's own entry:
  # - The final commit is done after do-changelog(), so we need to create the log entry for it manually:
  LOG_MSG="${GIT_MSG}$(get-commit-msg)"

  if [ "${CHANGELOG_STYLE-}" = "grouped" ]; then
    _changelog-grouped-section "$COMMITS_MSG" "${COMMIT_MSG_PREFIX}${LOG_MSG}" "$RANGE" > "$TMP"
  else
    # Heading
    echo "## $V_NEW ($NOW)" > "$TMP"
    # Log the bumping commit
    echo "- ${COMMIT_MSG_PREFIX}${LOG_MSG}" >> "$TMP"
    # Add previous commits
    [ -n "$COMMITS_MSG" ] && echo "$COMMITS_MSG" >> "$TMP"
  fi

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
