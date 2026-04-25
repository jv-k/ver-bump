#!/bin/bash

# shellcheck disable=SC2288
true

# ── Log helpers ────────────────────────────────────────────────────────────
# Every status line uses a 2-space gutter so messages read as subordinate to
# section headers. Pass the message without colour codes; helpers apply the
# icon, colour, and reset. Every colour variable is gated by USE_COLOR in
# lib/styles.sh, so piping / NO_COLOR / non-TTY strips ANSI automatically.

# log_success <msg> — green ✔ + plain body. %b on body interprets inline ANSI
# (e.g. ${S_OK}value${RESET}) without forcing every call site to printf.
log_success() { printf '  %b%s%b %b\n' "${S_OK-}" "${I_OK-}" "${RESET-}" "$1"; }

# log_warn <msg> — yellow ! + body
log_warn() { printf '  %b%s%b %b\n' "${S_ATTN-}" "${I_WARN-}" "${RESET-}" "$1"; }

# log_error <msg> — red ✖ + body, to stderr
log_error() { printf '  %b%s%b %b\n' "${S_ERROR-}" "${I_ERROR-}" "${RESET-}" "$1" >&2; }

# log_info <msg> — cyan ℹ + body
log_info() { printf '  %b%s%b %b\n' "${S_INFO-}" "${I_INFO-}" "${RESET-}" "$1"; }

# log_trace <detail> — 4-space indent, dim ↳ + dim body (subordinate line)
log_trace() {
  printf '    %b%s %b%b\n' "${S_DIM-}" "${I_TRACE-}" "$1" "${RESET-}"
}

# ── Section headers — inverted-video bold pills ────────────────────────────
# section    <TEXT> [<count>]  — cyan pill  (primary heading)
# subsection <TEXT> [<count>]  — green pill (secondary heading)
# subsection_warn / subsection_error for yellow / red variants.

_render_pill() {
  local colour="$1" text="$2" count="${3-}" upper label
  upper=$(printf '%s' "$text" | tr '[:lower:]' '[:upper:]')
  if [ -n "$count" ]; then
    label=" ${upper} (${count}) "
  else
    label=" ${upper} "
  fi
  printf '\n%b%s%b\n' "${colour}" "${label}" "${S_HDR_END-}"
}

section()          { _render_pill "${S_HDR_CYAN-}"   "$1" "${2-}"; }
subsection()       { _render_pill "${S_HDR_SUB-}"  "$1" "${2-}"; }
subsection_warn()  { _render_pill "${S_HDR_YELLOW-}" "$1" "${2-}"; }
subsection_error() { _render_pill "${S_HDR_RED-}"    "$1" "${2-}"; }

# ── Branded version block — multi-line splash ─────────────────────────────
# Shown by --about and at the top of --help. Pulls name / version / author
# / homepage from package.json via jq, with a grep fallback.
version_block() {
  local ver author home name desc
  if command -v jq >/dev/null 2>&1; then
    ver=$(   jq -r '.version     // ""' "$MODULE_DIR/package.json" )
    author=$(jq -r '.author      // ""' "$MODULE_DIR/package.json" )
    home=$(  jq -r '.homepage    // ""' "$MODULE_DIR/package.json" )
    name=$(  jq -r '.name        // "ver-bump"' "$MODULE_DIR/package.json" )
    desc=$(  jq -r '.description // ""' "$MODULE_DIR/package.json" )
  else
    ver="" author="" home="" name="ver-bump" desc=""
  fi

  printf '\n'
  printf '  %b%s%b %b v%s%b\n' \
    "${S_INFO-}${BOLD-}" "${name}" "${RESET-}" \
    "${S_OK-}${BOLD-}" "${ver}" "${RESET-}"
  printf '\n'
  if [ -n "$desc" ]; then
    printf '  %b%s%b\n\n' "${S_DIM-}" "${desc}" "${RESET-}"
  fi
  printf '  %b%s%b Author:   %s\n'   "${S_BULLET-}" "${I_BULLET-}" "${RESET-}" "${author}"
  printf '  %b%s%b Homepage: %s\n\n' "${S_BULLET-}" "${I_BULLET-}" "${RESET-}" "${home}"
}
