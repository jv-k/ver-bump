#!/usr/bin/env bats

# Fluid --help layout (lib/usage.sh): option descriptions word-wrap to the
# terminal width and hang under the description column instead of overflowing
# flush-left. The wrapping engine (_help_wrap) is a pure helper, unit-tested
# here directly. The full render only wraps on a TTY, so captured/piped output
# stays one line per option — the last test guards that gate.

load 'test_helper'

@test "help-wrap: wraps at word boundaries to the given width" {
  source ${profile_script}
  run _help_wrap 10 "one two three four five"
  assert_success
  assert_line --index 0 "one two"
  assert_line --index 1 "three four"
  assert_line --index 2 "five"
}

@test "help-wrap: an over-long word overflows on its own line, never hard-cut" {
  source ${profile_script}
  run _help_wrap 5 "hi supercalifragilistic bye"
  assert_success
  assert_line --index 0 "hi"
  assert_line --index 1 "supercalifragilistic"
  assert_line --index 2 "bye"
}

@test "help-wrap: text shorter than the width stays on a single line" {
  source ${profile_script}
  run _help_wrap 80 "short and sweet"
  assert_success
  assert_output "short and sweet"
}

@test "help-layout: piped (non-TTY) --help keeps descriptions on one line" {
  # The fluid wrap only engages on a real terminal; captured/piped output must
  # stay byte-stable so grepping the help — and these very tests — keeps
  # working. A long description that would wrap on a TTY appears intact here.
  run get_help_msg
  assert_success
  strip_ansi_output
  assert_output --partial "Without a value: print tool version and exit. With a value: set manual SemVer."
}
