#!/usr/bin/env bash
#
# dev/screenshots.sh — regenerate img/screenshot.png and img/demo.gif via vhs.
#
# Usage:
#   ./dev/screenshots.sh           # both
#   ./dev/screenshots.sh help      # just the --help PNG
#   ./dev/screenshots.sh demo      # just the sandbox-bump GIF
#
# Requires: vhs (https://github.com/charmbracelet/vhs).  Install: brew install vhs

set -eo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v vhs >/dev/null 2>&1; then
  echo "screenshots: vhs not found on PATH. Install with: brew install vhs" >&2
  exit 127
fi

mkdir -p img img/tmp

# Remove stale outputs so vhs can overwrite cleanly. Notably, earlier runs
# of vhs on `Output *.png` produced a *directory* of frames at that path —
# if one is still around, vhs can't write a plain file there. Nuke both
# possible shapes (file or dir) before re-rendering.
clean() {
  local p
  for p in "$@"; do rm -rf -- "$p"; done
}

target="${1:-all}"
case "$target" in
  help)
    clean img/screenshot.png img/tmp/help.gif
    vhs dev/help.tape
  ;;
  demo)
    clean img/demo.gif
    vhs dev/demo.tape
  ;;
  all)
    clean img/screenshot.png img/tmp/help.gif img/demo.gif
    vhs dev/help.tape
    vhs dev/demo.tape
  ;;
  *)
    echo "screenshots: unknown target '$target' (expected: help | demo | all)" >&2
    exit 2
  ;;
esac

# vhs' `Output` directive always produces a file even when we only care about
# the `Screenshot` frame — for help.tape that throwaway gif lands in img/tmp/.
echo "screenshots: wrote -> img/ (discarded intermediate gifs in img/tmp/)"
