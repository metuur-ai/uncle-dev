---
description: Reverse-engineer LLD + EARS specs from a /uncle-dev-feature-map output — a 5-agent swarm that maps domains to segments, writes specs, drafts LLDs, and anchors @spec annotations
---

## Working Principles

1. **Think Before Coding** — A feature map is a product catalog, not an LLD. Derive segments from its domain headers before assigning a single ID. State the segment→prefix mapping and get it confirmed before writing files.
2. **Simplicity First** — One LLD per real product-behavior segment, one prefix per segment. Don't compound prefixes (`AUTH-UI-*`) until a flat prefix feels cramped.
3. **Surgical Changes** — Agents output only; nothing is written until reconciliation. `@spec` annotations land only for `[x]` (implemented) specs.
4. **Goal-Driven Execution** — Done when `docs/llds/`, `docs/specs/`, and `docs/arrows/index.yaml` exist for every segment and `/uncle-dev-spec-scan` exits clean.

This command is backed by `uncle-dev-feature-map` (input), `uncle-dev-design-architecture-docs` (LLD/segment rules), and `uncle-dev-spec-annotations` (EARS IDs, `@spec`).

---

## Step 0 — Locate the feature map

The feature map is the input. Resolve it in this order:

1. If the user passed a path in `$ARGUMENTS`, use it.
2. Otherwise pick the most recent file in `.uncle-dev/feature-maps/`:
   ```bash
   ls -t .uncle-dev/feature-maps/*.md 2>/dev/null | head -1
   ```
3. If none exists, stop and offer to run `/uncle-dev-feature-map` first — do **not** invent a feature map.

Bind the resolved path to `<FEATURE_MAP_FILE>` for every agent below. Read it yourself first to confirm it has `### [Domain: …]` headers and `Feature | User Action | Backend Entry | Frontend Entry | Notes` tables. If it doesn't match that shape, say so and stop.

> **Graphify:** if `graphify-out/graph.json` exists, every spawned agent MUST use `graphify explain`/`graphify query` before grep/Glob/Read (per project CLAUDE.md). Agent 5 depends on this for fast source anchoring.

---

## Step 1 — Dispatch the swarm (5 agents, one message)

Call the Agent tool **five times in parallel** in a single message. Each is self-contained and shares only `<FEATURE_MAP_FILE>`. Each derives segments independently from the domain headers (deterministic), so they reconcile cleanly in Step 2.

### Agent 1 — Segment & Boundary Mapper

```
You are mapping a product feature map onto LID architecture segments.

Feature map: <FEATURE_MAP_FILE>

Tasks:
1. Read the feature map. List every "### [Domain: X]" header — each is a candidate segment.
2. For each domain, propose a segment named by product intent and ONE stable uppercase prefix
   (auth → AUTH-*, billing → BILLING-*, marketing site → MKT-SITE-*).
   - Reject weak names (utils/frontend/backend/shared/misc). If a domain is a file-location word,
     say what product behavior it actually describes and re-split it.
   - Propose a compound prefix (AUTH-UI-*, AUTH-API-*) ONLY if a single domain clearly mixes
     UI vs API vs persistence concerns. Otherwise stay flat.
3. Reconcile against what exists:
   - docs/arrows/index.yaml — is this segment already registered? Reuse its prefix, never invent a new one.
   - docs/llds/ and docs/specs/ — does an LLD/spec file already own this behavior?
   - Output per segment: REUSE EXISTING | NEW SEGMENT.
4. Flag boundary crossings: any feature row whose User Action spans two domains
   (e.g. "charge card on signup" = auth + billing). These need human confirmation before annotating.

Output: a table — Domain → Segment name → Prefix → status (REUSE/NEW) → registered in index.yaml? (yes/no),
plus a separate list of boundary-crossing features. Do NOT write files.
```

### Agent 2 — Behavior Extractor

```
You are extracting durable product behaviors from a feature map for EARS spec authoring.

Feature map: <FEATURE_MAP_FILE>

Tasks:
1. Read the feature map. Walk every feature row in every domain table.
2. For each row produce behavior candidates from BOTH columns:
   - User Action → the happy-path behavior ("When a user signs in with valid credentials, ...").
   - Notes → constraint behaviors, one per rule ("max 5 attempts", "token expires in 1h",
     "max 5 members per org" each become their own behavior).
3. Also mine the API-Only Capabilities, Orphaned UI, and Open Questions sections — these are
   real behaviors too, but mark their evidence: API-ONLY (backend, no UI), ORPHANED (UI, no backend),
   UNRESOLVED (Open Question — behavior unclear from code).
4. Keep only behaviors that are product-facing (a user or external system observes the outcome)
   AND testable. Drop internal plumbing, formatting, config notes, one-shot scripts.

Output: a numbered list grouped by domain. Each item:
  - Domain
  - Trigger (the "when")
  - Outcome (the "shall")
  - Source: the exact feature-map row/cell it came from
  - Evidence: BACKEND+FRONTEND | API-ONLY | ORPHANED | UNRESOLVED
Do NOT assign IDs. Do NOT write files.
```

### Agent 3 — EARS Writer + ID Assigner

```
You are writing EARS specs and assigning stable IDs from extracted behaviors.

Feature map: <FEATURE_MAP_FILE>

Tasks:
1. Read the feature map and derive segments+prefixes the same way Agent 1 does
   (domain headers → segment; reconcile with docs/arrows/index.yaml).
2. For each segment, scan docs/specs/<segment>-specs.md for the highest existing ID number
   so new IDs never collide. If the spec file does not exist, start at 001.
3. For every behavior in the feature map, write ONE EARS line:
   "When [trigger], the system SHALL [outcome]." — outcome observable, no implementation words.
4. Assign the next ID per segment: SEGMENT-AREA-NNN. Set the status marker by evidence:
   - [x] implemented   → has both backend AND frontend entry in the feature map
   - [ ] active gap    → API-only, orphaned UI, or otherwise partially wired
   - [D] deferred      → Open Question / behavior not yet confirmed in code
5. Emit ready-to-paste content per spec file, including the header that declares the prefix:

   --- docs/specs/<segment>-specs.md ---
   # <Segment> specs — prefix: SEGMENT-*
   - [x] **SEGMENT-AREA-001**: When [trigger], the system SHALL [outcome].
   - [ ] **SEGMENT-AREA-002**: When [trigger], the system SHALL [outcome].  (active gap: API-only)

Flag any behavior that crosses two segments — do not split one behavior across two prefixes.
Do NOT write files; output only for review.
```

### Agent 4 — LLD Synthesizer

```
You are reverse-engineering LLD documents from a product feature map.

Feature map: <FEATURE_MAP_FILE>

Tasks:
1. Read the feature map and group features by domain (= segment), the same way Agent 1 does.
2. If skills/uncle-dev-design-architecture-docs/resources/lld-template.md exists, follow it exactly.
   Otherwise use the structure below.
3. For EACH segment, draft docs/llds/<segment>.md answering:
   - Behaviors this segment owns (summarize from the domain's feature rows — product language, not code).
   - Segment boundary: what it explicitly does NOT own (name the adjacent segments that own those).
   - Key flows: derive from User Action + Backend Entry + Frontend Entry (route in → page/handler → outcome).
   - EARS prefix for this segment (from Agent 1's mapping).
   - Links: docs/specs/<segment>-specs.md and docs/arrows/<segment>.md.
4. Note any domain that is too thin to justify its own LLD, or two domains that should merge.

Output: one fenced markdown block per segment, ready to save as docs/llds/<segment>.md.
Keep each LLD to system-level approach — no code-level detail, no product narrative (that's the HLD).
Do NOT write files.
```

### Agent 5 — Source Anchor + Annotation Generator

```
You are anchoring EARS IDs to source entry points and generating @spec annotations.

Feature map: <FEATURE_MAP_FILE>

Context: the feature map already lists Backend Entry (route/handler) and Frontend Entry (page/component)
for most features — use those as your search seeds instead of blind grepping.

Tasks:
0. If graphify-out/graph.json exists, use `graphify explain "<feature>"` / `graphify query` FIRST
   to locate entry points; fall back to grep/Glob only if it returns empty.
1. For each behavior/feature, resolve its real entry point in src/, app/, lib/, pkg/:
   an exported function, route handler, or component — NOT a helper/util. Report file:line + name.
2. Find the test that proves it (tests/, __tests__/, *.test.ts, *.spec.ts, test_*.py).
3. Using the IDs proposed by Agent 3, emit a diff-ready @spec patch per entry point AND per test:
   - TS/JS/Go/Rust/Java: // @spec <ID>        Python: # @spec <ID>        HTML: <!-- @spec <ID> -->
   - Place the comment on the line directly before the topmost owning function. Multiple IDs: // @spec A-001, A-002
4. Status per pair:
   - ✓ already annotated with the correct ID (no change)
   - ⚠ annotated with a DIFFERENT ID (needs review)
   - ✗ NOT FOUND — flag as a gap (matches an API-only / orphaned / deferred spec)

Output: a per-file patch list only. Do NOT write any files.
```

---

## Step 2 — Reconcile (in cascade order)

After all five return, reconcile in this order — mirrors `HLD → LLD → EARS → Code`:

1. **Lock segments + prefixes** from Agent 1. Surface every boundary crossing to the human and resolve it *before* writing anything. Push back on weak segment names.
2. **Align IDs and LLDs** — apply Agent 1's final segment names to Agent 3's IDs and Agent 4's LLDs so prefixes match. Resolve any ID collisions Agent 3 missed.
3. **Write docs, top-down** (do not overwrite existing files without confirming):
   - `docs/llds/<segment>.md` (Agent 4)
   - `docs/specs/<segment>-specs.md` (Agent 3, with the prefix header)
   - `docs/arrows/<segment>.md` + register each segment in `docs/arrows/index.yaml` (status `PROPOSED` for new segments)
4. **Apply `@spec` annotations** from Agent 5 — only for `[x]` specs. Leave `[ ]` (active gap) and `[D]` (deferred) as untouched gaps.

Present a concise summary: segments created/reused, spec counts per segment ([x]/[ ]/[D]), and any boundary crossings or NOT FOUND gaps that need follow-up.

---

## Step 3 — Verify

```bash
/uncle-dev-spec-scan    # expect exit 0 — no ORPHAN, no MISSING TEST
/uncle-dev-spec-graph   # refresh docs/arrows/spec-graph.* with the new state
```

Surface anything the scanner flags. A clean scan plus a refreshed graph means the brownfield reverse-engineering is coherent.

## Notes

- This command writes documentation (`docs/llds/`, `docs/specs/`, `docs/arrows/`) and applies `@spec` annotations only to already-implemented entry points. It does not refactor source.
- It never invents a feature map — if none exists, it hands off to `/uncle-dev-feature-map`.
- For deeper segment/prefix guidance hand off to `uncle-dev-design-architecture-docs`; for annotation syntax, `uncle-dev-spec-annotations`.

$ARGUMENTS
