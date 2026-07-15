#!/usr/bin/env bats

# JSON write-path formatting: json_set_version (lib/json.sh) — R-FMT-1..3.
#
# The surgical path must leave every byte outside the top-level "version"
# line untouched (R-FMT-1), enforce parse + value postconditions before the
# atomic mv (R-FMT-2), and fall back to the full jq rewrite for ambiguous
# inputs with a log line, never silently (R-FMT-3). Shared setup lives in
# test/test_helper.bash.
#
# All tests run inside a fresh scratch_repo — byte-level fixtures must not
# pollute the project checkout.

load 'test_helper'

# ── surgical path: byte-identical except the version line ──────────────

@test "json_set_version: 2-space file — only the version line changes" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf '{\n  "name": "demo",\n  "version": "1.2.3",\n  "scripts": {\n    "test": "true"\n  }\n}\n' > in.json
  printf '{\n  "name": "demo",\n  "version": "2.0.0",\n  "scripts": {\n    "test": "true"\n  }\n}\n' > expected.json

  run json_set_version in.json 2.0.0
  strip_ansi_output
  assert_success
  refute_output --partial "falling back"

  run cmp in.json expected.json
  assert_success
}

@test "json_set_version: 4-space file — only the version line changes" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf '{\n    "name": "demo",\n    "version": "1.2.3",\n    "dependencies": {\n        "a": "^1.0.0"\n    }\n}\n' > in.json
  printf '{\n    "name": "demo",\n    "version": "2.0.0",\n    "dependencies": {\n        "a": "^1.0.0"\n    }\n}\n' > expected.json

  run json_set_version in.json 2.0.0
  strip_ansi_output
  assert_success
  refute_output --partial "falling back"

  run cmp in.json expected.json
  assert_success
}

@test "json_set_version: tab-indented file — only the version line changes" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf '{\n\t"version": "1.2.3",\n\t"name": "demo"\n}\n' > in.json
  printf '{\n\t"version": "2.0.0",\n\t"name": "demo"\n}\n' > expected.json

  run json_set_version in.json 2.0.0
  strip_ansi_output
  assert_success
  refute_output --partial "falling back"

  run cmp in.json expected.json
  assert_success
}

@test "json_set_version: file without trailing newline stays newline-less" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf '{\n  "version": "1.2.3"\n}' > in.json
  printf '{\n  "version": "2.0.0"\n}' > expected.json

  run json_set_version in.json 2.0.0
  strip_ansi_output
  assert_success
  refute_output --partial "falling back"

  run cmp in.json expected.json
  assert_success
}

@test "json_set_version: odd key spacing and trailing comma survive byte-for-byte" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf '{\n   "version"  :   "1.2.3" ,\n   "x": 1\n}\n' > in.json
  printf '{\n   "version"  :   "2.0.0" ,\n   "x": 1\n}\n' > expected.json

  run json_set_version in.json 2.0.0
  strip_ansi_output
  assert_success
  refute_output --partial "falling back"

  run cmp in.json expected.json
  assert_success
}

@test "json_set_version: nested \"version\" with a different value does not block the surgical path" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf '{\n    "version": "1.2.3",\n    "deps": {\n        "left-pad": {\n            "version": "9.9.9"\n        }\n    }\n}\n' > in.json
  printf '{\n    "version": "2.0.0",\n    "deps": {\n        "left-pad": {\n            "version": "9.9.9"\n        }\n    }\n}\n' > expected.json

  run json_set_version in.json 2.0.0
  strip_ansi_output
  assert_success
  refute_output --partial "falling back"

  run cmp in.json expected.json
  assert_success
}

# ── ambiguous inputs: logged fallback, correct top-level result ─────────

@test "json_set_version: minified file takes the logged jq fallback" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf '{"name":"demo","version":"1.2.3","ok":true}' > in.json

  run json_set_version in.json 2.0.0
  strip_ansi_output
  assert_success
  assert_output --partial "falling back to a full jq rewrite"

  run jq -r '.version' in.json
  assert_output "2.0.0"
}

@test "json_set_version: duplicate \"version\" keys take the fallback, top-level result correct" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf '{\n  "version": "1.2.3",\n  "version": "1.2.3"\n}\n' > in.json

  run json_set_version in.json 2.0.0
  strip_ansi_output
  assert_success
  assert_output --partial "falling back to a full jq rewrite"

  run jq -r '.version' in.json
  assert_output "2.0.0"
}

@test "json_set_version: nested-only \"version\" takes the fallback and only adds the top-level member" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf '{\n  "package": {\n    "version": "1.2.3"\n  }\n}\n' > in.json

  run json_set_version in.json 2.0.0
  strip_ansi_output
  assert_success
  assert_output --partial "falling back to a full jq rewrite"

  run jq -r '.version' in.json
  assert_output "2.0.0"
  run jq -r '.package.version' in.json
  assert_output "1.2.3"
}

@test "json_set_version: nested \"version\" with the same value is ambiguous — fallback, top-level only" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf '{\n  "version": "1.2.3",\n  "meta": {\n    "version": "1.2.3"\n  }\n}\n' > in.json

  run json_set_version in.json 2.0.0
  strip_ansi_output
  assert_success
  assert_output --partial "falling back to a full jq rewrite"

  run jq -r '.version' in.json
  assert_output "2.0.0"
  run jq -r '.meta.version' in.json
  assert_output "1.2.3"
}

@test "json_set_version: non-string version value takes the logged fallback" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf '{\n  "version": 1,\n  "name": "demo"\n}\n' > in.json

  run json_set_version in.json 2.0.0
  strip_ansi_output
  assert_success
  assert_output --partial "falling back to a full jq rewrite"

  run jq -r '.version | type' in.json
  assert_output "string"
  run jq -r '.version' in.json
  assert_output "2.0.0"
}

@test "json_set_version: version member sharing its line takes the fallback" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf '{\n  "name": "demo", "version": "1.2.3",\n  "ok": true\n}\n' > in.json

  run json_set_version in.json 2.0.0
  strip_ansi_output
  assert_success
  assert_output --partial "falling back to a full jq rewrite"

  run jq -r '.version' in.json
  assert_output "2.0.0"
}

# ── postcondition / failure discipline ──────────────────────────────────

@test "json_set_version: invalid JSON fails and replaces nothing" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf '{ this is not json\n' > in.json
  cp in.json before.json

  run json_set_version in.json 2.0.0
  assert_failure

  run cmp in.json before.json
  assert_success
}

@test "json_set_version: surgical mv failure cleans up the tmp and returns non-zero" {
  source ${profile_script}
  cd "$(scratch_repo)"

  # Simulate a rename(2) failure on the target while the directory stays
  # writable (so mktemp + the postcondition probe still succeed): macOS
  # user-immutable flag. Skip where chflags is unavailable (Linux CI).
  command -v chflags >/dev/null 2>&1 || skip "requires chflags (macOS immutable flag)"

  printf '{\n  "version": "1.2.3"\n}\n' > in.json
  cp in.json before.json
  chflags uchg in.json 2>/dev/null || skip "cannot set immutable flag here"

  run json_set_version in.json 2.0.0
  chflags nouchg in.json # always unlock before asserting so teardown can clean up

  assert_failure

  run cmp in.json before.json
  assert_success
  # No stray tmp files left behind next to the target.
  run bash -c 'ls in.json.* 2>/dev/null'
  assert_output ""
}

# ── call-site integration ───────────────────────────────────────────────

@test "do-packagefile-bump: 4-space package.json keeps its formatting; lock file still bumped" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf '{\n    "name": "demo",\n    "version": "1.2.3"\n}\n' > package.json
  printf '{\n    "name": "demo",\n    "version": "2.0.0"\n}\n' > expected.json
  printf '{\n  "version": "1.2.3",\n  "packages": {\n    "": { "version": "1.2.3" }\n  }\n}\n' > package-lock.json

  V_PREV="1.2.3"
  V_NEW="2.0.0"
  run do-packagefile-bump
  strip_ansi_output
  assert_success
  assert_output --partial "Bumped version in <package.json> and <package-lock.json>"
  refute_output --partial "falling back"

  run cmp package.json expected.json
  assert_success
  run jq -r '.version' package-lock.json
  assert_output "2.0.0"
  run jq -r '.packages[""].version' package-lock.json
  assert_output "2.0.0"
}

@test "bump-json-files: tab-indented -f target keeps its formatting" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf '{\n\t"version": "1.2.3",\n\t"name": "demo"\n}\n' > other.json
  printf '{\n\t"version": "2.0.0",\n\t"name": "demo"\n}\n' > expected.json

  V_NEW="2.0.0"
  JSON_FILES=( other.json )
  run bump-json-files
  strip_ansi_output
  assert_success
  assert_output --partial "1.2.3 → 2.0.0"
  refute_output --partial "falling back"

  run cmp other.json expected.json
  assert_success
}

@test "bump-json-files: minified -f target bumps via the logged fallback" {
  source ${profile_script}
  cd "$(scratch_repo)"

  printf '{"version":"1.2.3","name":"demo"}' > other.json

  V_NEW="2.0.0"
  JSON_FILES=( other.json )
  run bump-json-files
  strip_ansi_output
  assert_success
  assert_output --partial "falling back to a full jq rewrite"
  assert_output --partial "1.2.3 → 2.0.0"

  run jq -r '.version' other.json
  assert_output "2.0.0"
}
