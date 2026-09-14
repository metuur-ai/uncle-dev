# {{Segment}} Specs

**LLD**: docs/llds/{{segment}}.md
**Arrow**: docs/arrows/{{segment}}.md
**Prefix**: {{SEGMENT}}-* (e.g. {{SEGMENT}}-UI-*, {{SEGMENT}}-API-*)

Status markers: `[x]` implemented · `[ ]` active gap · `[D]` deferred

---

- [ ] **{{SEGMENT}}-001**: When [trigger condition], the system SHALL [observable behavior].
- [ ] **{{SEGMENT}}-002**: When [trigger condition], the system SHALL [observable behavior].
- [ ] **{{SEGMENT}}-003**: The system SHALL NOT [forbidden behavior].

<!--
Template notes (delete when filling in):

- Each spec describes ONE durable product behavior, not a task or implementation step.
- IDs are stable. Once an ID is used (even if [D] deferred), it is never reused for different behavior.
- Use compound prefixes (e.g. {{SEGMENT}}-UI-001, {{SEGMENT}}-API-001) when the segment has internal subdivisions.
- Phrase behaviors in EARS form: "WHEN <trigger>, the system SHALL <response>" or "The system SHALL [NOT] <invariant>".
- Each spec must be testable: a test can prove whether the behavior holds.
- Each [x] spec should have at least one code annotation and one test annotation citing its ID.
- Run `/uncle-dev-spec-scan` to validate the graph.
-->
