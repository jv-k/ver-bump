#!/bin/bash
#  _ _  ___  ___       ___  _ _  __ __  ___
# | | || __>| . \ ___ | . >| | ||  \  \| . \
# | ' || _> |   /|___|| . \| ' ||     ||  _/
# |__/ |___>|_\_\     |___/\___/|_|_|_||_|
#
# Author:
#   John Valai <git@jvk.to>
# Homepage: 
#   https://github.com/jv-k/ver-bump
#
# Description:
#   An opinionated release tool for Git projects with a `package.json` —
#   primarily Node / JS / TS projects, but also usable for any SemVer repo:
#   `--source <file>.json` swaps the version source / bump target, and with
#   no version file at all the current version is derived from the latest
#   release tag. It automates the mechanical
#   parts of cutting a release (SemVer bump, CHANGELOG, release branch,
#   tag, push), driven by Conventional Commits, and leaves the integration
#   step (merge back to `develop` / `main`) to the human.
#

# shellcheck disable=SC1090,SC2034,SC1017
true

MODULE_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

source "$MODULE_DIR/lib/icons.sh"
source "$MODULE_DIR/lib/errors.sh"
source "$MODULE_DIR/lib/ui.sh"
source "$MODULE_DIR/lib/validate.sh"
source "$MODULE_DIR/lib/json.sh"

source "$MODULE_DIR/lib/usage.sh"
source "$MODULE_DIR/lib/completions.sh"
source "$MODULE_DIR/lib/args.sh"

source "$MODULE_DIR/lib/git-checks.sh"
source "$MODULE_DIR/lib/version.sh"
source "$MODULE_DIR/lib/changelog.sh"
source "$MODULE_DIR/lib/git-actions.sh"

source "$MODULE_DIR/lib/config.sh"

NOW="$(date +%F)"

V_SUGGEST="0.1.0" # This is suggested in case VERSION file or user supplied version via -v is missing
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
: "${CHANGELOG_STYLE:=flat}" # CHANGELOG.md style: flat (1.x-identical, default) | grouped
: "${SOURCE_FILE:=package.json}" # Version source + primary bump target (R-SRC-1/5)

# Internal alias for the resolved version source. Everything downstream reads
# VER_FILE; main() re-derives it from SOURCE_FILE once config + CLI are final.
VER_FILE="$SOURCE_FILE"

JSON_FILES=()

# ── Initiate Script ────────────────────────────────────────────────────

main() {
  # Load .ver-bumprc (if any) and apply defaults BEFORE parsing CLI args.
  # Precedence: CLI (process-arguments below) > env (preserved in load-config)
  #             > file (.ver-bumprc) > default (apply-config-defaults).
  load-config
  apply-config-defaults

  # Process and prepare
  process-arguments "$@"
  # SOURCE_FILE is final here (CLI --source > env > .ver-bumprc > default);
  # point the internal VER_FILE alias at it (R-SRC-1/5).
  VER_FILE="$SOURCE_FILE"
  check-dependencies
  check-release-deps

  section "Verify"
  check-commits-exist
  check-worktree-clean
  check-release-branch
  check-remote-sync # must precede check-tag-exists so remote tags are visible
  process-version
  check-releasable-commits # needs V_PREV + TAG_PREFIX, so after process-version
  check-branch-notexist
  check-tag-exists
  check-pr-deps

  section "Release"
  do-packagefile-bump
  bump-json-files
  do-versionfile
  do-changelog
  do-branch
  do-commit
  do-tag
  do-push
  do-pr
  do-github-release

  section "Done"
  log_success "$( capitalise "$( get-commit-msg )" )"
  echo
}

# Execute script when it is executed as a script, and when it is brought into the environment with source (so it can be tested)
# shellcheck disable=SC2128
if [[ "$0" = "$BASH_SOURCE" ]]; then
  source "$MODULE_DIR/lib/styles.sh" # only load when not sourced, for tests to work
  main "$@"
fi
