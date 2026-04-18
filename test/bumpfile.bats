#!/usr/bin/env bats

# File-bumping: do-packagefile-bump, bump-json-files. Migrated verbatim
# from the monolithic ver-bump.bats; shared setup lives in
# test/test_helper.bash.
#
# The "does not stomp global V_PREV" regression test lives here because it
# exercises bump-json-files directly (the function-under-test), even though
# its failure mode concerns do-changelog.

load 'test_helper'

@test "do-packagefile-bump: can bump version in package.json + lock file" {
  source ${profile_script}

  local pkg="${repo_dir}/package.json"
  local pkg_lock="${repo_dir}/package-lock.json"

  # backup actual files, as this test will change them
  yes | cp $pkg "${pkg}.backup"
  yes | cp $pkg_lock "${pkg_lock}.backup"
  # add restore file cmds for post-test cleanup
  CLEANUP_CMDS+=("rm ${pkg} ${pkg_lock}")
  CLEANUP_CMDS+=("mv -f ${pkg}.backup ${pkg}")
  CLEANUP_CMDS+=("mv -f ${pkg_lock}.backup ${pkg_lock}")
  CLEANUP_CMDS+=("git reset -- ${pkg}")
  CLEANUP_CMDS+=("git reset -- ${pkg_lock}")

  V_NEW="35.12.23"
  run do-packagefile-bump
  assert_output -p "Bumped version in <package.json> and <package-lock.json>"

  run jsonfile_get_ver $pkg
  assert_output "${V_NEW}"
}

@test "bump-json-files: can bump version in a json file" {
  source ${profile_script}

  V_TEST="99.88.77"
  V_NEW="99.88.78"

  create_ver_file
  JSON_FILES=( "${VER_FILE}" )

  run bump-json-files # >&3
  assert_output -p "from ${V_TEST} -> ${V_NEW}"

  run jsonfile_get_ver $VER_FILE
  assert_output "${V_NEW}"
}

@test "bump-json-files: can fail bumping a json file when a version already exists in file" {
  source ${profile_script}

  V_TEST="99.88.77"
  V_NEW="99.88.77"

  create_ver_file
  JSON_FILES=( "${VER_FILE}" )

  run bump-json-files # >&3
  assert_output --partial "already contains version ${V_TEST}"

  run jsonfile_get_ver $VER_FILE
  assert_output "${V_TEST}"
}

@test "bump-json-files: can fail bumping a json file when no version found inside it" {
  source ${profile_script}

  V_TEST="99.88.77"
  V_NEW="99.88.77"

  create_ver_file
  > $VER_FILE <<< "" # clear file
  JSON_FILES=( "${VER_FILE}" )

  run bump-json-files # >&3
  assert_output --partial "a version name/value pair was not found to replace!"
}

@test "bump-json-files: does not stomp global V_PREV (needed by do-changelog)" {
  source ${profile_script}
  V_TEST="99.88.77"
  V_NEW="99.88.78"
  V_PREV="outer-sentinel"  # simulate the global set earlier in main()

  create_ver_file
  JSON_FILES=( "${VER_FILE}" )
  bump-json-files >/dev/null

  assert_equal "${V_PREV}" "outer-sentinel"
}
