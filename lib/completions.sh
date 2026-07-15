#!/bin/bash

# shellcheck disable=SC2288
true

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
      # User-scope XDG-style path. Consistent with the bash target
      # ($XDG_DATA_HOME/bash-completion/completions/) and with common
      # project-local conventions elsewhere.
      dir="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions"
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

  log_success "Installed ${shell} completion → ${S_VAL}${dest}${RESET-}"

  if [ "$shell" = zsh ]; then
    # Probe the live zsh $fpath to see if the install dir is already on it.
    # If yes, the user just needs to rebuild the compdump cache. If no, they
    # need to prepend the dir to fpath in .zshrc — and crucially, BEFORE any
    # `source $ZSH/oh-my-zsh.sh` line, otherwise omz's compinit runs first
    # and the new entry is never scanned.
    local on_fpath=0
    if command -v zsh >/dev/null 2>&1; then
      if zsh -c "print -rl -- \$fpath" 2>/dev/null | grep -qxF "$dir"; then
        on_fpath=1
      fi
    fi
    if [ "$on_fpath" = 1 ]; then
      log_info "Rebuild zsh's completion cache to pick it up:"
      log_trace "rm -f ~/.zcompdump*; exec zsh"
    else
      local dir_pretty
      if [[ "$dir" == "$HOME"* ]]; then
        dir_pretty="~${dir#"$HOME"}"
      else
        dir_pretty="$dir"
      fi
      log_info "Add this to ~/.zshrc BEFORE any 'source \$ZSH/oh-my-zsh.sh' line:"
      log_trace "fpath=(${dir_pretty} \$fpath)"
      log_info "Then rebuild the completion cache:"
      log_trace "rm -f ~/.zcompdump*; exec zsh"
    fi
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
        -f|--file|--source)
            COMPREPLY=( $(compgen -f -X '!*.json' -- "$cur") )
            return 0
            ;;
        --completions|--install-completions)
            COMPREPLY=( $(compgen -W 'bash zsh fish' -- "$cur") )
            return 0
            ;;
        # Options that take a free-form argument — no completion
        -v|--version|-m|--message|-p|--push|-t|--tag-prefix|-B|--branch-prefix|--undo|--base)
            return 0
            ;;
    esac

    opts="--version --message --file --source --push --tag-prefix --branch-prefix \
          --dry-run --no-commit --no-branch --no-changelog --pause-changelog \
          --yes --quiet --undo --branch --pr --base --major --minor --patch --release \
          --sign --allow-dirty --allow-empty --no-fetch --no-hooks \
          --help --completions --install-completions --about \
          -v -m -f -p -t -B -d -n -b -c -l -y -q -h"
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
    '(-v --version)'{-v,--version}'[print tool version (no arg) or set manual SemVer]::version:' \
    '(-m --message)'{-m,--message}'[custom annotated-tag message]:message:' \
    '(-f --file)'{-f,--file}'[bump version in extra JSON file]:file:_files -g "*.json"' \
    '--source[version source + primary bump target (default package.json)]:file:_files -g "*.json"' \
    '(-p --push)'{-p,--push}'[push branch + tag to <remote>]:remote:' \
    '(-t --tag-prefix)'{-t,--tag-prefix}'[override tag prefix]:prefix:' \
    '(-B --branch-prefix)'{-B,--branch-prefix}'[override branch prefix]:prefix:' \
    '(-d --dry-run)'{-d,--dry-run}'[print side-effects without executing]' \
    '(-n --no-commit)'{-n,--no-commit}'[disable commit (and tag + push)]' \
    '(-b --no-branch)'{-b,--no-branch}'[disable creating release branch]' \
    '(-c --no-changelog)'{-c,--no-changelog}'[disable CHANGELOG.md update]' \
    '(-l --pause-changelog)'{-l,--pause-changelog}'[pause before commit]' \
    '(-h --help)'{-h,--help}'[show help]' \
    '(-y --yes)'{-y,--yes}'[skip interactive confirmation prompts]' \
    '(-q --quiet)'{-q,--quiet}'[suppress decoration; print only the new version on stdout]' \
    '--undo[locally delete release branch + tag for <version>]::version:' \
    '--branch[cut a release-x.x.x branch (else tag in place)]' \
    '--pr[branch + push + open a release PR via gh]' \
    '--base[base branch for --pr]:branch:' \
    '(--major --minor --patch -v --version)--major[force a major bump from the current version]' \
    '(--major --minor --patch -v --version)--minor[force a minor bump from the current version]' \
    '(--major --minor --patch -v --version)--patch[force a patch bump from the current version]' \
    '--release[publish a GitHub release for the new tag via gh]' \
    '--sign[create a signed tag (git tag -s) instead of annotated]' \
    '--allow-dirty[skip the clean-working-tree preflight]' \
    '--allow-empty[release even with no new commits since the previous tag]' \
    '--no-fetch[skip the remote-sync preflight]' \
    '--no-hooks[skip the PRE_BUMP_CMD / POST_TAG_CMD release hooks]' \
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
    complete -c $_cmd -s v -l version        -d 'Print tool version (no arg) or set manual SemVer'
    complete -c $_cmd -s m -l message        -r -d 'Custom annotated-tag message'
    complete -c $_cmd -s f -l file           -r -a '(__fish_complete_suffix .json)' -d 'Bump version in extra JSON file'
    complete -c $_cmd      -l source         -r -a '(__fish_complete_suffix .json)' -d 'Version source + primary bump target'
    complete -c $_cmd -s p -l push           -r -d 'Push branch + tag to <remote>'
    complete -c $_cmd -s t -l tag-prefix     -r -d 'Override tag prefix'
    complete -c $_cmd -s B -l branch-prefix  -r -d 'Override branch prefix'
    complete -c $_cmd -s d -l dry-run        -d 'Print side-effects without executing'
    complete -c $_cmd -s n -l no-commit      -d 'Disable commit (and tag + push)'
    complete -c $_cmd -s b -l no-branch      -d 'Disable creating release branch'
    complete -c $_cmd -s c -l no-changelog   -d 'Disable CHANGELOG.md update'
    complete -c $_cmd -s l -l pause-changelog -d 'Pause before commit'
    complete -c $_cmd -s h -l help           -d 'Show help'
    complete -c $_cmd -s y -l yes            -d 'Skip interactive confirmation prompts'
    complete -c $_cmd -s q -l quiet          -d 'Suppress decoration; print only the new version on stdout'
    complete -c $_cmd      -l undo           -d 'Locally delete release branch + tag for <version>'
    complete -c $_cmd      -l branch         -d 'Cut a release-x.x.x branch (else tag in place)'
    complete -c $_cmd      -l pr             -d 'Branch + push + open a release PR via gh'
    complete -c $_cmd      -l base           -r -d 'Base branch for --pr'
    complete -c $_cmd      -l major          -d 'Force a major bump from the current version'
    complete -c $_cmd      -l minor          -d 'Force a minor bump from the current version'
    complete -c $_cmd      -l patch          -d 'Force a patch bump from the current version'
    complete -c $_cmd      -l release        -d 'Publish a GitHub release for the new tag via gh'
    complete -c $_cmd      -l sign           -d 'Create a signed tag (git tag -s) instead of annotated'
    complete -c $_cmd      -l allow-dirty    -d 'Skip the clean-working-tree preflight'
    complete -c $_cmd      -l allow-empty    -d 'Release even with no new commits since the previous tag'
    complete -c $_cmd      -l no-fetch       -d 'Skip the remote-sync preflight'
    complete -c $_cmd      -l no-hooks       -d 'Skip the PRE_BUMP_CMD / POST_TAG_CMD release hooks'
    complete -c $_cmd      -l completions    -x -a 'bash zsh fish' -d 'Emit completion script'
    complete -c $_cmd      -l install-completions -a 'bash zsh fish' -d 'Install completions for detected/specified shell'
    complete -c $_cmd      -l about          -d 'Print branded version info and exit'
end
FISH_EOF
}
