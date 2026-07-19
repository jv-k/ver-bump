#!/usr/bin/env bash
#
# dev/screenshots.sh — regenerate img/screenshot.png, img/verbump-demo.gif
# (plus its final-frame still img/verbump-demo-final.png), and
# img/social-preview.png via vhs. (img/demo.gif is the frozen legacy
# recording hotlinked by old ver-bump npm READMEs — never regenerated or
# cleaned here.)
#
# The social card is also copied to packages/docs-site/public/ — the user
# docs site serves its own copy, and this keeps the two in lock-step.
#
# Usage:
#   ./dev/screenshots.sh           # all three
#   ./dev/screenshots.sh help      # just the --help PNG
#   ./dev/screenshots.sh demo      # just the sandbox-bump GIF
#   ./dev/screenshots.sh social    # just the 1280x640 social card
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

sync_social() {
  cp -f img/social-preview.png packages/docs-site/public/social-preview.png
  echo "screenshots: synced social card -> packages/docs-site/public/"
}

target="${1:-all}"
case "$target" in
  help)
    clean img/screenshot.png img/tmp/help.gif
    vhs dev/help.tape
  ;;
  demo)
    clean img/verbump-demo.gif img/verbump-demo-final.png
    vhs dev/demo.tape
  ;;
  social)
    clean img/social-preview.png img/tmp/social.gif
    vhs dev/social.tape
    sync_social
  ;;
  all)
    clean img/screenshot.png img/verbump-demo.gif img/verbump-demo-final.png \
          img/social-preview.png img/tmp/help.gif img/tmp/social.gif
    vhs dev/help.tape
    vhs dev/demo.tape
    vhs dev/social.tape
    sync_social
  ;;
  *)
    echo "screenshots: unknown target '$target'" >&2
    echo "  expected: help | demo | social | all" >&2
    exit 2
  ;;
esac

# vhs' `Output` directive always produces a file even when we only care about
# the `Screenshot` frame — for help.tape that throwaway gif lands in img/tmp/.
echo "screenshots: wrote -> img/ (discarded intermediate gifs in img/tmp/)"
