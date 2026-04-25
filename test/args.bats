#!/usr/bin/env bats

# Argument parsing: short flags, long flags, -h, --completions, option errors.
# Tests were migrated verbatim from the monolithic ver-bump.bats; see
# test/test_helper.bash for the shared setup/teardown/helpers.

load 'test_helper'

@test "can run script" {
  source ${profile_script}
}

@test "process-arguments: -h: display help message" {
  run ${profile_script} -h
  assert_success
  assert_output --partial "USAGE"
  assert_output --partial "OPTIONS"
  assert_output --partial "--version"
}

@test "process-arguments: -v: bare prints version pill and exits 0" {
  run ${profile_script} -v
  assert_success
}

@test "process-arguments: -v x.x.x: succeed when supplying version" {
  local TEST_VER="9.8.7"
  source ${profile_script}
  process-arguments -v "${TEST_VER}"
  # assert_success
  assert_equal "${V_USR_SUPPLIED}" "${TEST_VER}"
}

@test "process-arguments: -v: rejects non-SemVer version" {
  source ${profile_script}
  run process-arguments -v "banana"
  assert_failure
  assert_output --partial "'banana' is not a valid SemVer 2.0 version"
}

@test "process-arguments: -v: accepts SemVer prerelease and build metadata" {
  source ${profile_script}
  process-arguments -v "1.2.3-rc.1+build.42"
  assert_equal "${V_USR_SUPPLIED}" "1.2.3-rc.1+build.42"
}

@test "process-arguments: -d: sets dry-run flag" {
  source ${profile_script}
  process-arguments -d
  assert_equal "${FLAG_DRYRUN}" "true"
}

@test "process-arguments: -t <prefix>: overrides tag prefix" {
  source ${profile_script}
  process-arguments -t "release/"
  assert_equal "${TAG_PREFIX}" "release/"
}

@test "process-arguments: -B <prefix>: overrides branch prefix" {
  source ${profile_script}
  process-arguments -B "hotfix-"
  assert_equal "${REL_PREFIX}" "hotfix-"
}

@test "long options: --version, --message, --file accept space-separated value" {
  source ${profile_script}
  process-arguments --version 1.2.3 --message "hello world" --file a.json --file b.json
  assert_equal "${V_USR_SUPPLIED}" "1.2.3"
  assert_equal "${REL_NOTE}" "hello world"
  assert_equal "${JSON_FILES[0]}" "a.json"
  assert_equal "${JSON_FILES[1]}" "b.json"
}

@test "long options: --name=value form" {
  source ${profile_script}
  process-arguments --version=9.8.7 --tag-prefix=release/ --branch-prefix=hotfix-
  assert_equal "${V_USR_SUPPLIED}" "9.8.7"
  assert_equal "${TAG_PREFIX}" "release/"
  assert_equal "${REL_PREFIX}" "hotfix-"
}

@test "long options: boolean flags set corresponding globals" {
  source ${profile_script}
  process-arguments --dry-run --no-commit --no-branch --no-changelog --pause-changelog
  assert_equal "${FLAG_DRYRUN}" "true"
  assert_equal "${FLAG_NOCOMMIT}" "true"
  assert_equal "${FLAG_NOBRANCH}" "true"
  assert_equal "${FLAG_NOCHANGELOG}" "true"
  assert_equal "${FLAG_CHANGELOG_PAUSE}" "true"
}

@test "long options: --push <remote> sets push flag + dest" {
  source ${profile_script}
  process-arguments --push upstream
  assert_equal "${FLAG_PUSH}" "true"
  assert_equal "${PUSH_DEST}" "upstream"
}

@test "long options: rejects unknown long option" {
  source ${profile_script}
  run process-arguments --bogus
  assert_failure
  assert_output --partial "Invalid option: --bogus"
}

@test "long options: rejects missing value for long option" {
  source ${profile_script}
  run process-arguments --push
  assert_failure
  assert_output --partial "Option --push requires an argument"
}

@test "long options: rejects value given to boolean long option" {
  source ${profile_script}
  run process-arguments --dry-run=yes
  assert_failure
  assert_output --partial "Option --dry-run doesn't take a value"
}

@test "long options: short and long forms can be mixed" {
  source ${profile_script}
  process-arguments -v 1.2.3 --dry-run -f a.json --file=b.json
  assert_equal "${V_USR_SUPPLIED}" "1.2.3"
  assert_equal "${FLAG_DRYRUN}" "true"
  assert_equal "${JSON_FILES[0]}" "a.json"
  assert_equal "${JSON_FILES[1]}" "b.json"
}

@test "completions: --completions bash emits a parseable script" {
  run ${profile_script} --completions bash
  assert_success
  assert_output --partial "complete -F _ver_bump ver-bump"
  # Script must be syntactically valid bash
  tmp=$(mktemp)
  echo "$output" > "$tmp"
  bash -n "$tmp"
  rm -f "$tmp"
}

@test "completions: --completions zsh emits a #compdef script" {
  run ${profile_script} --completions zsh
  assert_success
  assert_output --partial "#compdef ver-bump"
  assert_output --partial "_arguments"
}

@test "completions: --completions fish emits complete commands" {
  run ${profile_script} --completions fish
  assert_success
  assert_output --partial "complete -c"
  assert_output --partial "-l tag-prefix"
}

@test "completions: --completions=<shell> form works" {
  run ${profile_script} --completions=zsh
  assert_success
  assert_output --partial "#compdef ver-bump"
}

@test "completions: unknown shell exits non-zero" {
  run ${profile_script} --completions powershell
  assert_failure
  assert_output --partial "Unknown shell: powershell"
}

@test "completions: no shell argument prints usage hint" {
  run ${profile_script} --completions
  assert_success
  assert_output --partial "Usage: ver-bump --completions"
}

@test "process-arguments: -m: fail when not supplying release note" {
  source ${profile_script}
  run process-arguments -m
  assert_failure 2
  assert_output --partial "Option -m requires an argument."
}

@test "process-arguments: -m <note>: succeed when supplying release note" {
  local TEST_MSG="This is a custom release note"
  source ${profile_script}
  process-arguments -m "${TEST_MSG}"
  assert_equal "${REL_NOTE}" "${TEST_MSG}"
}

@test "process-arguments: -f: fail when not supplying filenames" {
  source ${profile_script}
  run process-arguments -f
  assert_failure 2
  assert_output --partial "Option -f requires an argument."
}

@test "process-arguments: -f <filename.json>: succeed with multiple filenames" {
  local TEST_FILENAMES=("test1.json" "test2.json" "test3.json")
  source ${profile_script}
  process-arguments -f "${TEST_FILENAMES[0]}" -f "${TEST_FILENAMES[1]}" -f "${TEST_FILENAMES[2]}"
  assert_equal "${JSON_FILES[0]}" "${TEST_FILENAMES[0]}"
  assert_equal "${JSON_FILES[1]}" "${TEST_FILENAMES[1]}"
  assert_equal "${JSON_FILES[2]}" "${TEST_FILENAMES[2]}"

  # Test info messages
  JSON_FILES=()
  run process-arguments -f "${TEST_FILENAMES[0]}" -f "${TEST_FILENAMES[1]}" -f "${TEST_FILENAMES[2]}"
  assert_output --partial "JSON file via [-f]: <${TEST_FILENAMES[0]}>"
  assert_output --partial "JSON file via [-f]: <${TEST_FILENAMES[1]}>"
  assert_output --partial "JSON file via [-f]: <${TEST_FILENAMES[2]}>"
}

@test "process-arguments: -p: fail when not supplying push destination" {
  source ${profile_script}
  run process-arguments -p
  assert_failure 2
  assert_output --partial "Option -p requires an argument."
}

@test "process-arguments: -p <repo destination>: succeed when supplying a destination" {
  local TEST_DEST="other-origin"
  source ${profile_script}
  process-arguments -p "${TEST_DEST}"
  assert_equal "${PUSH_DEST}" "${TEST_DEST}"
  assert_equal "${FLAG_PUSH}" "true"

  run process-arguments -p "${TEST_DEST}"
  strip_ansi_output
  assert_output --partial "Option set: push to <${PUSH_DEST}>"
}

@test "process-arguments: -n: set flag to prevent committing at the end" {
  source ${profile_script}
  process-arguments -n
  assert_equal "${FLAG_NOCOMMIT}" "true"

  run process-arguments -n
  strip_ansi_output
  assert_output --partial "disable commit (and tag + push) after bumping files."
}

@test "process-arguments: -b: set flag to disable creating a release branch" {
  source ${profile_script}
  process-arguments -b
  assert_equal "${FLAG_NOBRANCH}" "true"

  run process-arguments -b
  strip_ansi_output
  assert_output --partial "disable creating a new release-x.x.x branch."
}

@test "process-arguments: -c: set flag to disable creating/updating CHANGELOG.md" {
  source ${profile_script}
  process-arguments -c
  assert_equal "${FLAG_NOCHANGELOG}" "true"

  run process-arguments -c
  strip_ansi_output
  assert_output --partial "Option set: disable updating CHANGELOG.md"
}

@test "process-arguments: -l: set flag to enable pausing after CHANGELOG.md is created" {
  source ${profile_script}
  process-arguments -l
  assert_equal "${FLAG_CHANGELOG_PAUSE}" "true"

  run process-arguments -l
  strip_ansi_output
  assert_output --partial "Option set: pause to allow amending CHANGELOG.md"
}

@test "process-arguments: fail on not-existing argument" {
  local TEST_OPT="-X"
  source ${profile_script}
  run process-arguments "${TEST_OPT}"
  assert_failure 2
  assert_output --partial "Invalid option: -X"
}

# S4 — --name= (empty value after '=') must fail, not silently consume the
# following positional as the flag's value.
@test "process-arguments: --push= (empty value) -> 2" {
  source ${profile_script}
  run process-arguments --push= -d
  assert_failure 2
  assert_output --partial "Option --push requires a non-empty value"
}

@test "process-arguments: --version= (empty value) -> 2" {
  source ${profile_script}
  run process-arguments --version= -d
  assert_failure 2
  assert_output --partial "Option --version requires a non-empty value"
}

@test "process-arguments: --major sets BUMP_LEVEL" {
  source ${profile_script}
  process-arguments --major
  assert_equal "${BUMP_LEVEL}" "major"
}

@test "process-arguments: --minor sets BUMP_LEVEL" {
  source ${profile_script}
  process-arguments --minor
  assert_equal "${BUMP_LEVEL}" "minor"
}

@test "process-arguments: --patch sets BUMP_LEVEL" {
  source ${profile_script}
  process-arguments --patch
  assert_equal "${BUMP_LEVEL}" "patch"
}

@test "process-arguments: --major + --minor exits 2" {
  source ${profile_script}
  run process-arguments --major --minor
  assert_failure 2
  assert_output --partial "Conflicting bump-level flags"
  assert_output --partial "mutually exclusive"
}

@test "process-arguments: --minor + --patch exits 2" {
  source ${profile_script}
  run process-arguments --minor --patch
  assert_failure 2
  assert_output --partial "Conflicting bump-level flags"
}

@test "process-arguments: --major + --minor + --patch exits 2" {
  source ${profile_script}
  run process-arguments --major --minor --patch
  assert_failure 2
  assert_output --partial "Conflicting bump-level flags"
}

@test "process-arguments: --major rejects =value" {
  source ${profile_script}
  run process-arguments --major=2
  assert_failure 2
  assert_output --partial "Option --major doesn't take a value"
}

@test "process-arguments: --major + -v exits 2" {
  source ${profile_script}
  run process-arguments --major -v 1.2.3
  assert_failure 2
  assert_output --partial "Conflicting flags"
  assert_output --partial "--major"
}

@test "process-arguments: -v + --major exits 2" {
  source ${profile_script}
  run process-arguments -v 1.2.3 --major
  assert_failure 2
  # -v was parsed first via getopts; --major then triggers... wait, actually
  # normalize-long-opts runs first, so --major is consumed before getopts
  # sees -v. Either ordering hits the conflict — message anchors on the
  # bump-level half.
  assert_output --partial "Conflicting flags"
}

@test "process-arguments: --patch + --version=1.2.3 exits 2" {
  source ${profile_script}
  run process-arguments --patch --version=1.2.3
  assert_failure 2
  assert_output --partial "Conflicting flags"
}

@test "process-arguments: --major works alongside --dry-run" {
  source ${profile_script}
  process-arguments --major --dry-run
  assert_equal "${BUMP_LEVEL}" "major"
  assert_equal "${FLAG_DRYRUN}" "true"
}

@test "help↔README flag parity: every --help long flag appears in README" {
  local help_out flags flag
  help_out=$(get_help_msg)

  flags=$(printf '%s' "$help_out" | grep -oE -- '--[a-z][-a-z]+' | sort -u)

  for flag in $flags; do
    [[ "$flag" == "--name" ]] && continue
    grep -qF -- "$flag" "${repo_dir}/README.md" \
      || fail "Flag ${flag} appears in --help but not in README.md"
  done
}
