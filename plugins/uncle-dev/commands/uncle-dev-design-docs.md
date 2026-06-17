---
description: Scaffold HLD, LLD, and arrow docs for product behavior segments
---

Guide the human through authoring or refactoring HLD/LLD architecture docs and seeding the matching EARS spec catalog. Backed by `uncle-dev-design-architecture-docs`.

## Step 1 — Identify the operation

Ask the human which of these they're doing:

```
1. New HLD             — first time scaffolding the product's high-level design
2. New segment LLD     — adding a behavior segment to an existing product
3. Refactoring         — segment is wrong (split, merge, or rename)
```

If unclear, read `docs/high-level-design.md` and `docs/arrows/index.yaml` to infer state, then propose the operation type back.

## Step 2 — Branch by operation

### A) New HLD

1. Confirm `docs/high-level-design.md` does NOT already exist (do not overwrite).
2. Read the template: locate `skills/uncle-dev-design-architecture-docs/resources/hld-template.md` (search `${CLAUDE_PLUGIN_ROOT}` first, then plugin cache, then local clone).
3. Copy the template to `docs/high-level-design.md`.
4. Walk the human through filling in:
   - Vision (2-3 sentences)
   - Principles (durable architectural commitments)
   - Initial segment list (3-7 segments is typical for a new product)
   - Cross-segment invariants
   - Out-of-scope statements
5. After the HLD draft is reviewed, prompt for each declared segment to scaffold its LLD via the New segment LLD branch below.

### B) New segment LLD

1. Prompt for **segment name** (e.g. `auth`, `billing`). Validate against the rules in `uncle-dev-design-architecture-docs` — push back on weak names like `utils`, `frontend`, `backend`, `shared`.
2. Prompt for **EARS prefix** (e.g. `AUTH-*`). Default: uppercase segment name + `-*`.
3. Confirm no existing segment in `docs/arrows/index.yaml` already uses the prefix.
4. Scaffold these files (do not overwrite if present):
   - `docs/llds/<segment>.md` from `lld-template.md` in the design-architecture-docs skill resources
   - `docs/specs/<segment>-specs.md` from the spec template in `uncle-dev-spec-annotations/resources/templates/specs/SEGMENT-specs.md`
   - `docs/arrows/<segment>.md` from the arrow template in `uncle-dev-spec-annotations/resources/templates/arrows/SEGMENT.md`
5. Update `docs/arrows/index.yaml` — append a new entry under `arrows:` with the segment name, prefix, status `PROPOSED`, and `detail: <segment>.md`. If `docs/arrows/index.yaml` does not exist, scaffold it from `uncle-dev-spec-annotations/resources/templates/arrows/index.yaml`.
6. Substitute `{{segment}}` and `{{SEGMENT}}` placeholders in all four scaffolded files with the actual segment name + uppercase prefix root.
7. Walk the human through filling in:
   - LLD: responsibilities, what's in/out of scope for the segment, key flows
   - Spec catalog: first 1-3 EARS specs (use the `[ ]` gap marker for unimplemented behaviors)
   - Arrow doc: HLD section anchor link, paths to test/code (can be `[]` if none yet)
8. Run `/uncle-dev-spec-graph` to refresh the graph artifacts.

### C) Refactoring (split / merge / rename)

This is a cascade-aware operation. Walk the rules from `uncle-dev-design-architecture-docs` "Cascade Rules":

1. State which segments are involved and what's changing.
2. Run `/uncle-dev-spec-scan` to see current state.
3. For a **split**: create the new segment(s) (branch B above), then move EARS specs by renaming their IDs. Old IDs must be retired in the spec catalog (mark `[D]` deferred + comment); never reuse them.
4. For a **merge**: pick the surviving segment + prefix. Retire IDs from the deprecated segment one-by-one, replacing them with new IDs in the surviving prefix. Update `@spec` annotations in code/tests in the same PR.
5. For a **rename**: keep all spec IDs intact. Update `docs/arrows/index.yaml`, the arrow doc filename, the LLD filename, and the spec catalog filename. The prefix can stay (preferred) or change (rare; old IDs become legacy aliases).
6. Run `/uncle-dev-spec-scan` and `/uncle-dev-spec-graph` after every step.

## Step 3 — Verify

After any branch completes, run:

```bash
# Confirm the scanner is clean
/uncle-dev-spec-scan

# Refresh the graph so docs/arrows/spec-graph.* reflect the new state
/uncle-dev-spec-graph
```

Surface any orphans, missing tests, or boundary crossings introduced by the operation.

## Notes

- This command never edits source code — it scaffolds documentation only.
- It will not overwrite an existing file. If a target file exists, prompt the human first.
- Templates live with `uncle-dev-design-architecture-docs` (HLD/LLD) and `uncle-dev-spec-annotations` (specs/arrows). Cross-reference; do not duplicate.
- For deeper guidance on segment selection and prefix strategy, hand off to `uncle-dev-design-architecture-docs`.
