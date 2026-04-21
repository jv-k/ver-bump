#!/usr/bin/env bats

# Version-string primitives: is_semver, set-v-suggest, bump-prerelease,
# process-version. Migrated verbatim from the monolithic ver-bump.bats;
# shared setup lives in test/test_helper.bash.

load 'test_helper'

@test "is_semver: accepts and rejects per spec" {
  source ${profile_script}
  is_semver "1.2.3"            || return 1
  is_semver "0.0.0"            || return 1
  is_semver "1.2.3-alpha"      || return 1
  is_semver "1.2.3-alpha.1"    || return 1
  is_semver "1.2.3+build"      || return 1
  is_semver "1.2.3-rc.1+sha.2" || return 1

  ! is_semver ""        || return 1
  ! is_semver "1.2"     || return 1
  ! is_semver "1.2.3.4" || return 1
  ! is_semver "v1.2.3"  || return 1
  ! is_semver "1.2.a"   || return 1
  ! is_semver "01.2.3"  || return 1
}

@test "set-v-suggest: increments version" {
  source ${profile_script}

  set-v-suggest "35.12.5" || return 1
  assert_equal "${V_SUGGEST}" "35.12.6"
}

@test "bump-prerelease: bumps trailing numeric counter" {
  source ${profile_script}
  assert_equal "$(bump-prerelease '4.0.0-dev.6')" "4.0.0-dev.7"
  assert_equal "$(bump-prerelease '4.0.0-rc.9')" "4.0.0-rc.10"
  assert_equal "$(bump-prerelease '1.2.3-beta.0')" "1.2.3-beta.1"
}

@test "bump-prerelease: appends .1 when no numeric counter" {
  source ${profile_script}
  assert_equal "$(bump-prerelease '1.0.0-alpha')" "1.0.0-alpha.1"
  assert_equal "$(bump-prerelease '1.0.0-dev')"   "1.0.0-dev.1"
}

@test "bump-prerelease: preserves build metadata" {
  source ${profile_script}
  assert_equal "$(bump-prerelease '2.1.0-beta.3+build.sha')" "2.1.0-beta.4+build.sha"
  assert_equal "$(bump-prerelease '1.0.0-rc.1+exp.sha.5114f85')" "1.0.0-rc.2+exp.sha.5114f85"
}

@test "set-v-suggest: bumps prerelease counter instead of patch" {
  source ${profile_script}
  set-v-suggest "4.0.0-dev.6"
  assert_equal "${V_SUGGEST}" "4.0.0-dev.7"

  set-v-suggest "1.0.0-alpha"
  assert_equal "${V_SUGGEST}" "1.0.0-alpha.1"
}

# S6 — set-v-suggest dispatches on is_semver; legacy "contains a dash"
# heuristic could misroute inputs like "1-2.3.4" (not SemVer, no prerelease
# to bump). Should fall through to the warn-and-return-unchanged branch.
@test "set-v-suggest: non-SemVer containing a dash stays unchanged and warns" {
  source ${profile_script}
  local input="1-2.3.4"
  run set-v-suggest "${input}"
  strip_ansi_output
  assert_output --partial "Warning:"
  assert_output --partial "${input}"

  # Also verify V_SUGGEST is the untouched input when the function is called
  # in-process (the `run` above ran in a subshell).
  set-v-suggest "${input}"
  assert_equal "${V_SUGGEST}" "${input}"
}

@test "set-v-suggest: fails to increments non SemVer version" {
  source ${profile_script}

  TEST_V_GOOD="35.12.5"
  TEST_V_GOOD_INC="35.12.6"
  TEST_V_BAD="35.12.thiswontincrement"

  set-v-suggest "${TEST_V_GOOD}" || return 1
  assert_equal "${V_SUGGEST}" "${TEST_V_GOOD_INC}"

  set-v-suggest "${TEST_V_BAD}" || return 1
  assert_equal "${V_SUGGEST}" "${TEST_V_BAD}"

  run set-v-suggest "${TEST_V_BAD}" || return 1
  strip_ansi_output
  assert_output --partial "Warning:"
  assert_output --partial "${TEST_V_BAD}"
  assert_output --partial "doesn't look like a SemVer"
}

@test "process-version: fail on entering non-SemVer input" {
  source ${profile_script}

  V_TEST="99.88.77"
  V_TEST_INPUT="12.wrong.1"
  create_ver_file

  run process-version <<< "$V_TEST_INPUT"
  assert_failure
  assert_output --partial "'${V_TEST_INPUT}' is not a valid SemVer 2.0 version"
}

@test "process-version: patch of the version from json file should be bumped +1" {
  source ${profile_script}

  V_TEST="35.12.5"
  create_ver_file

  process-version <<< "" || return 1
  assert_equal "${V_PREV}" "${V_TEST}"
  assert_equal "${V_NEW}" "35.12.6"
}
