#!/bin/bash

is_number() {
  case $1 in
    ''|*[!0-9]*) return 0 ;;
    *) return 1 ;;
  esac
}

# Show credits & help
usage() { 
  local SCRIPT_VER SCRIPT_AUTH_EMAIL SCRIPT_AUTH_NAME SCRIPT_HOME
  # NPM environment variables are fetched with cross-platform tool cross-env (overkill to use a dependency, but seems the only way AFAIK to get npm vars)
  SCRIPT_VER=`cd $MODULE_DIR && cat package.json | grep version | head -1` 
  SCRIPT_AUTH=`cd $MODULE_DIR && cat package.json | grep author | head -1`
  SCRIPT_HOME=`cd $MODULE_DIR && cat package.json | grep homepage | head -1 | sed -ne 's/.*\(http[^"]*\).*/\1/p'`
  SCRIPT_NAME=`cd $MODULE_DIR && cat package.json | grep name | head -1`

  local env_vars=( SCRIPT_VER SCRIPT_AUTH SCRIPT_NAME )

  for env_var in "${env_vars[@]}"; do
    env_var_val=$( eval "echo \$${env_var}" | awk -F: '{ print $2 }' | sed 's/[",]//g' | sed "s/^[ \t]*//" )

    eval "${env_var}=\"${env_var_val}\""
  done

  # rip off the oh-my-zsh logo, clearly ;)
  printf  "%s _ _  %s___  %s___ %s     %s ___  %s_ _ %s __ __ %s ___  %s\n" "${RAINBOW[@]}" $RAINBOW_RST
  printf  "%s| | |%s| __>%s| . \%s ___ %s| . >%s| | |%s|  \  \%s| . \ %s\n" "${RAINBOW[@]}" $RAINBOW_RST
  printf  "%s| ' |%s| _> %s|   /%s|___|%s| . \%s| ' |%s|     |%s|  _/ %s\n" "${RAINBOW[@]}" $RAINBOW_RST
  printf  "%s|__/ %s|___>%s|_\_\%s     %s|___/%s\___/%s|_|_|_|%s|_|   %s\n" "${RAINBOW[@]}" $RAINBOW_RST

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
  echo -e "$S_WARN-p$S_NORM \t\t\tPush release branch to ORIGIN. "
  echo -e "$S_WARN-h$S_NORM \t\t\tShow this help message. \n"

  echo -e "${S_NORM}${BOLD}Credits:${S_LIGHT}"\
          "\n${SCRIPT_AUTH} ${RESET}"\
          "\n${SCRIPT_HOME}\n"
}

# If there are no commits in repo, quit, because you can't tag with zero commits.
check-commits-exist() {
  git rev-parse HEAD &> /dev/null
  if [ ! "$?" -eq 0 ]; then
    echo -e "\n${I_STOP} ${S_ERROR}Your current branch doesn't have any commits yet. Can't tag without at least one commit." >&2
    echo    
    exit 1
  fi
}

get-commit-msg() {
  echo Bumped $([ ! "${V_PREV}" = "${V_NEW}" ] && echo "${V_PREV} –>" || echo "to ") "$V_NEW"
}

# Process script options
process-arguments() {
  local OPTIONS OPTIND OPTARG

  # Get positional parameters
  while getopts ":v:p:m:f:hbnc" OPTIONS; do # Note: Adding the first : before the flags takes control of flags and prevents default error msgs.
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
        echo -e "\n${S_LIGHT}Option set: ${S_NOTICE}Release note:" ${S_NORM}"'"$REL_NOTE"'"
      ;;
      f )
        FLAG_JSON=true
        echo -e "\n${S_LIGHT}Option set: ${S_NOTICE}JSON file via [-f]: <${S_NORM}${OPTARG}${S_LIGHT}>"
        # Store JSON filenames(s)
        JSON_FILES+=($OPTARG)
      ;;
      p )
        FLAG_PUSH=true
        PUSH_DEST=${OPTARG} # Replace default with user input
        echo -e "\n${S_LIGHT}Option set: ${S_NOTICE}Pushing to <${S_NORM}${PUSH_DEST}${S_LIGHT}>, as the last action in this script."
      ;;
      n )
        FLAG_NOCOMMIT=true
        echo -e "\n${S_LIGHT}Option set: ${S_NOTICE}Disable commit after tagging."
      ;;
      b )
        FLAG_NOBRANCH=true
        echo -e "\n${S_LIGHT}Option set: ${S_NOTICE}Disable committing to new branch."
      ;;
      c )
        FLAG_NOCHANGELOG=true
        echo -e "\n${S_LIGHT}Option set: ${S_NOTICE}Disable updating CHANGELOG.md file."
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
  if [ -f $VER_FILE ] && [ -s $VER_FILE ]; then
    # Get the existing version number
    V_PREV=$( sed -n 's/.*"version":.*"\(.*\)"\(,\)\{0,1\}/\1/p' $VER_FILE )

    if [ -n "$V_PREV" ]; then

      echo -e "\n${S_NOTICE}Current version read from <${S_QUESTION}${VER_FILE}${S_NOTICE}> file: ${S_QUESTION}$V_PREV"

      # If the tag for $V_PREV doesn't exist, it could be the first time running ver-bump,
      # so use previous version without incrementing:
      TAG_EXISTS=`git tag -l v"$V_PREV"`
      if [ ! -n "$TAG_EXISTS" ]; then
        V_SUGGEST=$V_PREV
      else
        V_PREV_LIST=(`echo $V_PREV | tr '.' ' '`)
        V_MAJOR=${V_PREV_LIST[0]}; V_MINOR=${V_PREV_LIST[1]}; V_PATCH=${V_PREV_LIST[2]};

        is_number $V_MAJOR; (( IS_NO = $? )) 
        is_number $V_MINOR; (( IS_NO = $? && $IS_NO )) 
        
        # If major & minor are numbers, then proceed to increment patch
        if [ $IS_NO = 1 ]; then
          is_number $V_PATCH; 
          [ $? == 1 ] && V_PATCH=$((V_PATCH + 1)) # Increment
          V_SUGGEST="$V_MAJOR.$V_MINOR.$V_PATCH" 
        else
          # If patch not a number, do nothing
          echo -e "\n${I_WARN} ${S_WARN}Warning: ${S_QUESTION}${V_PREV}${S_WARN} doesn't look like a SemVer compatible version number!\n"
        fi
      fi

    else 
      echo -e "\n${I_WARN} ${S_ERROR}Warning: <${S_QUESTION}${VER_FILE}${S_WARN}> doesn't contain a 'version' field!\n"
    fi 
  else
    echo -ne "\n${S_WARN}Warning: <${S_QUESTION}${VER_FILE}${S_WARN}> "

    if [ ! -f $VER_FILE ]; then 
      echo "was not found!";     
    elif [ ! -s $VER_FILE ]; then 
      echo "is empty!";  
    fi
  fi  

  # If a version number is supplied by the user with [-v <version number>], then use it 
  if [ -n "$V_USR_SUPPLIED" ]; then
    echo -e "\n${S_NOTICE}You selected version using [-v]:" "${S_WARN}${V_USR_SUPPLIED}"      
    V_NEW="${V_USR_SUPPLIED}"
  else
    # Confirm it with user
    echo -ne "\n${S_QUESTION}Enter a new version number or press <enter> to use [${S_NORM}$V_SUGGEST${S_QUESTION}]: "
    echo -ne "$S_WARN"
    read V_USR_INPUT

    if [ "$V_USR_INPUT" = "" ]; then
      V_NEW="${V_SUGGEST}"
    else
      V_NEW="${V_USR_INPUT}"
    fi
  fi
}

# Only tag if tag doesn't already exist
check-tag-exists() {
  TAG_MSG=`git tag -l v"$V_NEW"`
  if [ -n "$TAG_MSG" ]; then
    echo -e "\n${I_STOP} ${S_ERROR}Error: A release with that tag version number already exists!\n"
    exit 0
  fi
}

do-tag() {
  if [ -z "${REL_NOTE}" ]; then
    # Default release note
    git tag -a "v${V_NEW}" -m "Tag version ${V_NEW}."
  else
    # Custom release note
    git tag -a "v${V_NEW}" -m "${REL_NOTE}"
  fi
  echo -e "\n${I_OK} ${S_NOTICE}Added GIT tag"
}

do-packagefile-bump() {  
  NOTICE_MSG="<${S_NORM}package.json${S_NOTICE}>"

  if [ "$V_NEW" = "$V_PREV" ]; then
    echo -e "\n${I_WARN}${NOTICE_MSG}${S_WARN} already contains version ${V_NEW}."
  else
    NPM_MSG=`npm version ${V_NEW} --git-tag-version=false 2>&1`

    if [ ! "$?" -eq 0 ]; then
      echo -e "\n${I_STOP} ${S_ERROR}Error updating <package.json> and/or <package-lock.json>.\n\n$NPM_MSG\n"
      exit 1
    else
      git add package.json
      GIT_MSG+="Updated package.json, "
      if [ -f package-lock.json ]; then
        git add package-lock.json
        GIT_MSG+="Updated package-lock.json, "
        NOTICE_MSG+=" and <${S_NORM}package-lock.json${S_NOTICE}>"
      fi
      echo -e "\n${I_OK} ${S_NOTICE}Bumped version in ${NOTICE_MSG}."
    fi
  fi
}

# Change `version:` value in JSON files, like packager.json, composer.json, etc
bump-json-files() {
  # if [ "$FLAG_JSON" != true ]; then return; fi
  
  JSON_PROCESSED=( ) # holds filenames after they've been changed

  for FILE in "${JSON_FILES[@]}"; do
    if [ -f $FILE ]; then
      # Get the existing version number
      V_OLD=$( sed -n 's/.*"version":.*"\(.*\)"\(,\)\{0,1\}/\1/p' $FILE )

      if [ "$V_OLD" = "$V_NEW" ]; then
        echo -e "\n${I_ERROR} ${S_WARN}File <${S_QUESTION}$FILE${S_WARN}> already contains version ${S_NORM}$V_OLD"
      else
        # Write to output file
        FILE_MSG=`sed -i .temp "s/\"version\":\(.*\)\"$V_OLD\"/\"version\":\1\"$V_NEW\"/g" $FILE 2>&1`

        if [ "$?" -eq 0 ]; then
          echo -e "\n${I_OK} ${S_NOTICE}Updated file <${S_NORM}$FILE${S_NOTICE}> from ${S_QUESTION}$V_OLD ${S_NOTICE}-> ${S_QUESTION}$V_NEW"
          rm -f ${FILE}.temp          
          # Add file change to commit message:
          GIT_MSG+="Updated $FILE, "
        else
          echo -e "\n${I_STOP} ${S_ERROR}Error updating version in file <${S_NORM}$FILE${S_NOTICE}> — Old version ${S_QUESTION}$V_OLD ${S_NOTICE} not found!"
        fi
      fi

      JSON_PROCESSED+=($FILE)
    else
      echo -e "\n${S_WARN}File <${S_NORM}$FILE${S_WARN}> not found."
    fi
  done
  # Stage files that were changed:
  [ -n "${JSON_PROCESSED}" ] && git add "${JSON_PROCESSED[@]}"
}

# Handle VERSION file - for backward compatibility
do-versionfile() {
  if [ -f VERSION ]; then
    GIT_MSG+="Updated VERSION, "
    echo $V_NEW > VERSION # Overwrite file
    # Stage file for commit
    git add VERSION

    echo -e "\n${I_OK} ${S_NOTICE}Updated [${S_NORM}VERSION${S_NOTICE}] file."\
            "\n${I_WARN} ${S_ERROR}Deprecation warning: using a <${S_NORM}VERSION${S_ERROR}> file is deprecated since v0.2.0 — support will be removed in future versions."      
  fi
}

# Dump git log history to CHANGELOG.md
do-changelog() {  
  [ "$FLAG_NOCHANGELOG" = true ] && return

  # Log latest commits to CHANGELOG.md:
  # Get latest commits since last version
  
  LOG_MSG=`git log --pretty=format:"- %s" $([ $(git tag -l "v${V_PREV}") ] && echo "v${V_PREV}...HEAD") 2>&1`

  if [ ! "$?" -eq 0 ]; then
    echo -e "\n${I_STOP} ${S_ERROR}Error getting commit history since last version bump for logging to CHANGELOG.\n\n$LOG_MSG\n"
    exit 1
  fi
  
  [ -f CHANGELOG.md ] && ACTION_MSG="Updated" || ACTION_MSG="Created"
  # Add info to commit message for later:
  GIT_MSG+="${ACTION_MSG} CHANGELOG.md, "
 
  # Add heading
  echo "## $V_NEW ($NOW)" > tmpfile

  # Log the bumping commit:
  # - The final commit is done after do-changelog(), so we need to create the log entry for it manually:
  echo "- ${GIT_MSG}$(get-commit-msg)" >> tmpfile
  # Add previous commits
  [ -n "$LOG_MSG" ] && echo "$LOG_MSG" >> tmpfile
  
  echo -en "\n" >> tmpfile

  if [ -f CHANGELOG.md ]; then
    # Append existing log
    cat CHANGELOG.md >> tmpfile
  else
    echo -e "\n${S_WARN}A [${S_NORM}CHANGELOG.md${S_WARN}] file was not found."  
  fi

  mv tmpfile CHANGELOG.md
  
  # User prompts
  echo -e "\n${I_OK} ${S_NOTICE}${ACTION_MSG} [${S_NORM}CHANGELOG.md${S_NOTICE}] file"
  # Pause & allow user to open and edit the file:
  echo -en "\n${S_QUESTION}Make adjustments to [${S_NORM}CHANGELOG.md${S_QUESTION}] if required now. Press <enter> to continue."
  read

  # Stage log file, to commit later
  git add CHANGELOG.md
}

#
check-branch-exist() {
  [ "$FLAG_NOBRANCH" = true ] && return

  BRANCH_MSG=`git rev-parse --verify "${REL_PREFIX}${V_NEW}" 2>&1`
  if [ "$?" -eq 0 ]; then
    echo -e "\n${I_STOP} ${S_ERROR}Error: Branch <${S_NORM}${REL_PREFIX}${V_NEW}${S_ERROR}> already exists!\n"
    exit 1
  fi  
}

# 
do-branch() {
  [ "$FLAG_NOBRANCH" = true ] && return

  echo -e "\n${S_NOTICE}Creating new release branch..."

  BRANCH_MSG=`git branch "${REL_PREFIX}${V_NEW}" 2>&1`
  if [ ! "$?" -eq 0 ]; then
    echo -e "\n${I_STOP} ${S_ERROR}Error\n$BRANCH_MSG\n"
    exit 1
  else
    BRANCH_MSG=`git checkout "${REL_PREFIX}${V_NEW}" 2>&1`
    echo -e "\n${I_OK} ${S_NOTICE}${BRANCH_MSG}"
  fi  
  
  # REL_PREFIX
}

# Stage & commit all files modified by this script
do-commit() {
  [ "$FLAG_NOCOMMIT" = true ] && return

  GIT_MSG+="$(get-commit-msg)" 
  echo -e "\n${S_NOTICE}Committing..."
  COMMIT_MSG=`git commit -m "${GIT_MSG}" 2>&1`
  if [ ! "$?" -eq 0 ]; then
    echo -e "\n${I_STOP} ${S_ERROR}Error\n$COMMIT_MSG\n"
    exit 1
  else
    echo -e "\n${I_OK} ${S_NOTICE}$COMMIT_MSG"
  fi  
}

# Pushes files + tags to remote repo. Changes are staged by earlier functions
do-push() {
  [ "$FLAG_NOCOMMIT" = true ] && return
  
  if [ "$FLAG_PUSH" = true ]; then
    CONFIRM="Y"
  else
    echo -ne "\n${S_QUESTION}Push tags to <${S_NORM}${PUSH_DEST}${S_QUESTION}>? [${S_NORM}N/y${S_QUESTION}]: "
    read CONFIRM  
  fi

  case "$CONFIRM" in
    [yY][eE][sS]|[yY] )
      echo -e "\n${S_NOTICE}Pushing files + tags to <${S_NORM}${PUSH_DEST}${S_NOTICE}>..."
      PUSH_MSG=`git push "${PUSH_DEST}" v"$V_NEW" 2>&1` # Push new tag
      if [ ! "$?" -eq 0 ]; then
        echo -e "\n${I_STOP} ${S_WARN}Warning\n$PUSH_MSG"
        # exit 1
      else
        echo -e "\n${I_OK} ${S_NOTICE}$PUSH_MSG"
      fi  
    ;;
  esac  
}
