# Mutation Catalogue

Eight categories of mutations, ordered from most to least likely to reveal meaningful test gaps.

Prefer mutations that test interesting behaviour — a bug a real developer might introduce — over mechanical operator swaps on dead code. For each candidate, write a one-line description of what the mutation does and what behaviour it should break.

---

## 1. Delete or skip a side effect

Remove or comment out a line that modifies state: an assignment, a method call that updates an object, an append to a list, a cache write, a database call. Tests whether the suite verifies that the side effect actually happened.

```python
# Original
self.count += 1
results.append(item)

# Mutation: delete the line entirely
```

---

## 2. Negate or invert a condition

Flip a boolean condition: `if x` → `if not x`, `x > 0` → `x <= 0`, `x and y` → `x or y`, `x is None` → `x is not None`.

```python
# Original
if user.is_active and user.has_permission:

# Mutation
if user.is_active or user.has_permission:
```

---

## 3. Change a boundary or comparison

Off-by-one and boundary errors: `<` → `<=`, `>=` → `>`, `== 0` → `== 1`, `range(n)` → `range(n - 1)`.

```python
# Original
if retry_count < max_retries:

# Mutation
if retry_count <= max_retries:
```

---

## 4. Swap or hardcode a return value

Replace a computed return value with a constant, or swap two return paths in a conditional. Tests whether callers actually use and verify the return value.

```python
# Original
return calculated_score

# Mutation
return 0
```

---

## 5. Delete an early return or guard clause

Remove a guard clause (`if bad_input: return/raise`) to see whether the suite has a test for the guarded condition.

```python
# Original
def process(items):
    if not items:
        return []
    ...

# Mutation — delete the guard
def process(items):
    ...
```

---

## 6. Change an operator

Swap arithmetic or string operators: `+` → `-`, `*` → `/`, `//` → `/`, `+` → `` (concatenation removed). Use sparingly — only when the operation has a testable effect on output.

---

## 7. Modify a default argument or constant

Change a default parameter value, a class constant, or a module-level constant. Tests whether any test exercises the default path.

```python
# Original
def connect(host, port=5432):

# Mutation
def connect(host, port=5433):
```

---

## 8. Swap the order of arguments or operands

Reverse argument order in an internal call, or swap operands around a non-commutative operator. Tests whether the suite is sensitive to argument semantics rather than just arity.

```python
# Original
result = divide(numerator, denominator)

# Mutation
result = divide(denominator, numerator)
```
