## Context

Three companion-mode pillars are being explored (Uncle Domain, Uncle Framework, Product Mode Agent). The extended research at `.uncle-dev/research/2026-05-17-companion-modes-extended-exploration.md` §18 confirms that all three depend on the same missing config and routing surface in this repo:

- `skills/uncle-dev-setup/uncle-dev-setup.template.yaml:21` — `project.framework` is a single string slot; no per-path mechanism.
- `skills/uncle-dev-graphify-aware-analysis/SKILL.md:18-22` — the path `graphify-out/graph.json` is hardcoded; no multi-graph config exists.
- `skills/uncle-dev-setup/uncle-dev-setup.template.yaml:47-65` — `skills.companions[*]` has no `applies_to` field; companion activation is manual prompting.
- No file in the repo today encodes `expected | current | platform` as a routable layer set — only the implicit cascade in `skills/uncle-dev-design-architecture-docs/SKILL.md:155-175`.

This change isolates the foundation work (config schema + loader + deterministic resolvers) from the pillar work (agent personas + content). The pillars will land in separate OpenSpec changes that depend on this one.

Binding constraints carried forward from the brief and from existing repo conventions:

- **Reactive invocation only.** The resolvers are pure libraries called by skills/hooks; they do not auto-spawn agents. This is consistent with `AGENTS.md:11` and the recommend-then-invoke pattern documented in research §13.
- **No LLM routing.** `skills/uncle-dev-acknowledge/inference-rules.md:90-94` is the binding precedent: *"A regex table is auditable; an LLM call isn't."* All resolvers in this change are pure-functional over config + path glob.
- **Backward compatibility.** Existing projects must render unchanged if they do not opt into the new keys.

## Goals / Non-Goals

**Goals:**

- Land a single coherent configuration extension that all three pillar changes can consume.
- Keep router logic deterministic (glob/dictionary lookup, no LLM) and unit-testable.
- Preserve current single-path Graphify, single-string `project.framework`, and manual companion activation as the defaults for projects that do not opt in.

**Non-Goals:**

- No pillar agent persona files (Uncle Domain, Uncle Framework, Product Mode Agent) — those land in their own changes.
- No new framework rule content (React/Vue/FastAPI/Django/etc.).
- No new `@`-annotations beyond `@spec`.
- No canonical Layer 3 artifact. The router returns the configured pointers; what L3 "is" remains an open SDD question per user decision Q2=(b).
- No flavor *content* — only the tagging mechanism. No `flavors/ecommerce/...` directory tree.
- No automatic side-loading of companions by the build/spec orchestrator. Activation remains a recommend-then-invoke flow; the resolver only returns the candidate list.

## Decisions

### D1 — Single config file, four additive keys

Extend `skills/uncle-dev-setup/uncle-dev-setup.template.yaml` rather than introduce a new file (per Q3). Sketch of the additions (all commented in the rendered template):

```yaml
graphify:
  graphs:                                # NEW — named graphs; absent = legacy single-path
    default: graphify-out/graph.json
    # web: packages/web/graphify-out/graph.json
    # api: packages/api/graphify-out/graph.json

skills:
  companions:
    build:
      - path: ../my-skill/SKILL.md
        name: my-skill
        applies_to:                      # NEW — globs; absent = always-on
          - "packages/web/**"
        flavors: [web-frontend]          # NEW — grouping tags

context_layers:                          # NEW
  expected:
    - docs/high-level-design.md
    - docs/llds/**.md
    - docs/specs/**-specs.md
    - openspec/changes/**/proposal.md
    - openspec/acknowledge/**.md
  current:
    - graph: default                     # references graphify.graphs
    - openspec/tracker/changes.yaml
    - .uncle-dev/feature-maps/**.md
  platform:                              # router-only; pointers to distributed signals
    - .uncle-dev/learns/runtime-errors/**
    - .uncle-dev/learns/performance-issues/**
    # NOTE: no canonical L3 artifact exists. The router returns these pointers;
    # the L3 artifact question is deferred to the SDD methodology.

flavors:                                 # NEW — descriptive only; resolves via tag filter
  web-frontend:
    description: "React/Tailwind/React Query stack on packages/web"
  api-backend:
    description: "FastAPI/Zod contracts on packages/api"
```

**Why:** All consumers already read this one file via the rendered `.agents/uncle-dev-setup.yaml`. Adding new files would fragment the config surface and require new loaders.

**Alternatives considered:**

- *New top-level config file* — rejected. Every consumer would need to learn a new path; defeats the existing single-file convention.
- *Per-skill config files under each `skills/<name>/`* — rejected. Would scatter routing logic; the existing `companions` block already centralizes it.

### D2 — Glob-based path resolver (not the acknowledge regex table)

Per Q4=(b), each companion entry gets an optional `applies_to: [glob, ...]` field. The resolver uses Python `fnmatch.fnmatchcase` semantics where `**` matches across directory separators. Match policy:

- Companions whose `applies_to` is non-empty AND contains at least one glob matching the input path → included.
- Companions whose `applies_to` is absent or empty → always included (preserves current behavior).

**Why glob over the existing acknowledge regex table (research §3.3.2):**

- Globs are the standard pattern users expect in YAML config (`.gitignore`, `pre-commit`, `eslint`, etc.).
- The acknowledge regex table routes free-text *notes*; this resolver routes file *paths*. Different input types call for different patterns.
- Glob matchers ship in every stdlib; regex requires extra escaping and is harder to audit at config-edit time.

**Why not LLM-based:** binding precedent at `inference-rules.md:90-94`.

### D3 — Multi-graph Graphify selector with legacy fallback

`graphify.graphs` is a map from `name → JSON path`. Resolution rules:

1. Named graph (e.g., `resolve_graph("web")`) → `graphify.graphs.web`.
2. `resolve_graph("default")` or `resolve_graph(None)` → `graphify.graphs.default` if set, else legacy `graphify-out/graph.json`.
3. If the resolved file does not exist on disk → return `None` so consumers fall through to the existing "graphify: OFF" branch at `skills/uncle-dev-graphify-aware-analysis/SKILL.md:18-22`.
4. Unknown name → raise `KeyError` with a message that lists the configured names.

**Why this fallback shape:** preserves current behavior for projects that never configure `graphify.graphs`. Projects can adopt named graphs incrementally without breaking existing consumers.

### D4 — Three-layer router treats `platform` as router-only

Per Q2=(b), the `platform` layer points at existing distributed signals (`.uncle-dev/learns/runtime-errors/`, `.uncle-dev/learns/performance-issues/`, etc.). No canonical Layer 3 artifact is created in this change.

The router exposes a single function: `resolve_layer(layer: str) -> list[ArtifactPointer]`, where `ArtifactPointer` is either a file-path glob string or a graph reference object `{"graph": "<name>"}`. The router does no reading; consumers iterate the returned pointers and use the appropriate tool (Read, glob, or `graphify` CLI).

**Why router-only for L3:** the SDD methodology has not yet settled what a canonical L3 artifact looks like. Forcing one now would either constrain that future decision or invent an empty artifact. The router can be extended later when L3 is defined; consumers see only the pointer list either way.

### D5 — Flavors are tags, not bundles

Per Q5, a flavor is a grouping concept. The schema adds:

- A top-level `flavors:` block mapping `<name> → {description: ...}` (documentation only).
- An optional `flavors: [name, ...]` field on each companion entry.

The loader exposes `companions_by_flavor(name: str) -> list[Companion]`. No bundle resolution, no directory copying, no inheritance. If a heavier bundle mechanism becomes necessary later, it can extend this without breaking the tag model.

### D6 — Loader and resolver location

The loader and resolvers live under `skills/uncle-dev-setup/`:

- `skills/uncle-dev-setup/config_loader.py` — single entry point `load_config(path: str) -> Config`; parses YAML, validates new keys, returns a typed object.
- `skills/uncle-dev-setup/resolvers.py` — `resolve_companions_for_path`, `resolve_graph`, `resolve_layer`, `companions_by_flavor`. Plain module-level functions; no class hierarchy.

**Why colocated with setup:** the setup skill already owns the template; the loader is the natural counterpart. Other skills import from a single well-known location.

### D7 — Validation in the loader, not the consumer

The loader performs all shape validation up front. Resolvers assume a valid `Config` object and never re-validate. Errors raised by the loader name the offending key and the expected shape; resolvers raise narrow errors (`KeyError`, `ValueError`) only for runtime lookups.

**Why:** keeps consumers small and predictable; centralizes the "what is a valid config" answer in one file.

## Risks / Trade-offs

- **[Schema drift between template and loader]** → Mitigation: loader unit tests load the literal `uncle-dev-setup.template.yaml` and assert successful parse for every commented example.
- **[Glob false positives]** (e.g., `packages/web/**` accidentally matching `packages/web-archive/**`) → Mitigation: documentation example shows trailing `/` for safety; loader emits a warning when a glob matches more than one top-level directory in the project AND lacks a trailing slash.
- **[Layer config bloat]** — config files balloon as users enumerate every spec path under `expected`. → Mitigation: layer values accept globs (not literal paths), defaults shipped in the template cover the standard repo layout, and the loader resolves globs lazily.
- **[L3 router returning empty]** — until L3 is defined, projects may leave `context_layers.platform` empty. → Mitigation: empty is valid; consumers must handle the empty-list case; documentation in the template explicitly states L3 is router-only today.
- **[Hidden coupling to pillar changes]** — the foundation is harder to validate without a consuming pillar. → Mitigation: include consumer-fixture unit tests in this change so resolver contracts are exercised end-to-end without waiting on pillar work.

## Migration Plan

- **Deploy:** Merge as a single change. Existing projects render unchanged because every new key is absent by default.
- **Rollback:** Revert the change. The loader and resolvers are net-new files. Template changes are additive; reverting removes them cleanly.
- **Adoption:** Pillar changes will document the specific keys they require. No project is required to adopt any new key until they invoke a pillar that uses it.

## Open Questions

- **OQ1 — Layer config validation strictness.** Should the loader reject a `context_layers.expected` value that resolves to zero files at config-load time, or only warn? Recommend *warn* to allow projects in early setup. Defer until first pillar consumes the layer router.
- **OQ2 — Cross-graph queries.** If a pillar needs to query *both* the `web` and the `api` graph in the same operation, do we expose a `resolve_graph_union(...)` helper now or wait for a concrete use case? Recommend wait.
- **OQ3 — Flavor inheritance.** Should a flavor be able to declare `inherits: [other_flavor]`? Recommend no — pure tag model is sufficient until proven otherwise.
