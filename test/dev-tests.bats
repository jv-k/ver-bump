#!/usr/bin/env bats

# UNIT TESTS for VER-BUMP

# Testing everything that could possibly break 🤡

# Note: The RUN helper executes its argument(s) in a subshell,
# so if writing tests against environmental side-effects like a
# variable’s value being changed, these changes will not persist
# after run completes.

setup() {
  load './test_helper/bats-support/load'
  load './test_helper/bats-assert/load'
  load './test_helper/bats-mocks/stub'

  repo_dir=$PWD
  profile_script="$repo_dir/ver-bump.sh"

  F_TEMPS=()
  TEST_F_VER=
  TEST_F_INPUT=
  CLEANUP_CMDS=()

  # set_mocks
}

teardown() {
  run_cleanup_cmds
  # unset_mocks
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

set_mocks() {
  stub git rev-parse\
      "--verify release-0.1.0 : echo 'hey hey'"
}

unset_mocks() {
  unstub git
}

@test "check-branch-exist: can detect branch exists" {
  # skip
  source ${profile_script}

  local V_NEW="123.456.7"
  # create test branch
  git branch "${REL_PREFIX}${V_NEW}"
  CLEANUP_CMDS+=("git branch -D ${REL_PREFIX}${V_NEW} --force")

  run check-branch-exist
  assert_failure
}

@test "check-branch-exist: can confirm release branch doesn't already exist" {
  source ${profile_script}

  local V_NEW="123.456.78338834"

  # git branch is stubbed, so expect
  run check-branch-notexist
  assert_success
}

@test "do-branch: can create a release branch" {
  source ${profile_script}

  local V_NEW="123.456.7"
  local CURR_BRANCH=$( git rev-parse --abbrev-ref HEAD )
  CLEANUP_CMDS+=("git checkout ${CURR_BRANCH} && git branch -D ${REL_PREFIX}${V_NEW} --force")

  run do-branch
  assert_success
}

@test "do-commit: can create a commit" {

}

do-pushy() {
  PUSH_MSG=`git push "${PUSH_DEST}" v"$V_NEW" 2>&1` # Push new tag

}

@test "do-push: can push a release branch" {
  skip
  source ${profile_script}

  # create clean-up cmds
  # create dummy file
  # stage file
  # create branch
  # push to branch

  local V_NEW="123.456.7"
  local CURR_BRANCH=$( git rev-parse --abbrev-ref HEAD )
  CLEANUP_CMDS+=("git checkout ${CURR_BRANCH} && git branch -D ${REL_PREFIX}${V_NEW} --force")
  run do-branch
  assert_success

  $DUMMY_FILE=($(mktemp ${repo_dir}/XXXXXXXXXXXXXXXXXXXX))
  CLEANUP_CMDS+=("rm ${DUMMY_FILE}")
  touch $DUMMY_FILE
  git add $DUMMY_FILE

  run do-push
  assert_output
  # echo -e "\n${S_NOTICE}Pushing files + tags to <${S_NORM}${PUSH_DEST}${S_NOTICE}>..."
  # PUSH_MSG=`git push "${PUSH_DEST}" v"$V_NEW" 2>&1` # Push new tag
  # assert_output "Warning"
}
