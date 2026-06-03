---
sidebar_position: 2
---

# How to Implement `@spec` Annotations for Product Behavior

This guide shows you how to use `@spec` annotations to connect durable product behavior to specs, tests, and code.

> **Note:** The sections before "How to Implement This in Another Repo" explain the concepts (the graph, what belongs in specs, code, and tests). If you want the procedure, skip to [How to Implement This in Another Repo](#how-to-implement-this-in-another-repo).

The core idea:

```text
@spec = pointer
graph = connected map of all pointers
arrow = direction intent flows: HLD -> LLD -> EARS -> Tests -> Code
```

`@spec` is not a changelog marker. It does not mean "this code changed in this task." It means "this code implements this product behavior."

## The Graph

The graph is the map that connects durable product intent to the code that implements it.

`@spec` is one edge in that graph.

```text
HLD
 |
 v
LLD
 |
 v
EARS spec
 |
 v
Test
 |
 v
Code
```

For one feature:

```text
HLD: account security
        |
        v
LLD: authentication flow
        |
        v
EARS: AUTH-UI-001
        |
        +--> test: "returns session for valid credentials"
        |
        +--> code: authenticate()
                  // @spec AUTH-UI-001
```

From code back to intent:

```text
authenticate()
  |
  | @spec AUTH-UI-001
  v
AUTH-UI-001
  |
  v
authentication LLD
  |
  v
account security HLD
```

In product terms:

```text
Product intent
   |
   +--> Feature design
           |
           +--> Specific behavior
                   |
                   +--> Tests
                   |
                   +--> Code
```

`docs/arrows/` is the index for that graph:

```text
docs/arrows/index.yaml
        |
        v
auth segment
        |
        +--> docs/llds/auth.md
        +--> docs/specs/auth-specs.md
        +--> tests with AUTH-* specs
        +--> code with AUTH-* specs
```

## What Should Be in the Spec?

Each spec should describe one durable product behavior.

Use a stable ID:

```text
AUTH-UI-001
```

Use a clear behavior statement:

```markdown
- [x] **AUTH-UI-001**: When a user submits valid credentials, the system SHALL return a session scoped to that user.
```

Good specs are:

- Stable: keep the ID when the wording gets sharper.
- Product-facing: describe behavior, not implementation details.
- Testable: a test can prove whether the behavior exists.
- Grep-friendly: the ID is easy to search across the repo.

Do not make specs for temporary implementation tasks:

```text
Bad:
AUTH-UI-001 = Refactor login.ts

Good:
AUTH-UI-001 = Valid credentials return a scoped session
```

## What Should Be in the Code?

Code should carry `@spec` at the entry point that owns the behavior.

TypeScript:

```ts
// @spec AUTH-UI-001, AUTH-UI-002
export async function authenticate(credentials: Credentials): Promise<AuthResult> {
  // ...
}
```

Python:

```python
# @spec AUTH-UI-001, AUTH-UI-002
def authenticate(credentials: Credentials) -> AuthResult:
    ...
```

Go:

```go
// @spec AUTH-UI-001, AUTH-UI-002
func Authenticate(credentials Credentials) (AuthResult, error) {
    // ...
}
```

Rust:

```rust
// @spec AUTH-UI-001, AUTH-UI-002
pub async fn authenticate(credentials: Credentials) -> Result<AuthResult, AuthError> {
    // ...
}
```

Java:

```java
// @spec AUTH-UI-001, AUTH-UI-002
public AuthResult authenticate(Credentials credentials) {
    // ...
}
```

HTML or templates:

```html
<!-- @spec MKT-SITE-045 -->
<section class="trace-panel">
  ...
</section>
```

The annotation belongs on the owner, not every helper.

```text
Good:

// @spec AUTH-UI-001
authenticate()
  |
  +--> parseCredentials()
  |
  +--> validatePassword()
  |
  +--> createSession()
```

Avoid noisy helper annotations:

```text
Noisy:

// @spec AUTH-UI-001
authenticate()

// @spec AUTH-UI-001
parseCredentials()

// @spec AUTH-UI-001
validatePassword()

// @spec AUTH-UI-001
createSession()
```

If one behavior spans subsystems, annotate each subsystem entry point.

```text
AUTH-UI-001
 |
 +--> UI entry point       // @spec AUTH-UI-001
 |
 +--> API entry point      // @spec AUTH-UI-001
 |
 +--> session boundary     // @spec AUTH-UI-001
```

## What Should Be in the Tests?

Tests should cite the spec IDs they verify.

TypeScript:

```ts
// @spec AUTH-UI-001
it("returns a scoped session for valid credentials", async () => {
  // ...
});
```

Python:

```python
# @spec AUTH-UI-001
def test_returns_scoped_session_for_valid_credentials():
    ...
```

Go:

```go
// @spec AUTH-UI-001
func TestReturnsScopedSessionForValidCredentials(t *testing.T) {
    // ...
}
```

Put the annotation on the test that proves the behavior, not every assertion inside the test.

```text
Spec
 |
 v
Test with @spec
 |
 v
Assertions
```

## What Should Be in the Skills or Agent Instructions?

Agent instructions should define the workflow and placement rules.

Include these rules:

```markdown
## Development Workflow

HLD -> LLD -> EARS -> Tests -> Code

## Code Annotations

Annotate code and tests with `@spec` comments citing EARS IDs.

Place the annotation at the entry point of the behavior's implementation graph:
the topmost function, class, route, component, job, or module that owns the behavior.
Do not annotate every helper.

When one behavior spans multiple subsystems, annotate the entry point in each subsystem.
```

Include a coherence rule:

```markdown
## Coherence Check

Before considering implementation complete:

1. Tests pass.
2. Every `@spec` annotation points to an existing spec ID.
3. Every behavioral spec has at least one test citation.
4. Specs still match the LLD.
5. The LLD still matches the HLD.
```

If your "code" is prompt text, such as a skill file, avoid putting `@spec` inside the prompt body if it would affect runtime behavior. Instead, put artifact pointers in the spec header:

```markdown
# Auth Skill Specs

**LLD**: docs/llds/auth-skill.md
**Implementing artifacts**:
- plugins/auth/skills/auth/SKILL.md
- plugins/auth/skills/auth/references/errors.md
```

Use that inversion only for prompt artifacts. Normal code should carry `@spec` directly.

## How to Implement This in Another Repo

### Prerequisites

Before you begin, ensure you have:

- A repository where you can add a `docs/` directory
- At least one product-behavior area to map (for example, auth or billing)
- The languages and test framework your code uses, so you can place `@spec` comments correctly

### 1. Create the intent docs

Use this structure:

```text
docs/
  high-level-design.md
  llds/
    auth.md
  specs/
    auth-specs.md
  arrows/
    index.yaml
    auth.md
```

### 2. Create the spec graph

The spec graph is the durable map from product intent to implementation.

Create it before adding annotations.

```text
HLD
 |
 +--> LLD segment
        |
        +--> EARS specs
               |
               +--> tests
               |
               +--> code
```

For a real feature:

```text
docs/high-level-design.md
  "Accounts must be secure and scoped to the authenticated user."
        |
        v
docs/llds/auth.md
  "Authentication flow owns login, logout, session creation, and safe errors."
        |
        v
docs/specs/auth-specs.md
  AUTH-UI-001
  AUTH-UI-002
        |
        +--> src/auth/authenticate.test.ts
        |
        +--> src/auth/authenticate.ts
```

Build the graph in this order:

```text
1. Choose the product behavior area.
2. Create or select the LLD segment.
3. Choose a stable spec prefix.
4. Write EARS specs under that prefix.
5. Add tests that cite those spec IDs.
6. Add code annotations that cite those spec IDs.
7. Add or update docs/arrows/ so the segment is indexed.
```

#### Choose segments

A segment is one product-behavior area owned by one LLD.

An arrow segment is a bounded slice of the larger intent graph.

```text
Whole product graph
 |
 +--> auth segment
 |
 +--> billing segment
 |
 +--> search segment
```

Each segment contains its own LLD, specs, tests, and code links.

```text
auth segment
 |
 +--> docs/llds/auth.md
 |
 +--> docs/specs/auth-specs.md
 |       |
 |       +--> AUTH-UI-001
 |       +--> AUTH-UI-002
 |
 +--> tests that cite AUTH-*
 |
 +--> code that cites AUTH-*
```

The LLD owns the segment. The spec prefix marks its boundary. The `@spec` annotations pull tests and code into the segment.

```text
LLD            -> docs/llds/auth.md
Spec prefix    -> AUTH-*
Tests/code     -> files with @spec AUTH-...
Segment map    -> docs/arrows/auth.md
```

Good segments:

```text
auth
billing
notifications
search
checkout
```

Weak segments:

```text
utils
frontend
backend
misc
shared
```

Use product intent, not file location, as the boundary.

```text
Good:
auth = login, logout, sessions, auth errors

Weak:
frontend = every UI file, regardless of product behavior
```

Segments matter during cascade. A change inside one segment can move down that segment quickly:

```text
auth LLD changes
     |
     v
AUTH-* specs change
     |
     v
AUTH-* tests change
     |
     v
code with @spec AUTH-* changes
```

If a change crosses from one segment to another, pause and confirm.

```text
auth segment              billing segment
     |                          |
     v                          v
AUTH-* specs      --->    BILLING-* specs
        boundary crossing
```

That pause matters because different segments can carry different intent, owners, risks, or unresolved design questions.

#### Choose prefixes

Each segment gets a stable spec prefix.

```text
auth segment       -> AUTH-*
billing segment    -> BILLING-*
marketing site     -> MKT-SITE-*
```

Use longer prefixes when needed:

```text
AUTH-UI-001
AUTH-API-001
AUTH-SESSION-001
```

The prefix defines the segment boundary:

```text
AUTH-* specs belong to auth
BILLING-* specs belong to billing
```

#### Add graph nodes

Each spec becomes a graph node:

```text
AUTH-UI-001
AUTH-UI-002
AUTH-SESSION-001
```

Each test or code annotation becomes an edge:

```text
AUTH-UI-001
   |
   +--> authenticate.test.ts
   |
   +--> authenticate.ts
```

Multiple specs can point to one code owner:

```text
AUTH-UI-001
        \
         +--> authenticate()
        /
AUTH-UI-002
```

One spec can point to multiple subsystem owners:

```text
AUTH-SESSION-001
   |
   +--> LoginForm.tsx
   |
   +--> authController.ts
   |
   +--> sessionStore.ts
```

#### Add the arrow index

`docs/arrows/index.yaml` is the graph's table of contents.

```yaml
schema_version: 1
last_updated: 2026-05-09

arrows:
  auth:
    status: MAPPED
    sampled: 2026-05-09
    audited: null
    audited_sha: null
    blocks: []
    blockedBy: []
    detail: auth.md
    next: "Run first coherence audit."
    drift: null
```

Each entry points to one segment document:

```text
docs/arrows/index.yaml
        |
        v
docs/arrows/auth.md
```

#### Add the segment document

`docs/arrows/auth.md` connects the segment to its source files:

```markdown
# Arrow: auth

Authentication behavior: login, logout, session creation, and user-safe auth errors.

## References

### HLD
- docs/high-level-design.md

### LLD
- docs/llds/auth.md

### EARS
- docs/specs/auth-specs.md

### Tests
- src/auth/authenticate.test.ts

### Code
- src/auth/authenticate.ts
```

After this exists, the graph can be walked:

```text
index.yaml
   |
   v
auth.md
   |
   +--> HLD
   +--> LLD
   +--> specs
   +--> tests
   +--> code
```

### 3. Define spec IDs

In `docs/specs/auth-specs.md`:

```markdown
# Auth Specs

**LLD**: docs/llds/auth.md

Status markers: `[x]` implemented · `[ ]` active gap · `[D]` deferred

---

- [x] **AUTH-UI-001**: When a user submits valid credentials, the system SHALL return a session scoped to that user.
- [x] **AUTH-UI-002**: When a user submits invalid credentials, the system SHALL return a user-safe authentication error.
```

### 4. Annotate tests

```ts
// @spec AUTH-UI-001
it("returns a scoped session for valid credentials", async () => {
  // ...
});

// @spec AUTH-UI-002
it("returns a user-safe error for invalid credentials", async () => {
  // ...
});
```

### 5. Annotate code

```ts
// @spec AUTH-UI-001, AUTH-UI-002
export async function authenticate(credentials: Credentials): Promise<AuthResult> {
  // ...
}
```

### 6. Add an arrow segment

In `docs/arrows/index.yaml`:

```yaml
schema_version: 1
last_updated: 2026-05-09

arrows:
  auth:
    status: MAPPED
    sampled: 2026-05-09
    audited: null
    audited_sha: null
    blocks: []
    blockedBy: []
    detail: auth.md
    next: "Run first coherence audit."
    drift: null
```

In `docs/arrows/auth.md`:

```markdown
# Arrow: auth

Authentication behavior: login, logout, session creation, and user-safe auth errors.

## References

### HLD
- docs/high-level-design.md

### LLD
- docs/llds/auth.md

### EARS
- docs/specs/auth-specs.md

### Tests
- src/auth/authenticate.test.ts

### Code
- src/auth/authenticate.ts
```

If you already created this in step 2, update it instead of duplicating it.

### 7. Add a scanner

At minimum, your scanner should do this:

```text
scan code/tests for @spec
        |
        v
extract IDs
        |
        v
scan docs/specs for IDs
        |
        v
report:
  - valid links
  - reverse orphans
  - specs without tests
  - code with no spec where one is expected
```

Pseudo-code:

```text
code_refs = find_all("@spec ...")
spec_defs = find_all("**SPEC-ID**" in docs/specs)

for id in code_refs:
  if id not in spec_defs:
    report "reverse orphan"

for id in spec_defs:
  if id has no test citation:
    report "missing test link"
```

### Verify it worked

Confirm the graph is wired correctly:

- Running the scanner reports no reverse orphans (every `@spec` ID in code and tests exists in `docs/specs/`).
- Running the scanner reports no specs missing a test link.
- Walking `docs/arrows/index.yaml` reaches each segment document, and each segment document links to its HLD, LLD, specs, tests, and code.

> **Flag:** The scanner's exact exit codes and output format are not specified in this guide. Confirm the expected output against your own scanner implementation.

## How to Use It During Development

When product intent changes:

```text
Update HLD or LLD
        |
        v
Update EARS specs
        |
        v
Update tests with @spec
        |
        v
Update code with @spec
        |
        v
Run coherence check
```

When code changes first:

```text
Code changed
     |
     v
Find @spec ID
     |
     v
Read matching EARS spec
     |
     v
Check test
     |
     v
Check LLD/HLD
```

If the code has no `@spec`, ask:

```text
Is this code implementing product behavior?
        |
        +--> yes: add or find the spec, then annotate the entry point
        |
        +--> no: no annotation needed
```

## Common Cases

### One Function Implements Multiple Specs

```ts
// @spec AUTH-UI-001, AUTH-UI-002
export async function authenticate(credentials: Credentials) {
  // handles valid and invalid credentials
}
```

Graph:

```text
authenticate()
   |
   +--> AUTH-UI-001
   |
   +--> AUTH-UI-002
```

### One Spec Spans Multiple Subsystems

```text
AUTH-UI-001
 |
 +--> LoginForm.tsx       // @spec AUTH-UI-001
 |
 +--> authController.ts   // @spec AUTH-UI-001
 |
 +--> sessionStore.ts     // @spec AUTH-UI-001
```

### Negative Requirement

For "shall NOT" behavior, the best pointer may be the test.

```markdown
- [x] **AUTH-SEC-004**: The system SHALL NOT expose raw authentication failure details to the user.
```

```ts
// @spec AUTH-SEC-004
it("does not expose raw authentication failure details", async () => {
  // ...
});
```

If production code has a clear boundary that enforces the rule, annotate that too.

```ts
// @spec AUTH-SEC-004
function toUserSafeAuthError(error: unknown): AuthError {
  // ...
}
```

## What Not to Do

Do not use `@spec` for tasks:

```text
Bad:
// @spec TASK-123
```

Do not annotate every helper:

```text
Bad:
Every function in auth/ has the same five @spec IDs.
```

Do not invent IDs only in code:

```text
Bad:
Code says @spec AUTH-UI-999, but docs/specs has no AUTH-UI-999.
```

Do not reuse deleted IDs for new behavior:

```text
Bad:
AUTH-UI-001 used to mean login.
Now it means password reset.
```

## Minimum Rules

If you only adopt the minimum system, use these rules:

```text
1. Every product behavior gets a stable EARS ID.
2. Tests cite the spec IDs they verify.
3. Code cites the spec IDs it implements.
4. Put @spec on behavior entry points, not helpers.
5. Scan annotations and specs for broken links.
6. When intent changes, walk down: HLD -> LLD -> EARS -> Tests -> Code.
7. When code changes, walk up: Code -> EARS -> LLD -> HLD.
```
