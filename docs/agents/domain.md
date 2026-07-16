# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root — the glossary / ubiquitous language. Not present yet; `/domain-modeling` creates it lazily when terms actually get resolved.
- **`docs/ADR.md`** — this repo keeps architectural decisions in a **single file**, one `## ADR-NN` section per decision (newest last), not a `docs/adr/` directory. Read the ADRs that touch the area you're about to work in.
- **`docs/PRD.md`** — the release-level product contract for the current target release.
- **`docs/features/<feature>/requirements.md`** — living, per-feature requirements with test mapping and open gaps. Read the one for the feature you're touching.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront. The `/domain-modeling` skill (reached via `/grill-with-docs` and `/improve-codebase-architecture`) creates them lazily when terms or decisions actually get resolved.

## File structure

Single-context repo. Domain docs live at the repo root and under `docs/`:

```
/
├── CONTEXT.md              ← glossary (created lazily; not present yet)
├── docs/
│   ├── ADR.md              ← all architectural decisions, `## ADR-NN` sections
│   ├── PRD.md              ← release-level product contract
│   └── features/
│       └── <feature>/requirements.md
├── ver-bump.sh
└── lib/
```

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal — either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-01 (pure-bash runtime; no npm/node at runtime) — but worth reopening because…_
