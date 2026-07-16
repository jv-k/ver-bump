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

@test "help-pack: packs atomic tokens without splitting a token" {
  source ${profile_script}
  # "[--major | --minor | --patch]" has inner spaces but is one atomic token —
  # it must never be broken across lines.
  run _help_pack 30 "[-v <version>]" "[-m <message>]" "[--major | --minor | --patch]" "[-h]"
  assert_success
  assert_line --index 0 "[-v <version>] [-m <message>]"
  assert_line --index 1 "[--major | --minor | --patch]"
  assert_line --index 2 "[-h]"
}

@test "help-pack: a token wider than the width overflows on its own line" {
  source ${profile_script}
  run _help_pack 8 "[-a]" "[--install-completions[=<shell>]]" "[-b]"
  assert_success
  assert_line --index 0 "[-a]"
  assert_line --index 1 "[--install-completions[=<shell>]]"
  assert_line --index 2 "[-b]"
}

@test "help-layout: USAGE is a concise synopsis, not a flag enumeration" {
  run get_help_msg
  assert_success
  strip_ansi_output
  # The version is an option value, not a positional — shown as -v <version>.
  assert_output --partial "ver-bump [-v <version>] [options]"
  refute_output --partial "ver-bump [<version>] [options]"
  # The old exhaustive per-flag synopsis is gone (flags live in OPTIONS).
  refute_output --partial "[-B <branch-prefix>]"
  refute_output --partial "[--install-completions[=<shell>]]"
}

@test "help-layout: OPTIONS lists the short alias first, long flag second" {
  run get_help_msg
  assert_success
  strip_ansi_output
  assert_output --partial "-v, --version"
  assert_output --partial "-m, --message"
  refute_output --partial "--version, -v"
}

@test "help-layout: no blank line after the name/version header pill" {
  run get_help_msg
  assert_success
  strip_ansi_output
  # The author bullet sits directly beneath the pill — no empty line between.
  refute_output --partial $'\n\n • Author'
}

@test "help: the tool description is sourced from package.json" {
  # The tagline is not hardcoded — it is package.json ".description" verbatim.
  local desc
  desc=$(jq -r '.description' "${repo_dir}/package.json")
  run get_help_msg
  assert_success
  strip_ansi_output
  assert_output --partial "$desc"
}

@test "help-layout: an over-long EXAMPLES command stacks above its description" {
  # A command wider than the description column sits alone on its line (so the
  # grid stays aligned and the command is easy to copy); the description hangs
  # under the column on the next line. Guards against the old inline layout that
  # shoved the description out of alignment.
  run get_help_msg
  assert_success
  strip_ansi_output
  assert_line "  ver-bump --bump 'main.go:Version = \"{{version}}\"'"
  assert_output --partial "                                        Also bump a Go const"
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
