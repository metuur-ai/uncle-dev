---
name: uncle-dev-feature-map
description: Discovers and catalogs product features by reading backend routes, controllers, service logic, and frontend pages/components. Outputs a feature map document focused on what users can do — not how the code works. Use when you need a product-level inventory of an unfamiliar codebase, before speccing new features, or when building a requirements doc from existing behavior.
---

# uncle-dev-feature-map

## Overview

Extracts a product-level feature catalog from source code by reading backend and frontend layers in parallel. The output answers "what can users do with this product?" — not "how is it implemented?" Every feature is named in product language, cross-referenced between backend and frontend, and gaps are explicitly flagged.

## When to Use

**Use when:**
- Joining an unfamiliar codebase and need a product overview before writing specs
- Auditing feature scope before a large refactor or migration
- Building a requirements doc from existing behavior (reverse-engineering the spec)
- Identifying orphaned UI or undocumented API-only capabilities
- Asked "what does this product do?" about a codebase you haven't read yet

**When NOT to use:**
- You need to understand how a specific feature is implemented → use `uncle-dev-research`
- You are making code changes → use `uncle-dev-source-driven-development`
- You already have a product spec and need to verify it → use `uncle-dev-spec-driven-development`

## Differentiator from `uncle-dev-research`

| Dimension | `uncle-dev-research` | `uncle-dev-feature-map` |
|---|---|---|
| Question | "How does X work?" | "What can users do?" |
| Output | Code explanation | Feature catalog |
| Focus | Implementation | Business capability |
| Audience | Engineers | Engineers + PMs |

## Core Process

### Step 1: Detect Stack and Entry Points

Read dependency manifests to identify frameworks before spawning agents:
- `package.json`, `pyproject.toml`, `composer.json`, `Gemfile`, `go.mod`
- Backend framework (Express, FastAPI, Rails, Django, Laravel) → determines where routes/controllers live
- Frontend framework (React/Next.js, Vue/Nuxt, Angular, Svelte) → determines where pages/views live

State findings explicitly. If ambiguous, ask — don't guess the project structure.

### Step 2: Spawn Parallel Subagents

Launch **two agents in a single message**:

**Backend agent** — scans routes, controllers, API handlers, and service layer.

**Frontend agent** — scans pages, views, navigation, and feature-gated components.

Each agent prompt must include:
> "Extract product features and business logic — not code explanations. Name each feature as a product manager would. For each feature include: feature name (user-facing), what the user can do, entry point (route path or handler), and any visible business rules or constraints."

### Step 3: Extract Feature Signals

**Backend signals:**
- HTTP routes grouped by resource/domain (not by file or controller)
- Auth/permission guards → reveals role-based access (who can do what)
- Service method names with business meaning (`chargeSubscription`, `sendInvoice`, `approveRequest`)
- Validation rules → reveals business constraints ("name required", "max 5 members")
- Queue jobs and events → reveals async or background features

**Frontend signals:**
- Page and view files mapped to their route paths
- Navigation menus, sidebars, and tab groups
- Feature flags and conditional UI blocks
- Multi-step form flows → indicates complex features
- Empty states and error messages → reveals expected user actions

**Do not report:**
- How something is implemented internally
- Variable names, class hierarchies, or architectural patterns
- Performance details or infrastructure choices

### Step 4: Cross-Reference Backend ↔ Frontend

After both agents complete:
- Match API endpoints to UI pages that call them
- Flag **API-only capabilities** — backend routes with no corresponding UI
- Flag **orphaned UI** — frontend pages with no backend match (mocks, stubs, dead screens)
- Group all features by product domain (auth, billing, dashboard, settings, admin, etc.)

### Step 5: Synthesize Feature Map Document

Save to `.uncle-dev/feature-maps/YYYY-MM-DD-[codebase-name].md`

```markdown
---
date: YYYY-MM-DD
git_commit: <sha>
repository: <name>
status: draft
---

# Feature Map: [Product Name]

## Summary
[2-3 sentences: what does this product do, who is it for?]

## Feature Catalog

### [Domain: Authentication]
| Feature | User Action | Backend Entry | Frontend Entry | Notes |
|---|---|---|---|---|
| Login | Sign in with email + password | POST /auth/login | /login | Rate limited to 5 attempts |
| Password Reset | Request reset link via email | POST /auth/forgot-password | /forgot-password | Token expires in 1h |

### [Domain: ...]

## API-Only Capabilities
- **[Feature name]** — `METHOD /route` — [what it does, no UI found]

## Orphaned UI
- **[Page path]** — [description, no backend match found]

## Open Questions
- [Business logic that couldn't be determined from code alone]
```

### Step 6: Verify and Flag Gaps

Before closing:
- Feature names are product language, not code identifiers (`"Create user account"` not `"UserController.store"`)
- Business rules are stated as constraints (`"max 5 users per org"`) not implementation (`"checks users.count < 5"`)
- Every feature entry has a backend **or** frontend reference — no entries without evidence
- API-only and orphaned UI sections are populated (even if empty, confirm they were checked)

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just read the README instead" | READMEs go stale. Routes and pages are the source of truth. |
| "The research skill already covers this" | Research explains code. Feature map catalogs product capabilities. Different question, different audience. |
| "I can describe the feature from the controller name alone" | Controller names reflect code organization, not user intent. Always read service layer + UI together. |
| "Orphaned UI is probably just unused — not worth flagging" | Dead screens are scope debt. Flag them and let the team decide what to do. |
| "I'll scan backend and frontend sequentially to keep it simple" | Parallel agents cut time in half and produce independent findings before cross-referencing. |

## Red Flags

- Features named after code constructs (`UserController.store`) instead of user actions (`Create user account`)
- No cross-reference performed between backend and frontend findings
- Document omits the API-Only Capabilities or Orphaned UI sections entirely
- Business rules described as implementation (`"calls stripe.charge()"`) instead of behavior (`"charges card on subscription start"`)
- Only one agent spawned for both backend and frontend layers
- Open Questions left empty when service logic was ambiguous

## Verification

- [ ] Feature names read as product capabilities, not code identifiers
- [ ] Every feature entry has a backend entry point (route/handler) or is explicitly flagged as API-only
- [ ] Every feature entry has a frontend entry point (page/component) or is explicitly flagged as orphaned
- [ ] Features are grouped by product domain, not by file or layer
- [ ] Business rules stated as constraints, not implementation details
- [ ] Document saved to `.uncle-dev/feature-maps/YYYY-MM-DD-[name].md`
- [ ] Open Questions section captures anything that couldn't be determined from code alone
