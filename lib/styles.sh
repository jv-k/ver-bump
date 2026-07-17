#!/bin/bash

# shellcheck disable=SC2034

# Colour gate. Precedence:
#   1. NO_COLOR set (any value)            -> off   (https://no-color.org)
#   2. CLICOLOR_FORCE / FORCE_COLOR truthy -> on    (force colour without a TTY,
#                                                    e.g. piping into `less -R`,
#                                                    screenshot capture, or CI)
#   3. stdout is a TTY                      -> on
#   4. otherwise (pipe, file, CI)          -> off
if [ -n "${NO_COLOR:-}" ]; then
  USE_COLOR=0
elif { [ -n "${CLICOLOR_FORCE:-}" ] && [ "${CLICOLOR_FORCE}" != 0 ]; } \
  || { [ -n "${FORCE_COLOR:-}" ] && [ "${FORCE_COLOR}" != 0 ]; }; then
  USE_COLOR=1
elif [ -t 1 ]; then
  USE_COLOR=1
else
  USE_COLOR=0
fi

if [ "$USE_COLOR" = 1 ]; then
  # ANSI/VT100 colours
  YELLOW='\033[1;33m'
  LIGHTYELLOW='\033[0;33m'
  RED='\033[0;31m'
  LIGHTRED='\033[1;31m'
  GREEN='\033[0;32m'
  LIGHTGREEN='\033[1;32m'
  BLUE='\033[0;34m'
  LIGHTBLUE='\033[1;34m'
  PURPLE='\033[0;35m'
  LIGHTPURPLE='\033[1;35m'
  CYAN='\033[0;36m'
  LIGHTCYAN='\033[1;36m'
  WHITE='\033[1;37m'
  LIGHTGRAY='\033[0;37m'
  DARKGRAY='\033[1;30m'
  DIM='\033[2m'
  BOLD='\033[1m'
  INVERT='\033[7m'
  RESET='\033[0m'

  RAINBOW=(
    "$(printf '\033[38;5;196m')"
    "$(printf '\033[38;5;202m')"
    "$(printf '\033[38;5;226m')"
    "$(printf '\033[38;5;082m')"
    "$(printf '\033[38;5;021m')"
    "$(printf '\033[38;5;093m')"
    "$(printf '\033[38;5;163m')"
  )
  # shellcheck disable=SC2059
  RAINBOW_RST=$(printf "$RESET")
else
  YELLOW=''; LIGHTYELLOW=''; RED=''; LIGHTRED=''; GREEN=''; LIGHTGREEN=''
  BLUE=''; LIGHTBLUE=''; PURPLE=''; LIGHTPURPLE=''; CYAN=''; LIGHTCYAN=''
  WHITE=''; LIGHTGRAY=''; DARKGRAY=''; DIM=''; BOLD=''; INVERT=''; RESET=''
  RAINBOW=( '' '' '' '' '' '' '' )
  RAINBOW_RST=''
fi

# Preset styles (character-level) — semantic aliases. Call sites reference
# these rather than raw colour vars so a single edit here re-skins the tool.
S_NORM="${BOLD}"      # emphasis = bold of the terminal's own fg (no colour)
S_LIGHT="${DIM}"      # markers/secondary = dim the terminal fg (theme-adaptive)
S_WARN="${LIGHTRED}"
S_ERROR="${RED}"
S_DIM="${DIM}"
S_OK="${GREEN}"       # log_success    (✔ green)
S_INFO="${CYAN}"      # log_info       (ℹ cyan)
S_ATTN="${YELLOW}"    # log_warn       (! yellow)
S_BULLET="${PURPLE}"  # version_block  (• magenta bullets)
S_VAL="${GREEN}"      # inline values (versions, paths, remotes) in run output

# Deprecated — retained as an alias to $GREEN until the last call site migrates
# to a log_* helper. Tests forbid its use on narrative lines in lib/helpers.sh
# and ver-bump.sh (see test/ui.bats).
S_NOTICE="${GREEN}"

# Inverted-video bold pills for section headers — ` TEXT ` reads as a solid
# coloured bar. Five variants: cyan (primary), green (secondary), yellow
# (outdated / warning), red (error), magenta (interactive prompt — awaiting
# user input). Close with S_HDR_END.
#
# Built from a single combined ANSI sequence (7=invert, 1=bold, 3N=fg) rather
# than ${INVERT}${BOLD}${COLOUR} concatenated, because the standalone fg codes
# begin with "\033[0;" (reset) which cancels the preceding invert + bold.
if [ "$USE_COLOR" = 1 ]; then
  S_HDR_CYAN=$'\033[7;1;36m'
  S_HDR_SUB=$'\033[7;1;32m'
  S_HDR_YELLOW=$'\033[7;1;33m'
  S_HDR_RED=$'\033[7;1;31m'
  S_HDR_PURPLE=$'\033[7;1;35m'
  S_HDR_END=$'\033[0m'
else
  S_HDR_CYAN=''; S_HDR_SUB=''; S_HDR_YELLOW=''; S_HDR_RED=''; S_HDR_PURPLE=''; S_HDR_END=''
fi
