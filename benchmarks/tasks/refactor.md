# Task (b): refactoring

**Prompt var (`task`):** refactor a small `formatName(first, last)` function to
remove duplication while preserving observable behavior and the public interface.

**What we measure:** does the refactor keep the public interface stable? The
checkable property is that the function name `formatName` survives — a surgical
refactor preserves the entry point, it does not rename or restructure the API.

**Deterministic assertion** (`promptfooconfig.yaml`):
```
type: icontains
value: 'formatName'
```
PASS = the refactored code still exposes `formatName`. This is a narrow but
objective behavior-preservation check (no live grading needed).
