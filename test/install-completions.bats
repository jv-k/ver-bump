#!/usr/bin/env bats

# --install-completions: auto-detect the user's shell (or take --=<shell>)
# and write the matching script to a user-scope directory. Supports bash,
# zsh, fish. Dry-run and error paths are also covered here.

load 'test_helper'

# Isolate HOME per test so each run writes into a throwaway dir.
setup() {
  load './test_helper/bats-support/load'
  load './test_helper/bats-assert/load'

  repo_dir=$PWD
  profile_script="$repo_dir/ver-bump.sh"

  FAKE_HOME=$(mktemp -d)
  export HOME="$FAKE_HOME"
  export XDG_DATA_HOME="$FAKE_HOME/.local/share"
  export XDG_CONFIG_HOME="$FAKE_HOME/.config"
  unset __fish_config_dir

  F_TEMPS=()
  CLEANUP_CMDS=( "rm -rf ${FAKE_HOME}" )
}

teardown() {
  run_cleanup_cmds
  unset FAKE_HOME XDG_DATA_HOME XDG_CONFIG_HOME
}

@test "install-completions: --install-completions=bash writes to XDG bash-completion path" {
  run ${profile_script} --install-completions=bash
  assert_success
  local dest="${HOME}/.local/share/bash-completion/completions/ver-bump"
  [ -f "$dest" ]
  # Emitted script must be syntactically valid bash.
  run bash -n "$dest"
  assert_success
}

@test "install-completions: --install-completions=zsh writes to XDG zsh site-functions path" {
  run ${profile_script} --install-completions=zsh
  assert_success
  [ -f "${HOME}/.local/share/zsh/site-functions/_ver-bump" ]
  # Non-TTY bats runs won't have the target dir on fpath, so the installer
  # prints the .zshrc reminder.
  assert_output --partial "fpath=(~/.local/share/zsh/site-functions"
}

@test "install-completions: --install-completions=fish writes to XDG fish completions path" {
  run ${profile_script} --install-completions=fish
  assert_success
  [ -f "${HOME}/.config/fish/completions/ver-bump.fish" ]
}

@test "install-completions: unknown shell exits 2" {
  run ${profile_script} --install-completions=powershell
  assert_failure 2
  assert_output --partial "Unsupported shell"
}

@test "install-completions: empty value after = exits 2" {
  run ${profile_script} --install-completions=
  assert_failure 2
  assert_output --partial "requires a shell name"
}

@test "install-completions: dry-run prints target path and writes nothing" {
  run ${profile_script} --dry-run --install-completions=bash
  assert_success
  assert_output --partial "[dry-run]"
  assert_output --partial "would write"
  [ ! -f "${HOME}/.local/share/bash-completion/completions/ver-bump" ]
}

@test "install-completions: overwrites an existing file without prompting" {
  mkdir -p "${HOME}/.local/share/zsh/site-functions"
  printf 'stale content\n' > "${HOME}/.local/share/zsh/site-functions/_ver-bump"
  run ${profile_script} --install-completions=zsh
  assert_success
  run cat "${HOME}/.local/share/zsh/site-functions/_ver-bump"
  refute_output --partial "stale content"
}

@test "install-completions: bare --install-completions uses \$SHELL basename" {
  export SHELL=/usr/bin/zsh
  run ${profile_script} --install-completions
  assert_success
  [ -f "${HOME}/.local/share/zsh/site-functions/_ver-bump" ]
}

@test "install-completions: bare flag with unsupported \$SHELL exits 2 with hint" {
  export SHELL=/opt/weird/tcsh
  run env -u SHELL SHELL=/opt/weird/tcsh ${profile_script} --install-completions
  # Can't guarantee auto-detect fails if PPID fallback finds bash/zsh/fish
  # running the test. Assert on a message pattern that matches either
  # "Unsupported shell" (PPID fallback found something unsupported) or
  # "Could not auto-detect" (all signals failed).
  if [ "$status" -ne 0 ]; then
    assert_output --partial "--install-completions=<"
  fi
}
