# Inference Rules: routing decision notes to scope files

Loaded by `uncle-dev-acknowledge` (capture mode) and by `uncle-dev-next-task/acknowledge-gate.md` (when deriving scopes for a story). Two callers, one rule table — that's why this file is its own reference.

## How the rules apply

For each decision note (one prose body), scan the body for every signal in the table below. Each matched signal contributes one or more scope names to the note's scope set. After all signals are evaluated, apply the duplication rule.

**Matching is case-insensitive** unless the signal is a path token (paths are case-sensitive on most filesystems we care about). Word-boundary matching (`\b`) prevents `apt-table` from matching `table`.

## The Rule Table

| Signal pattern | Scopes added | Notes |
|---|---|---|
| HTTP path tokens: `/auth/*`, `/api/*`, `/v1/*`, `/v2/*`, `/admin/*`, any `^/[a-z]+/[a-z]+` | `api` | Path appears in the body, not just the title |
| HTTP verbs followed by a path: `GET /…`, `POST /…`, `PUT /…`, `PATCH /…`, `DELETE /…` | `api` | |
| Controller / route / handler / endpoint / middleware / interceptor / guard | `api` | Word-boundary; "guards" is fine, "middleware-ish" is not |
| `migration`, `migrations/`, `schema`, `prisma`, `drizzle`, `table`, `column`, `nullable`, `not null`, `index`, `foreign key`, `unique constraint` | `api` + `share` | Schema decisions affect both the API surface and the shared types/DTOs |
| `render`, `routes/`, `pages/`, `useEffect`, `useState`, `useMemo`, `useCallback`, `tailwind`, `styled-components`, `<[A-Z][A-Za-z]*[/ >]`, `className=`, `next/`, `app/`, `react`, `vite` | `web` | The `<Component>` regex catches JSX usage |
| Type names with PascalCase suffix `DTO`, `Schema`, `Type`, `Interface`, `Contract`; bare words `interface`, `Zod`, `valibot`, `shared util`, `monorepo`, `workspace` | `share` | |
| Path mention `apps/<x>/`, `packages/<x>/`, `libs/<x>/`, `services/<x>/` | scope `<x>` (lazy create) | First path segment after the prefix becomes the scope name |
| Negation pattern: `No <noun> endpoint`, `not introducing <…>`, `no plans to <…>`, `intentionally not <…>`, `we are NOT going to <…>` | `general` + every scope the negated thing would have lived in (run the rest of the rules on the negated noun) | The human is acknowledging a *deliberate absence* — these are highest-value notes |
| Cross-cutting keywords: `security`, `perf budget`, `observability`, `error envelope`, `naming convention`, `rate limit`, `audit`, `logging`, `telemetry`, `feature flag` | `general` (always; in addition to other matches) | A security decision in `/auth/login` lands in BOTH `api` and `general` |
| Nothing matched | `general` only | Fallback — never lose a note |

## Duplication rule (formal)

```
scopes = ∅
for each signal in the body:
    if signal matches: add its scopes to scopes
if any cross-cutting keyword matched OR negation pattern matched:
    scopes = scopes ∪ {general}
if scopes == ∅:
    scopes = {general}
```

A note ends up in every file in `scopes`. All copies share one global D-id so ack propagates.

## Worked examples (matches the user's exemplar)

### D5 — constant-time login
Body mentions: `login`, `argon2`, `DUMMY_HASH`, `unknown-email`, `timing`, `user existence`.

| Match | Scopes added |
|---|---|
| `login` (endpoint name) | `api` |
| `security` (cross-cutting via "timing… user existence" — security keyword) | `general` |

**Final scopes:** `api`, `general`. ✓ matches plan.

### D6 — chain shape
Body mentions: `/auth/login`, `/auth/refresh`, `/auth/logout`, `JwtAuth`, `RoleGuard`, `Idempotency`, `FilterPrecedence`, `middleware`.

| Match | Scopes added |
|---|---|
| `/auth/*` paths | `api` |
| `middleware` / `Guard` | `api` |
| No cross-cutting keyword | — |

**Final scopes:** `api`. ✓ matches plan.

### D9 — passwordHash nullable
Body mentions: `User.passwordHash`, `nullable`, `schema`, `migration`.

| Match | Scopes added |
|---|---|
| `schema`, `nullable`, `migration` | `api` + `share` |
| No cross-cutting keyword | — |

**Final scopes:** `api`, `share`. ✓ matches plan.

### "No /me endpoint"
Body mentions: `No /me endpoint`, `login response`, `first render`, `restructure`.

| Match | Scopes added |
|---|---|
| Negation pattern `No /me endpoint` → run rules on `/me endpoint` | `api` (path token) |
| Negation pattern → also `general` | `general` |
| `first render` (web keyword via `render`) | `web` |

**Final scopes:** `general`, `api`, `web`. ✓ matches plan.

## When the rules disagree with you

If the routing table sends a note somewhere wrong, the answer is to **edit this file**, not to special-case the note. Two agents must always reach the same scopes for the same body. The capture-mode "routing summary" output exists precisely so a human can catch this and patch the rules.

If a project has its own monorepo conventions (e.g. `infra/`, `cli/`, `worker/`), add rows to the path-mention section. The skill creates `infra.md`, `cli.md`, `worker.md` lazily.

## Anti-patterns

- **LLM-based routing.** Don't. Two agents must agree byte-for-byte on the scope set. A regex table is auditable; an LLM call isn't.
- **Per-note scope override.** Don't add a `scope:` hint to the input. If the rules are wrong, fix the rules.
- **Allowlists.** Don't refuse unknown scopes. The system is open: any `<scope>.md` is valid; new ones spring into existence on first match.
