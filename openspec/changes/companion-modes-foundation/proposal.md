## Why

The three companion-mode pillars under consideration (Uncle Domain, Uncle Framework, Product Mode Agent) all depend on the same missing surface: configurable multi-path Graphify, glob-based path-to-rule routing, a three-layer (`expected | current | platform`) artifact router, and a flavor grouping concept. Research at `.uncle-dev/research/2026-05-17-companion-modes-extended-exploration.md` §18 confirms none of these exist in the current config schema or any consumer skill. Building any pillar before this foundation lands forces hardcoded paths and ad-hoc routing into each pillar separately, which the acknowledge inference table (`skills/uncle-dev-acknowledge/inference-rules.md:90-94`) explicitly warns against.

This change introduces only the configuration schema, the loader, and the deterministic routers — no pillar agents, no framework rule content, no new persona files, and no new canonical Layer 3 artifact. Subsequent pillar changes will consume these foundation primitives.

## What Changes

- Extend `skills/uncle-dev-setup/uncle-dev-setup.template.yaml` with four additive keys: `graphify.graphs`, `companions[*].applies_to`, `context_layers`, and `flavors`. All keys absent by default — projects render unchanged.
- Add a deterministic path resolver that maps a target file path to matching companion entries via glob (`applies_to:`). No LLM routing — binding precedent at `skills/uncle-dev-acknowledge/inference-rules.md:90-94`.
- Add a multi-graph Graphify selector that resolves a named graph (e.g., `web`, `api`) to its configured JSON path; the existing single-path `graphify-out/graph.json` remains the fallback when no named graph is configured.
- Add a three-layer router that resolves `expected | current | platform` → configured artifact pointers. For `platform` (Layer 3), the router returns the configured pointers only (e.g., `.uncle-dev/learns/runtime-errors/**`); **no new canonical L3 artifact is introduced** — that remains an open SDD question.
- Add a flavor filter: companion entries MAY carry `flavors: [name, ...]` tags; the loader exposes a tag-filter so downstream consumers can select companions by flavor without changing companion identity. Flavors are descriptive grouping only — no bundles, no inheritance, no directory copying.
- Update `skills/uncle-dev-setup/SKILL.md` and the rendered template to document every new key inline, with each example commented out by default.

## Capabilities

### New Capabilities

- `agent-config-schema`: YAML schema additions to `.agents/uncle-dev-setup.yaml` (`graphify.graphs`, `companions[*].applies_to`, `context_layers`, `flavors`, companion `flavors:` tag) and the loader that parses and validates them.
- `path-scoped-companion-activation`: Deterministic glob-based resolver that returns the companion entries applicable to a given file path. Replaces the implicit always-on companion activation for entries that opt into `applies_to:`.
- `multi-graph-graphify-routing`: Resolver that maps a named graph to its configured JSON path, with legacy fallback to `graphify-out/graph.json` for projects that do not adopt named graphs.
- `context-layer-routing`: Resolver that maps `expected | current | platform` to one or more configured artifact pointers; router-only for `platform` (no canonical artifact created in this change).

### Modified Capabilities

None — no specs exist in `openspec/specs/` yet.

## Impact

- **Code:** New Python utilities under `skills/uncle-dev-setup/` (loader, resolvers). No existing skill behavior changes — all new functionality is opt-in via the new config keys.
- **Templates:** `skills/uncle-dev-setup/uncle-dev-setup.template.yaml` gains four new keys, each documented inline and defaulted to empty/absent.
- **Dependencies:** No new runtime dependencies (glob matching via Python stdlib `fnmatch`).
- **Downstream:** The three pillar changes (`uncle-domain`, `uncle-framework`, `product-mode-agent`) will consume these primitives. Without this foundation, each pillar would have to re-implement routing.
- **Backward compatibility:** Fully additive. Projects that do not opt into the new keys see no behavior change. Existing single-path Graphify (`graphify-out/graph.json`), single-string `project.framework`, and existing companion entries continue to work unchanged.
- **Out of scope (explicitly deferred to pillar changes):** Uncle Domain agent persona, Uncle Framework rule content (React/Vue/FastAPI/etc.), Product Mode Agent persona, new `@`-annotations beyond `@spec`, canonical Layer 3 artifact, flavor *content* (only the tagging mechanism lands here).
