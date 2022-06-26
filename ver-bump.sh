#!/bin/bash

#  _ _  ___  ___       ___  _ _  __ __  ___  
# | | || __>| . \ ___ | . >| | ||  \  \| . \
# | ' || _> |   /|___|| . \| ' ||     ||  _/
# |__/ |___>|_\_\     |___/\___/|_|_|_||_|  
#
# Description:
#   - A handy utility that takes care of releasing Git software projects.
# Credits:
#   – https://github.com/jv-k/ver-bump
#

# shellcheck disable=SC1090,SC2034
true

MODULE_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

source "$MODULE_DIR/lib/helpers.sh"
source "$MODULE_DIR/lib/icons.sh"

NOW="$(date +'%B %d, %Y')"

V_SUGGEST="0.1.0" # This is suggested in case VERSION file or user supplied version via -v is missing
VER_FILE="package.json"
GIT_MSG=""
REL_NOTE=""
REL_PREFIX="release-"
COMMIT_MSG_PREFIX="chore: " # Commit msg prefix for the file changes this script makes
PUSH_DEST="origin"

JSON_FILES=()

#### Initiate Script ###########################

main() {
  # Process and prepare
  process-arguments "$@"
  check-commits-exist
  process-version

  check-branch-notexist
  check-tag-exists
  echo -e "\n${S_LIGHT}------"

  # Update files
  do-packagefile-bump
  bump-json-files
  do-versionfile
  do-changelog
  do-branch
  do-commit
  do-tag
  do-push

  echo -e "\n${S_LIGHT}------"
  echo -ne "\n${I_OK} ${S_NOTICE}"
  capitalise "$( get-commit-msg )"
  echo -e "\n${I_END} ${GREEN}Done!\n"
}

# Execute script when it is executed as a script, and when it is brought into the environment with source (so it can be tested)
# shellcheck disable=SC2128
if [[ "$0" = "$BASH_SOURCE" ]]; then
  # shellcheck source-path=lib
  source "$MODULE_DIR/lib/styles.sh" # only load when not sourced, for tests to work
  main "$@"
fi
