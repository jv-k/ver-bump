#!/usr/bin/env bats

# do-changelog tests. Shared setup lives in test/test_helper.bash.
#
# All tests run inside a fresh scratch_repo — the real project checkout
# would otherwise have its CHANGELOG.md rewritten mid-test.

load 'test_helper'

@test "do-changelog: can create a CHANGELOG.md (append to existing)" {
  source ${profile_script}
  cd "$(scratch_repo)"

  V_PREV="0.1.0"
  V_NEW="1.0.0"

  # seed a pre-existing CHANGELOG so the "append" branch is exercised
  printf '## 0.0.1 (2020-01-01)\n- chore: seed\n\n' > CHANGELOG.md

  run do-changelog <<< ""
  strip_ansi_output
  assert_success
  assert_output -p "Updated [CHANGELOG.md]"

  grep -F "updated CHANGELOG.md, bumped ${V_PREV} -> ${V_NEW}" CHANGELOG.md
  assert_success
  # The older entry should still be present — we appended, not overwrote.
  grep -F "## 0.0.1" CHANGELOG.md
  assert_success
}

# N3: first-ever CHANGELOG.md creation — no pre-existing file ###############

@test "do-changelog: creates a fresh CHANGELOG.md when one doesn't exist" {
  source ${profile_script}
  cd "$(scratch_repo)"

  V_PREV="0.1.0"
  V_NEW="1.0.0"

  [ ! -f CHANGELOG.md ]

  run do-changelog <<< ""
  strip_ansi_output
  assert_success
  assert_output -p "Created [CHANGELOG.md]"

  # File should now exist with the new version heading as its first entry.
  [ -f CHANGELOG.md ]
  grep -F "## ${V_NEW}" CHANGELOG.md
  assert_success
  grep -F "bumped ${V_PREV} -> ${V_NEW}" CHANGELOG.md
  assert_success
}

# N3: no-prev-tag range — when V_PREV has no tag, list every reachable commit #

@test "do-changelog: uses full history when no tag exists for V_PREV" {
  source ${profile_script}
  cd "$(scratch_repo)"

  # Add a couple of tracked commits on top of the scratch_repo's initial commit.
  git commit --allow-empty -qm "feat: first tagged change"
  git commit --allow-empty -qm "fix: second tagged change"

  V_PREV="0.1.0"   # intentionally NO v0.1.0 tag in this repo
  V_NEW="1.0.0"

  # Sanity check: the tag really doesn't exist; this drives the empty-RANGE
  # branch in do-changelog (which makes `git log` list everything).
  [ -z "$(git tag -l "v${V_PREV}")" ]

  run do-changelog <<< ""
  strip_ansi_output
  assert_success

  grep -F "feat: first tagged change" CHANGELOG.md
  assert_success
  grep -F "fix: second tagged change" CHANGELOG.md
  assert_success
}
