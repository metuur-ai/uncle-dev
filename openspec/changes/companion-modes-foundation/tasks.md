## 1. Config Schema Extension

- [ ] 1.1 Add `graphify.graphs` block to `skills/uncle-dev-setup/uncle-dev-setup.template.yaml` with commented examples for `default`, `web`, `api`.
- [ ] 1.2 Add `applies_to:` and `flavors:` fields to each companion entry example under `skills.companions` in the template, both commented out.
- [ ] 1.3 Add `context_layers:` top-level block with commented examples for `expected`, `current`, `platform` (including the L3 router-only note).
- [ ] 1.4 Add top-level `flavors:` map with commented examples for `web-frontend` and `api-backend`.
- [ ] 1.5 Update the template header comment to document the four new keys and link to this foundation change.

## 2. Loader

- [ ] 2.1 Create `skills/uncle-dev-setup/config_loader.py` with a `load_config(path: str) -> Config` entry point returning a typed object.
- [ ] 2.2 Validate `graphify.graphs` is a map; raise with a clear message if it is a list.
- [ ] 2.3 Validate `companions[*].applies_to` is a list of strings; raise if string.
- [ ] 2.4 Validate `context_layers.<layer>` is a list (or absent); raise otherwise.
- [ ] 2.5 Validate `flavors` is a map; raise if list.
- [ ] 2.6 Emit warnings for: (a) undeclared companion flavors, (b) broad-glob `applies_to` without a trailing slash that matches more than one top-level directory.

## 3. Resolvers

- [ ] 3.1 Create `skills/uncle-dev-setup/resolvers.py` importing `fnmatch` and the loader's `Config` type.
- [ ] 3.2 Implement `resolve_companions_for_path(file_path) -> list[Companion]` with OR-glob semantics and always-on fallback for entries without `applies_to`.
- [ ] 3.3 Implement `resolve_graph(name) -> str | None` with legacy fallback to `graphify-out/graph.json` and `None` when the resolved file is missing.
- [ ] 3.4 Implement `resolve_layer(layer) -> list[ArtifactPointer]` accepting only `expected | current | platform`; raise `ValueError` listing the three valid names on unknown input.
- [ ] 3.5 Implement `companions_by_flavor(name) -> list[Companion]`.

## 4. Tests

- [ ] 4.1 Add unit tests for the loader: parse the literal `uncle-dev-setup.template.yaml` with zero warnings; parse a stripped-down legacy config and assert all new-key accessors return defaults.
- [ ] 4.2 Add unit tests for `resolve_companions_for_path` covering every scenario in `specs/path-scoped-companion-activation/spec.md` (including the broad-glob warning).
- [ ] 4.3 Add unit tests for `resolve_graph` covering every scenario in `specs/multi-graph-graphify-routing/spec.md` (named, default, legacy fallback, missing file, unknown name).
- [ ] 4.4 Add unit tests for `resolve_layer` covering every scenario in `specs/context-layer-routing/spec.md` (mixed pointers, empty layer, unknown layer name).
- [ ] 4.5 Add unit tests for `companions_by_flavor` and the undeclared-flavor warning.
- [ ] 4.6 Add a malformed-config error-message test for each shape violation enumerated in `specs/agent-config-schema/spec.md`.

## 5. Documentation

- [ ] 5.1 Update `skills/uncle-dev-setup/SKILL.md` to document the four new keys with a one-paragraph reference per key.
- [ ] 5.2 Add a short "How to consume from a downstream skill" section to `skills/uncle-dev-setup/SKILL.md` showing the four import sites (`load_config`, `resolve_companions_for_path`, `resolve_graph`, `resolve_layer`).
- [ ] 5.3 Add a CHANGELOG entry (or repo equivalent) noting the additive schema extensions.

## 6. Validation

- [ ] 6.1 Run `openspec validate companion-modes-foundation --strict` and confirm it passes.
- [ ] 6.2 Run the loader against a freshly rendered template and assert zero warnings.
- [ ] 6.3 Manually verify backward compatibility by parsing an existing `.agents/uncle-dev-setup.yaml` with no new keys and confirming all resolvers return safe defaults.
- [ ] 6.4 Update or add `AGENTS.md` guidance under `skills/uncle-dev-setup/` if the directory has one, naming the new public API surface.
