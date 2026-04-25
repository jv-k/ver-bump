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

# Returns 0 if $1 looks like a SemVer 2.0 version (MAJOR.MINOR.PATCH with
# optional -prerelease and +build metadata). Uses the official regex from
# https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
is_semver() {
  [[ "$1" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(\.(0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*))*))?(\+([0-9a-zA-Z-]+(\.[0-9a-zA-Z-]+)*))?$ ]]
}

# Bump a SemVer prerelease version's trailing numeric counter.
# Examples:
#   1.2.3-dev.6         -> 1.2.3-dev.7
#   4.0.0-rc.9          -> 4.0.0-rc.10
#   1.0.0-alpha         -> 1.0.0-alpha.1   (no counter → append ".1")
#   2.1.0-beta.3+b.sha  -> 2.1.0-beta.4+b.sha   (build metadata preserved)
# If $1 isn't a prerelease (no "-"), echoes input unchanged and returns 1.
bump-prerelease() {
  local input="$1" base pre build=""
  # Split off build metadata (everything after '+')
  if [[ "$input" == *+* ]]; then
    build="+${input#*+}"
    input="${input%%+*}"
  fi
  if [[ "$input" != *-* ]]; then
    printf '%s' "${input}${build}"
    return 1
  fi
  base="${input%%-*}"
  pre="${input#*-}"

  local -a parts
  IFS='.' read -r -a parts <<< "$pre"
  local last_idx=$(( ${#parts[@]} - 1 ))
  local last="${parts[$last_idx]}"

  if is_number "$last"; then
    parts[last_idx]=$((last + 1))
  else
    # No numeric counter yet — start one at 1
    parts+=("1")
  fi

  local joined
  joined=$( IFS='.'; echo "${parts[*]}" )
  printf '%s' "${base}-${joined}${build}"
}

# Ensure required external tools are present before mutating the repo.
check-dependencies() {
  local tool missing=()
  for tool in git jq; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  if (( ${#missing[@]} )); then
    fail 3 \
      "Missing required tool(s): ${missing[*]}." \
      "Install the missing tool(s) (e.g. 'brew install ${missing[*]}' on macOS, or use your system package manager) and retry."
  fi
}
