#!/bin/bash

# shellcheck disable=SC2034

# Symbol vocabulary.
# Characters only; colour is applied at the call site via $S_*/$I_*_C variants.
I_OK="✔"       # success
I_WARN="!"     # warning
I_ERROR="✖"    # error
I_INFO="ℹ"     # informational
I_BULLET="•"   # bullet / list marker
I_ARROW="→"    # right-pointing flow (e.g. "1.0.0 → 1.0.1")
I_QUESTION="?" # interactive prompt
I_TRACE="↳"   # trailing / subordinate detail (indented under a status line)
I_PROMPT="?"   # leading glyph on soft (confirmation) prompts, paired with S_PROMPT

# Back-compat aliases — call sites in lib/helpers.sh still reference these.
# Removed in a later phase when all call sites migrate to log_* helpers.
I_STOP="$I_ERROR"
I_END="$I_OK"
