#!/bin/bash

# shellcheck disable=SC2288
true

# Multi-format bump targets (R-TGT). A "bump target" is a file plus an explicit
# locator saying where the version lives inside it. Two locator kinds:
#
#   1. Text pattern  — a search string containing the literal token
#      {{version}}. The search is the pattern with {{version}} -> V_PREV; the
#      replacement is the pattern with {{version}} -> V_NEW. Only lines holding
#      the literal search are rewritten; every other byte (indent, quoting,
#      CRLF, a missing final newline) survives — same discipline as
#      json_set_version (lib/json.sh). Pure bash, no external dependency, any
#      text format (Go, Makefile, Dockerfile, .cfg, plain VERSION, …).
#
#   2. Structured path — @<dotted.path> into a parsed document. JSON via jq
#      (always available); TOML via tomlq; YAML via yq. The jq-based yq suite
#      (kislyuk/yq: `yq`, `tomlq`) is assumed so one setpath() filter serves
#      all three. The path generalises the JSON bump — any dotted path, not
#      only top-level .version.
#
# Spec grammar (see docs/features/bump-targets/requirements.md):
#   <file>                         structured default .version, by file type
#   <file>:@<path>                 structured, explicit dotted path
#   <file>:<pattern-with-{{version}}>  text search/replace
#
# The first ':' splits file from locator; a leading '@' after it selects the
# structured locator, anything else is a text pattern (and must contain
# {{version}}). Filenames containing ':' are not supported (documented).

# Parse one spec into the _BT_* globals. Fails (exit 2) on a malformed spec.
# Sets: _BT_FILE, _BT_KIND (path|pattern), _BT_FMT (json|toml|yaml|text),
#       _BT_PATH (dotted path for kind=path), _BT_PATTERN (kind=pattern).
_bt-parse-spec() {
  local spec="$1" loc
  _BT_FILE="" _BT_KIND="" _BT_FMT="" _BT_PATH="" _BT_PATTERN=""

  if [[ "$spec" == *:* ]]; then
    _BT_FILE="${spec%%:*}"
    loc="${spec#*:}"
  else
    _BT_FILE="$spec"
    loc=""
  fi

  if [ -z "$_BT_FILE" ]; then
    fail 2 \
      "--bump spec '${spec}' has no file part." \
      "Use --bump <file>, --bump <file>:@<path>, or --bump '<file>:<pattern with {{version}}>'."
  fi

  _BT_FMT=$(_bt-format "$_BT_FILE")

  if [ -z "$loc" ]; then
    # Bare file: structured default .version, keyed on the extension. An
    # unknown/text extension is a usage error — never guess a text pattern.
    if [ "$_BT_FMT" = text ]; then
      fail 2 \
        "--bump ${_BT_FILE}: can't infer where the version lives in a non-JSON/TOML/YAML file." \
        "Give an explicit text pattern: --bump '${_BT_FILE}:<pattern with {{version}}>' (e.g. 'Version = \"{{version}}\"')."
    fi
    _BT_KIND="path"; _BT_PATH=".version"
  elif [[ "$loc" == @* ]]; then
    _BT_KIND="path"
    _BT_PATH="${loc#@}"
    [ -z "$_BT_PATH" ] && _BT_PATH=".version"
    if [ "$_BT_FMT" = text ]; then
      fail 2 \
        "--bump ${_BT_FILE}:@${_BT_PATH#.}: a structured @path needs a JSON, TOML, or YAML file." \
        "For any other format use a text pattern: --bump '${_BT_FILE}:<pattern with {{version}}>'."
    fi
    # Simple dotted keys only — reject array indices / quoted keys so the
    # setpath() array can be built without a shell-injection surface.
    case "$_BT_PATH" in
      *'"'*|*'['*|*']'*)
        fail 2 \
          "--bump ${_BT_FILE}:@${_BT_PATH#.}: only simple dotted paths are supported (e.g. @tool.poetry.version)." \
          "For array indices or exotic keys, use a text pattern instead: --bump '${_BT_FILE}:<pattern with {{version}}>'."
      ;;
    esac
  else
    _BT_KIND="pattern"
    _BT_PATTERN="$loc"
    if [[ "$_BT_PATTERN" != *'{{version}}'* ]]; then
      fail 2 \
        "--bump ${_BT_FILE}: text pattern '${_BT_PATTERN}' does not contain the {{version}} placeholder." \
        "Mark the version position with {{version}}, e.g. --bump '${_BT_FILE}:version = \"{{version}}\"'."
    fi
  fi
}

# Echo the format for a file, keyed only on its extension (the file need not
# exist yet — dep-checking runs before any read). Unknown extension = text.
_bt-format() {
  case "$1" in
    *.json)          echo json ;;
    *.toml)          echo toml ;;
    *.yaml|*.yml)    echo yaml ;;
    *)               echo text ;;
  esac
}

# The external helper a structured target needs, or empty for json/text.
_bt-helper-for() {
  case "$1" in
    toml) echo tomlq ;;
    yaml) echo yq ;;
    *)    echo "" ;;
  esac
}

# Resolve the full, ordered target list into the _RESOLVED_BUMP_SPECS array:
# BUMP_FILES (config/env, newline-separated) first, then --bump CLI entries
# (BUMP_TARGETS[]) — CLI appends, targets accumulate (R-TGT-1). Blank lines
# and leading/trailing whitespace in BUMP_FILES entries are ignored.
resolve-bump-targets() {
  _RESOLVED_BUMP_SPECS=()
  local line trimmed
  if [ -n "${BUMP_FILES:-}" ]; then
    while IFS= read -r line; do
      # Trim surrounding whitespace so indented .verbumprc lists parse.
      trimmed="${line#"${line%%[![:space:]]*}"}"
      trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
      [ -z "$trimmed" ] && continue
      _RESOLVED_BUMP_SPECS+=("$trimmed")
    done <<< "$BUMP_FILES"
  fi
  local spec
  for spec in ${BUMP_TARGETS[@]+"${BUMP_TARGETS[@]}"}; do
    _RESOLVED_BUMP_SPECS+=("$spec")
  done
}

# Preflight (R-TGT-4): parse every spec (so grammar errors surface before any
# mutation) and verify the helper for each structured TOML/YAML target is
# installed. Missing helper -> exit 3 with an install hint AND the no-dep
# escape route (a {{version}} text pattern). jq is covered by
# check-dependencies. Runs in the Verify phase; a no-target run is a silent
# no-op.
check-bump-deps() {
  resolve-bump-targets
  ((${#_RESOLVED_BUMP_SPECS[@]})) || return 0

  local spec helper
  for spec in "${_RESOLVED_BUMP_SPECS[@]}"; do
    _bt-parse-spec "$spec"  # fails 2 on a bad spec
    [ "$_BT_KIND" = path ] || continue
    helper=$(_bt-helper-for "$_BT_FMT")
    [ -z "$helper" ] && continue
    if ! command -v "$helper" >/dev/null 2>&1; then
      fail 3 \
        "--bump ${_BT_FILE}: bumping a ${_BT_FMT} path needs '${helper}', which isn't installed." \
        "Install ${helper} (the jq-based yq suite: 'pip install yq', or 'brew install python-yq'), or bump ${_BT_FILE} with a text pattern instead: --bump '${_BT_FILE}:<pattern with {{version}}>' (no extra tool)."
    fi
  done
}

# Read the current value at a structured path, or empty. Uses the jq-syntax
# yq suite so one filter serves json/toml/yaml.
_bt-struct-get() {
  local file="$1" fmt="$2" arr="$3"
  # shellcheck disable=SC2016
  case "$fmt" in
    json) jq   -r "getpath(${arr}) // empty" "$file" 2>/dev/null ;;
    toml) tomlq -r "getpath(${arr}) // empty" "$file" 2>/dev/null ;;
    yaml) yq   -r "getpath(${arr}) // empty" "$file" 2>/dev/null ;;
  esac
}

# Set a structured path to <new>, atomically. json/toml/yaml via jq/tomlq/yq,
# all sharing the setpath() filter. Returns non-zero (leaving the file
# untouched) on any tool error or empty output. The default JSON .version case
# is handled by the caller via the surgical, formatting-preserving
# json_set_version (R-TGT-3); this path re-serialises and may normalise
# formatting (documented, mirrors R-FMT-3).
_bt-struct-set() {
  local file="$1" fmt="$2" arr="$3" new="$4"
  local tmp rc
  tmp=$(mktemp "${file}.XXXXXX") || return 1
  # shellcheck disable=SC2016 # $V is a jq variable, not a bash expansion
  case "$fmt" in
    json) jq          --arg V "$new" "setpath(${arr}; \$V)" "$file" >"$tmp" 2>/dev/null; rc=$? ;;
    toml) tomlq -t    --arg V "$new" "setpath(${arr}; \$V)" "$file" >"$tmp" 2>/dev/null; rc=$? ;;
    yaml) yq   -y     --arg V "$new" "setpath(${arr}; \$V)" "$file" >"$tmp" 2>/dev/null; rc=$? ;;
    *)    rm -f "$tmp"; return 1 ;;
  esac
  if [ "$rc" -eq 0 ] && [ -s "$tmp" ]; then
    mv -f "$tmp" "$file"; return 0
  fi
  rm -f "$tmp"; return 1
}

# Build a jq setpath() key array from a dotted path: ".tool.version" ->
# ["tool","version"]. Keys are already validated (no '"' / '[' / ']'), so the
# concatenation is injection-safe.
_bt-path-array() {
  local p="${1#.}" IFS=. key arr="[" first=1
  local -a keys
  read -r -a keys <<< "$p"
  for key in "${keys[@]}"; do
    [ "$first" -eq 1 ] || arr+=","
    arr+="\"${key}\""
    first=0
  done
  arr+="]"
  printf '%s' "$arr"
}

# Rewrite every line containing the literal <search>, replacing all
# occurrences with <replace>, preserving all other bytes. Writes atomically.
# Sets _BT_COUNT to the number of replacements made. Returns:
#   0  wrote the file (>=1 replacement) and postcondition held
#   2  zero matches (nothing written)
#   1  a write / postcondition failure
_bt-text-set() {
  local file="$1" search="$2" replace="$3"
  local line out="" eof=false before remain acc tmp
  _BT_COUNT=0

  while [ "$eof" = false ]; do
    IFS= read -r line || eof=true
    [ "$eof" = true ] && [ -z "$line" ] && break
    # Quoted "$search" is a literal in the glob; the unquoted * is the wildcard.
    if [[ "$line" == *"$search"* ]]; then
      acc=""; remain="$line"
      while [[ "$remain" == *"$search"* ]]; do
        before="${remain%%"$search"*}"
        acc+="${before}${replace}"
        remain="${remain#*"$search"}"
        _BT_COUNT=$((_BT_COUNT + 1))
      done
      line="${acc}${remain}"
    fi
    if [ "$eof" = true ]; then
      out+=$line
    else
      out+=$line$'\n'
    fi
  done < "$file"

  [ "$_BT_COUNT" -eq 0 ] && return 2

  tmp=$(mktemp "${file}.XXXXXX") || return 1
  if printf '%s' "$out" > "$tmp" && grep -qF -- "$replace" "$tmp"; then
    if mv -f "$tmp" "$file"; then
      return 0
    fi
  fi
  rm -f "$tmp"
  return 1
}

# Bump every registered target (--bump / BUMP_FILES). Runs in the Release
# phase alongside bump-json-files; the two are independent. Mirrors
# bump-json-files' logging, dry-run previews, GIT_MSG accounting, and staging.
bump-target-files() {
  resolve-bump-targets
  ((${#_RESOLVED_BUMP_SPECS[@]})) || return 0

  local spec cur arr desc rc
  local -a PROCESSED=()

  for spec in "${_RESOLVED_BUMP_SPECS[@]}"; do
    _bt-parse-spec "$spec"  # already validated in check-bump-deps; cheap to redo

    if [ ! -f "$_BT_FILE" ]; then
      log_warn "file <${S_VAL-}${_BT_FILE}${RESET-}> not found — skipping."
      continue
    fi

    if [ "$_BT_KIND" = pattern ]; then
      # Text search/replace. The search line must currently read the pattern
      # with V_PREV; with no prior version there is nothing to search for.
      if [ -z "${V_PREV:-}" ]; then
        log_error "<${S_VAL-}${_BT_FILE}${RESET-}>: no previous version to build a {{version}} search from — pass -v or add a source file."
        continue
      fi
      local search="${_BT_PATTERN//\{\{version\}\}/$V_PREV}"
      local replace="${_BT_PATTERN//\{\{version\}\}/$V_NEW}"
      desc="'${_BT_PATTERN}'"

      if [ "$search" = "$replace" ]; then
        # V_NEW == V_PREV: replacing is a no-op. Warn if present, else report.
        if grep -qF -- "$search" "$_BT_FILE"; then
          log_warn "<${S_VAL-}${_BT_FILE}${RESET-}> already matches version ${S_VAL-}${V_NEW}${RESET-}."
        else
          log_error "<${S_VAL-}${_BT_FILE}${RESET-}>: no line matching ${S_VAL-}${search}${RESET-} found."
        fi
        continue
      fi

      if [ "$FLAG_DRYRUN" = true ]; then
        if grep -qF -- "$search" "$_BT_FILE"; then
          echo -e "${S_LIGHT-}[dry-run]${RESET-} would replace ${S_VAL-}${search}${RESET-} ${I_ARROW-→} ${S_VAL-}${replace}${RESET-} in ${S_VAL-}${_BT_FILE}${RESET-}" >&2
          GIT_MSG+="updated ${_BT_FILE}, "
          PROCESSED+=("$_BT_FILE")
        elif grep -qF -- "$replace" "$_BT_FILE"; then
          log_warn "<${S_VAL-}${_BT_FILE}${RESET-}> already contains version ${S_VAL-}${V_NEW}${RESET-}."
        else
          log_error "<${S_VAL-}${_BT_FILE}${RESET-}>: no line matching ${S_VAL-}${search}${RESET-} found."
        fi
        continue
      fi

      _bt-text-set "$_BT_FILE" "$search" "$replace"; rc=$?
      case "$rc" in
        0)
          log_success "Updated <${S_VAL-}${_BT_FILE}${RESET-}>: ${S_VAL-}${V_PREV}${RESET-} ${I_ARROW-→} ${S_VAL-}${V_NEW}${RESET-} (${_BT_COUNT}×)."
          GIT_MSG+="updated ${_BT_FILE}, "
          PROCESSED+=("$_BT_FILE")
        ;;
        2)
          if grep -qF -- "$replace" "$_BT_FILE"; then
            log_warn "<${S_VAL-}${_BT_FILE}${RESET-}> already contains version ${S_VAL-}${V_NEW}${RESET-}."
          else
            log_error "<${S_VAL-}${_BT_FILE}${RESET-}>: no line matching ${S_VAL-}${search}${RESET-} found."
          fi
        ;;
        *)
          # Write / postcondition failure. The file is left untouched (the
          # temp is only renamed after the in-tmp grep check passes), so —
          # like a failed JSON extra in bump-json-files — this is loud but
          # non-fatal: the release continues without this file bumped.
          log_error "failed to update <${S_VAL-}${_BT_FILE}${RESET-}> (write or postcondition check failed) — left untouched."
        ;;
      esac
      continue
    fi

    # Structured path (json/toml/yaml).
    arr=$(_bt-path-array "$_BT_PATH")
    cur=$(_bt-struct-get "$_BT_FILE" "$_BT_FMT" "$arr")
    desc="@${_BT_PATH#.}"

    if [ "$cur" = "$V_NEW" ]; then
      log_warn "<${S_VAL-}${_BT_FILE}${RESET-}> already contains version ${S_VAL-}${V_NEW}${RESET-} at ${S_VAL-}${desc}${RESET-}."
      continue
    fi

    if [ "$FLAG_DRYRUN" = true ]; then
      echo -e "${S_LIGHT-}[dry-run]${RESET-} would set ${S_VAL-}${desc}${RESET-} = '${S_VAL-}${V_NEW}${RESET-}' in ${S_VAL-}${_BT_FILE}${RESET-} (was ${S_VAL-}${cur:-none}${RESET-})" >&2
      GIT_MSG+="updated ${_BT_FILE}, "
      PROCESSED+=("$_BT_FILE")
      continue
    fi

    if [ "$_BT_FMT" = json ] && [ "$_BT_PATH" = ".version" ]; then
      # Reuse the surgical, formatting-preserving top-level rewrite (R-TGT-3).
      _bt-json-version-set "$_BT_FILE"; rc=$?
    else
      _bt-struct-set "$_BT_FILE" "$_BT_FMT" "$arr" "$V_NEW"; rc=$?
    fi

    if [ "$rc" -eq 0 ] && [ "$(_bt-struct-get "$_BT_FILE" "$_BT_FMT" "$arr")" = "$V_NEW" ]; then
      # Postcondition (R-TGT-5): the re-read through the locator confirms V_NEW.
      log_success "Updated <${S_VAL-}${_BT_FILE}${RESET-}>: ${S_VAL-}${cur:-none}${RESET-} ${I_ARROW-→} ${S_VAL-}${V_NEW}${RESET-} at ${S_VAL-}${desc}${RESET-}."
      GIT_MSG+="updated ${_BT_FILE}, "
      PROCESSED+=("$_BT_FILE")
    elif [ "$rc" -eq 0 ]; then
      # Tool reported success but the value didn't take — surface it (non-fatal,
      # like a failed JSON extra) rather than trusting a silent bad write.
      log_error "post-write check failed for <${S_VAL-}${_BT_FILE}${RESET-}>: ${S_VAL-}${desc}${RESET-} is not ${S_VAL-}${V_NEW}${RESET-} after the write."
    else
      log_error "failed to update <${S_VAL-}${_BT_FILE}${RESET-}> at ${S_VAL-}${desc}${RESET-}."
    fi
  done

  ((${#PROCESSED[@]})) && dryrun git add "${PROCESSED[@]}"
  return 0
}

# Thin wrapper so bump-target-files can call json_set_version by name while
# keeping the "reuse the surgical rewrite" intent explicit at the call site.
_bt-json-version-set() {
  json_set_version "$1" "$V_NEW"
}
