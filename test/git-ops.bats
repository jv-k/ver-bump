#!/usr/bin/env bats

# Git-side operations: do-branch, do-tag, and their preflight checks
# (check-branch-notexist, check-tag-exists). Migrated verbatim from the
# monolithic ver-bump.bats; shared setup lives in test/test_helper.bash.

load 'test_helper'

@test "check-branch-notexist: can detect branch DOES exist" {
  source ${profile_script}

  local V_NEW="123.456.7"
  # create test branch
  git branch "${REL_PREFIX}${V_NEW}"
  CLEANUP_CMDS+=("git branch -D ${REL_PREFIX}${V_NEW} --force")

  run check-branch-notexist
  assert_failure
}

@test "check-branch-notexist: can confirm branch DOES'NT exist" {
  source ${profile_script}

  local V_NEW="123.456.78338834"

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

@test "do-tag: create a tag" {
  source ${profile_script}
  V_NEW="35.12.5"
  REL_NOTE=
  CLEANUP_CMDS+=("git tag -d v${V_NEW}")

  run do-tag
  assert_success --partial "Added GIT tag"
}

@test "check-tag-exists: check doesn't exist" {
  source ${profile_script}
  V_NEW="35.12.5"
  REL_NOTE=

  run check-tag-exists
  assert_success
}

@test "check-tag-exists: check it exists" {
  source ${profile_script}
  V_NEW="35.12.5"
  REL_NOTE=
  CLEANUP_CMDS+=("git tag -d v${V_NEW}")

  # run do-tag
  git tag -a v${V_NEW} -m "Test tag"

  run check-tag-exists
  assert_output --partial "Error: A release with that tag"
}
