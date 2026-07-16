#!/usr/bin/env bats

# `fail` helper behaviour and exit-code coverage for the Task 1.9 contract
# (argument parsing -> 2, preconditions -> 3, user-abort reserved -> 5).
# Migrated verbatim from the monolithic ver-bump.bats; shared setup lives
# in test/test_helper.bash.

load 'test_helper'

# Tests: fail helper + exit codes #############################################

@test "fail: exits with supplied code" {
  source ${profile_script}
  run fail 2 "bad flag"
  assert_failure 2
}

@test "fail: prints message and hint on stderr when hint provided" {
  source ${profile_script}
  run fail 3 "missing jq" "Install jq: brew install jq"
  assert_failure 3
  assert_output --partial "Error:"
  assert_output --partial "missing jq"
  assert_output --partial "Hint: Install jq: brew install jq"
}

@test "fail: separates the hint from the error with a blank line" {
  source ${profile_script}
  run fail 3 "missing jq" "Install jq: brew install jq"
  assert_failure 3
  strip_ansi_output
  # A blank line precedes the dim hint so it reads apart from the error.
  [[ "$output" == *$'\n\n  Hint:'* ]] \
    || bats_fail "expected a blank line before the Hint, got: ${output}"
}

@test "fail: omits hint line when no hint provided" {
  source ${profile_script}
  run fail 1 "generic failure"
  assert_failure 1
  assert_output --partial "generic failure"
  refute_output --partial "Hint:"
}

@test "fail: uses generic code 1 path" {
  source ${profile_script}
  run fail 1 "oops"
  assert_failure 1
}

@test "fail: supports user-abort code 5" {
  source ${profile_script}
  run fail 5 "user declined"
  assert_failure 5
}

# Exit-code coverage: argument parsing -> 2 ###################################

@test "exit code: unknown short flag -> 2" {
  source ${profile_script}
  run process-arguments -Z
  assert_failure 2
  assert_output --partial "Invalid option:"
  assert_output --partial "Hint:"
}

@test "exit code: unknown long flag -> 2" {
  source ${profile_script}
  run process-arguments --bogus
  assert_failure 2
  assert_output --partial "Invalid option: --bogus"
  assert_output --partial "Hint:"
}

@test "exit code: -v with invalid SemVer -> 2 (arg-parse)" {
  # The -v flag's SemVer validation happens at arg-parse time, so this is a
  # usage error (code 2), not a runtime precondition (code 3).
  source ${profile_script}
  run process-arguments -v banana
  assert_failure 2
  assert_output --partial "is not a valid SemVer"
  assert_output --partial "Hint:"
}

@test "exit code: long opt missing value -> 2" {
  source ${profile_script}
  run process-arguments --push
  assert_failure 2
  assert_output --partial "requires an argument"
}

@test "exit code: boolean long opt given value -> 2" {
  source ${profile_script}
  run process-arguments --dry-run=yes
  assert_failure 2
  assert_output --partial "doesn't take a value"
}

# Exit-code coverage: precondition -> 3 #######################################

@test "exit code: missing package.json -> 3" {
  source ${profile_script}
  cd "$(scratch_repo)"
  VER_FILE="package.json"
  run process-version
  assert_failure 3
  assert_output --partial "was not found"
  assert_output --partial "Hint:"
}

@test "exit code: empty package.json -> 3" {
  source ${profile_script}
  cd "$(scratch_repo)"
  : > package.json  # create empty file
  VER_FILE="package.json"
  run process-version
  assert_failure 3
  assert_output --partial "is empty"
}

@test "exit code: package.json without 'version' field -> 3" {
  source ${profile_script}
  cd "$(scratch_repo)"
  echo '{"name":"no-version"}' > package.json
  VER_FILE="package.json"
  run process-version
  assert_failure 3
  assert_output --partial "doesn't contain a 'version' field"
}

@test "exit code: check-commits-exist with no commits -> 3" {
  source ${profile_script}
  local dir
  dir=$(mktemp -d)
  CLEANUP_CMDS+=("rm -rf ${dir}")
  # Init without a starting branch name, so both old and new git work.
  # --initial-branch is git 2.28+; fall back cleanly on older versions.
  git init -q "$dir"
  ( cd "$dir" && git symbolic-ref HEAD refs/heads/main 2>/dev/null || true )
  cd "$dir"
  run check-commits-exist
  assert_failure 3
  assert_output --partial "doesn't have any commits"
  assert_output --partial "Hint:"
}

@test "exit code: tag already exists -> 3" {
  source ${profile_script}
  cd "$(scratch_repo)"
  V_NEW="35.12.5"
  git tag -a "v${V_NEW}" -m "Test tag"
  run check-tag-exists
  assert_failure 3
  assert_output --partial "already exists"
  assert_output --partial "git tag -d"
}

@test "exit code: branch already exists -> 3" {
  source ${profile_script}
  cd "$(scratch_repo)"
  V_NEW="1.2.3"
  FLAG_BRANCH=true
  git branch "${REL_PREFIX}${V_NEW}"
  run check-branch-notexist
  assert_failure 3
  assert_output --partial "already exists"
  assert_output --partial "Hint:"
}

@test "exit code: missing dependency -> 3" {
  # Simulate missing jq by prepending an empty-PATH shim directory so the
  # `command -v jq` check fails. We keep /usr/bin + /bin around so bash
  # itself still runs.
  source ${profile_script}
  local shim
  shim=$(mktemp -d)
  CLEANUP_CMDS+=("rm -rf ${shim}")
  # Write a `git` shim so only jq is missing (covers the common case)
  cat > "${shim}/git" <<'SH'
#!/bin/sh
exec /usr/bin/env git "$@"
SH
  chmod +x "${shim}/git"
  PATH="${shim}" run check-dependencies
  assert_failure 3
  assert_output --partial "Missing required tool"
  assert_output --partial "Hint:"
}

# Exit-code coverage: user abort path reserved -> 5 ###########################

@test "exit code: fail 5 helper honours exit code" {
  source ${profile_script}
  run fail 5 "user declined push" "Re-run without declining, or pass --yes to auto-confirm."
  assert_failure 5
  assert_output --partial "user declined push"
  assert_output --partial "--yes"
}

@test "exit code: ESC at the version prompt -> 5 via fail" {
  source ${profile_script}
  cd "$(scratch_repo)"
  V_TEST="1.2.3"
  create_ver_file
  # First byte on stdin is ESC — the prompt's single-keystroke pre-read
  # detects it and must abort via `fail 5`, not a raw `exit 130`.
  run process-version <<< $'\e'
  assert_failure 5
  assert_output --partial "version prompt aborted"
  assert_output --partial "Hint:"
}

@test "exit code: do-push declining the prompt -> 5" {
  source ${profile_script}
  cd "$(scratch_repo)"
  # FLAG_PUSH defaults to unset, so do-push takes the interactive branch
  # and reads from stdin. Anything other than y/yes is "declined" -> 5.
  run do-push <<< "n"
  assert_failure 5
  assert_output --partial "push declined"
}
