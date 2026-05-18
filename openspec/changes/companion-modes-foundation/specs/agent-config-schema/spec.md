## ADDED Requirements

### Requirement: Config loader SHALL parse the four new top-level keys without breaking existing projects

The config loader SHALL read `.agents/uncle-dev-setup.yaml` and accept four new optional keys: `graphify.graphs`, `companions[*].applies_to`, `context_layers`, and `flavors`. When any new key is absent, the loader SHALL return safe defaults that preserve current behavior.

#### Scenario: Existing project with no new keys loads unchanged

- **WHEN** the loader parses a config file that contains only pre-existing keys (no `graphify.graphs`, no `applies_to`, no `context_layers`, no `flavors`)
- **THEN** parsing SHALL succeed with no warnings
- **AND** every new-key accessor SHALL return an empty collection or the documented legacy default

#### Scenario: Loader rejects malformed new keys with a clear error

- **WHEN** the loader encounters `graphify.graphs` as a list instead of a map, OR `companions[*].applies_to` as a string instead of a list, OR `context_layers.<layer>` as anything other than a list, OR `flavors` as a list instead of a map
- **THEN** the loader SHALL exit with a non-zero status
- **AND** the error message SHALL name the offending key and state the expected shape

### Requirement: Template SHALL document every new key inline

`skills/uncle-dev-setup/uncle-dev-setup.template.yaml` SHALL include commented examples for every new key introduced by this change. Each example SHALL be commented out so a freshly rendered project file remains inert by default.

#### Scenario: Setup skill renders template with new keys present-but-inert

- **WHEN** a user runs the setup skill against a fresh project
- **THEN** the rendered `.agents/uncle-dev-setup.yaml` SHALL contain commented examples for `graphify.graphs`, `companions[*].applies_to`, `context_layers`, and `flavors`
- **AND** the loader SHALL parse the rendered file with zero warnings

### Requirement: Companions SHALL support flavor tags filterable via the loader

Each companion entry MAY carry an optional `flavors: [name, ...]` field listing one or more flavor names. The loader SHALL expose `companions_by_flavor(name: str) -> list[Companion]` returning every companion whose `flavors` list contains `name`.

The top-level `flavors:` map SHALL be descriptive only. The loader SHALL NOT enforce that every flavor referenced by a companion is declared in the top-level map, but SHALL emit a warning when a referenced flavor is undeclared.

#### Scenario: Filter returns companions tagged with the flavor

- **GIVEN** companion A with `flavors: [web-frontend]` and companion B with `flavors: [api-backend]`
- **WHEN** `companions_by_flavor("web-frontend")` is called
- **THEN** the returned list SHALL contain A but not B

#### Scenario: Undeclared flavor warns but does not error

- **GIVEN** a companion with `flavors: [unknown-flavor]` and no `unknown-flavor` entry in the top-level `flavors:` map
- **WHEN** the loader parses the config
- **THEN** a warning SHALL be emitted naming the companion and the undeclared flavor
- **AND** the loader SHALL NOT raise
