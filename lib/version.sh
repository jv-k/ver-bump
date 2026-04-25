#!/bin/bash

# shellcheck disable=SC2288
true

# Suggests version from VERSION file, or grabs from user supplied -v <version>.
# If none is set, suggest default from options.

# - If <package.json> doesn't exist, warn + exit
# - If -v specified, set version from that
# - Else,
#   - Grab from package.json
#   - Suggest incremented number
#   - Give prompt to user to modify
# - Set globally

# According to SemVer 2.0.0, given a version number MAJOR.MINOR.PATCH, suggest incremented value:
# — MAJOR version when you make incompatible API changes,
# — MINOR version when you add functionality in a backwards compatible manner, and
# — PATCH version when you make backwards compatible bug fixes.
process-version() {
  # Read V_PREV from VER_FILE (package.json) for display + same-version dedup.
  # When -v is supplied, V_PREV is best-effort: the user already gave us V_NEW,
  # so missing/empty VER_FILE is allowed. Without -v we need a version to bump,
  # so a missing VER_FILE is a hard error.
  if [ -f "$VER_FILE" ] && [ -s "$VER_FILE" ]; then
    V_PREV=$( jq -r '.version // empty' "$VER_FILE" 2>/dev/null )

    if [ -n "$V_PREV" ]; then
      echo -e "\nCurrent version read from <${S_VAL}${VER_FILE}${RESET}>: ${S_VAL}$V_PREV${RESET}"
      set-v-suggest "$V_PREV" # check + compute next version from conventional commits (or patch +1)
    elif [ -z "$V_USR_SUPPLIED" ]; then
      fail 3 \
        "<${VER_FILE}> doesn't contain a 'version' field." \
        "Add a top-level \"version\" key to ${VER_FILE}, or pass an explicit version with -v <version>."
    fi
  elif [ -z "$V_USR_SUPPLIED" ]; then
    local reason
    if [ ! -f "$VER_FILE" ]; then
      reason="was not found"
    elif [ ! -s "$VER_FILE" ]; then
      reason="is empty"
    else
      reason="could not be read"
    fi
    fail 3 \
      "<${VER_FILE}> ${reason}." \
      "Run ver-bump inside a directory with a valid ${VER_FILE}, pass -v <version> to bypass, or override via VER_FILE=<path>."
  fi

  # If a version number is supplied by the user with [-v <version number>] — use it!
  if [ -n "$V_USR_SUPPLIED" ]; then
    echo -e "\nVersion supplied via [-v]: ${S_VAL}${V_USR_SUPPLIED}${RESET}"
    V_NEW="${V_USR_SUPPLIED}"
  else
    # Display a suggested version
    echo -ne "\n${S_QUESTION}Enter a new version number, <enter> for [${S_VAL}$V_SUGGEST${S_QUESTION}], or <esc> to quit:${RESET} "

    # Two-stage read:
    #   1. Capture a single keystroke silently. If ESC → abort instantly.
    #      If Enter → accept default. Anything else → fall through.
    #   2. Hand off to readline (`read -e -i "$_first"`) so the first char
    #      is pre-filled and the whole line stays editable (backspace works).
    # Requires bash 4+ for `read -i`.
    local _first
    IFS= read -rsn1 _first
    if [ "$_first" = $'\e' ]; then
      printf '\n\n%b aborted %b\n' "${S_HDR_RED-}" "${S_HDR_END-}"
      exit 130
    fi
    if [ -z "$_first" ]; then
      V_USR_INPUT=""
    elif [ -t 0 ] && (( ${BASH_VERSINFO[0]:-0} >= 4 )); then
      # Interactive on bash 4+: pre-fill readline so the first char stays
      # editable (backspace works). `read -i` requires both readline (-e)
      # and bash 4+; the script's #!/bin/bash on macOS resolves to bash
      # 3.2, which doesn't have it.
      read -e -r -i "$_first" V_USR_INPUT
    else
      # Bash 3.2 or piped stdin: readline unavailable — echo the first
      # char and concatenate the rest. Trade-off: backspacing past that
      # first char looks odd in the terminal but doesn't lose data.
      printf '%s' "$_first"
      read -r V_USR_INPUT
      V_USR_INPUT="${_first}${V_USR_INPUT}"
    fi

    if [ "$V_USR_INPUT" = "" ]; then
      # User accepted the suggested version
      V_NEW=$V_SUGGEST
    else
      V_NEW=$V_USR_INPUT
    fi

    # Validate whatever we end up with (suggested or entered) as SemVer.
    # This only runs in interactive path; -v already validates at parse time.
    if ! is_semver "$V_NEW"; then
      fail 3 \
        "Version '$V_NEW' is not a valid SemVer 2.0 version." \
        "Enter a SemVer 2.0 version (MAJOR.MINOR.PATCH[-prerelease][+build]), e.g. 1.2.3 or 1.2.3-rc.1."
    fi
  fi
}

# Inspect commit messages since the previous version's tag and suggest the
# appropriate bump per Conventional Commits:
#   - BREAKING CHANGE / <type>! → major
#   - feat:                     → minor
#   - anything else             → patch
# Falls back to patch if no tag for previous version exists, or if parsing fails.
#
# Subject vs. body handling: we split every commit into its subject (first
# line) and body (rest) via a record-separator/unit-separator format. Only
# the subject is matched against the "<type>:" / "<type>!:" patterns, so a
# commit body that quotes a prior subject can't trigger a spurious bump.
# "BREAKING CHANGE:" / "BREAKING-CHANGE:" is matched only when it appears as
# a footer — start-of-line followed by the token and a colon.
suggest-bump-level() {
  local prev_tag log level="patch" record subject body line
  prev_tag="${TAG_PREFIX}${1}"

  if ! git rev-parse --verify "refs/tags/${prev_tag}" >/dev/null 2>&1; then
    echo "patch"; return
  fi

  # %s = subject, %b = body. RS (0x1e) separates subject/body; US (0x1f)
  # separates commits. Both are unlikely in any sane commit message.
  log=$(git log --format='%s%x1e%b%x1f' "${prev_tag}..HEAD" 2>/dev/null) || {
    echo "patch"; return
  }

  local re_breaking_subject='^[a-zA-Z]+(\([^)]*\))?!:'
  local re_feat='^feat(\([^)]*\))?:'
  local re_breaking_footer='^BREAKING[ -]CHANGE:'

  while IFS= read -r -d $'\x1f' record; do
    # Trim the newline git inserts between format records.
    record="${record#$'\n'}"
    [ -z "$record" ] && continue
    subject="${record%%$'\x1e'*}"
    if [[ "$record" == *$'\x1e'* ]]; then
      body="${record#*$'\x1e'}"
    else
      body=""
    fi

    # Breaking change via "<type>!:" — subject only.
    if [[ "$subject" =~ $re_breaking_subject ]]; then
      echo "major"; return
    fi

    # Breaking change footer — anchored at start of a body line.
    if [ -n "$body" ]; then
      while IFS= read -r line; do
        if [[ "$line" =~ $re_breaking_footer ]]; then
          echo "major"; return
        fi
      done <<< "$body"
    fi

    # feat: → minor (subject only; never downgrade).
    if [[ "$subject" =~ $re_feat ]]; then
      level="minor"
    fi
  done <<< "$log"

  echo "$level"
}

set-v-suggest() {
  local V_PREV_LIST V_MAJOR V_MINOR V_PATCH BUMP

  # Dispatch on whether the input is a valid SemVer 2.0 string first.
  # Semver inputs take the prerelease-counter or conventional-commits branch.
  # Anything else is treated as best-effort "dotted numeric" and only bumped
  # when every component is a decimal integer.
  if is_semver "$1"; then
    # Prerelease counter bumping: if the previous version has a prerelease
    # identifier (e.g. 4.0.0-dev.6, 1.2.3-rc.1, 1.0.0-alpha), bump the
    # trailing numeric counter — or append ".1" if there isn't one. Takes
    # precedence over conventional-commit bumping because pre-release
    # workflows iterate on the same MAJOR.MINOR.PATCH.
    if [[ "$1" == *-* ]]; then
      V_SUGGEST=$(bump-prerelease "$1")
      echo -e "${S_LIGHT}Detected prerelease — bumping trailing counter → ${S_VAL}$V_SUGGEST${RESET}"
      return
    fi

    # Pristine MAJOR.MINOR.PATCH (+build): bump per conventional commits.
    # is_semver already guarantees numeric components, so we can strip any
    # build metadata and bash-arithmetic the rest without re-validating.
    IFS='.' read -r V_MAJOR V_MINOR V_PATCH <<< "${1%%+*}"
    BUMP=$(suggest-bump-level "$1")
    case "$BUMP" in
      major)
        V_MAJOR=$((V_MAJOR + 1)); V_MINOR=0; V_PATCH=0
        echo -e "${S_LIGHT}Detected breaking change — suggesting ${S_VAL}major${RESET}${S_LIGHT} bump.${RESET}"
      ;;
      minor)
        V_MINOR=$((V_MINOR + 1)); V_PATCH=0
        echo -e "${S_LIGHT}Detected feat: commits — suggesting ${S_VAL}minor${RESET}${S_LIGHT} bump.${RESET}"
      ;;
      *)
        V_PATCH=$((V_PATCH + 1))
      ;;
    esac
    V_SUGGEST="$V_MAJOR.$V_MINOR.$V_PATCH"
    return
  fi

  # Non-SemVer input: best-effort dotted-numeric bump. Split via IFS read so
  # globbing can't kick in (silences ShellCheck SC2207 too). Only bump when
  # every component is a decimal integer; otherwise keep the input verbatim.
  local -a V_PREV_LIST
  IFS='.' read -r -a V_PREV_LIST <<< "$1"
  V_MAJOR=${V_PREV_LIST[0]-}
  V_MINOR=${V_PREV_LIST[1]-}
  V_PATCH=${V_PREV_LIST[2]-}

  if [ "${#V_PREV_LIST[@]}" -eq 3 ] \
     && is_number "$V_MAJOR" \
     && is_number "$V_MINOR" \
     && is_number "$V_PATCH"; then
    V_PATCH=$((V_PATCH + 1))
    V_SUGGEST="$V_MAJOR.$V_MINOR.$V_PATCH"
    return
  fi

  log_warn "${S_VAL}${1}${RESET} doesn't look like a SemVer-compatible version — couldn't bump automatically."
  # Keep the input as-is
  V_SUGGEST="$1"
}

do-packagefile-bump() {
  local NOTICE_MSG
  NOTICE_MSG="<${S_VAL}package.json${RESET}>"

  # Skip entirely if package.json is absent. With -v + -f, the user may be
  # bumping only auxiliary JSON files — process-version already allowed
  # missing VER_FILE in that path.
  if [ ! -f package.json ]; then
    log_warn "${NOTICE_MSG} not found — skipping."
    return
  fi

  if [ "$V_NEW" = "$V_PREV" ]; then
    log_warn "${NOTICE_MSG} already contains version ${S_VAL}${V_PREV}${RESET}."
    return
  fi

  if [ "$FLAG_DRYRUN" = true ]; then
    echo -e "${S_LIGHT}[dry-run]${RESET} would set .version = '${S_VAL}$V_NEW${RESET}' in package.json" >&2
    [ -f package-lock.json ] && echo -e "${S_LIGHT}[dry-run]${RESET} would set .version = '${S_VAL}$V_NEW${RESET}' in package-lock.json" >&2
  else
    # Bump package.json via jq (no npm dependency).
    # Note: $V is a jq variable (set via --arg), not a bash expansion — single
    # quotes on the jq program are correct.
    # shellcheck disable=SC2016
    if ! jq_inplace package.json '.version = $V' --arg V "$V_NEW"; then
      fail 1 \
        "Error updating <package.json>." \
        "Check that package.json is valid JSON (run: jq . package.json) and that the file is writable."
    fi
    # package-lock.json: update both top-level .version and (if present) the
    # root package entry .packages[""].version — matches npm's own behaviour.
    if [ -f package-lock.json ]; then
      # shellcheck disable=SC2016
      if ! jq_inplace package-lock.json '
        .version = $V
        | if has("packages") and (.packages | has("")) then
            .packages[""].version = $V
          else . end
      ' --arg V "$V_NEW"; then
        fail 1 \
          "Error updating <package-lock.json>." \
          "Check that package-lock.json is valid JSON (run: jq . package-lock.json) and that the file is writable."
      fi
    fi
  fi

  dryrun git add package.json
  GIT_MSG+="updated package.json, "
  if [ -f package-lock.json ]; then
    dryrun git add package-lock.json
    GIT_MSG+="updated package-lock.json, "
    NOTICE_MSG+=" and <${S_VAL}package-lock.json${RESET}>"
  fi

  log_success "Bumped version in ${NOTICE_MSG}."
}

# Change `version:` value in JSON files, like packager.json, composer.json, etc
bump-json-files() {
  local FILE FILE_V_PREV
  local JSON_PROCESSED=( ) # holds filenames after they've been changed

  for FILE in "${JSON_FILES[@]}"; do
    if [ -f "$FILE" ]; then
      # Get the existing version number (top-level .version only)
      FILE_V_PREV=$( jq -r '.version // empty' "$FILE" 2>/dev/null )

      if [ -z "$FILE_V_PREV" ]; then
        log_error "no .version field in <${S_VAL}$FILE${RESET}> to replace."
      elif [ "$FILE_V_PREV" = "$V_NEW" ]; then
        log_warn "<${S_VAL}$FILE${RESET}> already contains version ${S_VAL}$FILE_V_PREV${RESET}."
      elif [ "$FLAG_DRYRUN" = true ]; then
        echo -e "${S_LIGHT}[dry-run]${RESET} would set .version = '${S_VAL}$V_NEW${RESET}' in ${S_VAL}$FILE${RESET} (was ${S_VAL}$FILE_V_PREV${RESET})" >&2
        GIT_MSG+="updated $FILE, "
      else
        # shellcheck disable=SC2016
        if jq_inplace "$FILE" '.version = $V' --arg V "$V_NEW"; then
          log_success "Updated <${S_VAL}$FILE${RESET}>: ${S_VAL}$FILE_V_PREV${RESET} ${I_ARROW} ${S_VAL}$V_NEW${RESET}"
          # Add file change to commit message:
          GIT_MSG+="updated $FILE, "
        else
          log_error "failed to update <${S_VAL}$FILE${RESET}> via jq."
        fi
      fi

      JSON_PROCESSED+=("$FILE")
    else
      log_warn "file <${S_VAL}$FILE${RESET}> not found."
    fi
  done
  # Stage files that were changed:
  ((${#JSON_PROCESSED[@]})) && dryrun git add "${JSON_PROCESSED[@]}"
}

# Handle VERSION file - for backward compatibility
do-versionfile() {
  if [ -f VERSION ]; then
    GIT_MSG+="updated VERSION, "
    if [ "$FLAG_DRYRUN" = true ]; then
      echo -e "${S_LIGHT}[dry-run]${RESET} would write '${S_VAL}$V_NEW${RESET}' to VERSION" >&2
    else
      echo "$V_NEW" > VERSION # Overwrite file
    fi
    # Stage file for commit
    dryrun git add VERSION

    log_success "Updated [${S_VAL}VERSION${RESET}] file."
    log_warn "Deprecation: the <${S_VAL}VERSION${RESET}> file is deprecated since v0.2.0 — support will be removed in a future version."
  fi
}
