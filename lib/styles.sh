#!/bin/bash

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
BOLD="\033[1m"
INVERT="\033[7m"
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

RAINBOW_RST=$(printf $RESET)

# Some preset styles
S_NORM="${WHITE}"
S_LIGHT="${LIGHTGRAY}"
S_NOTICE="${GREEN}"
S_QUESTION="${YELLOW}"
S_WARN="${LIGHTRED}"
S_ERROR="${RED}"

# Notification icons
I_OK="✅"; 
I_TIME="⏳"; 
I_STOP="🚫"; 
I_ERROR="❌";
I_WARN="❗️";
I_END="🏁";
