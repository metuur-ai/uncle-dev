# Task (a): spec-first feature work

**Prompt var (`task`):** implement a cart-subtotal function (price × quantity per
line item), provide the implementation.

**What we measure:** does the arm produce acceptance criteria / EARS-style
obligation phrasing BEFORE jumping to code? The uncle-dev arm's system prompt
instructs spec-first behavior; the no-skill arm has no such instruction.

**Deterministic assertion** (`promptfooconfig.yaml`):
```
type: regex
value: '(?i)THE SYSTEM SHALL|acceptance criteria|WHEN .* SHALL'
```
PASS = the answer contains EARS/acceptance-criteria language. The expectation is
the uncle-dev arm passes more often than no-skill; the table records each arm's
result.
