#!/usr/bin/env bash
#
# dev/social-frame.sh — print the composed frame for the GitHub social-preview
# card. Driven by dev/social.tape (vhs) at 1280x640 / FontSize 32 (~64 cols);
# the hardcoded indents center each line for exactly that geometry.

set -eo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

help_lines() { CLICOLOR_FORCE=1 ./VerBump.sh --help | sed -n "$1"; }

printf '\n'
help_lines '1,3p' | sed 's/^/                   /'
printf '\n'
help_lines '5p'   | sed 's/^/                      /'
printf '\n'
printf '               \e[1mRelease tool for any Git repo.\e[0m\n'
printf '\n'
printf '   \e[33mConventional Commits\e[0m → \e[32mSemVer\e[0m → \e[36mchangelog\e[0m → \e[35mtag\e[0m → \e[34mpush\e[0m\n'
