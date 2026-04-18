#!/usr/bin/env bash

# Shared setup/teardown/helpers for all ver-bump .bats files.
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

  repo_dir=$PWD
  profile_script="$repo_dir/ver-bump.sh"

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
  ${profile_script} -h | grep "This script automates"
}

create_ver_file() {
  F_TEMPS+=($(mktemp ${repo_dir}/XXXXXXXXXXXXXXXXXXXX)) # push
  F_TMP=${F_TEMPS[${#F_TEMPS[@]}-1]} # last pushed
  printf "{ \n\"version\": \"${V_TEST}\"\n }" > $F_TMP
  VER_FILE=$F_TMP # set value used in test target
}

jsonfile_get_ver() {
  sed -n 's/.*"version":.*"\(.*\)"\(,\)\{0,1\}/\1/p' $1
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
