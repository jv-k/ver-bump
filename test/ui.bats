#!/usr/bin/env bats

# UI / colour discipline regression guards. These tests do not exercise
# behaviour — they lock in the "plain narrative, colour for values only"
# convention so future edits don't drift back to the whole-line-green
# style the refactor cleaned up.
#
# Rule of thumb:
#   - Narrative text       → no style token
#   - Interpolated values  → S_NORM (reset after)
#   - User prompts         → S_QUESTION
#   - Warning bodies       → S_WARN "Warning:" prefix + plain body
#   - Errors               → via fail helper (S_ERROR label)
#   - Dim markers          → S_LIGHT ("[dry-run]", "Option set:")
#
# `S_NOTICE` and raw `GREEN` are both forbidden on narrative lines.
# Help output in usage() is out of scope and allowed to keep BOLD headers.

load 'test_helper'

@test "UI: no S_NOTICE references in lib/helpers.sh or ver-bump.sh" {
  # S_NOTICE was the whole-line green narrative token. The refactor stripped
  # it; ensure it doesn't creep back.
  run grep -n 'S_NOTICE' "${repo_dir}/lib/helpers.sh" "${repo_dir}/ver-bump.sh"
  assert_failure
}

@test "UI: no raw GREEN references outside lib/styles.sh" {
  # GREEN is defined in styles.sh (fine) but must not be used directly in
  # narrative echoes anywhere else.
  run grep -rn --include='*.sh' -l 'GREEN' \
      "${repo_dir}/lib/helpers.sh" "${repo_dir}/ver-bump.sh" "${repo_dir}/lib/config.sh"
  assert_failure
}

@test "UI: 'Option set:' banners keep S_LIGHT dim prefix + reset" {
  # Option-set acknowledgements are secondary info; the prefix stays dim
  # ($S_LIGHT) and the narrative body is plain.
  run grep -c 'S_LIGHT}Option set:${RESET}' "${repo_dir}/lib/helpers.sh"
  assert_success
  # At least the 10 option handlers (-m, -f, -p, -t, -B, -d, -n, -b, -c, -l).
  [ "${output}" -ge 10 ]
}

@test "UI: dry-run lines keep [dry-run] dim marker" {
  # [dry-run] stays dim so it reads as a marker, not narrative.
  run grep -c 'S_LIGHT}\[dry-run\]${RESET}' "${repo_dir}/lib/helpers.sh"
  assert_success
  [ "${output}" -ge 6 ]
}
