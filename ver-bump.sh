#!/bin/bash

#  _ _  ___  ___       ___  _ _  __ __  ___  
# | | || __>| . \ ___ | . >| | ||  \  \| . \
# | ' || _> |   /|___|| . \| ' ||     ||  _/
# |__/ |___>|_\_\     |___/\___/|_|_|_||_|  
#
# Description:
#   - This script automates bumping the git software project's version using automation.

#   - It does several things that are typically required for releasing a Git repository, like git tagging, 
#     automatic updating of CHANGELOG.md, and incrementing the version number in various JSON files.

#     - Increments / suggests the current software project's version number
#     - Adds a Git tag, named after the chosen version number
#     - Updates CHANGELOG.md
#     - Updates VERSION file
#     - Commits files to a new branch  
#     - Pushes to remote (optionally)
#     - Updates "version" : "x.x.x" tag in JSON files if [-v file1 -v file2...] argument is supplied.
#
# Usage: 
#   ./ver-bump.sh [-v <version number>] [-m <release message>] [-j <file1>] [-j <file2>].. [-n] [-p] [-b] [-h]
#
# Options:
#   -v <version number>	  Specify a manual version number
#   -m <release message>	Custom release message.
#   -f <filename.json>	  Update version number inside JSON files.
# 			                  * For multiple files, add a separate -f option for each one,
#	  		                  * For example: ./ver-bump.sh -f src/plugin/package.json -f composer.json
#   -p <repository alias> Push commits to remote repository, eg `-p origin`
#   -n 	                  Don't perform a commit automatically.
#	  		                  * You may want to do that yourself, for example.
#   -b                    Don't create automatic `release-<version>` branch
#   -h 	                  Show help message.

#
# Detailed notes:
#   – The contents of the `VERSION` file which should be a semantic version number such as "1.2.3" 
#     or even "1.2.3-beta+001.ab"
#   
#   – It pulls a list of changes from git history & prepends to a file called CHANGELOG.md 
#     under the title of the new version # number, allows the user to review and update the changelist
#
#   – Creates a Git tag with the version number
#
#   - Creates automatic `release-<version>` branch
#
#   – Commits the new version to the current repository
#
#   – Optionally pushes the commit to remote repository
#
#   – Make sure to set execute permissions for the script, eg `$ chmod 755 ver-bump.sh`
#
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
