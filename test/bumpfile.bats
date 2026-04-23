#!/usr/bin/env bats

# File-bumping: do-packagefile-bump, bump-json-files. Shared setup lives
# in test/test_helper.bash.
#
# The "does not stomp global V_PREV" regression test lives here because it
# exercises bump-json-files directly (the function-under-test), even though
# its failure mode concerns do-changelog.
#
# All tests run inside a fresh scratch_repo — the real project checkout
# would otherwise be polluted with test package.json rewrites.

load 'test_helper'

@test "do-packagefile-bump: can bump version in package.json + lock file" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf '{ "version": "0.1.0" }\n' > package.json
  printf '{\n  "version": "0.1.0",\n  "packages": {\n    "": { "version": "0.1.0" }\n  }\n}\n' > package-lock.json

  V_PREV="0.1.0"
  V_NEW="35.12.23"
  run do-packagefile-bump
  strip_ansi_output
  assert_output -p "Bumped version in <package.json> and <package-lock.json>"

  run jsonfile_get_ver package.json
  assert_output "${V_NEW}"
}

@test "bump-json-files: can bump version in a json file" {
  source ${profile_script}
  cd "$(scratch_repo)"

  V_TEST="99.88.77"
  V_NEW="99.88.78"

  create_ver_file
  JSON_FILES=( "${VER_FILE}" )

  run bump-json-files # >&3
  strip_ansi_output
  assert_output -p "${V_TEST} → ${V_NEW}"

  run jsonfile_get_ver $VER_FILE
  assert_output "${V_NEW}"
}

@test "bump-json-files: can fail bumping a json file when a version already exists in file" {
  source ${profile_script}
  cd "$(scratch_repo)"

  V_TEST="99.88.77"
  V_NEW="99.88.77"

  create_ver_file
  JSON_FILES=( "${VER_FILE}" )

  run bump-json-files # >&3
  strip_ansi_output
  assert_output --partial "already contains version ${V_TEST}"

  run jsonfile_get_ver $VER_FILE
  assert_output "${V_TEST}"
}

@test "bump-json-files: can fail bumping a json file when no version found inside it" {
  source ${profile_script}
  cd "$(scratch_repo)"

  V_TEST="99.88.77"
  V_NEW="99.88.77"

  create_ver_file
  > $VER_FILE <<< "" # clear file
  JSON_FILES=( "${VER_FILE}" )

  run bump-json-files # >&3
  strip_ansi_output
  assert_output --partial "no .version field in"
}

@test "bump-json-files: does not stomp global V_PREV (needed by do-changelog)" {
  source ${profile_script}
  cd "$(scratch_repo)"
  V_TEST="99.88.77"
  V_NEW="99.88.78"
  V_PREV="outer-sentinel"  # simulate the global set earlier in main()

  create_ver_file
  JSON_FILES=( "${VER_FILE}" )
  bump-json-files >/dev/null

  assert_equal "${V_PREV}" "outer-sentinel"
}

# S7 coverage — process-version allows missing package.json when -v supplied

@test "do-packagefile-bump: silently skips when package.json is absent" {
  source ${profile_script}
  cd "$(scratch_repo)"

  V_PREV=""
  V_NEW="1.2.3"
  run do-packagefile-bump
  strip_ansi_output
  assert_success
  assert_output --partial "not found"
  refute_output --partial "Bumped version"
}

@test "-v + -f other.json with no package.json succeeds end-to-end (dry-run)" {
  local repo
  repo="$(scratch_repo)"
  cd "$repo"
  printf '{ "version": "0.9.0" }\n' > "$repo/other.json"

  run ${profile_script} -d -b -c -p origin -v 1.0.1 -f other.json
  strip_ansi_output
  assert_success
  # package.json skip notice + the -f JSON bump happens instead.
  assert_output --partial "not found"
  assert_output --partial "would set .version = '1.0.1' in other.json"
}
