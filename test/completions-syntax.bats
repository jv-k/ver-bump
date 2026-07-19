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

@test "completions: zsh output survives a live _arguments run" {
  # zsh -n can't catch bad _arguments specs (e.g. unescaped ']' inside an
  # option description) — they only explode when the completion actually
  # runs. Drive a real interactive completion through zsh/zpty and assert
  # candidates appear without comparguments errors.
  command -v zsh >/dev/null || skip "zsh not installed"
  zsh -c 'zmodload zsh/zpty' 2>/dev/null || skip "zsh/zpty not available"
  local dir
  dir=$(mktemp -d)
  CLEANUP_CMDS+=("rm -rf ${dir}")
  ${profile_script} --completions zsh > "${dir}/_VerBump"
  cat > "${dir}/comptest.zsh" <<'ZSH'
emulate -L zsh
zmodload zsh/zpty
dir=$1 word=$2
zpty vb 'zsh -f -i'
zpty -w vb "PS1='%% '; fpath=($dir \$fpath); autoload -U compinit; compinit -u -D; LISTMAX=1000"
sleep 1
for i in {1..10}; do zpty -r -t vb chunk 2>/dev/null; sleep 0.1; done
zpty -w -n vb "$word"$'\t'
out=""
for i in {1..80}; do
  if zpty -r -t vb chunk 2>/dev/null; then out+="$chunk"; fi
  [[ $out == *"--branch"* || $out == *"invalid option"* ]] && break
  sleep 0.1
done
zpty -d vb
print -r -- "$out"
ZSH
  run zsh "${dir}/comptest.zsh" "$dir" "VerBump --"
  assert_success
  refute_output --partial "invalid option definition"
  assert_output --partial "--branch"
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
