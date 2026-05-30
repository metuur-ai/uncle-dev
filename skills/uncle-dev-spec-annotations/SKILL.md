---
name: uncle-dev-spec-annotations
description: Connects durable product behavior to specs, tests, and code via `@spec` annotations. Use when adding behavior that should be traceable from intent to implementation, when specs need stable IDs, or when running coherence checks across HLD/LLD/EARS/tests/code.
---

# Spec Annotations

## Overview

`@spec` is one edge in a graph that connects durable product intent to the code that implements it. The graph flows in one direction:

```
HLD ──▶ LLD ──▶ EARS spec ──▶ Test ──▶ Code
```

`@spec` is **not** a changelog marker. It does not mean "this code changed in this task." It means "this code implements this product behavior." A spec ID is stable: it survives renames, refactors, and OpenSpec change archival.

Pair this skill with `uncle-dev-spec-driven-development` (which owns the transient OpenSpec change workflow) and `uncle-dev-design-architecture-docs` (which owns HLD/LLD authorship). This skill owns the spec-to-code edge.

## When to Use

- You are about to write code or a test that implements a durable product behavior
- You are reviewing code and want to verify every behavior entry point cites a real spec
- You are reading code that has no `@spec` annotation and need to decide whether to add one
- You are about to commit and want to confirm no broken spec links exist
- You are designing a new feature and need to introduce new EARS spec IDs

**When NOT to use:** Pure formatting changes, dependency bumps, build-tool config edits, or one-shot scripts that don't implement product behavior.

## The Graph

For one feature:

```
HLD: account security
        │
        ▼
LLD: authentication flow
        │
        ▼
EARS: AUTH-UI-001
        │
        ├──▶ test: "returns session for valid credentials"
        │
        └──▶ code: authenticate()
                  // @spec AUTH-UI-001
```

Walking from code back to intent (this is what makes the system valuable):

```
authenticate()
   │
   │ @spec AUTH-UI-001
   ▼
AUTH-UI-001
   │
   ▼
authentication LLD
   │
   ▼
account security HLD
```

`docs/arrows/index.yaml` is the index for that graph. Each segment (`auth`, `billing`, `search`) gets one entry pointing to a per-segment crosslink doc.

## What Should Be in the Spec

Each spec describes one durable product behavior. Use a stable ID:

```
AUTH-UI-001
```

Use a clear, testable behavior statement:

```markdown
- [x] **AUTH-UI-001**: When a user submits valid credentials, the system SHALL return a session scoped to that user.
```

Status markers: `[x]` implemented · `[ ]` active gap · `[D]` deferred.

Good specs are:

- **Stable** — the ID survives when the wording gets sharper
- **Product-facing** — describes behavior, not implementation details
- **Testable** — a test can prove whether the behavior exists
- **Grep-friendly** — the ID is easy to search across the repo

Do not make specs for temporary implementation tasks:

```
Bad:  AUTH-UI-001 = Refactor login.ts
Good: AUTH-UI-001 = Valid credentials return a scoped session
```

## What Should Be in the Code

Code carries `@spec` at the entry point that owns the behavior. The annotation belongs on the owner, not every helper.

See `resources/annotation-examples.md` for full per-language examples (TypeScript, Python, Go, Rust, Java, HTML).

```typescript
// @spec AUTH-UI-001, AUTH-UI-002
export async function authenticate(credentials: Credentials): Promise<AuthResult> {
  // ...
}
```

```
Good:
// @spec AUTH-UI-001
authenticate()
  ├──▶ parseCredentials()      ← no annotation (helper)
  ├──▶ validatePassword()      ← no annotation (helper)
  └──▶ createSession()         ← no annotation (helper)

Noisy:
// @spec AUTH-UI-001
authenticate()
// @spec AUTH-UI-001
parseCredentials()
// @spec AUTH-UI-001
validatePassword()
// @spec AUTH-UI-001
createSession()
```

If one behavior spans subsystems, annotate each subsystem entry point:

```
AUTH-UI-001
   │
   ├──▶ UI entry point       // @spec AUTH-UI-001
   ├──▶ API entry point      // @spec AUTH-UI-001
   └──▶ session boundary     // @spec AUTH-UI-001
```

## What Should Be in the Tests

Tests cite the spec IDs they verify. Place the annotation on the test that proves the behavior, not every assertion inside it.

```typescript
// @spec AUTH-UI-001
it("returns a scoped session for valid credentials", async () => {
  // ...
});
```

For "shall NOT" behaviors (negative requirements), the test is often the best pointer:

```markdown
- [x] **AUTH-SEC-004**: The system SHALL NOT expose raw authentication failure details to the user.
```

```typescript
// @spec AUTH-SEC-004
it("does not expose raw authentication failure details", async () => {
  // ...
});
```

## Segment & Prefix Conventions

A **segment** is one product-behavior area owned by one LLD. The spec prefix marks its boundary.

```
auth segment       → AUTH-*
billing segment    → BILLING-*
marketing site     → MKT-SITE-*
```

Use longer prefixes when a segment has internal subdivisions:

```
AUTH-UI-001
AUTH-API-001
AUTH-SESSION-001
```

Choose segments by **product intent**, not file location:

```
Good: auth = login, logout, sessions, auth errors
Weak: frontend = every UI file regardless of behavior
```

Weak segment names to avoid: `utils`, `frontend`, `backend`, `misc`, `shared`. Use `uncle-dev-design-architecture-docs` to guide segment selection when in doubt.

### Segment-boundary crossings

If a single change crosses from one segment to another, pause and confirm. Different segments can carry different intent, owners, risks, or unresolved design questions.

```
auth segment              billing segment
     │                          │
     ▼                          ▼
AUTH-* specs      ──×──▶  BILLING-* specs
        boundary crossing — pause
```

## Coherence Check Workflow

Run `/uncle-dev-spec-scan` to validate the graph end-to-end. The scanner:

1. Parses spec IDs from `docs/specs/**/*.md`
2. Walks code/tests with per-language AST adapters and extracts `@spec` annotations
3. Reports:
   - `✓` specs with both code + test annotations
   - `✗ ORPHAN` — code/test cites a spec ID that doesn't exist
   - `✗ MISSING TEST` — spec has code but no test citation
   - `⚠ MISSING CODE` — spec has test but no code citation
   - `⚠ HELPER ANNOTATION` — annotation on a non-entry-point AST node
4. Exits non-zero on ORPHAN (blocking). `--strict` makes MISSING/HELPER also block.

The `spec-coherence-guard.sh` hook runs this scanner before edits and commits — broken spec links cannot be committed.

For full algorithm details, see `resources/scanner-design.md`.

When intent changes, walk **down** the graph:

```
Update HLD or LLD
  │
  ▼
Update EARS specs
  │
  ▼
Update tests with @spec
  │
  ▼
Update code with @spec
  │
  ▼
Run coherence check
```

When code changes first, walk **up** the graph:

```
Code changed
  │
  ▼
Find @spec ID
  │
  ▼
Read matching EARS spec
  │
  ▼
Check test
  │
  ▼
Check LLD/HLD
```

If the code has no `@spec`, ask: "Is this implementing product behavior?"
- Yes → add or find the spec, then annotate the entry point
- No → no annotation needed (utility, helper, internal plumbing)

## Templates

Three templates ship with this skill in `resources/templates/`:

- `specs/SEGMENT-specs.md` — EARS spec file with status markers and ID format
- `arrows/index.yaml` — segment registry (the table of contents for the graph)
- `arrows/SEGMENT.md` — per-segment crosslink (HLD/LLD/EARS/Tests/Code references)

For HLD and LLD templates, see `uncle-dev-design-architecture-docs` (those live with the authorship skill).

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll add `@spec` later, after the code is stable" | Later never comes. Specs added in PR review are guesses. Add the annotation when you write the entry point. |
| "Every function should have `@spec` for completeness" | No. Helpers don't get annotations — only the entry point that owns the behavior. Noise dilutes signal. |
| "This is internal plumbing, no spec needed" | Often correct. But ask: does any product behavior depend on this boundary working? If yes, the boundary deserves an annotation even if the behavior lives upstream. |
| "I'll invent a spec ID just for this code" | No. Spec IDs are defined in `docs/specs/`, not inferred from code. Code citing an undefined ID is an ORPHAN. |
| "The old spec ID was deleted, I'll reuse the number" | Never. Reused IDs corrupt the graph. New behavior gets a new ID. |
| "The behavior is obvious from the code, the spec is busywork" | Code answers "what does this do." Spec answers "why must it do this." When the code rots, the spec is what tells the next agent what was intended. |

## Red Flags

- Code under `src/` with behavior obviously product-facing but no `@spec` annotation
- `@spec` ID in code that doesn't exist in `docs/specs/` (the scanner will block this)
- The same `@spec` ID on five sibling functions (annotation belongs on one entry point)
- A spec marked `[x]` implemented but with no code citation in the scanner report
- A "shall NOT" spec with no test citation (negative requirements live or die in tests)
- Reusing a deleted spec ID for unrelated new behavior
- Inventing a spec ID inline without adding it to `docs/specs/`
- Crossing segment boundaries in a single PR without surfacing the boundary crossing

## Verification

Before considering the implementation complete:

- [ ] Every product behavior introduced has a stable EARS ID in `docs/specs/<segment>-specs.md`
- [ ] Every entry point that owns a behavior carries `// @spec <ID>` (one annotation, on the owner)
- [ ] Every behavioral test cites the `@spec` ID it verifies
- [ ] `/uncle-dev-spec-scan` runs clean (zero ORPHANS)
- [ ] No helper functions carry redundant `@spec` annotations
- [ ] Segment prefix matches the segment registered in `docs/arrows/index.yaml`
- [ ] If a new segment was introduced, `docs/arrows/index.yaml` and `docs/arrows/<segment>.md` are updated

## Minimum Rules

If you adopt only the minimum, follow these seven rules:

1. Every product behavior gets a stable EARS ID
2. Tests cite the spec IDs they verify
3. Code cites the spec IDs it implements
4. Put `@spec` on behavior entry points, not helpers
5. Run the scanner to catch broken links
6. When intent changes, walk down: HLD → LLD → EARS → Tests → Code
7. When code changes, walk up: Code → EARS → LLD → HLD
