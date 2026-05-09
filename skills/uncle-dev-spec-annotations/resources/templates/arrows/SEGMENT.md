# Arrow: {{segment}}

[One-paragraph description of what this segment owns. Use product-intent language, not file-location language.
Example: "Authentication behavior: login, logout, session creation, and user-safe auth errors."]

## Segment Boundary

- **Prefix**: {{SEGMENT}}-*
- **Owner LLD**: docs/llds/{{segment}}.md
- **Spec catalog**: docs/specs/{{segment}}-specs.md

Specs whose IDs do not start with `{{SEGMENT}}-` belong to a different segment.
If a behavior crosses segment boundaries, pause and confirm before adding annotations across them.

## References

### HLD

- docs/high-level-design.md#{{section-anchor-for-this-segment}}

### LLD

- docs/llds/{{segment}}.md

### EARS

- docs/specs/{{segment}}-specs.md

### Tests

- [path to test files for this segment, e.g. src/{{segment}}/**/*.test.ts]

### Code

- [path to source files for this segment, e.g. src/{{segment}}/**/*.ts]

## Cascade Notes

When upstream intent changes (HLD or LLD), walk down:
HLD → LLD → EARS specs → tests → code.

When a `{{SEGMENT}}-*` spec is added, modified, or deferred:
- [ ] Update the spec entry in `docs/specs/{{segment}}-specs.md`
- [ ] Update or add the test annotation
- [ ] Update or add the code annotation
- [ ] Run `/uncle-dev-spec-scan` to confirm graph is coherent

## Open Questions

[List any unresolved design questions about this segment. Drift between LLD and EARS specs indicates one of these is stale.]
