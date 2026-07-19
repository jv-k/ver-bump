#!/bin/bash

# shellcheck disable=SC2288
true

# fail <exit_code> <message> [hint]
#   Writes a red ERROR header pill to stderr with the bold message flush on
#   the next line, optionally followed by a blank line, a gray HINT pill, and
#   the dim hint text (also flush), then exits with <exit_code>. The blank
#   line sets the actionable hint apart from the error message. Pills follow
#   the same on-their-own-line convention as lib/ui.sh prompt pills.
#
# Exit code convention (see README / v2.0 plan §1.3):
#   0  success
#   1  generic error
#   2  usage / arg-parse error
#   3  precondition (dirty tree, missing tag, SemVer parse failure,
#                    missing package.json, missing dependency like git/jq)
#   4  hook failure (PRE_BUMP_CMD / POST_TAG_CMD exited non-zero, R-HOOK-1/2)
#   5  user abort (declined prompt)
fail() {
  local code=$1
  local msg=$2
  local hint=${3-}
  printf '\n%b ERROR %b\n%b%s%b\n' "${S_HDR_RED-}" "${S_HDR_END-}" "${S_NORM-}" "$msg" "${RESET-}" >&2
  if [ -n "$hint" ]; then
    printf '\n%b HINT %b\n%b%s%b\n' "${S_HDR_GRAY-}" "${S_HDR_END-}" "${S_LIGHT-}" "$hint" "${RESET-}" >&2
  fi
  exit "$code"
}
