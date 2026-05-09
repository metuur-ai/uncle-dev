# Acknowledge Gate (Step 4b)

Loaded by `uncle-dev-next-task` after Step 4 (compute ready set) and before Step 5 (rank). Drops any story whose touched-scopes intersect with any `status: pending` decision in `openspec/acknowledge/`. The block is **non-bypassable** — there is no flag to skip the gate.

## When the gate is active

If `openspec/acknowledge/` does not exist, the gate is a no-op (and the picker proceeds normally). The gate becomes active on the first run of `/uncle-dev-acknowledge`, which auto-creates the directory plus `general.md` and `_meta.yaml`.

## Touched-scopes derivation for a story

For each story still in the ready set after Step 4, compute the set of scopes the story touches. Sources, in order — union all that match:

1. **Annotation.** Parse the story's `**Annotations:**` line for `(scope: a, b)` per `parsing-and-annotations.md`. Comma-separated, whitespace-tolerant. If present, this is authoritative — the human declared it.
2. **Path globs in story prose.** Scan the entire story block (heading + acceptance criteria + verification + dependencies + annotations) for paths matching `apps/<x>/`, `packages/<x>/`, `libs/<x>/`, `services/<x>/`. The first segment after the prefix becomes a scope.
3. **`design.md` correlation.** Read `openspec/changes/<change-id>/design.md`. If the **Technical Decisions** section names this story id (e.g. as a heading or a row tag), pull the scopes from any sibling rows that include path mentions per (2).
4. **Fallback.** If no scope is derived from any of the above, treat the story's scope set as `{general}`. This means: any pending decision in `general.md` blocks ALL stories (which is correct — `general` is for cross-cutting concerns).

## The filter

```
For each pending decision D in openspec/acknowledge/<scope>.md (any scope, any file):
    For each story S still in the ready set:
        if S.touched_scopes ∩ {D.scope} ≠ ∅:
            move S to blocked-by-acknowledgement
            record D as one of S's blockers
```

Scope match is exact-string on filename-without-`.md`. No prefix matching, no wildcards.

A story is **blocked-by-acknowledgement** when at least one pending decision in any of its touched scopes exists. The story does NOT re-enter the ready set until every pending decision in those scopes is acked, rejected, or superseded.

## The BLOCKED output (replaces the recommendation block)

When at least one story is blocked-by-acknowledgement AND the recommendation would have been one of those stories, the picker emits the BLOCKED block instead of the standard "READY SET" output:

```
BLOCKED: pending acknowledgements for scopes touched by 1.3 [api, share]
  • D5 (api) — constant-time login            openspec/acknowledge/api.md:14
  • D9 (api, share) — passwordHash nullable   openspec/acknowledge/api.md:48

Other stories in the ready set are also affected:
  • 1.4 [api]      blocked by D5, D6
  • 2.1 [share]    blocked by D9

To unblock:
  /uncle-dev-acknowledge ack D5,D9               # mark acknowledged
  /uncle-dev-acknowledge reject D5 --reason "…"  # reject + record
  Edit openspec/acknowledge/<scope>.md and flip `status:` manually

This gate is non-bypassable. After unblocking, re-run /uncle-dev-next-task.
```

The file:line locations are derived by re-grepping each scope file for the section anchor; the picker MUST display the location pointing at the heading line, not the comment line.

When `--ready` is passed (no recommendation requested, just print the ready set), the gate still applies but the output keeps the standard READY SET shape with a `(blocked-by-ack: D5)` annotation per affected story instead of dropping them silently. This keeps the diagnostic mode useful.

## Interaction with `--claim`

If the recommended story is blocked-by-acknowledgement, `--claim` MUST refuse to acquire a lock and print the BLOCKED block. There is no override. This is the integration point that makes `/uncle-dev-build` honor the gate without needing its own awareness of acknowledge state.

## Performance

Reading every `openspec/acknowledge/<scope>.md` on every picker run is fine — these are small files (one per package, dozens of sections each at most). No caching is needed. The gate adds ~10–50ms to a typical picker call, well below the lock-acquisition timing.

If the directory grows enormous (hundreds of scopes, thousands of decisions), the optimization is to maintain a cached index in `_meta.yaml` (`pending_by_scope:`), refreshed on every capture/workflow operation. Don't build that until measurements demand it.

## Determinism

The gate is deterministic given the same `openspec/acknowledge/` state and the same story. Two parallel picker calls return the same blocker list for the same story. They race only on `/uncle-dev-acknowledge ack`, where exactly one ack wins the `_meta.yaml` lock at a time.

## Edge cases

| Case | Behavior |
|---|---|
| `openspec/acknowledge/` exists but is empty (no `_meta.yaml`, no scope files) | Gate is a no-op. |
| `general.md` exists with only acknowledged decisions | Gate is a no-op for stories whose touched scopes don't include other pending decisions elsewhere. |
| A pending decision in `web.md` and a story whose touched scopes are `[api]` only | Story is NOT blocked. Scope match is exact. |
| A pending decision in `general.md` | Blocks every story whose touched-scopes derivation falls back to `{general}` — which is most stories without explicit scope annotations. This is intentional pressure to add `(scope: …)` annotations to your stories. |
| A story with `(scope: none)` annotation | Treated as `{general}` (no override of the gate via "none"). |
| `_meta.yaml` missing or malformed | Warn and read the scope files directly; the gate still works without `_meta.yaml`. |
