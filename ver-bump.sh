#!/bin/bash

#  _ _  ___  ___       ___  _ _  __ __  ___  
# | | || __>| . \ ___ | . >| | ||  \  \| . \
# | ' || _> |   /|___|| . \| ' ||     ||  _/
# |__/ |___>|_\_\     |___/\___/|_|_|_||_|  
#
# Description:
#   - This script automates bumping the git software project's version using automation.
# Credits:
#   – https://github.com/jv-k/ver-bump
#

MODULE_DIR="$(dirname "$(realpath "$0")")"

source $MODULE_DIR/lib/helpers.sh
source $MODULE_DIR/lib/styles.sh

NOW="$(date +'%B %d, %Y')"

V_SUGGEST="0.1.0" # This is suggested in case VERSION file or user supplied version via -v is missing
VER_FILE="package.json"
GIT_MSG=""
REL_NOTE=""
REL_PREFIX="release-"
PUSH_DEST="origin"

JSON_FILES=($VER_FILE)

#### Initiate Script ###########################

# Process and prepare
process-arguments "$@"
check-commits-exist
process-version

check-branch-exist
check-tag-exists

echo -e "\n${S_LIGHT}––––––"

# Update files
bump-json-files
do-versionfile
do-changelog
do-branch
do-commit
tag "${V_USR_INPUT}" "${REL_NOTE}"
do-push

echo -e "\n${S_LIGHT}––––––"
echo -e "\n${I_OK} ${S_NOTICE}"Bumped $([ -n "${V_PREV}" ] && echo "${V_PREV} –>" || echo "to ") "$V_USR_INPUT"
echo -e "\n${I_END} ${GREEN}Done!\n"
