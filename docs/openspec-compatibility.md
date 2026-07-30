# OpenSpec compatibility

OpenMerge is developed through OpenSpec using the project-local custom schema
`openmerge-product`. Custom schemas are marked experimental upstream, and not every
OpenSpec command handles one. This file records exactly which do, which do not,
and what to use instead.

Re-verify this file after upgrading OpenSpec.

## Pinned version

| | |
| --- | --- |
| OpenSpec version verified against | **1.7.0** |
| Schema | `openspec/schemas/openmerge-product/` |
| First artifact | `research.md` (there is **no** `proposal.md`) |
| Artifact order | research → product → specs → architecture → threat-model → benchmark → adrs → rollout → tasks → verification |

Upgrade with `npm install -g @fission-ai/openspec@latest`, then re-run the
verification commands below. Running a stale CLI is not neutral: 1.7.0's own
changelog documents that an out-of-date install reports tools as up to date while
never writing workflows added in newer releases.

## Commands that work

| Command | Notes |
| --- | --- |
| `openspec status --change <name>` | primary progress view; `--json` for tooling |
| `openspec instructions <artifact> --change <name>` | delivers template, context, rules, dependencies; `--json` for tooling |
| `openspec instructions apply --change <name>` | returns apply inputs including `operationGuidance` |
| `openspec instructions archive --change <name>` | returns archive inputs including `operationGuidance` |
| `openspec validate <name>` | structural check; `--strict` for the stricter pass |
| `openspec schema validate openmerge-product` | validates the schema itself |
| `openspec templates --schema openmerge-product` | resolves every artifact template path |
| `openspec list` | lists active changes |
| `openspec context` | prints the working context for the resolved root |
| `openspec new change <name>` | scaffolds with the configured schema |
| `openspec update` | regenerates agent skills and commands |

## Commands that do not work

### `openspec show <change> --json --deltas-only`

```
$ openspec show define-product-contracts --json --deltas-only
{
  "status": [
    {
      "severity": "error",
      "code": "show_error",
      "message": "Change \"define-product-contracts\" has no proposal.md yet. Run \"openspec status --change define-product-contracts\" to see which artifact comes next."
    }
  ]
}
```

**Cause.** The command requires a `proposal.md` artifact. This schema replaces
`proposal` with `research` plus `product`, so the precondition can never be
satisfied.

**Impact.** Any workflow that inspects parsed deltas through this command fails
here. The bundled `openspec-verify-change` skill suggests it as a debugging step.

**Use instead.** `openspec validate <name> --strict` confirms the deltas parse.
For content, read `openspec/changes/<name>/specs/*/spec.md` directly, or use
`scripts/openspec-context.sh`.

**Do not** add an empty `proposal` artifact to satisfy the command. That bends the
schema to fit a tool rather than the reverse, and leaves a permanent fake node in
the artifact graph.

## Behaviours that look like bugs and are not

**`openspec validate` fails on a change with artifacts but no specs.** The error
is `Change must have at least one delta. No deltas found.` This is expected while
a change is still in the artifact phase — validation is delta-oriented, and there
are no deltas until `specs/` exists. Use `openspec status --change` for progress
until then.

**`openspec new change` prints the default schema name before the real one.** The
progress line reads `Creating change '<name>' with schema 'spec-driven'` and the
following line reports `Schema: openmerge-product`. The recorded schema in
`.openspec.yaml` is correct; only the progress line is misleading.

**`/opsx:verify` reports no design document to check.** Its coherence dimension
looks for a `design` artifact. This schema has `architecture` and `adrs` instead.
Map the check onto those; an ADR violation is a CRITICAL coherence finding here.

**Config `rules` entries containing `": "` are silently dropped.** An unquoted
YAML sequence item containing a colon-space parses as a mapping, and OpenSpec then
reports `Rules for '<artifact>' must be an array of strings, ignoring this
artifact's rules` — discarding **all** rules for that artifact, not just the
malformed entry. Quote any rule containing `": "`.

## Upstream status

No upstream issues have been filed for the items above yet. If any is filed, link
it here with its state, so nobody re-diagnoses a known problem.

| Item | Upstream issue | State |
| --- | --- | --- |
| `show --deltas-only` requires `proposal.md` | not filed | — |
| `new change` reports the default schema in its progress line | not filed | — |
| Malformed rule entry discards all rules for the artifact | not filed | — |
