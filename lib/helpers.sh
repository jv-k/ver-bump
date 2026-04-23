#!/bin/bash

# shellcheck disable=SC2288
true

# fail <exit_code> <message> [hint]
#   Writes a red labeled error line to stderr, optionally followed by a
#   dim hint line, then exits with <exit_code>.
#
# Exit code convention (see README / v2.0 plan §1.3):
#   0  success
#   1  generic error
#   2  usage / arg-parse error
#   3  precondition (dirty tree, missing tag, SemVer parse failure,
#                    missing package.json, missing dependency like git/jq)
#   4  hook failure (reserved)
#   5  user abort (declined prompt)
fail() {
  local code=$1
  local msg=$2
  local hint=${3-}
  printf '\n%b%s Error:%b %s%b\n' "${S_ERROR-}" "${I_ERROR-}" "${S_NORM-}" "$msg" "${RESET-}" >&2
  if [ -n "$hint" ]; then
    printf '%b  Hint: %s%b\n' "${S_LIGHT-}" "$hint" "${RESET-}" >&2
  fi
  exit "$code"
}

# Returns 0 (success) if $1 is a non-empty decimal integer, non-zero otherwise.
is_number() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

# Returns 0 if $1 looks like a SemVer 2.0 version (MAJOR.MINOR.PATCH with
# optional -prerelease and +build metadata). Uses the official regex from
# https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
is_semver() {
  [[ "$1" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(\.(0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*))*))?(\+([0-9a-zA-Z-]+(\.[0-9a-zA-Z-]+)*))?$ ]]
}

# Bump a SemVer prerelease version's trailing numeric counter.
# Examples:
#   1.2.3-dev.6         -> 1.2.3-dev.7
#   4.0.0-rc.9          -> 4.0.0-rc.10
#   1.0.0-alpha         -> 1.0.0-alpha.1   (no counter → append ".1")
#   2.1.0-beta.3+b.sha  -> 2.1.0-beta.4+b.sha   (build metadata preserved)
# If $1 isn't a prerelease (no "-"), echoes input unchanged and returns 1.
bump-prerelease() {
  local input="$1" base pre build=""
  # Split off build metadata (everything after '+')
  if [[ "$input" == *+* ]]; then
    build="+${input#*+}"
    input="${input%%+*}"
  fi
  if [[ "$input" != *-* ]]; then
    printf '%s' "${input}${build}"
    return 1
  fi
  base="${input%%-*}"
  pre="${input#*-}"

  local -a parts
  IFS='.' read -r -a parts <<< "$pre"
  local last_idx=$(( ${#parts[@]} - 1 ))
  local last="${parts[$last_idx]}"

  if is_number "$last"; then
    parts[last_idx]=$((last + 1))
  else
    # No numeric counter yet — start one at 1
    parts+=("1")
  fi

  local joined
  joined=$( IFS='.'; echo "${parts[*]}" )
  printf '%s' "${base}-${joined}${build}"
}

# Writes JSON to a temp file next to the target, then atomically replaces it.
# Args: <file> <jq-expr> [<jq-args>...]
# Keeps stderr separate so jq warnings can't corrupt the JSON output.
# Returns 0 on success, prints jq error to stderr and returns non-zero on failure.
jq_inplace() {
  local file="$1"; shift
  local expr="$1"; shift
  local tmp err rc
  tmp=$(mktemp "${file}.XXXXXX") || return 1
  err=$(mktemp "${file}.err.XXXXXX") || { rm -f "$tmp"; return 1; }
  jq "$@" "$expr" "$file" >"$tmp" 2>"$err"; rc=$?
  if [ "$rc" -eq 0 ] && [ -s "$tmp" ]; then
    # Surface any jq warnings to the caller's stderr but still commit the write.
    [ -s "$err" ] && cat "$err" >&2
    rm -f "$err"
    mv -f "$tmp" "$file"
    return 0
  fi
  cat "$err" >&2
  rm -f "$tmp" "$err"
  return 1
}

# Ensure required external tools are present before mutating the repo.
check-dependencies() {
  local tool missing=()
  for tool in git jq; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  if (( ${#missing[@]} )); then
    fail 3 \
      "Missing required tool(s): ${missing[*]}." \
      "Install the missing tool(s) (e.g. 'brew install ${missing[*]}' on macOS, or use your system package manager) and retry."
  fi
}

# ── Log helpers ────────────────────────────────────────────────────────────
# Every status line uses a 2-space gutter so messages read as subordinate to
# section headers. Pass the message without colour codes; helpers apply the
# icon, colour, and reset. Every colour variable is gated by USE_COLOR in
# lib/styles.sh, so piping / NO_COLOR / non-TTY strips ANSI automatically.

# log_success <msg> — green ✔ + plain body
log_success() { printf '  %b%s%b %s\n' "${S_OK-}" "${I_OK-}" "${RESET-}" "$1"; }

# log_warn <msg> — yellow ! + plain body
log_warn() { printf '  %b%s%b %s\n' "${S_ATTN-}" "${I_WARN-}" "${RESET-}" "$1"; }

# log_error <msg> — red ✖ + plain body, to stderr
log_error() { printf '  %b%s%b %s\n' "${S_ERROR-}" "${I_ERROR-}" "${RESET-}" "$1" >&2; }

# log_info <msg> — cyan ℹ + plain body
log_info() { printf '  %b%s%b %s\n' "${S_INFO-}" "${I_INFO-}" "${RESET-}" "$1"; }

# log_trace <detail> — 4-space indent, dim ↳ + dim body (subordinate line)
log_trace() {
  printf '    %b%s %s%b\n' "${S_DIM-}" "${I_TRACE-}" "$1" "${RESET-}"
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

# Show --help.
usage() {
  local SCRIPT_VER SCRIPT_NAME SCRIPT_AUTH SCRIPT_HOME env_var env_var_val
  local env_vars=( SCRIPT_VER SCRIPT_NAME SCRIPT_AUTH SCRIPT_HOME )

  if command -v jq >/dev/null 2>&1; then
    SCRIPT_VER=$(  jq -r '.version  // ""'         "$MODULE_DIR/package.json" )
    SCRIPT_NAME=$( jq -r '.name     // "ver-bump"' "$MODULE_DIR/package.json" )
    SCRIPT_AUTH=$( jq -r '.author   // ""'         "$MODULE_DIR/package.json" )
    SCRIPT_HOME=$( jq -r '.homepage // ""'         "$MODULE_DIR/package.json" )
  else
    # Fallback: grep + trim (works without jq for --help alone)
    SCRIPT_VER=$(  cd "$MODULE_DIR" && grep version  package.json | head -1 )
    SCRIPT_NAME=$( cd "$MODULE_DIR" && grep name     package.json | head -1 )
    SCRIPT_AUTH=$( cd "$MODULE_DIR" && grep author   package.json | head -1 )
    SCRIPT_HOME=$( cd "$MODULE_DIR" && grep homepage package.json | head -1 | sed -ne 's/.*\(http[^"]*\).*/\1/p' )

    for env_var in "${env_vars[@]}"; do
      env_var_val=$( printf '%s' "${!env_var}" | awk -F: '{ print $2 }' | sed 's/[",]//g' | sed "s/^[ \t]*//" )
      printf -v "$env_var" '%s' "$env_var_val"
    done
  fi

  # rip off the oh-my-zsh logo, clearly ;)
  printf  "%s _ _  %s___  %s___ %s     %s ___  %s_ _ %s __ __ %s ___  %s\n" "${RAINBOW[@]}" "$RAINBOW_RST"
  printf  "%s| | |%s| __>%s| . \%s ___ %s| . >%s| | |%s|  \  \%s| . \ %s\n" "${RAINBOW[@]}" "$RAINBOW_RST"
  printf  "%s| ' |%s| _> %s|   /%s|___|%s| . \%s| ' |%s|     |%s|  _/ %s\n" "${RAINBOW[@]}" "$RAINBOW_RST"
  printf  "%s|__/ %s|___>%s|_\_\%s     %s|___/%s\___/%s|_|_|_|%s|_|   %s\n" "${RAINBOW[@]}" "$RAINBOW_RST"

  # Branded header pill + author/homepage bullets + dim tagline.
  printf '\n  %b %s v%s %b\n' "${S_HDR_CYAN-}" "${SCRIPT_NAME}" "${SCRIPT_VER}" "${S_HDR_END-}"
  printf '  %b%s%b Author:   %s\n'   "${S_BULLET-}" "${I_BULLET-}" "${RESET-}" "${SCRIPT_AUTH}"
  printf '  %b%s%b Homepage: %s\n\n' "${S_BULLET-}" "${I_BULLET-}" "${RESET-}" "${SCRIPT_HOME}"
  printf '  %bA bash release CLI — SemVer bump, CHANGELOG, tag, push, driven by Conventional Commits.%b\n' \
    "${S_DIM-}" "${RESET-}"

  # USAGE section pill
  printf '\n%b USAGE %b\n' "${S_HDR_CYAN-}" "${S_HDR_END-}"
  printf '  %b%s%b [-v <version>] [-m <message>] [-f <file.json>]... [-p <remote>] [-t <tag-prefix>] [-B <branch-prefix>] [-d] [-n] [-b] [-c] [-l] [-h]\n' \
    "${BOLD-}" "${SCRIPT_NAME}" "${RESET-}"
  printf '  %b%s%b [--completions <shell>] [--about]\n' \
    "${BOLD-}" "${SCRIPT_NAME}" "${RESET-}" 1>&2;

  # Column width for the label (flag + arg) column. The longest label is
  # "-B, --branch-prefix <prefix>" = 28 chars; 32 gives a 4-space gutter.
  local OPT_COL=32

  # print-opt-row <short> <long> <arg-or-empty> <description>
  # Pads the visible label to $OPT_COL columns (ignoring ANSI), then
  # emits the colored label + description.
  print-opt-row() {
    local short="$1" long="$2" arg="$3" desc="$4"
    local plain label pad head_plain head_label
    if [ -n "$short" ]; then
      head_plain="${short}, ${long}"
      head_label="${S_WARN}${short}${S_NORM}, ${S_WARN}${long}${S_NORM}"
    else
      # Align long-only rows under the long-flag column (after "    ")
      head_plain="    ${long}"
      head_label="    ${S_WARN}${long}${S_NORM}"
    fi
    if [ -n "$arg" ]; then
      plain="${head_plain} ${arg}"
      label="${head_label} ${arg}"
    else
      plain="${head_plain}"
      label="${head_label}"
    fi
    if (( ${#plain} >= OPT_COL )); then
      pad=" "
    else
      printf -v pad '%*s' $((OPT_COL - ${#plain})) ''
    fi
    echo -e "${label}${pad}${desc}"
  }

  # print-opt-cont <text> — continuation row, aligned under the description column
  print-opt-cont() {
    printf '%*s' "$OPT_COL" ''
    echo -e "$1"
  }

  printf '\n%b OPTIONS %b %b(long forms accept %b--name value%b or %b--name=value%b)%b\n' \
    "${S_HDR_CYAN-}" "${S_HDR_END-}" \
    "${S_DIM-}" "${S_NORM-}" "${S_DIM-}" "${S_NORM-}" "${S_DIM-}" "${RESET-}"
  print-opt-row "-v" "--version"       "<version>"   "Specify a manual SemVer version number (validated)."
  print-opt-row "-m" "--message"       "<message>"   "Custom annotated-tag release message."
  print-opt-row "-f" "--file"          "<file.json>" "Also bump \"version\" in this JSON file. Repeatable:"
  print-opt-cont "${S_NORM}ver-bump -f src/plugin/package.json -f composer.json"
  print-opt-row "-p" "--push"          "<remote>"    "Push release branch + tag to <remote> at end of run."
  print-opt-row "-t" "--tag-prefix"    "<prefix>"    "Override tag prefix (default: ${S_NORM}v${S_LIGHT})."
  print-opt-row "-B" "--branch-prefix" "<prefix>"    "Override branch prefix (default: ${S_NORM}release-${S_LIGHT})."
  print-opt-row "-d" "--dry-run"       ""            "Dry-run: print every side-effect without executing."
  print-opt-row "-n" "--no-commit"     ""            "Disable commit (and tag + push) after bumping files."
  print-opt-row "-b" "--no-branch"     ""            "Disable creating a new release-x.x.x branch."
  print-opt-row "-c" "--no-changelog"  ""            "Disable updating CHANGELOG.md automatically."
  print-opt-row "-l" "--pause-changelog" ""          "Pause before commit so CHANGELOG.md can be edited."
  print-opt-row "-h" "--help"          ""            "Show this help message."
  print-opt-row ""   "--about"              ""            "Print name, version, author, and homepage; then exit."
  print-opt-row ""   "--completions"        "<shell>"     "Emit completion script for ${S_NORM}bash${S_LIGHT}, ${S_NORM}zsh${S_LIGHT}, or ${S_NORM}fish${S_LIGHT}."
  print-opt-row ""   "--install-completions" "[=<shell>]" "Install completion script for the detected shell (or specified one)."

  # EXAMPLES section pill
  printf '\n%b EXAMPLES %b\n' "${S_HDR_CYAN-}" "${S_HDR_END-}"
  print-opt-row "" "${SCRIPT_NAME}"                  ""              "Interactive — reads commits, suggests bump, prompts."
  print-opt-row "" "${SCRIPT_NAME} -v 2.0.0"         ""              "Non-interactive, explicit version."
  print-opt-row "" "${SCRIPT_NAME} --dry-run"        ""              "Preview every side-effect without executing."
  print-opt-row "" "${SCRIPT_NAME} -p origin"        ""              "Push the release branch + tag when done."
  print-opt-row "" "${SCRIPT_NAME} -t release/"      ""              "Use a custom tag prefix (e.g. ${S_NORM}release/1.2.3${S_LIGHT})."
  print-opt-row "" "${SCRIPT_NAME} -f composer.json" ""              "Also bump version in an extra JSON file."
  print-opt-row "" "${SCRIPT_NAME} --about"          ""              "Show branded version info."
  print-opt-row "" "${SCRIPT_NAME} --install-completions" ""         "Install shell completions (auto-detects shell)."
  echo
}

# Emit a shell completion script to stdout. Supported: bash, zsh, fish.
# Usage: ver-bump --completions <shell>
emit-completions() {
  case "$1" in
    bash) _emit-bash-completion ;;
    zsh)  _emit-zsh-completion  ;;
    fish) _emit-fish-completion ;;
    ''|-h|--help)
      echo "Usage: ver-bump --completions <bash|zsh|fish>"
      echo
      echo "Install:"
      echo "  bash: ver-bump --completions bash > /usr/local/etc/bash_completion.d/ver-bump"
      echo "  zsh:  ver-bump --completions zsh  > \"\${fpath[1]}/_ver-bump\"  # then autoload"
      echo "  fish: ver-bump --completions fish > ~/.config/fish/completions/ver-bump.fish"
      return 0
    ;;
    *)
      echo "Unknown shell: $1 (supported: bash, zsh, fish)" >&2
      return 1
    ;;
  esac
}

# detect-shell — print bash|zsh|fish for the user's login shell, or return 1.
# Primary signal: $SHELL basename. Fallback: parent process name. Strips any
# leading '-' (login-shell argv[0] convention).
detect-shell() {
  local shell
  if [ -n "${SHELL-}" ]; then
    shell="$(basename "$SHELL")"
  fi
  if [ -z "${shell-}" ] && command -v ps >/dev/null 2>&1; then
    shell="$(ps -p "$PPID" -o comm= 2>/dev/null | tr -d ' ')"
    shell="$(basename "$shell")"
  fi
  shell="${shell#-}"
  case "$shell" in
    bash|zsh|fish) printf '%s' "$shell" ;;
    *) return 1 ;;
  esac
}

# install-completions <shell> — generate the matching completion script and
# write it to a user-scope location that each shell is already configured to
# read. Supports bash / zsh / fish. Overwrites an existing file (content is
# deterministic). Honours FLAG_DRYRUN by printing the target path only.
install-completions() {
  local shell="$1" dir dest content
  case "$shell" in
    bash)
      dir="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"
      dest="${dir}/ver-bump"
      content=$(_emit-bash-completion)
      ;;
    zsh)
      dir="${HOME}/.zfunc"
      dest="${dir}/_ver-bump"
      content=$(_emit-zsh-completion)
      ;;
    fish)
      dir="${__fish_config_dir:-${XDG_CONFIG_HOME:-$HOME/.config}/fish}/completions"
      dest="${dir}/ver-bump.fish"
      content=$(_emit-fish-completion)
      ;;
    *)
      fail 2 \
        "Unsupported shell: '${shell}'." \
        "Supported: bash, zsh, fish. Pass --install-completions=<shell> explicitly."
      ;;
  esac

  if [ "${FLAG_DRYRUN:-false}" = true ]; then
    printf '%b[dry-run]%b would write %s\n' "${S_LIGHT-}" "${RESET-}" "$dest" >&2
    return 0
  fi

  mkdir -p "$dir" || fail 3 \
    "Cannot create directory: ${dir}" \
    "Check filesystem permissions on the parent path."

  printf '%s\n' "$content" > "$dest" || fail 3 \
    "Cannot write to: ${dest}" \
    "Check filesystem permissions or use a writable HOME."

  log_success "Installed ${shell} completion → ${S_NORM}${dest}${RESET-}"

  if [ "$shell" = zsh ]; then
    log_info "Ensure ~/.zfunc is on \$fpath. Add to ~/.zshrc if missing:"
    log_trace "fpath+=(~/.zfunc) && autoload -U compinit && compinit"
  fi
}

_emit-bash-completion() {
  cat <<'BASH_EOF'
# ver-bump bash completion — source this or drop it in your bash_completion.d
# shellcheck disable=SC2207
_ver_bump() {
    local cur prev opts
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Options that take a file argument → complete .json paths
    case "$prev" in
        -f|--file)
            COMPREPLY=( $(compgen -f -X '!*.json' -- "$cur") )
            return 0
            ;;
        --completions|--install-completions)
            COMPREPLY=( $(compgen -W 'bash zsh fish' -- "$cur") )
            return 0
            ;;
        # Options that take a free-form argument — no completion
        -v|--version|-m|--message|-p|--push|-t|--tag-prefix|-B|--branch-prefix)
            return 0
            ;;
    esac

    opts="--version --message --file --push --tag-prefix --branch-prefix \
          --dry-run --no-commit --no-branch --no-changelog --pause-changelog \
          --help --completions --install-completions --about \
          -v -m -f -p -t -B -d -n -b -c -l -h"
    COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
}
complete -F _ver_bump ver-bump
complete -F _ver_bump ver-bump.sh
BASH_EOF
}

_emit-zsh-completion() {
  cat <<'ZSH_EOF'
#compdef ver-bump ver-bump.sh
# ver-bump zsh completion — put this file as _ver-bump in a dir on $fpath,
# then `autoload -U compinit && compinit`.

_ver_bump() {
  _arguments -s -S \
    '(-v --version)'{-v,--version}'[manual SemVer version]:version:' \
    '(-m --message)'{-m,--message}'[custom annotated-tag message]:message:' \
    '(-f --file)'{-f,--file}'[bump version in extra JSON file]:file:_files -g "*.json"' \
    '(-p --push)'{-p,--push}'[push branch + tag to <remote>]:remote:' \
    '(-t --tag-prefix)'{-t,--tag-prefix}'[override tag prefix]:prefix:' \
    '(-B --branch-prefix)'{-B,--branch-prefix}'[override branch prefix]:prefix:' \
    '(-d --dry-run)'{-d,--dry-run}'[print side-effects without executing]' \
    '(-n --no-commit)'{-n,--no-commit}'[disable commit (and tag + push)]' \
    '(-b --no-branch)'{-b,--no-branch}'[disable creating release branch]' \
    '(-c --no-changelog)'{-c,--no-changelog}'[disable CHANGELOG.md update]' \
    '(-l --pause-changelog)'{-l,--pause-changelog}'[pause before commit]' \
    '(-h --help)'{-h,--help}'[show help]' \
    '--completions[emit completion script]:shell:(bash zsh fish)' \
    '--install-completions[install completion script for detected / specified shell]::shell:(bash zsh fish)' \
    '--about[print branded version info and exit]'
}

_ver_bump "$@"
ZSH_EOF
}

_emit-fish-completion() {
  cat <<'FISH_EOF'
# ver-bump fish completion — save to ~/.config/fish/completions/ver-bump.fish
for _cmd in ver-bump ver-bump.sh
    complete -c $_cmd -s v -l version        -r -d 'Manual SemVer version'
    complete -c $_cmd -s m -l message        -r -d 'Custom annotated-tag message'
    complete -c $_cmd -s f -l file           -r -a '(__fish_complete_suffix .json)' -d 'Bump version in extra JSON file'
    complete -c $_cmd -s p -l push           -r -d 'Push branch + tag to <remote>'
    complete -c $_cmd -s t -l tag-prefix     -r -d 'Override tag prefix'
    complete -c $_cmd -s B -l branch-prefix  -r -d 'Override branch prefix'
    complete -c $_cmd -s d -l dry-run        -d 'Print side-effects without executing'
    complete -c $_cmd -s n -l no-commit      -d 'Disable commit (and tag + push)'
    complete -c $_cmd -s b -l no-branch      -d 'Disable creating release branch'
    complete -c $_cmd -s c -l no-changelog   -d 'Disable CHANGELOG.md update'
    complete -c $_cmd -s l -l pause-changelog -d 'Pause before commit'
    complete -c $_cmd -s h -l help           -d 'Show help'
    complete -c $_cmd      -l completions    -x -a 'bash zsh fish' -d 'Emit completion script'
    complete -c $_cmd      -l install-completions -a 'bash zsh fish' -d 'Install completions for detected/specified shell'
    complete -c $_cmd      -l about          -d 'Print branded version info and exit'
end
FISH_EOF
}

# Translate GNU-style long options (--dry-run, --version=1.2.3, --file foo.json)
# into their short-form equivalents so getopts can process them uniformly.
# Writes the translated argv to the global array NORMALIZED_ARGV. On an
# unknown long option or a missing required value, prints an error and exits 1.
normalize-long-opts() {
  local arg name val has_val short needs_arg
  NORMALIZED_ARGV=()

  while (( $# )); do
    arg="$1"; shift
    # Bare "--" stops option processing; pass it and remaining args through
    if [ "$arg" = "--" ]; then
      NORMALIZED_ARGV+=("--" "$@")
      return 0
    fi

    # Special case: --about — print the branded version block and exit 0,
    # so users can check what they have installed without needing a
    # package.json or a git repo in the working directory.
    if [ "$arg" = "--about" ]; then
      version_block
      exit 0
    fi

    # Special case: --install-completions[=shell] — detect the user's shell
    # (or accept an explicit override) and drop the matching completion
    # script into a user-scope location. Exits immediately.
    if [ "$arg" = "--install-completions" ] || [[ "$arg" == "--install-completions="* ]]; then
      local ic_shell ic_a
      # getopts hasn't run yet, so FLAG_DRYRUN is unset even if --dry-run
      # was seen earlier. Walk both already-normalized and remaining args
      # so install-completions can honour dry-run in either order.
      for ic_a in "$@" "${NORMALIZED_ARGV[@]}"; do
        case "$ic_a" in --dry-run|-d) FLAG_DRYRUN=true; break ;; esac
      done
      if [[ "$arg" == "--install-completions="* ]]; then
        ic_shell="${arg#--install-completions=}"
        [ -z "$ic_shell" ] && fail 2 \
          "--install-completions= requires a shell name." \
          "Supported: bash, zsh, fish."
      else
        ic_shell=$(detect-shell) || fail 2 \
          "Could not auto-detect your shell from \$SHELL." \
          "Pass --install-completions=<bash|zsh|fish> explicitly."
      fi
      install-completions "$ic_shell"
      exit $?
    fi

    # Special case: --completions [shell] — emit and exit immediately, so
    # users can run this without a package.json or a git repo present.
    if [ "$arg" = "--completions" ] || [[ "$arg" == "--completions="* ]]; then
      local shell
      if [[ "$arg" == "--completions="* ]]; then
        shell="${arg#--completions=}"
      elif (( $# )) && [ "${1:0:1}" != "-" ]; then
        shell="$1"; shift
      else
        shell=""
      fi
      emit-completions "$shell"
      exit $?
    fi

    if [[ "$arg" == --*=* ]]; then
      name="${arg%%=*}"; name="${name#--}"
      val="${arg#*=}"
      has_val=1
    elif [[ "$arg" == --?* ]]; then
      name="${arg#--}"
      val=""
      has_val=0
    else
      NORMALIZED_ARGV+=("$arg")
      continue
    fi

    case "$name" in
      version)         short="-v"; needs_arg=1 ;;
      message)         short="-m"; needs_arg=1 ;;
      file)            short="-f"; needs_arg=1 ;;
      push)            short="-p"; needs_arg=1 ;;
      tag-prefix)      short="-t"; needs_arg=1 ;;
      branch-prefix)   short="-B"; needs_arg=1 ;;
      dry-run)         short="-d"; needs_arg=0 ;;
      no-commit)       short="-n"; needs_arg=0 ;;
      no-branch)       short="-b"; needs_arg=0 ;;
      no-changelog)    short="-c"; needs_arg=0 ;;
      pause-changelog) short="-l"; needs_arg=0 ;;
      help)            short="-h"; needs_arg=0 ;;
      *)
        fail 2 \
          "Invalid option: --${name}" \
          "Run 'ver-bump --help' to see the list of supported options."
      ;;
    esac

    NORMALIZED_ARGV+=("$short")
    if (( needs_arg )); then
      if (( has_val )); then
        # Reject --name= (empty value after '='). Without this, getopts would
        # silently consume the next positional as the flag's value.
        if [ -z "$val" ]; then
          fail 2 \
            "Option --${name} requires a non-empty value." \
            "Pass a value: --${name} <value> or --${name}=<value>."
        fi
        NORMALIZED_ARGV+=("$val")
      elif (( $# )) && [ "${1:0:1}" != "-" ]; then
        NORMALIZED_ARGV+=("$1"); shift
      else
        fail 2 \
          "Option --${name} requires an argument." \
          "Pass a value: --${name} <value> or --${name}=<value>."
      fi
    elif (( has_val )); then
      fail 2 \
        "Option --${name} doesn't take a value." \
        "Drop the '=<value>' — --${name} is a boolean flag."
    fi
  done
}

# Process script options
process-arguments() {
  local OPTIONS OPTIND OPTARG

  normalize-long-opts "$@"
  set -- ${NORMALIZED_ARGV[@]+"${NORMALIZED_ARGV[@]}"}

  # Get positional parameters
  while getopts ":v:p:m:f:t:B:hbncdl" OPTIONS; do # Note: Adding the first : before the flags takes control of flags and prevents default error msgs.
    case "$OPTIONS" in
      h )
        # Show help
        usage
        exit 0
      ;;
      v )
        # User has supplied a version number — validate SemVer
        if ! is_semver "$OPTARG"; then
          fail 2 \
            "Version '$OPTARG' is not a valid SemVer 2.0 version (expected MAJOR.MINOR.PATCH[-prerelease][+build])." \
            "Pass a SemVer 2.0 version, e.g. -v 1.2.3 or -v 1.2.3-rc.1+build.42."
        fi
        V_USR_SUPPLIED=$OPTARG
      ;;
      m )
        REL_NOTE=$OPTARG
        # Custom release note
        echo -e "\n${S_LIGHT}Option set:${RESET} release note: ${S_NORM}'$REL_NOTE'${RESET}"
      ;;
      f )
        echo -e "\n${S_LIGHT}Option set:${RESET} JSON file via [-f]: <${S_NORM}${OPTARG}${RESET}>"
        # Store JSON filenames(s)
        JSON_FILES+=("$OPTARG")
      ;;
      p )
        FLAG_PUSH=true
        PUSH_DEST=${OPTARG} # Replace default with user input
        echo -e "\n${S_LIGHT}Option set:${RESET} push to <${S_NORM}${PUSH_DEST}${RESET}> as the last step."
      ;;
      t )
        TAG_PREFIX=$OPTARG
        echo -e "\n${S_LIGHT}Option set:${RESET} tag prefix: <${S_NORM}${TAG_PREFIX}${RESET}>"
      ;;
      B )
        REL_PREFIX=$OPTARG
        echo -e "\n${S_LIGHT}Option set:${RESET} branch prefix: <${S_NORM}${REL_PREFIX}${RESET}>"
      ;;
      d )
        FLAG_DRYRUN=true
        echo -e "\n${S_LIGHT}Option set:${RESET} dry-run — no files, commits, tags, or pushes will be made."
      ;;
      n )
        FLAG_NOCOMMIT=true
        echo -e "\n${S_LIGHT}Option set:${RESET} disable commit (and tag + push) after bumping files."
      ;;
      b )
        FLAG_NOBRANCH=true
        echo -e "\n${S_LIGHT}Option set:${RESET} disable creating a new release-x.x.x branch."
      ;;
      c )
        FLAG_NOCHANGELOG=true
        echo -e "\n${S_LIGHT}Option set:${RESET} disable updating CHANGELOG.md automatically."
      ;;
      l )
        FLAG_CHANGELOG_PAUSE=true
        echo -e "\n${S_LIGHT}Option set:${RESET} pause to allow amending CHANGELOG.md."
      ;;
      \? )
        fail 2 \
          "Invalid option: -$OPTARG" \
          "Run 'ver-bump --help' to see the list of supported options."
      ;;
      : )
        fail 2 \
          "Option -$OPTARG requires an argument." \
          "Pass a value after the flag, e.g. -$OPTARG <value>."
      ;;
    esac
  done
}

# Dry-run helper: runs $@ if not in dry-run mode, otherwise prints what would run.
dryrun() {
  if [ "$FLAG_DRYRUN" = true ]; then
    echo -e "${S_LIGHT}[dry-run]${RESET} $*" >&2
    return 0
  fi
  "$@"
}

# If there are no commits in repo, quit, because you can't tag with zero commits.
check-commits-exist() {
  if ! git rev-parse HEAD &> /dev/null; then
    fail 3 \
      "Your current branch doesn't have any commits yet. Can't tag without at least one commit." \
      "Make an initial commit first: git commit --allow-empty -m 'initial commit'."
  fi
}

# Suggests version from VERSION file, or grabs from user supplied -v <version>.
# If none is set, suggest default from options.

# - If <package.json> doesn't exist, warn + exit
# - If -v specified, set version from that
# - Else,
#   - Grab from package.json
#   - Suggest incremented number
#   - Give prompt to user to modify
# - Set globally

# According to SemVer 2.0.0, given a version number MAJOR.MINOR.PATCH, suggest incremented value:
# — MAJOR version when you make incompatible API changes,
# — MINOR version when you add functionality in a backwards compatible manner, and
# — PATCH version when you make backwards compatible bug fixes.
process-version() {
  # Read V_PREV from VER_FILE (package.json) for display + same-version dedup.
  # When -v is supplied, V_PREV is best-effort: the user already gave us V_NEW,
  # so missing/empty VER_FILE is allowed. Without -v we need a version to bump,
  # so a missing VER_FILE is a hard error.
  if [ -f "$VER_FILE" ] && [ -s "$VER_FILE" ]; then
    V_PREV=$( jq -r '.version // empty' "$VER_FILE" 2>/dev/null )

    if [ -n "$V_PREV" ]; then
      echo -e "\nCurrent version read from <${S_NORM}${VER_FILE}${RESET}>: ${S_NORM}$V_PREV${RESET}"
      set-v-suggest "$V_PREV" # check + compute next version from conventional commits (or patch +1)
    elif [ -z "$V_USR_SUPPLIED" ]; then
      fail 3 \
        "<${VER_FILE}> doesn't contain a 'version' field." \
        "Add a top-level \"version\" key to ${VER_FILE}, or pass an explicit version with -v <version>."
    fi
  elif [ -z "$V_USR_SUPPLIED" ]; then
    local reason
    if [ ! -f "$VER_FILE" ]; then
      reason="was not found"
    elif [ ! -s "$VER_FILE" ]; then
      reason="is empty"
    else
      reason="could not be read"
    fi
    fail 3 \
      "<${VER_FILE}> ${reason}." \
      "Run ver-bump inside a directory with a valid ${VER_FILE}, pass -v <version> to bypass, or override via VER_FILE=<path>."
  fi

  # If a version number is supplied by the user with [-v <version number>] — use it!
  if [ -n "$V_USR_SUPPLIED" ]; then
    echo -e "\nVersion supplied via [-v]: ${S_NORM}${V_USR_SUPPLIED}${RESET}"
    V_NEW="${V_USR_SUPPLIED}"
  else
    # Display a suggested version
    echo -ne "\n${S_QUESTION}Enter a new version number or press <enter> to use [${S_NORM}$V_SUGGEST${S_QUESTION}]:${RESET} "
    read -r V_USR_INPUT

    if [ "$V_USR_INPUT" = "" ]; then
      # User accepted the suggested version
      V_NEW=$V_SUGGEST
    else
      V_NEW=$V_USR_INPUT
    fi

    # Validate whatever we end up with (suggested or entered) as SemVer.
    # This only runs in interactive path; -v already validates at parse time.
    if ! is_semver "$V_NEW"; then
      fail 3 \
        "Version '$V_NEW' is not a valid SemVer 2.0 version." \
        "Enter a SemVer 2.0 version (MAJOR.MINOR.PATCH[-prerelease][+build]), e.g. 1.2.3 or 1.2.3-rc.1."
    fi
  fi
}

# Inspect commit messages since the previous version's tag and suggest the
# appropriate bump per Conventional Commits:
#   - BREAKING CHANGE / <type>! → major
#   - feat:                     → minor
#   - anything else             → patch
# Falls back to patch if no tag for previous version exists, or if parsing fails.
#
# Subject vs. body handling: we split every commit into its subject (first
# line) and body (rest) via a record-separator/unit-separator format. Only
# the subject is matched against the "<type>:" / "<type>!:" patterns, so a
# commit body that quotes a prior subject can't trigger a spurious bump.
# "BREAKING CHANGE:" / "BREAKING-CHANGE:" is matched only when it appears as
# a footer — start-of-line followed by the token and a colon.
suggest-bump-level() {
  local prev_tag log level="patch" record subject body line
  prev_tag="${TAG_PREFIX}${1}"

  if ! git rev-parse --verify "refs/tags/${prev_tag}" >/dev/null 2>&1; then
    echo "patch"; return
  fi

  # %s = subject, %b = body. RS (0x1e) separates subject/body; US (0x1f)
  # separates commits. Both are unlikely in any sane commit message.
  log=$(git log --format='%s%x1e%b%x1f' "${prev_tag}..HEAD" 2>/dev/null) || {
    echo "patch"; return
  }

  local re_breaking_subject='^[a-zA-Z]+(\([^)]*\))?!:'
  local re_feat='^feat(\([^)]*\))?:'
  local re_breaking_footer='^BREAKING[ -]CHANGE:'

  while IFS= read -r -d $'\x1f' record; do
    # Trim the newline git inserts between format records.
    record="${record#$'\n'}"
    [ -z "$record" ] && continue
    subject="${record%%$'\x1e'*}"
    if [[ "$record" == *$'\x1e'* ]]; then
      body="${record#*$'\x1e'}"
    else
      body=""
    fi

    # Breaking change via "<type>!:" — subject only.
    if [[ "$subject" =~ $re_breaking_subject ]]; then
      echo "major"; return
    fi

    # Breaking change footer — anchored at start of a body line.
    if [ -n "$body" ]; then
      while IFS= read -r line; do
        if [[ "$line" =~ $re_breaking_footer ]]; then
          echo "major"; return
        fi
      done <<< "$body"
    fi

    # feat: → minor (subject only; never downgrade).
    if [[ "$subject" =~ $re_feat ]]; then
      level="minor"
    fi
  done <<< "$log"

  echo "$level"
}

set-v-suggest() {
  local V_PREV_LIST V_MAJOR V_MINOR V_PATCH BUMP

  # Dispatch on whether the input is a valid SemVer 2.0 string first.
  # Semver inputs take the prerelease-counter or conventional-commits branch.
  # Anything else is treated as best-effort "dotted numeric" and only bumped
  # when every component is a decimal integer.
  if is_semver "$1"; then
    # Prerelease counter bumping: if the previous version has a prerelease
    # identifier (e.g. 4.0.0-dev.6, 1.2.3-rc.1, 1.0.0-alpha), bump the
    # trailing numeric counter — or append ".1" if there isn't one. Takes
    # precedence over conventional-commit bumping because pre-release
    # workflows iterate on the same MAJOR.MINOR.PATCH.
    if [[ "$1" == *-* ]]; then
      V_SUGGEST=$(bump-prerelease "$1")
      echo -e "${S_LIGHT}Detected prerelease — bumping trailing counter → ${S_NORM}$V_SUGGEST${RESET}"
      return
    fi

    # Pristine MAJOR.MINOR.PATCH (+build): bump per conventional commits.
    # is_semver already guarantees numeric components, so we can strip any
    # build metadata and bash-arithmetic the rest without re-validating.
    IFS='.' read -r V_MAJOR V_MINOR V_PATCH <<< "${1%%+*}"
    BUMP=$(suggest-bump-level "$1")
    case "$BUMP" in
      major)
        V_MAJOR=$((V_MAJOR + 1)); V_MINOR=0; V_PATCH=0
        echo -e "${S_LIGHT}Detected breaking change — suggesting ${S_NORM}major${RESET}${S_LIGHT} bump.${RESET}"
      ;;
      minor)
        V_MINOR=$((V_MINOR + 1)); V_PATCH=0
        echo -e "${S_LIGHT}Detected feat: commits — suggesting ${S_NORM}minor${RESET}${S_LIGHT} bump.${RESET}"
      ;;
      *)
        V_PATCH=$((V_PATCH + 1))
      ;;
    esac
    V_SUGGEST="$V_MAJOR.$V_MINOR.$V_PATCH"
    return
  fi

  # Non-SemVer input: best-effort dotted-numeric bump. Split via IFS read so
  # globbing can't kick in (silences ShellCheck SC2207 too). Only bump when
  # every component is a decimal integer; otherwise keep the input verbatim.
  local -a V_PREV_LIST
  IFS='.' read -r -a V_PREV_LIST <<< "$1"
  V_MAJOR=${V_PREV_LIST[0]-}
  V_MINOR=${V_PREV_LIST[1]-}
  V_PATCH=${V_PREV_LIST[2]-}

  if [ "${#V_PREV_LIST[@]}" -eq 3 ] \
     && is_number "$V_MAJOR" \
     && is_number "$V_MINOR" \
     && is_number "$V_PATCH"; then
    V_PATCH=$((V_PATCH + 1))
    V_SUGGEST="$V_MAJOR.$V_MINOR.$V_PATCH"
    return
  fi

  log_warn "${S_NORM}${1}${RESET} doesn't look like a SemVer-compatible version — couldn't bump automatically."
  # Keep the input as-is
  V_SUGGEST="$1"
}

#
check-branch-notexist() {
  [ "$FLAG_NOBRANCH" = true ] && return
  if git rev-parse --verify "${REL_PREFIX}${V_NEW}" &> /dev/null; then
    fail 3 \
      "Branch <${REL_PREFIX}${V_NEW}> already exists." \
      "Delete the existing branch (git branch -D ${REL_PREFIX}${V_NEW}), pick a different version, or pass -b/--no-branch to skip branch creation."
  fi
}

# Only tag if tag doesn't already exist
check-tag-exists() {
  local TAG_MSG
  TAG_MSG=$( git tag -l "${TAG_PREFIX}${V_NEW}" )
  if [ -n "$TAG_MSG" ]; then
    fail 3 \
      "A release with that tag version number already exists: ${TAG_MSG}" \
      "Delete the existing tag with: git tag -d ${TAG_MSG}, or pick a different version."
  fi
}

do-packagefile-bump() {
  local NOTICE_MSG
  NOTICE_MSG="<${S_NORM}package.json${RESET}>"

  # Skip entirely if package.json is absent. With -v + -f, the user may be
  # bumping only auxiliary JSON files — process-version already allowed
  # missing VER_FILE in that path.
  if [ ! -f package.json ]; then
    log_warn "${NOTICE_MSG} not found — skipping."
    return
  fi

  if [ "$V_NEW" = "$V_PREV" ]; then
    log_warn "${NOTICE_MSG} already contains version ${S_NORM}${V_PREV}${RESET}."
    return
  fi

  if [ "$FLAG_DRYRUN" = true ]; then
    echo -e "${S_LIGHT}[dry-run]${RESET} would set .version = '${S_NORM}$V_NEW${RESET}' in package.json" >&2
    [ -f package-lock.json ] && echo -e "${S_LIGHT}[dry-run]${RESET} would set .version = '${S_NORM}$V_NEW${RESET}' in package-lock.json" >&2
  else
    # Bump package.json via jq (no npm dependency).
    # Note: $V is a jq variable (set via --arg), not a bash expansion — single
    # quotes on the jq program are correct.
    # shellcheck disable=SC2016
    if ! jq_inplace package.json '.version = $V' --arg V "$V_NEW"; then
      fail 1 \
        "Error updating <package.json>." \
        "Check that package.json is valid JSON (run: jq . package.json) and that the file is writable."
    fi
    # package-lock.json: update both top-level .version and (if present) the
    # root package entry .packages[""].version — matches npm's own behaviour.
    if [ -f package-lock.json ]; then
      # shellcheck disable=SC2016
      if ! jq_inplace package-lock.json '
        .version = $V
        | if has("packages") and (.packages | has("")) then
            .packages[""].version = $V
          else . end
      ' --arg V "$V_NEW"; then
        fail 1 \
          "Error updating <package-lock.json>." \
          "Check that package-lock.json is valid JSON (run: jq . package-lock.json) and that the file is writable."
      fi
    fi
  fi

  dryrun git add package.json
  GIT_MSG+="updated package.json, "
  if [ -f package-lock.json ]; then
    dryrun git add package-lock.json
    GIT_MSG+="updated package-lock.json, "
    NOTICE_MSG+=" and <${S_NORM}package-lock.json${RESET}>"
  fi

  log_success "Bumped version in ${NOTICE_MSG}."
}

# Change `version:` value in JSON files, like packager.json, composer.json, etc
bump-json-files() {
  local FILE FILE_V_PREV
  local JSON_PROCESSED=( ) # holds filenames after they've been changed

  for FILE in "${JSON_FILES[@]}"; do
    if [ -f "$FILE" ]; then
      # Get the existing version number (top-level .version only)
      FILE_V_PREV=$( jq -r '.version // empty' "$FILE" 2>/dev/null )

      if [ -z "$FILE_V_PREV" ]; then
        log_error "no .version field in <${S_NORM}$FILE${RESET}> to replace."
      elif [ "$FILE_V_PREV" = "$V_NEW" ]; then
        log_warn "<${S_NORM}$FILE${RESET}> already contains version ${S_NORM}$FILE_V_PREV${RESET}."
      elif [ "$FLAG_DRYRUN" = true ]; then
        echo -e "${S_LIGHT}[dry-run]${RESET} would set .version = '${S_NORM}$V_NEW${RESET}' in ${S_NORM}$FILE${RESET} (was ${S_NORM}$FILE_V_PREV${RESET})" >&2
        GIT_MSG+="updated $FILE, "
      else
        # shellcheck disable=SC2016
        if jq_inplace "$FILE" '.version = $V' --arg V "$V_NEW"; then
          log_success "Updated <${S_NORM}$FILE${RESET}>: ${S_NORM}$FILE_V_PREV${RESET} ${I_ARROW} ${S_NORM}$V_NEW${RESET}"
          # Add file change to commit message:
          GIT_MSG+="updated $FILE, "
        else
          log_error "failed to update <${S_NORM}$FILE${RESET}> via jq."
        fi
      fi

      JSON_PROCESSED+=("$FILE")
    else
      log_warn "file <${S_NORM}$FILE${RESET}> not found."
    fi
  done
  # Stage files that were changed:
  ((${#JSON_PROCESSED[@]})) && dryrun git add "${JSON_PROCESSED[@]}"
}

# Handle VERSION file - for backward compatibility
do-versionfile() {
  if [ -f VERSION ]; then
    GIT_MSG+="updated VERSION, "
    if [ "$FLAG_DRYRUN" = true ]; then
      echo -e "${S_LIGHT}[dry-run]${RESET} would write '${S_NORM}$V_NEW${RESET}' to VERSION" >&2
    else
      echo "$V_NEW" > VERSION # Overwrite file
    fi
    # Stage file for commit
    dryrun git add VERSION

    log_success "Updated [${S_NORM}VERSION${RESET}] file."
    log_warn "Deprecation: the <${S_NORM}VERSION${RESET}> file is deprecated since v0.2.0 — support will be removed in a future version."
  fi
}

get-commit-msg() {
  local CMD
  CMD=$([ ! "${V_PREV}" = "${V_NEW}" ] && echo "${V_PREV} ->" || echo "to")
  echo bumped "$CMD" "$V_NEW"
}

capitalise() {
  echo "$(tr '[:lower:]' '[:upper:]' <<< "${1:0:1}")${1:1}"
}

# Dump git log history to CHANGELOG.md
do-changelog() {
  [ "$FLAG_NOCHANGELOG" = true ] && return
  local ACTION_MSG COMMITS_MSG LOG_MSG LOG_RC RANGE TMP

  RANGE=$([ "$(git tag -l "${TAG_PREFIX}${V_PREV}")" ] && echo "${TAG_PREFIX}${V_PREV}..HEAD")
  # shellcheck disable=SC2086
  COMMITS_MSG=$( git log --pretty=format:"- %s" ${RANGE} 2>&1 ); LOG_RC=$?
  if [ "$LOG_RC" -ne 0 ]; then
    fail 1 \
      "Error getting commit history since last version bump for logging to CHANGELOG: ${COMMITS_MSG}" \
      "Verify the previous tag exists (git tag -l) and that 'git log ${RANGE}' runs successfully, or pass -c/--no-changelog to skip."
  fi

  if [ -f CHANGELOG.md ]; then
    ACTION_MSG="updated"
  else
    ACTION_MSG="created"
  fi
  # Add info to commit message for later:
  GIT_MSG+="${ACTION_MSG} CHANGELOG.md, "

  # Build new CHANGELOG content in a temp file next to the target, so a
  # partial write can't leave garbage in the repo root.
  TMP=$(mktemp "./CHANGELOG.md.XXXXXX")
  # Heading
  echo "## $V_NEW ($NOW)" > "$TMP"

  # Log the bumping commit:
  # - The final commit is done after do-changelog(), so we need to create the log entry for it manually:
  LOG_MSG="${GIT_MSG}$(get-commit-msg)"
  echo "- ${COMMIT_MSG_PREFIX}${LOG_MSG}" >> "$TMP"
  # Add previous commits
  [ -n "$COMMITS_MSG" ] && echo "$COMMITS_MSG" >> "$TMP"

  printf '\n' >> "$TMP"

  if [ -f CHANGELOG.md ]; then
    # Append existing log
    cat CHANGELOG.md >> "$TMP"
  else
    printf '\nNo existing [%bCHANGELOG.md%b] found — creating one.\n' "${S_NORM}" "${RESET}"
  fi

  if [ "$FLAG_DRYRUN" = true ]; then
    printf '%b[dry-run]%b would replace CHANGELOG.md with:\n' "${S_LIGHT}" "${RESET}" >&2
    cat "$TMP" >&2
    rm -f "$TMP"
  else
    mv -f "$TMP" CHANGELOG.md
  fi

  log_success "$( capitalise "${ACTION_MSG}" ) [${S_NORM}CHANGELOG.md${RESET}]."

  # Optionally pause & allow user to open and edit the file:
  if [ "$FLAG_CHANGELOG_PAUSE" = true ] && [ "$FLAG_DRYRUN" != true ]; then
    printf '\n%bMake adjustments to [%bCHANGELOG.md%b] if required now. Press <enter> to continue.%b' "${S_QUESTION}" "${S_NORM}" "${S_QUESTION}" "${RESET}"
    read -r
  fi

  # Stage log file, to commit later
  dryrun git add CHANGELOG.md
}

do-branch() {
  [ "$FLAG_NOBRANCH" = true ] && return

  local BRANCH_MSG

  echo -e "\nCreating release branch..."

  if [ "$FLAG_DRYRUN" = true ]; then
    echo -e "${S_LIGHT}[dry-run]${RESET} would run: git branch ${S_NORM}${REL_PREFIX}${V_NEW}${RESET} && git checkout ${S_NORM}${REL_PREFIX}${V_NEW}${RESET}" >&2
    log_success "Switched to (dry-run) branch '${S_NORM}${REL_PREFIX}${V_NEW}${RESET}'"
    return
  fi

  BRANCH_MSG=$(git branch "${REL_PREFIX}${V_NEW}" 2>&1)
  if [ -z "$BRANCH_MSG" ]; then
    BRANCH_MSG=$(git checkout "${REL_PREFIX}${V_NEW}" 2>&1)
    log_success "${BRANCH_MSG}"
  else
    fail 1 \
      "Failed to create release branch: ${BRANCH_MSG}" \
      "Resolve the git branch error above, or pass -b/--no-branch to skip branch creation."
  fi
}

# Stage & commit all files modified by this script
do-commit() {
  [ "$FLAG_NOCOMMIT" = true ] && return

  local COMMIT_MSG COMMIT_RC

  GIT_MSG+="$(get-commit-msg)"
  echo -e "\nCommitting..."

  if [ "$FLAG_DRYRUN" = true ]; then
    echo -e "${S_LIGHT}[dry-run]${RESET} would run: git commit -m '${S_NORM}${COMMIT_MSG_PREFIX}${GIT_MSG}${RESET}'" >&2
    log_success "(dry-run) commit prepared"
    return
  fi

  COMMIT_MSG=$( git commit -m "${COMMIT_MSG_PREFIX}${GIT_MSG}" 2>&1 ); COMMIT_RC=$?
  if [ "$COMMIT_RC" -ne 0 ]; then
    fail 1 \
      "git commit failed: ${COMMIT_MSG}" \
      "Resolve the git commit error above, or pass -n/--no-commit to skip committing."
  else
    log_success "$COMMIT_MSG"
  fi
}

# Create a Git tag using the SemVer
do-tag() {
  # If we skipped committing, the version bumps are not persisted, so tagging
  # would point at the wrong (pre-bump) commit. Skip the tag too.
  [ "$FLAG_NOCOMMIT" = true ] && return

  local tag_msg
  tag_msg="${REL_NOTE:-Tag version ${V_NEW}.}"

  if [ "$FLAG_DRYRUN" = true ]; then
    echo -e "${S_LIGHT}[dry-run]${RESET} would run: git tag -a ${S_NORM}${TAG_PREFIX}${V_NEW}${RESET} -m '${tag_msg}'" >&2
    log_success "Tagged ${S_NORM}${TAG_PREFIX}${V_NEW}${RESET}"
    return
  fi

  git tag -a "${TAG_PREFIX}${V_NEW}" -m "${tag_msg}"
  log_success "Tagged ${S_NORM}${TAG_PREFIX}${V_NEW}${RESET}"
}

# Pushes branch + tag to remote repo. Changes are staged by earlier functions
do-push() {
  [ "$FLAG_NOCOMMIT" = true ] && return

  local CONFIRM PUSH_MSG PUSH_RC REMOTE_REF

  if [ "$FLAG_PUSH" = true ]; then
    CONFIRM="Y"
  else
    echo -ne "\n${S_QUESTION}Push branch + tags to <${S_NORM}${PUSH_DEST}${S_QUESTION}>? [${S_NORM}N/y${S_QUESTION}]:${RESET} "
    read -r CONFIRM
  fi

  case "$CONFIRM" in
    [yY][eE][sS]|[yY] )
      echo -e "\nPushing branch + tag to <${S_NORM}${PUSH_DEST}${RESET}>..."
      if [ "$FLAG_NOBRANCH" = true ]; then
        REMOTE_REF=$(git rev-parse --abbrev-ref HEAD)
      else
        REMOTE_REF="${REL_PREFIX}${V_NEW}"
      fi

      if [ "$FLAG_DRYRUN" = true ]; then
        echo -e "${S_LIGHT}[dry-run]${RESET} would run: git push -u ${S_NORM}${PUSH_DEST}${RESET} ${S_NORM}${REMOTE_REF}${RESET} ${S_NORM}${TAG_PREFIX}${V_NEW}${RESET}" >&2
        log_success "(dry-run) push prepared"
        return
      fi

      PUSH_MSG=$( git push -u "${PUSH_DEST}" "${REMOTE_REF}" "${TAG_PREFIX}${V_NEW}" 2>&1 ); PUSH_RC=$?
      if [ "$PUSH_RC" -ne 0 ]; then
        log_warn "Push failed"
        log_trace "$PUSH_MSG"
      else
        log_success "$PUSH_MSG"
      fi
    ;;
    * )
      fail 5 \
        "push declined" \
        "Re-run and answer 'y' when prompted, or pass -p/--push <remote> to skip the prompt."
    ;;
  esac
}
