#!/usr/bin/env bats

# do-changelog tests. Migrated verbatim from the monolithic ver-bump.bats;
# shared setup lives in test/test_helper.bash.

load 'test_helper'

@test "do-changelog: can create a CHANGELOG.md" {
  source ${profile_script}

  V_PREV="0.1.0" # guaranteed: commits available
  V_NEW="1.0.0"
  local F_CL="CHANGELOG.md"

  # backup present
  [ -f "$F_CL" ] && mv "$F_CL" "${F_CL}.backup" && touch "$F_CL"
  CLEANUP_CMDS+=("rm ${F_CL} && mv ${F_CL}.backup ${F_CL}")

  run do-changelog <<< ""
  assert_success
  assert_output -p "Updated [CHANGELOG.md] file"

  # Test CL.md actually contains the line
  grep -F "updated ${F_CL}, bumped ${V_PREV} -> ${V_NEW}" $F_CL
  assert_success
}
