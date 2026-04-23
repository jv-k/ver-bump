#!/bin/bash

#  _ _  ___  ___       ___  _ _  __ __  ___
# | | || __>| . \ ___ | . >| | ||  \  \| . \
# | ' || _> |   /|___|| . \| ' ||     ||  _/
# |__/ |___>|_\_\     |___/\___/|_|_|_||_|
#
# Description:
#   - A handy utility that takes care of releasing Git software projects.
# Credits:
#   - https://github.com/jv-k/ver-bump
#

# shellcheck disable=SC1090,SC2034,SC1017
true

MODULE_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

source "$MODULE_DIR/lib/helpers.sh"
source "$MODULE_DIR/lib/icons.sh"
source "$MODULE_DIR/lib/config.sh"

NOW="$(date +%F)"

V_SUGGEST="0.1.0" # This is suggested in case VERSION file or user supplied version via -v is missing
VER_FILE="package.json"
GIT_MSG=""
REL_NOTE=""
FLAG_DRYRUN=false

# Config-keyed defaults use `:=` so exported env values survive. An
# unconditional assignment (e.g. `TAG_PREFIX="v"`) would clobber
# `export TAG_PREFIX=from-env` here — load-config's env-vs-file snapshot
# would then see the default, and env would silently lose to .ver-bumprc.
# apply-config-defaults (lib/config.sh) is the canonical source of defaults;
# these `:=` lines just keep sourcing ver-bump.sh directly (from tests) sane.
: "${REL_PREFIX:=release-}"
: "${TAG_PREFIX:=v}"
: "${COMMIT_MSG_PREFIX:=chore: }" # Commit msg prefix for the file changes this script makes
: "${PUSH_DEST:=origin}"

JSON_FILES=()

#### Initiate Script ###########################

main() {
  # Load .ver-bumprc (if any) and apply defaults BEFORE parsing CLI args.
  # Precedence: CLI (process-arguments below) > env (preserved in load-config)
  #             > file (.ver-bumprc) > default (apply-config-defaults).
  load-config
  apply-config-defaults

  # Process and prepare
  process-arguments "$@"
  check-dependencies
  check-commits-exist
  process-version

  check-branch-notexist
  check-tag-exists
  echo -e "\n${S_LIGHT}------${RESET}"

  # Update files
  do-packagefile-bump
  bump-json-files
  do-versionfile
  do-changelog
  do-branch
  do-commit
  do-tag
  do-push

  echo -e "\n${S_LIGHT}------${RESET}"
  log_success "$( capitalise "$( get-commit-msg )" )"
  log_success "Done!"
  echo
}

# Execute script when it is executed as a script, and when it is brought into the environment with source (so it can be tested)
# shellcheck disable=SC2128
if [[ "$0" = "$BASH_SOURCE" ]]; then
  source "$MODULE_DIR/lib/styles.sh" # only load when not sourced, for tests to work
  main "$@"
fi
