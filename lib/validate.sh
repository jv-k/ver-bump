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

# Force a major / minor / patch bump on a SemVer string, dropping any
# prerelease (-dev.N) and build (+sha) metadata.
# Examples:
#   force-bump "1.2.3"        major  -> 2.0.0
#   force-bump "1.2.3"        minor  -> 1.3.0
#   force-bump "1.2.3"        patch  -> 1.2.4
#   force-bump "1.2.3-dev.5"  patch  -> 1.2.4   (prerelease dropped, patch bumped)
#   force-bump "1.2.3-rc.1"   minor  -> 1.3.0
#   force-bump "1.2.3+sha"    major  -> 2.0.0   (build metadata dropped)
# Caller is responsible for passing a SemVer-valid $1; assumes is_semver "$1".
force-bump() {
  local version="$1" level="$2" stripped major minor patch
  stripped="${version%%+*}"   # strip build metadata
  stripped="${stripped%%-*}"  # strip prerelease
  IFS='.' read -r major minor patch <<< "$stripped"
  case "$level" in
    major) major=$((major + 1)); minor=0; patch=0 ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    patch) patch=$((patch + 1)) ;;
    *) return 1 ;;
  esac
  printf '%s.%s.%s' "$major" "$minor" "$patch"
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
