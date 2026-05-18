## ADDED Requirements

### Requirement: Resolver SHALL return the configured graph path for a named or default graph, with legacy fallback

A `resolve_graph(name: str | None) -> str | None` function SHALL return:

1. The path configured at `graphify.graphs[<name>]` when `name` is provided and the key exists.
2. The path configured at `graphify.graphs.default` when `name` is `None` or `"default"`.
3. The legacy path `graphify-out/graph.json` when no `graphify.graphs` block is configured at all AND `name` is `None` or `"default"`.
4. `None` when the resolved file does not exist on disk, so consumers fall through to the existing "graphify: OFF" branch at `skills/uncle-dev-graphify-aware-analysis/SKILL.md:18-22`.

#### Scenario: Named graph resolves to its configured path

- **GIVEN** `graphify.graphs: {web: packages/web/graphify-out/graph.json}` and that file exists
- **WHEN** `resolve_graph("web")` is called
- **THEN** the function SHALL return `"packages/web/graphify-out/graph.json"`

#### Scenario: Default graph resolves to configured default

- **GIVEN** `graphify.graphs: {default: custom/graph.json}` and that file exists
- **WHEN** `resolve_graph(None)` is called
- **THEN** the function SHALL return `"custom/graph.json"`

#### Scenario: Legacy fallback when no graphs configured

- **GIVEN** no `graphify.graphs` block in config AND `graphify-out/graph.json` exists at repo root
- **WHEN** `resolve_graph(None)` is called
- **THEN** the function SHALL return `"graphify-out/graph.json"`

#### Scenario: Missing file returns None

- **GIVEN** `graphify.graphs: {web: nonexistent.json}`
- **WHEN** `resolve_graph("web")` is called
- **THEN** the function SHALL return `None`

#### Scenario: Unknown name raises a clear error

- **GIVEN** `graphify.graphs: {web: packages/web/graphify-out/graph.json}` (no `api` key)
- **WHEN** `resolve_graph("api")` is called
- **THEN** the function SHALL raise a `KeyError` whose message names `"api"` and lists the configured graph names
