#!/usr/bin/env bats

# Regression coverage for #78.
#
# Tests source ver-bump's libraries to unit-test functions, which brings in
# `fail` from lib/errors.sh (signature: `fail <exit-code> <msg> [<hint>]`).
# That shadows bats-support's `fail <message>` (used inside a test body to
# force a failure through bats' own reporter), so a deliberately-failing
# assertion in a sourcing test would invoke ver-bump's exit-code machinery
# instead — garbling the failure output.
#
# test/test_helper.bash's setup() captures bats-support's fail as `bats_fail`
# immediately after bats-support loads, before any test can source ver-bump's
# libs. This file proves the fix: `bats_fail` keeps working after ver-bump's
# `fail` is sourced, ver-bump's own `fail` keeps its exit-code contract via
# `run`, and the two coexist in the same test shell.

load 'test_helper'

@test "bats_fail: identical to bats-support's fail before any ver-bump lib is sourced" {
  # Sanity check on the capture itself: at this point nothing has sourced
  # ver-bump's lib/errors.sh yet, so `fail` is still bats-support's — the
  # captured `bats_fail` copy must match it body-for-body.
  assert_equal "$(declare -f bats_fail | sed '1s/^bats_fail /fail /')" "$(declare -f fail)"
}

@test "sourcing ver-bump's lib/errors.sh shadows fail() but leaves bats_fail() untouched" {
  local bats_fail_before
  bats_fail_before="$(declare -f bats_fail)"

  source ${profile_script}

  # `fail` in this shell is now ver-bump's exit-code helper (lib/errors.sh) ...
  local vb_fail_body
  vb_fail_body="$(declare -f fail)"
  [[ "$vb_fail_body" == *'exit "$code"'* ]]

  # ... while the captured bats_fail is byte-for-byte unchanged.
  assert_equal "$(declare -f bats_fail)" "$bats_fail_before"
}

@test "bats_fail: forces a bats-support-style failure through bats' reporter after ver-bump libs are sourced" {
  source ${profile_script}

  # bats-support's fail() prints the message to stderr and returns 1 — it
  # never exits the process. That's the contract bats_fail must preserve.
  run bats_fail "forced failure for regression coverage"
  assert_equal "$status" 1
  assert_output --partial "forced failure for regression coverage"
}

@test "collision proof: a bare fail() call after sourcing is ver-bump's and garbles a forced-failure message" {
  source ${profile_script}

  # This is the bug #78 describes: calling the bats-support idiom `fail
  # "<message>"` directly (instead of `bats_fail`) now hits ver-bump's
  # `fail <code> <msg> [<hint>]`. The single string argument is treated as
  # the exit code, so bash's own `exit` builtin rejects it — the process
  # exits 2 with a bash usage error, not bats-support's clean status 1 +
  # message.
  run fail "would-be forced failure message"
  assert_not_equal "$status" 1
  assert_output --partial "numeric argument required"
}

@test "coexistence: ver-bump's fail still enforces its exit-code contract via run" {
  source ${profile_script}

  run fail 3 "precondition failed" "a helpful hint"
  assert_failure 3
  assert_output --partial "Error:"
  assert_output --partial "precondition failed"
  assert_output --partial "Hint: a helpful hint"

  # bats_fail is unaffected by the run above — still bats-support's helper.
  run bats_fail "second forced failure in the same test"
  assert_equal "$status" 1
  assert_output --partial "second forced failure in the same test"
}
