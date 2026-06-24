#!/usr/bin/env bash
#
# dev/capture-freeze.sh — render ver-bump's REAL ANSI output to crisp,
# deterministic PNGs via charmbracelet/freeze. Replaces the vhs `Screenshot`
# path for all STATIC panels (help, dry-run, undo, completions). The single
# animated demo stays in dev/demo.tape (vhs).
#
# Why freeze and not vhs for these:
#   - deterministic: renders the literal captured text, no typing animation
#   - small: ~80KB PNG vs ~460KB vhs frame-grab
#   - real output: we run the actual command, capture its ANSI, render that
#
# Why a PTY: ver-bump disables color when stdout is not a TTY
# (lib/styles.sh: `[ -t 1 ]`) and exposes NO FORCE_COLOR override, so we run
# each command under `script` to get a real PTY and keep the ANSI colors.
#
# Usage:
#   ./dev/capture-freeze.sh              # all static panels
#   ./dev/capture-freeze.sh help         # just img/help.png
#   FONT_FILE=/abs/path.ttf ./dev/capture-freeze.sh
#   THEME=monokai ./dev/capture-freeze.sh
#
# Requires: freeze (brew install charmbracelet/tap/freeze) and a monospace
# .ttf (NOT .ttc — freeze v0.2.x silently renders blank chrome on .ttc).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
OUT_DIR="$REPO_ROOT/img"
RAW_DIR="$REPO_ROOT/img/tmp/ansi"   # gitignored debug copies
THEME="${THEME:-dracula}"
FREEZE="${FREEZE:-freeze}"
MIN_BYTES="${MIN_BYTES:-120}"
COLS="${COLS:-100}"

mkdir -p "$OUT_DIR" "$RAW_DIR"

die() { echo "capture-freeze: ERROR: $*" >&2; exit 1; }

command -v "$FREEZE" >/dev/null 2>&1 || die "freeze not found. brew install charmbracelet/tap/freeze"

# Resolve a usable .ttf. freeze v0.2.x silently produces a blank window (only
# chrome, exit 0) when handed a .ttc (macOS Menlo/SF Mono are .ttc), so we
# pass an explicit --font.file and refuse .ttc up front.
if [[ -z "${FONT_FILE:-}" ]]; then
  for c in \
    "$HOME/Library/Fonts/JetBrainsMono-Regular.ttf" \
    "/Library/Fonts/JetBrainsMono-Regular.ttf" \
    "/usr/share/fonts/truetype/jetbrains-mono/JetBrainsMono-Regular.ttf" \
    "$HOME/Library/Fonts/IosevkaNerdFont-Regular.ttf"; do
    [[ -f "$c" ]] && { FONT_FILE="$c"; break; }
  done
fi
[[ -n "${FONT_FILE:-}" ]] || die "no monospace .ttf found. Set FONT_FILE=/abs/path.ttf (install: brew install --cask font-jetbrains-mono)"
[[ "$FONT_FILE" == *.ttc ]] && die "FONT_FILE is a .ttc; freeze v0.2.x can't load it. Use a .ttf. Got: $FONT_FILE"
[[ -f "$FONT_FILE" ]] || die "FONT_FILE not found: $FONT_FILE"
echo "capture-freeze: font -> $FONT_FILE"

# ver-bump honours CLICOLOR_FORCE (lib/styles.sh), so we get its REAL coloured
# output without allocating a PTY — which means this works headless and in CI,
# where `script`/pty tricks are flaky. We then strip the C0 control bytes that
# would otherwise land in freeze's SVG and abort the render with "illegal
# character code U+0008": every C0 control EXCEPT tab (0o011), newline (0o012)
# and ESC (0o033, the start of every ANSI colour sequence freeze needs).
sanitize() { LC_ALL=C tr -d '\000-\010\013-\032\034-\037'; }
run_capture() {
  local cmd="$1"
  # stdin from /dev/null so a stray interactive read can never block the capture.
  CLICOLOR_FORCE=1 COLUMNS="$COLS" /bin/sh -c "$cmd" </dev/null 2>&1 | sanitize
}

render() {
  local ansi="$1" png="$2"
  "$FREEZE" "$ansi" --output "$png" \
    --theme "$THEME" --language ansi --window \
    --padding 20,30 --margin 20 --border.radius 8 \
    --shadow.blur 30 --shadow.x 0 --shadow.y 12 \
    --font.file "$FONT_FILE"
}

# capture <label> <png-basename> <command...>
capture() {
  local label="$1" base="$2"; shift 2
  local cmd="$*"
  local ansi="$RAW_DIR/$label.ansi" png="$OUT_DIR/$base"
  printf '==> %-12s %s\n' "$label" "$cmd"
  run_capture "$cmd" > "$ansi"
  local size; size=$(wc -c < "$ansi" | tr -d '[:space:]')
  if [[ "$size" -lt "$MIN_BYTES" ]]; then
    echo "    captured only ${size} bytes (< ${MIN_BYTES}) — presumed broken:" >&2
    head -c 400 "$ansi" >&2; echo >&2
    die "capture '$label' produced too little output (raw kept at $ansi)"
  fi
  render "$ansi" "$png"
  [[ -s "$png" ]] || die "freeze wrote an empty PNG for '$label' (font/theme issue?)"
  printf '    -> %s (%s bytes ansi)\n' "$png" "$size"
}

# A throwaway sandbox repo gives deterministic dry-run / undo output without
# touching the real repo. dev/sandbox.sh seeds commits + a tag, forwards flags.
SANDBOX="$REPO_ROOT/dev/sandbox.sh"

target="${1:-all}"
case "$target" in
  help)
    capture help        help.png        "$REPO_ROOT/ver-bump.sh --help"
    ;;
  dry-run)
    capture dry-run     dry-run.png     "$SANDBOX -q -v 2.0.0 -d -y"
    ;;
  undo)
    # Create a release in a kept sandbox, then capture its --undo plan.
    capture undo        undo.png        "$SANDBOX -q -v 2.0.0 -y && true; $SANDBOX -q --undo 2.0.0 -d"
    ;;
  completions)
    capture completions completions.png "$REPO_ROOT/ver-bump.sh --completions zsh | head -25"
    ;;
  all)
    capture help        help.png        "$REPO_ROOT/ver-bump.sh --help"
    capture dry-run     dry-run.png     "$SANDBOX -q -v 2.0.0 -d -y"
    capture completions completions.png "$REPO_ROOT/ver-bump.sh --completions zsh | head -25"
    ;;
  *)
    echo "unknown target '$target' (expected: help | dry-run | undo | completions | all)" >&2
    exit 2
    ;;
esac

echo "capture-freeze: done. PNGs in $OUT_DIR (raw ANSI kept in $RAW_DIR, gitignored)."
