# VerBump

The domain language of `VerBump`, an opinionated release tool for Git
repositories. This glossary fixes the vocabulary the tool, its docs, and its
tests use. It is a glossary only — not a spec (see `docs/PRD.md`) and free of
implementation detail (see `docs/ADR.md`).

## Language

**Plain-bash release tool** (the canonical self-description):
What `VerBump` is: a plain-bash release tool for Git repositories with no Node
runtime, `git` and `jq` its only default-path dependencies. `ver-bump.sh` is the
entry point to read; the `lib/*.sh` split is an implementation detail, so the
tool is not described by a file count.
_Avoid_: one file, single-file, one-file script

**Default path**:
The execution of a `VerBump` invocation that uses no opt-in feature flags. It
is contractually restricted to `bash`, `git`, and `jq` — the dependency freeze
recorded in ADR-15.
_Avoid_: happy path, core path

**Opt-in feature**:
A capability gated behind an explicit flag or config key whose extra
dependencies are preflighted only when it is invoked (e.g. `--release` needs
`gh`; TOML/YAML bump targets need `tomlq`/`yq`). The counterpart to the default
path.
_Avoid_: plugin, extension, add-on
