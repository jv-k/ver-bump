#!/bin/bash

# Flags set here are consumed in other lib/*.sh modules. shellcheck lints each
# file in isolation, so it can't see the cross-module reads — silence SC2034
# for this file and rely on the modules that *read* the flags to fail loudly
# if a name drifts.
# shellcheck disable=SC2034,SC2288
true

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

    # Special case: bare --version / -v (no following value) — print the
    # branded version block and exit. With a value, fall through to the
    # generic translation so it acts as the manual SemVer setter.
    if [ "$arg" = "--version" ] || [ "$arg" = "-v" ]; then
      if (( $# == 0 )) || [ "${1:0:1}" = "-" ]; then
        local _ver
        if command -v jq >/dev/null 2>&1; then
          _ver=$(jq -r '.version // ""' "$MODULE_DIR/package.json")
        else
          _ver=$(grep -m1 '"version"' "$MODULE_DIR/package.json" | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
        fi
        # Branded pill when colour is on; a plain, parseable "ver-bump X.Y.Z"
        # (program name + version, no stray pill padding) when it isn't —
        # so `ver-bump --version` piped into a script yields a clean token.
        if [ "${USE_COLOR:-0}" = 1 ]; then
          printf '%b ver-bump v%s %b\n' "${S_HDR_SUB-}" "${_ver}" "${S_HDR_END-}"
        else
          printf 'ver-bump %s\n' "${_ver}"
        fi
        exit 0
      fi
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
      elif (( $# )) && [ "${1:0:1}" != "-" ]; then
        # Space form: --install-completions bash (mirrors --completions / --undo).
        ic_shell="$1"; shift
      else
        ic_shell=$(detect-shell) || fail 2 \
          "Could not auto-detect your shell from \$SHELL." \
          "Pass --install-completions=<bash|zsh|fish> explicitly."
      fi
      install-completions "$ic_shell"
      exit $?
    fi

    # Special case: --undo [version] — locally delete the release branch
    # and tag for <version>. Honours --dry-run and --yes seen earlier or
    # later in argv. Exits immediately.
    if [ "$arg" = "--undo" ] || [[ "$arg" == "--undo="* ]]; then
      local undo_ver undo_a undo_capture=""
      # do-undo runs and exits from here, before the getopts loop ever sees
      # -t/-B. Pre-scan the rest of argv for the flags it needs. -t/-B take a
      # value, so honour "-t v" / "--tag-prefix v" and "--tag-prefix=v" forms.
      for undo_a in "$@" "${NORMALIZED_ARGV[@]}"; do
        if [ -n "$undo_capture" ]; then
          case "$undo_capture" in
            t) TAG_PREFIX="$undo_a" ;;
            B) REL_PREFIX="$undo_a" ;;
          esac
          undo_capture=""
          continue
        fi
        case "$undo_a" in
          --dry-run|-d)       FLAG_DRYRUN=true ;;
          --yes|-y)           FLAG_YES=true ;;
          -t|--tag-prefix)    undo_capture=t ;;
          -B|--branch-prefix) undo_capture=B ;;
          --tag-prefix=*)     TAG_PREFIX="${undo_a#*=}" ;;
          --branch-prefix=*)  REL_PREFIX="${undo_a#*=}" ;;
        esac
      done
      if [[ "$arg" == "--undo="* ]]; then
        undo_ver="${arg#--undo=}"
        [ -z "$undo_ver" ] && fail 2 \
          "--undo= requires a version." \
          "Pass MAJOR.MINOR.PATCH, e.g. --undo=1.2.0"
      elif (( $# )) && [ "${1:0:1}" != "-" ]; then
        undo_ver="$1"; shift
      else
        undo_ver=""
      fi
      do-undo "$undo_ver"
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

    # --release is a long-only boolean with no short form. Set the global
    # directly and skip the getopts pipeline (which only handles single-char
    # short flags). --release=value is rejected — see the boolean-flag
    # check at the bottom of this loop for the same treatment of -d/--dry-run.
    if [ "$arg" = "--release" ]; then
      DO_RELEASE=true
      continue
    elif [[ "$arg" == "--release="* ]]; then
      fail 2 \
        "Option --release doesn't take a value." \
        "Drop the '=<value>' — --release is a boolean flag."
    fi

    # --pr — long-only boolean: open a release PR via `gh`. A PR needs its head
    # branch on the remote, so --pr implies a release branch (--branch) and a
    # push (-p origin by default; override the remote with -p). --pr=value rejected.
    if [ "$arg" = "--pr" ]; then
      DO_PR=true
      FLAG_BRANCH=true
      FLAG_PUSH=true
      continue
    elif [[ "$arg" == "--pr="* ]]; then
      fail 2 \
        "Option --pr doesn't take a value." \
        "Drop the '=<value>' — --pr is a boolean flag (use --base <branch> to set the PR target)."
    fi

    # --branch — long-only boolean: opt into cutting a release-<v> branch (the
    # pre-2.0 default). Without it (or --pr), ver-bump tags the current branch.
    if [ "$arg" = "--branch" ]; then
      FLAG_BRANCH=true
      continue
    elif [[ "$arg" == "--branch="* ]]; then
      fail 2 \
        "Option --branch doesn't take a value." \
        "Drop the '=<value>' — --branch is a boolean flag (did you mean --branch-prefix=?)."
    fi

    # --allow-dirty — long-only boolean: skip the clean-working-tree preflight
    # (R-SAFE-2). Sets the ALLOW_DIRTY config key directly, so the CLI wins
    # over env / .ver-bumprc per R-CFG-3 (process-arguments runs last).
    if [ "$arg" = "--allow-dirty" ]; then
      ALLOW_DIRTY=true
      continue
    elif [[ "$arg" == "--allow-dirty="* ]]; then
      fail 2 \
        "Option --allow-dirty doesn't take a value." \
        "Drop the '=<value>' — --allow-dirty is a boolean flag."
    fi

    # --base <branch> / --base=<branch> — explicit base branch for --pr. Long-only
    # value flag (no short form), captured here like --undo so it needs no getopts slot.
    if [ "$arg" = "--base" ] || [[ "$arg" == "--base="* ]]; then
      if [[ "$arg" == "--base="* ]]; then
        PR_BASE="${arg#--base=}"
        [ -z "$PR_BASE" ] && fail 2 \
          "--base= requires a branch name." \
          "Pass a base branch: --base <branch> or --base=<branch>."
      elif (( $# )) && [ "${1:0:1}" != "-" ]; then
        PR_BASE="$1"; shift
      else
        fail 2 \
          "Option --base requires a branch name." \
          "Pass a base branch: --base <branch> or --base=<branch>."
      fi
      continue
    fi

    # --major / --minor / --patch — long-only boolean bump-level switches.
    # Mutually exclusive with each other; the -v / --version conflict is
    # caught later when getopts processes -v (BUMP_LEVEL is already set
    # by the time normalize-long-opts has emitted -v into NORMALIZED_ARGV).
    case "$arg" in
      --major|--minor|--patch)
        local lvl="${arg#--}"
        if [ -n "${BUMP_LEVEL-}" ]; then
          fail 2 \
            "Conflicting bump-level flags: --${BUMP_LEVEL} and ${arg} are mutually exclusive." \
            "Pass only one of --major, --minor, --patch."
        fi
        BUMP_LEVEL="$lvl"
        continue
      ;;
      --major=*|--minor=*|--patch=*)
        fail 2 \
          "Option ${arg%%=*} doesn't take a value." \
          "Drop the '=<value>' — ${arg%%=*} is a boolean flag."
      ;;
    esac

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
      yes)             short="-y"; needs_arg=0 ;;
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

  # DO_RELEASE and BUMP_LEVEL are CLI-only switches with no env / .ver-bumprc
  # contract. Reset them before parsing so an inherited exported var — or a
  # .ver-bumprc assignment (load-config sources the rc as raw shell) — can't
  # silently force a bump or publish a release with no flag on the command line.
  DO_RELEASE=false
  DO_PR=false
  BUMP_LEVEL=

  normalize-long-opts "$@"
  set -- ${NORMALIZED_ARGV[@]+"${NORMALIZED_ARGV[@]}"}

  # Get positional parameters
  while getopts ":v:p:m:f:t:B:hbncdly" OPTIONS; do # Note: Adding the first : before the flags takes control of flags and prevents default error msgs.
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
        if [ -n "${BUMP_LEVEL-}" ]; then
          fail 2 \
            "Conflicting flags: -v / --version and --${BUMP_LEVEL} are mutually exclusive." \
            "Pass either an explicit version (-v X.Y.Z) or a bump level (--${BUMP_LEVEL}), not both."
        fi
        V_USR_SUPPLIED=$OPTARG
      ;;
      m )
        REL_NOTE=$OPTARG
        # Custom release note
        echo -e "\n${S_LIGHT}Option set:${RESET} release note: ${S_VAL}'$REL_NOTE'${RESET}"
      ;;
      f )
        echo -e "\n${S_LIGHT}Option set:${RESET} JSON file via [-f]: <${S_VAL}${OPTARG}${RESET}>"
        # Store JSON filenames(s)
        JSON_FILES+=("$OPTARG")
      ;;
      p )
        FLAG_PUSH=true
        PUSH_DEST=${OPTARG} # Replace default with user input
        echo -e "\n${S_LIGHT}Option set:${RESET} push to <${S_VAL}${PUSH_DEST}${RESET}> as the last step."
      ;;
      t )
        TAG_PREFIX=$OPTARG
        echo -e "\n${S_LIGHT}Option set:${RESET} tag prefix: <${S_VAL}${TAG_PREFIX}${RESET}>"
      ;;
      B )
        REL_PREFIX=$OPTARG
        echo -e "\n${S_LIGHT}Option set:${RESET} branch prefix: <${S_VAL}${REL_PREFIX}${RESET}>"
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
        # Deprecated as of 2.0: tag-in-place is the default, so -b/--no-branch is
        # a no-op. Kept so existing scripts/CI don't hard-fail. Use --branch to opt in.
        echo -e "\n${S_LIGHT}Note:${RESET} -b/--no-branch is deprecated — tag-in-place is the default now; use --branch to cut a release branch." >&2
      ;;
      c )
        FLAG_NOCHANGELOG=true
        echo -e "\n${S_LIGHT}Option set:${RESET} disable updating CHANGELOG.md automatically."
      ;;
      l )
        FLAG_CHANGELOG_PAUSE=true
        echo -e "\n${S_LIGHT}Option set:${RESET} pause to allow amending CHANGELOG.md."
      ;;
      y )
        FLAG_YES=true
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
