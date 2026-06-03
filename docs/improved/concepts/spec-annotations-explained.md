---
sidebar_position: 3
---

# LID `@spec` Annotations Explained

LID uses `@spec` as a pointer from code or tests back to the intent they implement. After reading this, you will understand what the annotation links, where it goes, and how the arrow graph uses it.

The intent chain looks like this:

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

An EARS spec has a stable ID:

```text
AUTH-UI-001
```

Tests and code cite that ID:

```ts
// @spec AUTH-UI-001
export async function authenticate(credentials) {
  // ...
}
```

That makes the chain walkable in both directions.

## From Intent to Code

```text
HLD
 |
 v
LLD
 |
 v
AUTH-UI-001
 |
 +--> test cites AUTH-UI-001
 |
 +--> code cites AUTH-UI-001
```

## From Code Back to Intent

```text
authenticate()
  |
  |  // @spec AUTH-UI-001
  v
AUTH-UI-001 in docs/specs/
  |
  v
LLD that owns AUTH-UI specs
  |
  v
HLD
```

## Where the Annotation Goes

Put `@spec` on the topmost function or module that owns the behavior.

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

Do not repeat the same annotation on every helper.

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

If one behavior spans several subsystems, annotate each subsystem entry point.

```text
AUTH-UI-001
 |
 +--> UI entry point       // @spec AUTH-UI-001
 |
 +--> API entry point      // @spec AUTH-UI-001
 |
 +--> session boundary     // @spec AUTH-UI-001
```

## How the Graph Uses It

The arrow graph lives in `docs/arrows/`.

```text
docs/arrows/index.yaml
        |
        v
docs/arrows/auth.md
        |
        +--> HLD reference
        +--> LLD reference
        +--> EARS spec file
        +--> tests with @spec
        +--> code with @spec
```

`@spec` gives the graph its bottom edge: tests and code point back to EARS.

```text
Code/Test
   |
   | @spec AUTH-UI-001
   v
EARS: AUTH-UI-001
   |
   v
LLD
   |
   v
HLD
```

## Coherence Check

LID checks that annotations resolve to real specs.

```text
@spec in code or test
        |
        v
Does this ID exist in docs/specs/?
        |
        +--> yes: linked
        |
        +--> no: reverse orphan
```

It also checks the neighboring layers:

```text
Code passes tests?
Tests cite specs?
Specs match LLD?
LLD matches HLD?
```

## One Special Case

Normal projects put `@spec` in code and tests.

```text
Code/Test  --@spec-->  EARS
```

LID's own `SKILL.md` files are different. They are prompt text, so putting `@spec` inside them would affect what the model reads as instructions. For those files, the spec points to the artifact instead.

```text
EARS spec header  -->  SKILL.md / references
```

## Short Version

```text
EARS ID = named intent
@spec   = pointer from code/test back to that intent
arrows  = index that connects HLD, LLD, specs, tests, and code
```
