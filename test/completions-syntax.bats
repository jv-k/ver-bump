#!/usr/bin/env bats

# R-COMP-1: an emitted completion script must be syntactically valid for its
# target shell. test/args.bats proves the CONTENT (substrings like `#compdef`,
# `_arguments`, `complete -c`); these tests prove the emitted script actually
# PARSES under each shell's own syntax checker, so a future edit to an emitter
# that breaks quoting fails CI instead of shipping a broken completion.

load 'test_helper'

@test "completions: bash output passes 'bash -n'" {
  run bash -c "${profile_script} --completions bash | bash -n"
  assert_success
}

@test "completions: zsh output passes 'zsh -n'" {
  command -v zsh >/dev/null || skip "zsh not installed"
  run bash -c "${profile_script} --completions zsh | zsh -n"
  assert_success
}

@test "completions: fish output passes 'fish --no-execute'" {
  command -v fish >/dev/null || skip "fish not installed"
  local f
  f=$(mktemp)
  CLEANUP_CMDS+=("rm -f ${f}")
  ${profile_script} --completions fish > "$f"
  run fish --no-execute "$f"
  assert_success
}
