# Context

## Product requirements

@docs/PRD.md

## Coding standards

@.sandcastle/CODING_STANDARDS.md

## Open issues (gated by `ready-for-agent`)

!`gh issue list --state open --label ready-for-agent --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`

## Host working-tree state (paths with uncommitted changes on `develop`)

These paths are dirty on the host and MUST NOT overlap with any issue you
schedule this iteration. If a candidate issue would touch any of these
files, defer it.

!`git status --porcelain | awk '{print $2}'`

## Recent RALPH activity (signals what was just merged / parallel inflight)

!`git log --oneline --grep="ralph:" -20`

# Task

You are the **Planner**. Build a dependency graph of the open
`ready-for-agent` issues and select the subset that can be worked on
**concurrently in this iteration** without producing merge conflicts
either against each other or against the host's dirty working tree.

## Blocking rules

Issue B is blocked by issue A if **any** of the following hold:

1. B requires code, helpers, or contracts that A introduces (e.g. B
   needs a new `lib/x.sh` that A creates).
2. B and A modify overlapping files. For ver-bump, treat these as the
   high-collision surfaces:
   - `ver-bump.sh` (orchestrator — almost every change touches it)
   - `lib/helpers.sh` (will eventually be split per #44)
   - `lib/config.sh`
   - any single file in `lib/` that both issues' descriptions reference
3. B's spec depends on a decision A makes (API shape, config key name,
   exit-code assignment).
4. **Host overlap:** B's expected file set intersects the dirty paths
   listed in the "Host working-tree state" section above.

## Exclusions

- **PRD/meta issues** with linked implementation children: planner must
  **never** select these — they are `ready-for-human`-equivalent
  containers, not work items.
- **Issues missing acceptance criteria** in their body: defer (the
  implementer needs concrete done-conditions).
- **Issues already in flight on a `sandcastle/*` branch** with commits
  ahead of `develop`: skip; their merger run hasn't completed.

## Branch naming

For each selected issue, assign:

    sandcastle/issue-<number>-<kebab-slug-of-title>

Slug ≤ 32 chars, lowercase, ASCII only, no leading/trailing dash.

# Output

Emit a single JSON object inside `<plan>` tags. Nothing else after the
closing tag. Example:

<plan>
{"issues": [
  {"number": 47, "title": "Strip ANSI when stdout is not a TTY", "branch": "sandcastle/issue-47-strip-ansi-non-tty"},
  {"number": 51, "title": "Add --json output for --about", "branch": "sandcastle/issue-51-about-json"}
]}
</plan>

If every open issue is blocked (by host dirt, by inflight branches, or
by each other), output `{"issues": []}` — the orchestrator will skip
the iteration. Do NOT pick a "least bad" candidate that conflicts with
the host tree; the SyncError on merge-back is worse than an idle
iteration.

If there are zero open `ready-for-agent` issues, also output
`{"issues": []}`.
