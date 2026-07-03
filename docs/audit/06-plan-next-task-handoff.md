# 06 — Fix plan → next-task handoff; reconcile the two spec universes (P0/P1)

## Problem

Two workflow handoffs are broken by format mismatch, one artifact is written
but never read, and the ecosystem contains two spec-document universes that
both claim to be the source of truth but never intersect.

### Finding A — plan output is unparseable by next-task (P0)

The next-task picker's parser requires
(`skills/uncle-dev-next-task/parsing-and-annotations.md:15,33`):

- story IDs matching `^[0-9]+(\.[0-9]+)*$`
- `### Story 1.1:` **h3** headers

The planning skill's templates emit
(`skills/uncle-dev-planning-and-task-breakdown/SKILL.md:195,285`):

- `## Story STORY-101: [Title]` — **h2** headers with IDs that fail the regex

Stories written per the plan template cannot be parsed by the picker's
declared grammar.

### Finding B — plan never writes the `**Annotations:**` line (P0)

The plan skill's Step 4 template (`SKILL.md:194-211`) has no Annotations
line. The parser's backward-compat fallback
(`parsing-and-annotations.md:112-118`) then serializes everything to document
order — **silently defeating the entire parallelism/mutex machinery** the
picker exists for. `uncle-dev-next-task/SKILL.md:363` says the planning skill
"emits the annotations this skill consumes"; it never instructs writing them.

### Finding C — orphan `handoff.md` (P1)

`commands/uncle-dev-spec.md:217-219` creates
`openspec/changes/<id>/handoff.md`; zero consumers exist (grep across
commands/ and skills/). Real handoffs go to `.devlocal/handoffs/` via
`/uncle-dev-wrap`. Orphan artifact with a name collision against the wrap
handoff concept.

### Finding D — change-ID format contradiction (P1)

`commands/uncle-dev-spec.md:216` and `hooks/openspec-guard.sh` require
`NNN-slug` (`^[0-9]{3}-`), but `skills/uncle-dev-next-task/SKILL.md:27` uses
example ID `PF-001-foundations-cross-cutting` (fails the regex), and the
repo's own live change `openspec/changes/companion-modes-foundation/` also
fails it.

### Finding E — two spec universes that never intersect (P1, design decision)

- **SDD chain**: `docs/hld|lld|ears/<slug>.md` with `R-x.y` IDs
  (`skills/uncle-dev-spec-driven-development/SKILL.md:59-160`).
- **Design-docs/brownfield/annotations chain**: `docs/llds/<segment>.md`
  (plural), `docs/specs/<segment>-specs.md`, `docs/arrows/` with
  `SEG-AREA-NNN` IDs (`skills/uncle-dev-design-architecture-docs/SKILL.md:34,211`,
  `commands/uncle-dev-brownfield.md:101-181`).

CLAUDE.md claims "HLD → LLD → EARS specs → tests → code" is one flow; the two
chains never intersect — no command bridges `docs/ears/` into `docs/specs/`.
Consequences:

- The `@spec` scanner validates only `SEG-AREA-NNN` IDs against
  `docs/specs/`; `R-1.1`-style IDs contain a dot and fail the scanner's ID
  regex (`hooks/spec-coherence-guard.sh` spec_id_set:
  `[A-Z][A-Z0-9-]*-[0-9]+`); `docs/ears/` is never scanned.
- `commands/uncle-dev-ship.md:57` requires "for each requirement (R-x.y),
  confirm at least one test asserts it" — **no mechanism exists**; the check
  is purely manual.

## Change instructions

1. **Unify the story grammar** (pick the parser's grammar; it's the machine
   consumer):
   - Update `skills/uncle-dev-planning-and-task-breakdown/SKILL.md:195,285`
     templates to `### Story 1.1: [Title]` (h3, numeric dotted IDs).
   - OR extend the parser to accept `STORY-\d+` IDs and h2 headers — but then
     update `parsing-and-annotations.md` grammar and the conflict-resolution
     doc consistently. (Recommendation: change the template; one file vs
     three.)
2. **Make plan emit annotations**: add to the plan skill's Step 4 template an
   explicit `**Annotations:** [files: …] [mutex: …] [depends: …]` line per
   story, with instructions copied/summarized from
   `parsing-and-annotations.md`, and a note that omitting it forces
   sequential execution. Cross-reference instead of duplicating detail.
3. **Resolve `handoff.md`**: remove its creation from
   `commands/uncle-dev-spec.md:217-219` (and from the "required artifacts"
   enumeration), OR give it a consumer (e.g. `/uncle-dev-wrap` in openspec
   mode reads/updates it). Recommendation: remove — `.devlocal/handoffs/` is
   the working convention; also rename mentions to avoid the collision.
4. **Fix the change-ID example**: `skills/uncle-dev-next-task/SKILL.md:27` →
   a compliant example like `001-foundations-cross-cutting`. Fix or archive
   the repo's own non-compliant change (see audit file 05, Finding G).
5. **Bridge or separate the spec universes** (explicit decision required):
   - **Option 1 — bridge (recommended long-term)**: extend the scanner
     (`skills/uncle-dev-spec-annotations/scanner/`) to also load
     `docs/ears/*.md` and accept `R-\d+\.\d+` IDs; then ship's coverage check
     has a mechanism (`scan-spec-coherence.py` can report untested R-IDs).
   - **Option 2 — separate (smaller)**: update CLAUDE.md and the ship command
     to state the two tracks explicitly: EARS (`R-x.y`) is reviewed manually;
     `@spec` annotations (`SEG-AREA-NNN`) are scanner-enforced. Delete the
     unenforceable "confirm each R-x.y has a test" wording from
     `commands/uncle-dev-ship.md:57` or mark it manual.
6. **Add a round-trip test**: generate a plan file from the (fixed) template
   with 2 stories + annotations, run the next-task parsing logic against it,
   assert both stories parse with correct IDs and the ready-set respects the
   mutex annotation. Place in `scripts/tests/`.

## Expected result after

- A plan produced by `/uncle-dev-plan` is directly consumable by
  `/uncle-dev-next-task`; parallel-safe ready sets actually compute from
  annotations instead of silently degrading to document order.
- No orphan `handoff.md` (or it has a real consumer).
- Every documented change-ID example passes the guard regex the ecosystem
  enforces.
- Ship's EARS coverage claim is either mechanically checkable or honestly
  labeled manual — no phantom guarantee.

## Verification

```bash
grep -n '## Story STORY-' skills/uncle-dev-planning-and-task-breakdown/SKILL.md   # expect: none
grep -n 'Annotations:' skills/uncle-dev-planning-and-task-breakdown/SKILL.md      # expect: present in template
grep -rn 'handoff\.md' commands/ skills/ | grep -v devlocal                        # expect: none or consumer pair
grep -n 'PF-001' skills/uncle-dev-next-task/SKILL.md                               # expect: none
bash scripts/tests/run-all.sh                                                      # incl. new round-trip test — green
```
