# TASK

Review the code changes on branch `{{BRANCH}}`, improve clarity,
consistency, and maintainability while preserving exact functionality,
then open a pull request so a human can land the change.

# CONTEXT

## Coding standards (load first)

The canonical rules for this project. Read before reviewing:
@.sandcastle/CODING_STANDARDS.md

## Product requirements

Background and scope context for why the change exists:
@docs/PRD.md

## Issue being addressed

You are reviewing **#{{ISSUE_NUMBER}} — {{ISSUE_TITLE}}**.
The implementer's PR will need to close it via a `Closes #{{ISSUE_NUMBER}}.`
trailer; do not re-derive the number from commit messages.

## Branch overview

Diff stat against the integration branch (`feat/v2.0`):

!`git diff --stat feat/v2.0...{{BRANCH}}`

Commits added by the implementer:

!`git log feat/v2.0..{{BRANCH}} --oneline`

## Reviewing the actual change

The full diff is intentionally NOT inlined — for any non-trivial branch
it would exceed the OS argv limit and crash the agent invocation
(observed E2BIG on docs-only branch with `pnpm-lock.yaml` in the host
tree). Read what you need on demand:

- `git diff feat/v2.0...{{BRANCH}} -- <path>` to read a single file's diff.
- `git show <sha>` to read one commit at a time.
- `git diff feat/v2.0...{{BRANCH}} --name-only` to enumerate touched files.

Skip auto-generated lockfiles (`pnpm-lock.yaml`, `package-lock.json`)
unless the issue is specifically about dependency changes.

# REVIEW PROCESS

## 1. Understand the change

Read the diff, the commits, the referenced issue, and the relevant PRD
section. Confirm the change matches the stated intent before touching
anything.

## 2. Check Bash-specific failure modes

This is a Bash project targeting Bash 3.2+. Audit for these concrete
problems — not TypeScript concerns:

### Quoting and expansions

- Unquoted variable expansions that could word-split or glob
  (`$var` vs `"$var"`, `$@` vs `"$@"`, array expansion without
  `"${arr[@]}"`).
- Missing `${var-}` / `${var:-default}` in code paths that may run
  before defaults are applied, or under `set -u`.
- Use of `${arr[@]}` without the `${arr[@]+"${arr[@]}"}` guard on
  possibly-empty arrays (Bash 3.2 "unbound variable" trap).

### Bash 3.2 compatibility

- Use of associative arrays (`declare -A`) — banned; use parallel
  indexed arrays.
- Use of `${var^^}` / `${var,,}` case conversion — not in 3.2.
- Use of `readarray` / `mapfile` without a fallback.

### Project UI/colour discipline (regression-guarded by `test/ui.bats`)

- Raw `GREEN` / `RED` / other colour vars referenced outside `lib/styles.sh`.
- Reintroduction of `S_NOTICE` anywhere in `lib/helpers.sh` or `ver-bump.sh`.
- Narrative lines wrapped in colour (should be plain; only values get
  `S_VAL`, prompts get `S_QUESTION`, dim markers get `S_LIGHT`, errors
  go via `fail`).
- Style tokens referenced without default-safe form (`${S_OK-}` not
  `${S_OK}`) in library code that tests source directly.

### Error and exit-code contract

- New error paths that exit via raw `exit 1` instead of
  `fail <code> "<msg>" "<hint>"`.
- Exit codes that don't fit the canonical table in `CODING_STANDARDS.md`
  (0 ok, 1 generic, 2 usage, 3 precondition, 4 hook, 5 user-abort).
- Error messages missing a hint when self-service recovery is possible.
- Errors written to stdout instead of stderr.

### Side-effects and dry-run

- New filesystem / git / network calls not routed through `dryrun` or
  an explicit `[ "$FLAG_DRYRUN" = true ]` guard.
- Non-atomic file writes where `jq_inplace`-style
  mktemp-then-rename would be correct.
- Commands that mutate `$PWD` (bare `cd`) without a subshell or a
  guaranteed restore.

### Config and precedence

- New config keys that break the `CLI > env > file > default`
  precedence enforced by `load-config` → `apply-config-defaults` →
  `process-arguments`.
- Unconditional assignment (`TAG_PREFIX="v"`) where `:=`
  (`: "${TAG_PREFIX:=v}"`) is required to preserve env values.

### ShellCheck hygiene

- New `# shellcheck disable=...` directives without an inline comment
  explaining why.
- File-scope `shellcheck disable` for rules that don't apply to every
  line.

## 3. Check general clarity (after Bash-specific audit)

- Unnecessary complexity, nesting, or abstraction.
- Redundant code or dead branches.
- Variable and function names that don't match the project's
  kebab-case (public) / snake_case (helpers) / `UPPER_SNAKE_CASE`
  (globals) conventions.
- Obvious comments that narrate *what* the code does rather than *why*.
- Missing comments on non-obvious invariants (interop contracts,
  edge-case rationale, references to issues resolved earlier).

## 4. Check correctness and coverage

- Does the implementation match the issue's intent? Are edge cases
  handled?
- Is the new/changed behaviour covered by a **bats** test in the
  appropriate `test/<feature>.bats` file?
- Does anything touching git state use `scratch_repo` isolation rather
  than the live checkout?
- Does anything asserting on user-facing output call `strip_ansi_output`
  first?
- Security: any injection risk from unquoted user input in `eval` /
  `bash -c` / unquoted `$(cmd)` substitutions? Any credential / token
  leak in logs or error messages?

## 5. Maintain balance

Avoid over-simplification that would:

- Reduce clarity or maintainability.
- Produce overly clever solutions that are hard to understand.
- Combine unrelated concerns into one function.
- Remove helpful abstractions (`log_*`, `dryrun`, `jq_inplace`, `fail`)
  in favour of inlined ad-hoc code.
- Make debugging or extension harder.

## 6. Preserve functionality

Never change what the code does — only how. All existing flags, output
text, exit codes, and side-effects must remain intact.

# EXECUTION

## If you make improvements

1. Make the edits directly on branch `{{BRANCH}}`.
2. Re-run the full verification suite. All must pass:
   - `npm run tests:run`
   - `shellcheck -x -e SC1017 ./ver-bump.sh ./lib/helpers.sh ./lib/styles.sh ./lib/icons.sh`
3. Commit the refinements in a **separate commit** from the
   implementer's work, so the diff between "implement" and "review"
   stays legible in history. Use:

       refactor(ralph-review:<area>): <subject>

   Body summarises what was tightened and why — do not restate the
   implementer's change.

## If the code is already clean

Do not make a no-op commit. Proceed straight to the PR step.

## Open the pull request

After review edits (or immediately if none were needed):

1. Push the branch: `git push -u origin {{BRANCH}}`.
2. Open a PR with `gh pr create`. The title MUST follow
   Conventional Commits (see `CODING_STANDARDS.md` — scoped, imperative,
   ≤ 70 chars, no `ralph` marker in the PR title itself since that is
   commit-level metadata).
3. The PR body MUST include:
   - A one-paragraph summary of **why** (mirroring the commit body).
   - A bullet list of concrete changes, grouped by area if multi-scope.
   - Behavioural notes / edge cases / precedence rules touched.
   - Test coverage: files added/changed and `Full suite: N/N.`.
   - ShellCheck status: `ShellCheck: clean.`.
   - A `Closes #{{ISSUE_NUMBER}}.` trailer. This is where issue closure
     happens — **not** from an agent-invoked `gh issue close`.
4. Do **not** merge the PR. A human reviewer lands it.

# Done

Once the PR URL is printed, output:

<promise>COMPLETE</promise>
