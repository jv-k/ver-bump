#!/usr/bin/env bats

# End-to-end behaviour of TAG_PREFIX / REL_PREFIX overrides across do-tag,
# do-branch, check-tag-exists, do-changelog. Migrated verbatim from the
# monolithic ver-bump.bats; shared setup lives in test/test_helper.bash.

load 'test_helper'

@test "prefix override: do-tag uses TAG_PREFIX" {
  source ${profile_script}
  cd "$(scratch_repo)"

  TAG_PREFIX="rel/"
  V_NEW="1.2.3"
  REL_NOTE=

  run do-tag
  assert_success

  run git tag -l
  assert_output "rel/1.2.3"
}

@test "prefix override: check-tag-exists uses TAG_PREFIX" {
  source ${profile_script}
  cd "$(scratch_repo)"

  TAG_PREFIX="rel/"
  V_NEW="1.2.3"
  git tag -a "rel/1.2.3" -m "tag"

  run check-tag-exists
  assert_output --partial "A release with that tag"
}

@test "prefix override: do-branch uses REL_PREFIX" {
  source ${profile_script}
  cd "$(scratch_repo)"

  REL_PREFIX="hotfix-"
  V_NEW="9.9.9"

  run do-branch
  assert_success

  run git rev-parse --abbrev-ref HEAD
  assert_output "hotfix-9.9.9"
}

@test "prefix override: do-changelog uses TAG_PREFIX when finding previous tag" {
  source ${profile_script}
  cd "$(scratch_repo)"

  TAG_PREFIX="rel/"
  git tag -a "rel/0.1.0" -m "tag"
  git commit --allow-empty -qm "feat: after previous tag"

  V_PREV="0.1.0"
  V_NEW="0.2.0"

  run do-changelog <<< ""
  strip_ansi_output
  assert_success
  assert_output --partial "Created [CHANGELOG.md]"
  grep -F "feat: after previous tag" CHANGELOG.md
}
