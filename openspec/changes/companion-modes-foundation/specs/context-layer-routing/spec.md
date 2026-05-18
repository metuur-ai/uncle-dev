## ADDED Requirements

### Requirement: Resolver SHALL return artifact pointers for a named layer

A `resolve_layer(layer: str) -> list[ArtifactPointer]` function SHALL accept exactly the three layer names `"expected"`, `"current"`, `"platform"` and return the list of pointers configured under `context_layers.<layer>` in the project config.

Each pointer SHALL be either:

- A file-path glob string (e.g., `"docs/specs/**-specs.md"`), or
- A graph reference object of the form `{"graph": "<name>"}` resolvable via `resolve_graph`.

The resolver SHALL NOT read any artifact contents — it returns only the pointers.

#### Scenario: Expected layer returns configured docs paths in declared order

- **GIVEN** `context_layers.expected: ["docs/high-level-design.md", "docs/specs/**-specs.md"]`
- **WHEN** `resolve_layer("expected")` is called
- **THEN** the returned list SHALL be exactly `["docs/high-level-design.md", "docs/specs/**-specs.md"]` in that order

#### Scenario: Current layer returns mix of paths and graph references

- **GIVEN** `context_layers.current: [{graph: default}, "openspec/tracker/changes.yaml"]`
- **WHEN** `resolve_layer("current")` is called
- **THEN** the returned list SHALL contain `{"graph": "default"}` and `"openspec/tracker/changes.yaml"` in that order

#### Scenario: Platform layer returns configured pointers without creating a canonical artifact

- **GIVEN** `context_layers.platform: [".uncle-dev/learns/runtime-errors/**"]`
- **WHEN** `resolve_layer("platform")` is called
- **THEN** the returned list SHALL contain `".uncle-dev/learns/runtime-errors/**"`
- **AND** the resolver SHALL NOT require or check for any canonical Layer 3 artifact

#### Scenario: Empty layer is valid

- **GIVEN** `context_layers.platform` is absent or empty
- **WHEN** `resolve_layer("platform")` is called
- **THEN** the function SHALL return `[]` without raising

#### Scenario: Unknown layer name raises a clear error

- **WHEN** `resolve_layer("runtime")` is called (not one of `expected`, `current`, `platform`)
- **THEN** the function SHALL raise a `ValueError` whose message lists the three valid layer names

### Requirement: Layer router SHALL be the only sanctioned route to platform-level signals during this change

Until a canonical Layer 3 artifact is defined by the SDD methodology, downstream skills SHALL consult `resolve_layer("platform")` rather than hardcoding paths to `.uncle-dev/learns/runtime-errors/` or other distributed signals. This requirement defines the contract; enforcement (e.g., a scanner) is out of scope for this change.

#### Scenario: Documentation directs consumers to the router

- **WHEN** a downstream skill or hook needs to read platform-level signals
- **THEN** the SKILL.md or hook script SHALL reference `resolve_layer("platform")` (or its equivalent invocation) rather than hardcoding `.uncle-dev/learns/runtime-errors/` or similar paths
