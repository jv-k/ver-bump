#!/usr/bin/env bats

# Regression coverage for #78.
#
# Tests source VerBump's libraries to unit-test functions, which brings in
# `fail` from lib/errors.sh (signature: `fail <exit-code> <msg> [<hint>]`).
# That shadows bats-support's `fail <message>` (used inside a test body to
# force a failure through bats' own reporter), so a deliberately-failing
# assertion in a sourcing test would invoke VerBump's exit-code machinery
# instead — garbling the failure output.
#
# test/test_helper.bash's setup() captures bats-support's fail as `bats_fail`
# immediately after bats-support loads, before any test can source VerBump's
# libs. This file proves the fix: `bats_fail` keeps working after VerBump's
# `fail` is sourced, VerBump's own `fail` keeps its exit-code contract via
# `run`, and the two coexist in the same test shell.

load 'test_helper'

@test "bats_fail: identical to bats-support's fail before any VerBump lib is sourced" {
  # Sanity check on the capture itself: at this point nothing has sourced
  # VerBump's lib/errors.sh yet, so `fail` is still bats-support's — the
  # captured `bats_fail` copy must match it body-for-body.
  assert_equal "$(declare -f bats_fail | sed '1s/^bats_fail /fail /')" "$(declare -f fail)"
}

@test "sourcing VerBump's lib/errors.sh shadows fail() but leaves bats_fail() untouched" {
  # Capture bats-support's fail BEFORE any VerBump lib is sourced — at this
  # point `fail` is still bats-support's. We compare against this captured
  # definition rather than matching any specific line of VerBump's fail, so
  # the test proves the *collision* without coupling to fail()'s internals: a
  # contract-preserving refactor of VerBump's fail must not break it.
  local support_fail support_fail_body
  support_fail="$(declare -f fail)"
  support_fail_body="$(declare -f fail | sed '1d')" # body only; name line differs

  source ${profile_script}

  # The shadow happened: fail's definition now DIFFERS from bats-support's.
  assert_not_equal "$(declare -f fail)" "$support_fail"

  # The capture survived: bats_fail's body still MATCHES bats-support's fail
  # (compare bodies — the `bats_fail`/`fail` name line necessarily differs).
  assert_equal "$(declare -f bats_fail | sed '1d')" "$support_fail_body"
}

@test "bats_fail: forces a bats-support-style failure through bats' reporter after VerBump libs are sourced" {
  source ${profile_script}

  # bats-support's fail() prints the message to stderr and returns 1 — it
  # never exits the process. That's the contract bats_fail must preserve.
  run bats_fail "forced failure for regression coverage"
  assert_equal "$status" 1
  assert_output --partial "forced failure for regression coverage"
}

@test "collision proof: a bare fail() call after sourcing is VerBump's and garbles a forced-failure message" {
  source ${profile_script}

  # This is the bug #78 describes: calling the bats-support idiom `fail
  # "<message>"` directly (instead of `bats_fail`) now hits VerBump's
  # `fail <code> <msg> [<hint>]`. The single string argument is treated as
  # the exit code, so bash's own `exit` builtin rejects it — the process
  # exits 2 with a bash usage error, not bats-support's clean status 1 +
  # message.
  run fail "would-be forced failure message"
  assert_not_equal "$status" 1
  assert_output --partial "numeric argument required"
}

@test "coexistence: VerBump's fail still enforces its exit-code contract via run" {
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
