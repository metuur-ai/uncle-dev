## ADDED Requirements

### Requirement: Resolver SHALL return companion entries whose `applies_to` globs match a given path

A `resolve_companions_for_path(file_path: str) -> list[Companion]` function SHALL return:

1. Every companion whose `applies_to` list contains at least one glob that matches `file_path`.
2. Every companion that has no `applies_to` field (always-on, current behavior preserved).

Glob semantics SHALL follow Python `fnmatch.fnmatchcase` with `**` meaning "match across directory separators".

#### Scenario: Path-scoped companion matches its glob

- **GIVEN** a companion entry with `applies_to: ["packages/web/**"]`
- **WHEN** `resolve_companions_for_path("packages/web/src/App.tsx")` is called
- **THEN** the companion SHALL be in the returned list

#### Scenario: Path-scoped companion does not match a sibling directory

- **GIVEN** a companion entry with `applies_to: ["packages/web/**"]`
- **WHEN** `resolve_companions_for_path("packages/api/src/handler.py")` is called
- **THEN** the companion SHALL NOT be in the returned list

#### Scenario: Companion without `applies_to` is always returned

- **GIVEN** a companion entry with no `applies_to` field
- **WHEN** `resolve_companions_for_path(<any path>)` is called
- **THEN** the companion SHALL be in the returned list

#### Scenario: Multiple globs in `applies_to` use OR semantics

- **GIVEN** a companion entry with `applies_to: ["packages/web/**", "apps/admin/**"]`
- **WHEN** `resolve_companions_for_path("apps/admin/page.tsx")` is called
- **THEN** the companion SHALL be in the returned list

### Requirement: Loader SHALL warn on broad globs that match multiple top-level directories without a trailing slash

When a companion's `applies_to` glob matches more than one top-level directory in the project AND the glob lacks a trailing `/` separator, the loader SHALL emit a warning to stderr naming the companion and the glob.

#### Scenario: Bare directory-name glob triggers warning

- **GIVEN** a companion entry with `applies_to: ["web*"]` in a project containing both `packages/web/` and `packages/web-archive/`
- **WHEN** the loader is called
- **THEN** a warning SHALL be emitted naming the companion and recommending a trailing-slash form (e.g., `web*/`)
- **AND** the loader SHALL NOT raise
