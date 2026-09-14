# `@spec` Annotation Examples

Per-language syntax for `@spec` annotations on code and tests. Annotations always live in a comment node directly preceding the entity that owns the behavior.

## Single Spec ID

### TypeScript / JavaScript

```typescript
// @spec AUTH-UI-001
export async function authenticate(credentials: Credentials): Promise<AuthResult> {
  // ...
}
```

```typescript
// @spec AUTH-UI-001
it("returns a scoped session for valid credentials", async () => {
  // ...
});
```

### Python

```python
# @spec AUTH-UI-001
def authenticate(credentials: Credentials) -> AuthResult:
    ...
```

```python
# @spec AUTH-UI-001
def test_returns_scoped_session_for_valid_credentials():
    ...
```

### Go

```go
// @spec AUTH-UI-001
func Authenticate(credentials Credentials) (AuthResult, error) {
    // ...
}
```

```go
// @spec AUTH-UI-001
func TestReturnsScopedSessionForValidCredentials(t *testing.T) {
    // ...
}
```

### Rust

```rust
// @spec AUTH-UI-001
pub async fn authenticate(credentials: Credentials) -> Result<AuthResult, AuthError> {
    // ...
}
```

```rust
#[test]
// @spec AUTH-UI-001
fn returns_scoped_session_for_valid_credentials() {
    // ...
}
```

### Java

```java
// @spec AUTH-UI-001
public AuthResult authenticate(Credentials credentials) {
    // ...
}
```

```java
@Test
// @spec AUTH-UI-001
public void returnsScopedSessionForValidCredentials() {
    // ...
}
```

### HTML / Templates

```html
<!-- @spec MKT-SITE-045 -->
<section class="trace-panel">
  ...
</section>
```

## Multiple Spec IDs

When one entry point owns multiple behaviors, list IDs comma-separated:

```typescript
// @spec AUTH-UI-001, AUTH-UI-002
export async function authenticate(credentials: Credentials): Promise<AuthResult> {
  // handles both valid and invalid credentials
}
```

```python
# @spec AUTH-UI-001, AUTH-UI-002
def authenticate(credentials: Credentials) -> AuthResult:
    ...
```

The scanner accepts whitespace and trailing punctuation:

```
// @spec AUTH-UI-001, AUTH-UI-002
// @spec AUTH-UI-001,AUTH-UI-002
// @spec AUTH-UI-001  AUTH-UI-002    ← also accepted (whitespace-separated)
```

## Multi-Subsystem Behavior

When one behavior crosses subsystems, annotate each subsystem entry point:

```
AUTH-UI-001
   │
   ├──▶ LoginForm.tsx       // @spec AUTH-UI-001
   ├──▶ authController.ts   // @spec AUTH-UI-001
   └──▶ sessionStore.ts     // @spec AUTH-UI-001
```

```typescript
// LoginForm.tsx
// @spec AUTH-UI-001
export function LoginForm() { ... }
```

```typescript
// authController.ts
// @spec AUTH-UI-001
export async function handleLogin(req, res) { ... }
```

```typescript
// sessionStore.ts
// @spec AUTH-UI-001
export function createSession(userId: string) { ... }
```

Three annotations, one spec, three subsystem entry points. The scanner counts all three as `implemented_by` edges.

## Negative Requirements ("shall NOT")

Spec:

```markdown
- [x] **AUTH-SEC-004**: The system SHALL NOT expose raw authentication failure details to the user.
```

The strongest pointer is usually the test that proves the absence:

```typescript
// @spec AUTH-SEC-004
it("does not expose raw authentication failure details", async () => {
  const result = await authenticate({ email: "x", password: "wrong" });
  expect(result.error).not.toContain("Postgres");
  expect(result.error).not.toContain("stack trace");
});
```

If production code has a clear boundary that enforces the rule, annotate that too:

```typescript
// @spec AUTH-SEC-004
function toUserSafeAuthError(error: unknown): AuthError {
  // ...
}
```

## Anti-Patterns

### Don't annotate every helper

```
Bad:
// @spec AUTH-UI-001
authenticate()

// @spec AUTH-UI-001
parseCredentials()           ← helper, no annotation needed

// @spec AUTH-UI-001
validatePassword()           ← helper, no annotation needed

// @spec AUTH-UI-001
createSession()              ← helper, no annotation needed
```

The scanner's `--strict` mode flags these as `HELPER ANNOTATION` warnings.

### Don't invent IDs only in code

```
Bad:
Code says @spec AUTH-UI-999, but docs/specs/ has no AUTH-UI-999.
```

The scanner reports this as `ORPHAN` and the hook blocks the commit.

### Don't reuse deleted IDs for new behavior

```
Bad:
AUTH-UI-001 used to mean login.
After deletion, AUTH-UI-001 now means password reset.
```

Reused IDs corrupt the graph. Once deleted, an ID is retired forever. New behavior gets the next sequential number.

### Don't use `@spec` for OpenSpec change IDs or tasks

```
Bad:
// @spec 002-auth-refactor       ← that's a change ID, not a spec ID
// @spec TASK-123                ← tasks aren't durable
```

`@spec` cites EARS spec IDs only (e.g., `AUTH-UI-001`). OpenSpec change IDs (`002-auth-refactor`) live in `proposal.md`'s `## EARS Specs` block, not in code.

### Don't annotate non-behavioral code

Pure utilities, build scripts, internal plumbing, and one-shot migrations don't need `@spec`. The annotation is for **product behavior**.

```
No annotation needed:
- date formatting helpers
- string utility functions
- type definitions with no logic
- build/lint config files
- one-time data migrations
```

If you're not sure, ask: "Does this code implement a behavior a user, customer, or stakeholder would care about?" If no, no annotation.
