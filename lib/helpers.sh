#!/bin/bash

# shellcheck disable=SC2288
true

# Returns 0 (success) if $1 is a non-empty decimal integer, non-zero otherwise.
is_number() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

# Ensure required external tools are present before mutating the repo.
check-dependencies() {
  local tool missing=()
  for tool in git jq npm; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  if (( ${#missing[@]} )); then
    echo -e "\n${I_STOP} ${S_ERROR}Missing required tool(s): ${S_WARN}${missing[*]}${S_ERROR}. Please install and retry.\n" >&2
    exit 1
  fi
}

# Show credits & help
usage() {
  local SCRIPT_VER SCRIPT_AUTH SCRIPT_HOME SCRIPT_NAME env_var env_var_val
  local env_vars=( SCRIPT_VER SCRIPT_AUTH SCRIPT_NAME )

  if command -v jq >/dev/null 2>&1; then
    SCRIPT_VER=$(  jq -r '.version  // ""' "$MODULE_DIR/package.json" )
    SCRIPT_AUTH=$( jq -r '.author   // ""' "$MODULE_DIR/package.json" )
    SCRIPT_HOME=$( jq -r '.homepage // ""' "$MODULE_DIR/package.json" )
    SCRIPT_NAME=$( jq -r '.name     // ""' "$MODULE_DIR/package.json" )
  else
    # Fallback: grep + trim (works without jq for --help alone)
    SCRIPT_VER=$(  cd "$MODULE_DIR" && grep version  package.json | head -1 )
    SCRIPT_AUTH=$( cd "$MODULE_DIR" && grep author   package.json | head -1 )
    SCRIPT_HOME=$( cd "$MODULE_DIR" && grep homepage package.json | head -1 | sed -ne 's/.*\(http[^"]*\).*/\1/p' )
    SCRIPT_NAME=$( cd "$MODULE_DIR" && grep name     package.json | head -1 )

    for env_var in "${env_vars[@]}"; do
      env_var_val=$( printf '%s' "${!env_var}" | awk -F: '{ print $2 }' | sed 's/[",]//g' | sed "s/^[ \t]*//" )
      printf -v "$env_var" '%s' "$env_var_val"
    done
  fi

  # rip off the oh-my-zsh logo, clearly ;)
  printf  "%s _ _  %s___  %s___ %s     %s ___  %s_ _ %s __ __ %s ___  %s\n" "${RAINBOW[@]}" "$RAINBOW_RST"
  printf  "%s| | |%s| __>%s| . \%s ___ %s| . >%s| | |%s|  \  \%s| . \ %s\n" "${RAINBOW[@]}" "$RAINBOW_RST"
  printf  "%s| ' |%s| _> %s|   /%s|___|%s| . \%s| ' |%s|     |%s|  _/ %s\n" "${RAINBOW[@]}" "$RAINBOW_RST"
  printf  "%s|__/ %s|___>%s|_\_\%s     %s|___/%s\___/%s|_|_|_|%s|_|   %s\n" "${RAINBOW[@]}" "$RAINBOW_RST"

  echo -e "\t\t\t${LIGHTGRAY}    Version: $S_WARN${SCRIPT_VER}"

  echo -e "${S_NORM}${BOLD}Description:${RESET}"\
          "\nThis script automates bumping the git software project's version automatically."\
          "\nIt does several things that are typically required for releasing a Git repository, like git tagging, automatic updating of CHANGELOG.md, and incrementing the version number in various JSON files."

  echo -e "\n${S_NORM}${BOLD}Usage:${RESET}"\
          "\n${SCRIPT_NAME} [-v <version number>] [-m <release message>] [-j <file1>] [-j <file2>].. [-n] [-c] [-p] [-h]" 1>&2; 

  echo -e "\n${S_NORM}${BOLD}Options:${RESET}"
  echo -e "$S_WARN-v$S_NORM <version number>\tSpecify a manual version number"
  echo -e "$S_WARN-m$S_NORM <release message>\tCustom release message."
  echo -e "$S_WARN-f$S_NORM <filename.json>\tUpdate version number inside JSON files."\
          "\n\t\t\tFor multiple files, add a separate -f option for each one, for example:"\
          "\n\t\t\t${S_NORM}ver-bump -f src/plugin/package.json -f composer.json"
  echo -e "$S_WARN-p$S_NORM \t\t\tPush release branch to ORIGIN."
  echo -e "$S_WARN-n$S_NORM \t\t\tDisable commit after tagging release."
  echo -e "$S_WARN-b$S_NORM \t\t\tDisable commit to a new release-x.x.x branch."
  echo -e "$S_WARN-c$S_NORM \t\t\tDisable updating CHANGELOG.md automatically with new commits since last release tag."
  echo -e "$S_WARN-l$S_NORM \t\t\tPause enabled for amending CHANGELOG.md"
  echo -e "$S_WARN-h$S_NORM \t\t\tShow this help message.\n"

  echo -e "${S_NORM}${BOLD}Credits:${S_LIGHT}"\
          "\n${SCRIPT_AUTH} ${RESET}"\
          "\n${SCRIPT_HOME}\n"
}

# Process script options
process-arguments() {
  local OPTIONS OPTIND OPTARG

  # Get positional parameters
  while getopts ":v:p:m:f:hbncl" OPTIONS; do # Note: Adding the first : before the flags takes control of flags and prevents default error msgs.
    case "$OPTIONS" in
      h )
        # Show help
        usage
        exit 0
      ;;
      v )
        # User has supplied a version number
        V_USR_SUPPLIED=$OPTARG
      ;;
      m )
        REL_NOTE=$OPTARG
        # Custom release note
        echo -e "\n${S_LIGHT}Option set: ${S_NOTICE}Release note: ${S_NORM} '$REL_NOTE'"
      ;;
      f )
        echo -e "\n${S_LIGHT}Option set: ${S_NOTICE}JSON file via [-f]: <${S_NORM}${OPTARG}${S_LIGHT}>"
        # Store JSON filenames(s)
        JSON_FILES+=("$OPTARG")
      ;;
      p )
        FLAG_PUSH=true
        PUSH_DEST=${OPTARG} # Replace default with user input
        echo -e "\n${S_LIGHT}Option set: ${S_NOTICE}Pushing to <${S_NORM}${PUSH_DEST}${S_LIGHT}>, as the last action in this script."
      ;;
      n )
        FLAG_NOCOMMIT=true
        echo -e "\n${S_LIGHT}Option set: ${S_NOTICE}Disable commit after tagging release."
      ;;
      b )
        FLAG_NOBRANCH=true
        echo -e "\n${S_LIGHT}Option set: ${S_NOTICE}Disable committing to new branch."
      ;;
      c )
        FLAG_NOCHANGELOG=true
        echo -e "\n${S_LIGHT}Option set: ${S_NOTICE}Disable updating CHANGELOG.md automatically with new commits since last release tag."
      ;;
      l )
        FLAG_CHANGELOG_PAUSE=true
        echo -e "\n${S_LIGHT}Option set: ${S_NOTICE}Pause enabled for amending CHANGELOG.md"
      ;;
      \? )
        echo -e "\n${I_ERROR}${S_ERROR} Invalid option: ${S_WARN}-$OPTARG" >&2
        echo
        exit 1
      ;;
      : )
        echo -e "\n${I_ERROR}${S_ERROR} Option ${S_WARN}-$OPTARG ${S_ERROR}requires an argument." >&2
        echo
        exit 1
      ;;
    esac
  done
}

# If there are no commits in repo, quit, because you can't tag with zero commits.
check-commits-exist() {
  if ! git rev-parse HEAD &> /dev/null; then
    echo -e "\n${I_STOP} ${S_ERROR}Your current branch doesn't have any commits yet. Can't tag without at least one commit." >&2
    echo
    exit 1
  fi
}

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
  # As a minimum pre-requisite ver-bump needs a version number from a JSON file
  # to read + bump. If it doesn't exist, throw an error + exit:
  if [ -f "$VER_FILE" ] && [ -s "$VER_FILE" ]; then
    # Get the existing version number (top-level .version only)
    V_PREV=$( jq -r '.version // empty' "$VER_FILE" 2>/dev/null )

    if [ -n "$V_PREV" ]; then
      echo -e "\n${S_NOTICE}Current version read from <${S_QUESTION}${VER_FILE}${S_NOTICE}> file: ${S_QUESTION}$V_PREV"
      set-v-suggest "$V_PREV" # check + increment patch number
    else
      echo -e "\n${I_WARN} ${S_ERROR}Error: <${S_QUESTION}${VER_FILE}${S_WARN}> doesn't contain a 'version' field!\n"
      exit 1
    fi
  else
    echo -ne "\n${S_ERROR}Error: <${S_QUESTION}${VER_FILE}${S_WARN}> "
    if [ ! -f "$VER_FILE" ]; then
      echo "was not found!";
    elif [ ! -s "$VER_FILE" ]; then
      echo "is empty!";
    fi
    exit 1
  fi

  # If a version number is supplied by the user with [-v <version number>] — use it!
  if [ -n "$V_USR_SUPPLIED" ]; then
    echo -e "\n${S_NOTICE}You selected version using [-v]:" "${S_WARN}${V_USR_SUPPLIED}"
    V_NEW="${V_USR_SUPPLIED}"
  else
    # Display a suggested version
    echo -ne "\n${S_QUESTION}Enter a new version number or press <enter> to use [${S_NORM}$V_SUGGEST${S_QUESTION}]: "
    echo -ne "$S_WARN"
    read -r V_USR_INPUT

    if [ "$V_USR_INPUT" = "" ]; then
      # User accepted the suggested version
      V_NEW=$V_SUGGEST
    else
      V_NEW=$V_USR_INPUT
    fi
  fi
}

set-v-suggest() {
  local V_PREV_LIST V_MAJOR V_MINOR V_PATCH

  # shellcheck disable=SC2207
  V_PREV_LIST=( $( echo "$1" | tr '.' ' ' ) )
  V_MAJOR=${V_PREV_LIST[0]}
  V_MINOR=${V_PREV_LIST[1]}
  V_PATCH=${V_PREV_LIST[2]}

  # If all three components are decimal integers, increment the patch.
  if is_number "$V_MAJOR" && is_number "$V_MINOR" && is_number "$V_PATCH"; then
    V_PATCH=$((V_PATCH + 1))
    V_SUGGEST="$V_MAJOR.$V_MINOR.$V_PATCH"
    return
  fi

  echo -e "\n${I_WARN} ${S_WARN}Warning: ${S_QUESTION}${1}${S_WARN} doesn't look like a SemVer compatible version number! Couldn't automatically bump the patch value. \n"
  # Keep the input as-is
  V_SUGGEST="$1"
}

#
check-branch-notexist() {
  [ "$FLAG_NOBRANCH" = true ] && return
  if git rev-parse --verify "${REL_PREFIX}${V_NEW}" &> /dev/null; then
    echo -e "\n${I_STOP} ${S_ERROR}Error: Branch <${S_NORM}${REL_PREFIX}${V_NEW}${S_ERROR}> already exists!\n"
    exit 1
  fi
}

# Only tag if tag doesn't already exist
check-tag-exists() {
  local TAG_MSG
  TAG_MSG=$( git tag -l "v${V_NEW}" )
  if [ -n "$TAG_MSG" ]; then
    echo -e "\n${I_STOP} ${S_ERROR}Error: A release with that tag version number already exists!\n\n$TAG_MSG\n"
    exit 1
  fi
}

do-packagefile-bump() {
  local NOTICE_MSG NPM_MSG NPM_RC
  NOTICE_MSG="<${S_NORM}package.json${S_NOTICE}>"
  if [ "$V_NEW" = "$V_PREV" ]; then
    echo -e "\n${I_WARN}${NOTICE_MSG}${S_WARN} already contains version ${V_NEW}."
  else
    NPM_MSG=$( npm version "${V_NEW}" --git-tag-version=false --force 2>&1 ); NPM_RC=$?
    if [ "$NPM_RC" -ne 0 ]; then
      echo -e "\n${I_STOP} ${S_ERROR}Error updating <package.json> and/or <package-lock.json>.\n\n$NPM_MSG\n"
      exit 1
    else
      git add package.json
      GIT_MSG+="updated package.json, "
      if [ -f package-lock.json ]; then
        git add package-lock.json
        GIT_MSG+="updated package-lock.json, "
        NOTICE_MSG+=" and <${S_NORM}package-lock.json${S_NOTICE}>"
      fi
      echo -e "\n${I_OK} ${S_NOTICE}Bumped version in ${NOTICE_MSG}."
    fi
  fi
}

# Change `version:` value in JSON files, like packager.json, composer.json, etc
bump-json-files() {
  local FILE FILE_V_PREV JQ_ERR
  local JSON_PROCESSED=( ) # holds filenames after they've been changed

  for FILE in "${JSON_FILES[@]}"; do
    if [ -f "$FILE" ]; then
      # Get the existing version number (top-level .version only)
      FILE_V_PREV=$( jq -r '.version // empty' "$FILE" 2>/dev/null )

      if [ -z "$FILE_V_PREV" ]; then
        echo -e "\n${I_STOP} ${S_ERROR}Error updating version in file <${S_NORM}$FILE${S_NOTICE}> - a version name/value pair was not found to replace!"
      elif [ "$FILE_V_PREV" = "$V_NEW" ]; then
        echo -e "\n${I_WARN} ${S_WARN}File <${S_QUESTION}$FILE${S_WARN}> already contains version ${S_NORM}$FILE_V_PREV"
      else
        # Write to output file; redirection order captures stderr into JQ_ERR
        # while stdout (the json) goes to the temp file.
        # shellcheck disable=SC2261
        if JQ_ERR=$( jq --arg V_NEW "$V_NEW" '.version = $V_NEW' "$FILE" 2>&1 >"${FILE}.temp" ) \
           && [ -s "${FILE}.temp" ]; then
          mv -f "${FILE}.temp" "${FILE}"
          echo -e "\n${I_OK} ${S_NOTICE}Updated file <${S_NORM}$FILE${S_NOTICE}> from ${S_QUESTION}$FILE_V_PREV ${S_NOTICE}-> ${S_QUESTION}$V_NEW"
          # Add file change to commit message:
          GIT_MSG+="updated $FILE, "
        else
          rm -f "${FILE}.temp"
          echo -e "\n${I_STOP} ${S_ERROR}Error updating <${S_NORM}$FILE${S_ERROR}> with jq.\n${JQ_ERR}"
        fi
      fi

      JSON_PROCESSED+=("$FILE")
    else
      echo -e "\n${S_WARN}File <${S_NORM}$FILE${S_WARN}> not found."
    fi
  done
  # Stage files that were changed:
  ((${#JSON_PROCESSED[@]})) && git add "${JSON_PROCESSED[@]}"
}

# Handle VERSION file - for backward compatibility
do-versionfile() {
  if [ -f VERSION ]; then
    GIT_MSG+="updated VERSION, "
    echo "$V_NEW" > VERSION # Overwrite file
    # Stage file for commit
    git add VERSION

    echo -e "\n${I_OK} ${S_NOTICE}Updated [${S_NORM}VERSION${S_NOTICE}] file."\
            "\n${I_WARN} ${S_ERROR}Deprecation warning: using a <${S_NORM}VERSION${S_ERROR}> file is deprecated since v0.2.0 - support will be removed in future versions."      
  fi
}

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
  local ACTION_MSG COMMITS_MSG LOG_MSG LOG_RC RANGE

  RANGE=$([ "$(git tag -l v"${V_PREV}")" ] && echo "v${V_PREV}..HEAD")
  # shellcheck disable=SC2086
  COMMITS_MSG=$( git log --pretty=format:"- %s" ${RANGE} 2>&1 ); LOG_RC=$?
  if [ "$LOG_RC" -ne 0 ]; then
    echo -e "\n${I_STOP} ${S_ERROR}Error getting commit history since last version bump for logging to CHANGELOG.\n\n$COMMITS_MSG\n"
    exit 1
  fi

  if [ -f CHANGELOG.md ]; then
    ACTION_MSG="updated"
  else
    ACTION_MSG="created"
  fi
  # Add info to commit message for later:
  GIT_MSG+="${ACTION_MSG} CHANGELOG.md, "

  # Add heading
  echo "## $V_NEW ($NOW)" > tmpfile

  # Log the bumping commit:
  # - The final commit is done after do-changelog(), so we need to create the log entry for it manually:
  LOG_MSG="${GIT_MSG}$(get-commit-msg)"
  # LOG_MSG="$( capitalise "${LOG_MSG}" )" # Capitalise first letter
  echo "- ${COMMIT_MSG_PREFIX}${LOG_MSG}" >> tmpfile
  # Add previous commits
  [ -n "$COMMITS_MSG" ] && echo "$COMMITS_MSG" >> tmpfile

  echo -en "\n" >> tmpfile

  if [ -f CHANGELOG.md ]; then
    # Append existing log
    cat CHANGELOG.md >> tmpfile
  else
    echo -e "\n${S_WARN}An existing [${S_NORM}CHANGELOG.md${S_WARN}] file was not found. Creating one..."
  fi

  mv tmpfile CHANGELOG.md

  echo -e "\n${I_OK} ${S_NOTICE}$( capitalise "${ACTION_MSG}" ) [${S_NORM}CHANGELOG.md${S_NOTICE}] file."

  # Optionally pause & allow user to open and edit the file:
  if [ "$FLAG_CHANGELOG_PAUSE" = true ]; then
    echo -en "\n${S_QUESTION}Make adjustments to [${S_NORM}CHANGELOG.md${S_QUESTION}] if required now. Press <enter> to continue."
    read -r
  fi

  # Stage log file, to commit later
  git add CHANGELOG.md
}

do-branch() {
  [ "$FLAG_NOBRANCH" = true ] && return

  local BRANCH_MSG

  echo -e "\n${S_NOTICE}Creating new release branch..."

  BRANCH_MSG=$(git branch "${REL_PREFIX}${V_NEW}" 2>&1)
  if [ -z "$BRANCH_MSG" ]; then
    BRANCH_MSG=$(git checkout "${REL_PREFIX}${V_NEW}" 2>&1)
    echo -e "\n${I_OK} ${S_NOTICE}${BRANCH_MSG}"
  else
    echo -e "\n${I_STOP} ${S_ERROR}Error\n$BRANCH_MSG\n"
    exit 1
  fi
}

# Stage & commit all files modified by this script
do-commit() {
  [ "$FLAG_NOCOMMIT" = true ] && return

  local COMMIT_MSG COMMIT_RC

  GIT_MSG+="$(get-commit-msg)"
  echo -e "\n${S_NOTICE}Committing..."
  COMMIT_MSG=$( git commit -m "${COMMIT_MSG_PREFIX}${GIT_MSG}" 2>&1 ); COMMIT_RC=$?
  if [ "$COMMIT_RC" -ne 0 ]; then
    echo -e "\n${I_STOP} ${S_ERROR}Error\n$COMMIT_MSG\n"
    exit 1
  else
    echo -e "\n${I_OK} ${S_NOTICE}$COMMIT_MSG"
  fi
}

# Create a Git tag using the SemVar
do-tag() {
  # If we skipped committing, the version bumps are not persisted, so tagging
  # would point at the wrong (pre-bump) commit. Skip the tag too.
  [ "$FLAG_NOCOMMIT" = true ] && return

  if [ -z "${REL_NOTE}" ]; then
    # Default release note
    git tag -a "v${V_NEW}" -m "Tag version ${V_NEW}."
  else
    # Custom release note
    git tag -a "v${V_NEW}" -m "${REL_NOTE}"
  fi
  echo -e "\n${I_OK} ${S_NOTICE}Added GIT tag"
}

# Pushes branch + tag to remote repo. Changes are staged by earlier functions
do-push() {
  [ "$FLAG_NOCOMMIT" = true ] && return

  local CONFIRM PUSH_MSG PUSH_RC REMOTE_REF

  if [ "$FLAG_PUSH" = true ]; then
    CONFIRM="Y"
  else
    echo -ne "\n${S_QUESTION}Push branch + tags to <${S_NORM}${PUSH_DEST}${S_QUESTION}>? [${S_NORM}N/y${S_QUESTION}]: "
    read -r CONFIRM
  fi

  case "$CONFIRM" in
    [yY][eE][sS]|[yY] )
      echo -e "\n${S_NOTICE}Pushing branch + tag to <${S_NORM}${PUSH_DEST}${S_NOTICE}>..."
      if [ "$FLAG_NOBRANCH" = true ]; then
        REMOTE_REF=$(git rev-parse --abbrev-ref HEAD)
      else
        REMOTE_REF="${REL_PREFIX}${V_NEW}"
      fi
      PUSH_MSG=$( git push -u "${PUSH_DEST}" "${REMOTE_REF}" "v${V_NEW}" 2>&1 ); PUSH_RC=$?
      if [ "$PUSH_RC" -ne 0 ]; then
        echo -e "\n${I_STOP} ${S_WARN}Warning\n$PUSH_MSG"
      else
        echo -e "\n${I_OK} ${S_NOTICE}$PUSH_MSG"
      fi
    ;;
  esac
}
