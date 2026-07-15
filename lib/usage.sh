#!/bin/bash

# shellcheck disable=SC2288
true

# Show --help.
usage() {
  local SCRIPT_VER SCRIPT_NAME SCRIPT_AUTH SCRIPT_HOME env_var env_var_val
  local env_vars=( SCRIPT_VER SCRIPT_NAME SCRIPT_AUTH SCRIPT_HOME )

  if command -v jq >/dev/null 2>&1; then
    SCRIPT_VER=$(  jq -r '.version  // ""'         "$MODULE_DIR/package.json" )
    SCRIPT_NAME=$( jq -r '.name     // "ver-bump"' "$MODULE_DIR/package.json" )
    SCRIPT_AUTH=$( jq -r '.author   // ""'         "$MODULE_DIR/package.json" )
    SCRIPT_HOME=$( jq -r '.homepage // ""'         "$MODULE_DIR/package.json" )
  else
    # Fallback: grep + trim (works without jq for --help alone)
    SCRIPT_VER=$(  cd "$MODULE_DIR" && grep version  package.json | head -1 )
    SCRIPT_NAME=$( cd "$MODULE_DIR" && grep name     package.json | head -1 )
    SCRIPT_AUTH=$( cd "$MODULE_DIR" && grep author   package.json | head -1 )
    SCRIPT_HOME=$( cd "$MODULE_DIR" && grep homepage package.json | head -1 | sed -ne 's/.*\(http[^"]*\).*/\1/p' )

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

  # Branded header pill + author/homepage bullets + dim tagline.
  # Green inverse pill for name + version, blank line, then author/homepage bullets and dim tagline.
  printf '\n %b %s v%s %b\n\n' "${S_HDR_SUB-}" "${SCRIPT_NAME}" "${SCRIPT_VER}" "${S_HDR_END-}"
  printf ' %b%s%b Author:   %s\n'   "${S_BULLET-}" "${I_BULLET-}" "${RESET-}" "${SCRIPT_AUTH}"
  printf ' %b%s%b Homepage: %s\n\n' "${S_BULLET-}" "${I_BULLET-}" "${RESET-}" "${SCRIPT_HOME}"
  printf '  %bAn opinionated release tool for Git projects with a package.json — automates SemVer%b\n' \
    "${S_DIM-}" "${RESET-}"
  printf '  %bbump, CHANGELOG, tag, and push, driven by Conventional Commits.%b\n' \
    "${S_DIM-}" "${RESET-}"

  # USAGE section pill
  printf '\n%bUSAGE %b\n' "${S_HDR_CYAN-}" "${S_HDR_END-}"
  printf '  %b%s%b [-v <version>] [-m <message>] [-f <file.json>]... [-p <remote>] [-t <tag-prefix>] [-B <branch-prefix>] [-d] [-n] [-b] [-c] [-l] [-h]\n' \
    "${BOLD-}" "${SCRIPT_NAME}" "${RESET-}"
  printf '  %b%s%b [--branch] [--pr] [--base <branch>] [--major | --minor | --patch] [--release] [--completions <shell>] [--install-completions[=<shell>]] [--about]\n' \
    "${BOLD-}" "${SCRIPT_NAME}" "${RESET-}"

  # Column width for label + 2-space gutter. Longest label is
  # "  --install-completions [=<shell>]" = 34 chars. OPT_COL 40 gives a
  # comfortable description column start.
  local OPT_COL=40

  # print-opt-row <short> <long> <arg-or-empty> <description>
  # 2-space left gutter on every row. Flag names are bold + default colour
  # (no red/pink accent). Long-only rows align under the long-flag column.
  print-opt-row() {
    local short="$1" long="$2" arg="$3" desc="$4"
    local plain label pad head_plain head_label
    if [ -n "$short" ]; then
      head_plain="  ${short}, ${long}"
      head_label="  ${BOLD-}${short}${RESET-}, ${BOLD-}${long}${RESET-}"
    else
      # Align long-only rows under the long-flag column: 2-space gutter + "-x, " = 6 chars indent.
      head_plain="      ${long}"
      head_label="      ${BOLD-}${long}${RESET-}"
    fi
    if [ -n "$arg" ]; then
      plain="${head_plain} ${arg}"
      label="${head_label} ${arg}"
    else
      plain="${head_plain}"
      label="${head_label}"
    fi
    if (( ${#plain} >= OPT_COL )); then
      pad=" "
    else
      printf -v pad '%*s' $((OPT_COL - ${#plain})) ''
    fi
    echo -e "${label}${pad}${desc}"
  }

  # print-opt-cont <text> — continuation row, aligned under the description column
  print-opt-cont() {
    printf '%*s' "$OPT_COL" ''
    echo -e "$1"
  }

  # print-example-row <command> <description> — 2-space gutter, bold command,
  # description column aligned to OPT_COL. No "-x, --long" pattern.
  print-example-row() {
    local cmd="$1" desc="$2"
    local plain pad
    plain="  ${cmd}"
    if (( ${#plain} >= OPT_COL )); then
      pad=" "
    else
      printf -v pad '%*s' $((OPT_COL - ${#plain})) ''
    fi
    printf '  %b%s%b%s%s\n' "${BOLD-}" "${cmd}" "${RESET-}" "${pad# }" "${desc}"
  }

  # OPTIONS section pill (the "long forms accept ..." note moved to the bottom).
  printf '\n%bOPTIONS %b\n' "${S_HDR_CYAN-}" "${S_HDR_END-}"
  print-opt-row "-v" "--version"       "[<version>]" "Without a value: print tool version and exit. With a value: set manual SemVer."
  print-opt-row "-m" "--message"       "<message>"   "Custom annotated-tag release message."
  print-opt-row "-f" "--file"          "<file.json>" "Also bump \"version\" in this JSON file. Repeatable:"
  print-opt-cont "ver-bump -f src/plugin/package.json -f composer.json"
  print-opt-row "-p" "--push"          "<remote>"    "Push release branch + tag to <remote> at end of run."
  print-opt-row "-t" "--tag-prefix"    "<prefix>"    "Override tag prefix (default: v)."
  print-opt-row "-B" "--branch-prefix" "<prefix>"    "Override branch prefix (default: release-)."
  print-opt-row "-d" "--dry-run"       ""            "Dry-run: print every side-effect without executing."
  print-opt-row "-n" "--no-commit"     ""            "Disable commit (and tag + push) after bumping files."
  print-opt-row "-b" "--no-branch"     ""            "(deprecated) Tag-in-place is the default now; this is a no-op."
  print-opt-row "-c" "--no-changelog"  ""            "Disable updating CHANGELOG.md automatically."
  print-opt-row "-l" "--pause-changelog" ""          "Pause before commit so CHANGELOG.md can be edited."
  print-opt-row "-h" "--help"          ""            "Show this help message."
  print-opt-row "-y" "--yes"           ""            "Skip interactive confirmation prompts."
  print-opt-row ""   "--undo"          "[<version>]" "Locally delete release-X.Y.Z + tag vX.Y.Z (refuses if pushed/dirty)."
  print-opt-row ""   "--major"              ""            "Force a major bump from the current version (mutually exclusive)."
  print-opt-row ""   "--minor"              ""            "Force a minor bump from the current version (mutually exclusive)."
  print-opt-row ""   "--patch"              ""            "Force a patch bump from the current version (mutually exclusive)."
  print-opt-row ""   "--allow-dirty"        ""            "Skip the clean-working-tree check (untracked files never trigger it)."
  print-opt-row ""   "--allow-empty"        ""            "Release even with no new commits since the previous tag."
  print-opt-row ""   "--no-fetch"           ""            "Skip the remote-sync preflight (no fetch / behind-upstream check)."
  print-opt-row ""   "--no-hooks"           ""            "Skip the PRE_BUMP_CMD / POST_TAG_CMD release hooks for this run."
  print-opt-row ""   "--branch"             ""            "Cut a release-x.x.x branch (pre-2.0 default); otherwise tag in place."
  print-opt-row ""   "--pr"                 ""            "Branch + push + open a release PR via 'gh' (GitHub-only; implies push to origin)."
  print-opt-row ""   "--base"               "<branch>"    "Base branch for --pr (GitHub-only; default: the branch you ran ver-bump from)."
  print-opt-row ""   "--release"            ""            "Publish a GitHub release for the new tag (GitHub-only; requires -p, uses 'gh')."
  print-opt-row ""   "--about"              ""            "Print name, version, author, and homepage; then exit."
  print-opt-row ""   "--completions"        "<shell>"     "Emit completion script for bash, zsh, or fish."
  print-opt-row ""   "--install-completions" "[=<shell>]" "Install completion script (auto-detects shell)."

  # EXAMPLES section pill
  printf '\n%bEXAMPLES %b\n' "${S_HDR_CYAN-}" "${S_HDR_END-}"
  print-example-row "${SCRIPT_NAME}"                       "Interactive — reads commits, suggests bump, prompts."
  print-example-row "${SCRIPT_NAME} -v 2.0.0"              "Non-interactive, explicit version."
  print-example-row "${SCRIPT_NAME} --dry-run"             "Preview every side-effect without executing."
  print-example-row "${SCRIPT_NAME} -p origin"             "Push the release branch + tag when done."
  print-example-row "${SCRIPT_NAME} --pr"                  "Branch, push, and open a release PR (needs gh)."
  print-example-row "${SCRIPT_NAME} -t release/"           "Use a custom tag prefix (e.g. release/1.2.3)."
  print-example-row "${SCRIPT_NAME} -f composer.json"      "Also bump version in an extra JSON file."
  print-example-row "${SCRIPT_NAME} --about"               "Show branded version info."
  print-example-row "${SCRIPT_NAME} --install-completions" "Install shell completions (auto-detects shell)."

  printf '\n  %b(long forms accept --name value or --name=value)%b\n\n' "${S_DIM-}" "${RESET-}"
}
