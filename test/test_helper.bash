#!/usr/bin/env bash

# Shared setup/teardown/helpers for all VerBump .bats files.
#
# Each .bats file begins with:
#
#   load 'test_helper'
#
# which sources this file and pulls in setup(), teardown(), and all helpers
# below. Keep this file behaviour-identical to the pre-split monolith:
# any change here changes every test file.

setup() {
  load './test_helper/bats-support/load'
  load './test_helper/bats-assert/load'

  # Capture bats-support's fail() under a test-only name right after it's
  # loaded, before any test can `source ${profile_script}` and pull in
  # VerBump's own `fail` from lib/errors.sh (signature: `fail <code> <msg>
  # [<hint>]`), which would otherwise shadow bats-support's `fail <message>`
  # (used to force a failure through bats's reporter). Tests that need to
  # force a failure call `bats_fail "message"` instead of bare `fail`, so the
  # forced-failure path keeps working regardless of load order within the
  # test body. See docs/CODE_STYLE.md §Testing.
  eval "bats_fail() $(declare -f fail | sed '1d')"

  repo_dir=$PWD
  profile_script="$repo_dir/verbump.sh"

  F_TEMPS=()
  TEST_F_VER=
  TEST_F_INPUT=
  CLEANUP_CMDS=()
}

teardown() {
  run_cleanup_cmds

  unset F_TEMPS
  unset TEST_F_VER
  unset TEST_V_PREV
  unset TEST_F_INPUT
  unset VER_FILE
  unset CLEANUP_CMDS
}

run_cleanup_cmds() {
  for F in "${F_TEMPS[@]}"; do
    [ -f $F ] && rm -f $F && git reset -- $F >&2
  done

  for (( i = 0; i < ${#CLEANUP_CMDS[@]} ; i++ )); do
    # Run each command in array
    eval "${CLEANUP_CMDS[$i]}"
  done
}

get_help_msg() {
  ${profile_script} -h 2>&1
}

create_ver_file() {
  # Create the scratch JSON in $PWD so tests that cd into scratch_repo don't
  # leak files into the real project checkout. Callers are expected to have
  # cd'd into their desired working directory before invoking.
  F_TEMPS+=($(mktemp ${PWD}/XXXXXXXXXXXXXXXXXXXX)) # push
  F_TMP=${F_TEMPS[${#F_TEMPS[@]}-1]} # last pushed
  printf "{ \n\"version\": \"${V_TEST}\"\n }" > $F_TMP
  VER_FILE=$F_TMP # set value used in test target
}

jsonfile_get_ver() {
  sed -n 's/.*"version":.*"\(.*\)"\(,\)\{0,1\}/\1/p' $1
}

# Strip ANSI CSI sequences from $output in place, so assert_output --partial
# can match plain narrative substrings regardless of inline colour escapes.
# Call immediately after `run <cmd>` in tests that assert on user-facing text.
strip_ansi_output() {
  # shellcheck disable=SC2001
  output=$(printf '%s' "$output" | sed $'s/\x1b\\[[0-9;]*m//g')
  lines=()
  local _line
  while IFS= read -r _line; do lines+=("$_line"); done <<< "$output"
}

# Scratch repo whose package.json version (1.2.3) is already tagged, plus
# one releasable feat: commit — the conventional-commits suggestion is a
# minor bump (1.2.3 -> 1.3.0). Shared by quiet.bats / dry-run-json.bats.
releasable_repo() {
  released_repo
  git commit -q --allow-empty -m "feat: something new"
}

# Scratch repo where package.json's version (1.2.3) is already tagged at
# HEAD: zero commits since the previous tag — the no-op state (#60).
# Shared by no-release.bats / quiet.bats / dry-run-json.bats.
released_repo() {
  local repo
  repo="$(scratch_repo)"
  cd "$repo" || exit 1
  printf '{ "version": "1.2.3" }\n' > package.json
  git add package.json && git commit -qm "chore: bumped to 1.2.3"
  git tag -a v1.2.3 -m "v1.2.3"
}

# Two-package monorepo (#96, spec #128): pkg-a at 1.2.3 and pkg-b at 0.4.0,
# each with a per-package .verbumprc carrying its TAG_PREFIX, baseline tags,
# then one feat(pkg-b) and one fix(pkg-a) commit — the canonical layout from
# the #118 audit. A bare "remote" is wired up as origin so full (non-dry)
# runs can push with -p origin. Leaves $PWD at the repo root; tests cd into
# packages/* themselves (the blessed package-cwd flow). Shared by
# monorepo-scope.bats / monorepo-preflights.bats.
monorepo_fixture() {
  local repo remote
  repo="$(scratch_repo)"
  remote=$(mktemp -d)
  CLEANUP_CMDS+=("rm -rf ${remote}")
  git init -q --bare "$remote"
  cd "$repo" || exit 1
  git remote add origin "$remote"
  mkdir -p packages/pkg-a packages/pkg-b
  printf '{ "version": "1.2.3" }\n' > packages/pkg-a/package.json
  printf '{ "version": "0.4.0" }\n' > packages/pkg-b/package.json
  printf 'TAG_PREFIX=pkg-a-v\n' > packages/pkg-a/.verbumprc
  printf 'TAG_PREFIX=pkg-b-v\n' > packages/pkg-b/.verbumprc
  # load-config refuses group/world-writable rc files — pin the mode so the
  # fixture can't inherit a permissive umask from the host.
  chmod 644 packages/pkg-a/.verbumprc packages/pkg-b/.verbumprc
  git add packages
  git commit -qm "chore: scaffold packages"
  git tag -a pkg-a-v1.2.3 -m "pkg-a-v1.2.3"
  git tag -a pkg-b-v0.4.0 -m "pkg-b-v0.4.0"
  echo "widget" > packages/pkg-b/widget.txt
  git add packages/pkg-b/widget.txt
  git commit -qm "feat(pkg-b): add widget"
  echo "rounding" > packages/pkg-a/rounding.txt
  git add packages/pkg-a/rounding.txt
  git commit -qm "fix(pkg-a): correct rounding"
}

# Make a throwaway git repo under /tmp and echo its path. Adds cleanup.
# Initial state: one empty commit on the default branch. No tags.
scratch_repo() {
  local dir
  dir=$(mktemp -d)
  CLEANUP_CMDS+=("rm -rf ${dir}")
  (
    cd "$dir" || exit 1
    git init -q -b main 2>/dev/null || git init -q
    git config user.email "test@example.com"
    git config user.name  "Test User"
    git commit --allow-empty -qm "initial"
  )
  echo "$dir"
}
