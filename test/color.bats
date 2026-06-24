#!/usr/bin/env bats

# Colour gate (lib/styles.sh). Precedence: NO_COLOR off > CLICOLOR_FORCE /
# FORCE_COLOR on > TTY on > otherwise off. The force vars let screenshot
# capture and `cmd | less -R` get real colour without a PTY.

load 'test_helper'

has_ansi() { printf '%s' "$1" | LC_ALL=C grep -q $'\033'; }

@test "color: piped output has no ANSI by default (non-TTY)" {
  run ${profile_script} --about
  assert_success
  ! has_ansi "$output"
}

@test "color: CLICOLOR_FORCE=1 forces ANSI even when piped" {
  run env CLICOLOR_FORCE=1 ${profile_script} --about
  assert_success
  has_ansi "$output"
}

@test "color: FORCE_COLOR=1 forces ANSI even when piped" {
  run env FORCE_COLOR=1 ${profile_script} --about
  assert_success
  has_ansi "$output"
}

@test "color: NO_COLOR wins over CLICOLOR_FORCE" {
  run env NO_COLOR=1 CLICOLOR_FORCE=1 ${profile_script} --about
  assert_success
  ! has_ansi "$output"
}
