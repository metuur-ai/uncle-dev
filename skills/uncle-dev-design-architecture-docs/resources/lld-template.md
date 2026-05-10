# LLD: {{segment}}

[One paragraph stating what product behavior this segment owns, framed in user-visible terms.
Example: "Authentication: how users prove identity, establish sessions, and surface auth errors safely."]

---

## Segment Boundary

- **Prefix**: `{{SEGMENT}}-*` (or `{{SEGMENT}}-AREA-*` for compound prefixes)
- **EARS specs**: [docs/specs/{{segment}}-specs.md](../specs/{{segment}}-specs.md)
- **Arrow doc**: [docs/arrows/{{segment}}.md](../arrows/{{segment}}.md)
- **HLD parent section**: [docs/high-level-design.md#{{anchor}}](../high-level-design.md#{{anchor}})

### What this segment owns

- [Behavior 1 — e.g. "Validating user credentials"]
- [Behavior 2 — e.g. "Issuing user-scoped sessions"]
- [Behavior 3 — e.g. "Returning user-safe authentication errors"]

### What this segment does NOT own

- [Adjacent behavior owned by another segment — e.g. "Authorization (which segment owns access checks?)"]
- [Adjacent behavior — e.g. "Account creation (owned by `accounts` segment, not `auth`)"]

If a behavior could plausibly belong here OR somewhere else, decide explicitly and write the decision in the boundary.

## Responsibilities

System-level approach for this segment's behaviors. Not code-level — that lives in OpenSpec change folders.

- **[Responsibility]**: [e.g. "All credentials are hashed before any persistence layer sees them."]
- **[Responsibility]**: [e.g. "Sessions are short-lived; long-lived auth uses refresh-token rotation."]

## Key Flows

The most important behaviors this segment implements, described in flow form. Each flow that has a stable observable behavior should map to one or more EARS specs.

### Flow: [User logs in with valid credentials]

```
1. User submits credentials → entry point
2. Credentials validated against persistence
3. Session issued, scoped to user
4. Response includes session token
```

→ EARS specs: `{{SEGMENT}}-001`, `{{SEGMENT}}-002`

### Flow: [User submits invalid credentials]

```
1. User submits credentials → entry point
2. Validation fails
3. User-safe error returned (no stack trace, no DB details)
```

→ EARS spec: `{{SEGMENT}}-003`

## Constraints

Technical or operational constraints that shape the segment's design.

- [e.g. "Must support 10k concurrent sessions per node"]
- [e.g. "Must work without external identity providers"]

## Open Questions

Unresolved design decisions. Track them here until decided; once decided, move the answer into Responsibilities and delete the question.

- [ ] [Question]
- [ ] [Question]

---

<!--
LLD authorship notes (delete when filling in):

- One LLD per segment. Don't merge segments into a "system.md" LLD — the prefix
  ownership becomes ambiguous and cascade breaks.
- The LLD declares the EARS prefix. Specs in docs/specs/<segment>-specs.md
  must use this prefix; the spec scanner enforces this.
- Code-level details (function signatures, file paths) DON'T belong here —
  those live in per-feature OpenSpec change folders (proposal.md, design.md).
- When this LLD changes, run /uncle-dev-spec-scan to surface affected specs,
  then walk the cascade rules in uncle-dev-design-architecture-docs.
-->
