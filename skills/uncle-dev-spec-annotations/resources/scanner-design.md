# Scanner Design — `scan-spec-coherence.py`

Algorithm spec for the `@spec` coherence scanner. The scanner is the **source of truth** for what the graph contains; the hook and graph generator both consume its output.

## Goals

1. Validate every `@spec` annotation in code/tests resolves to a defined spec ID
2. Detect specs that have code but no test (or vice versa)
3. Detect annotations placed on non-entry-point AST nodes (helpers)
4. Be deterministic, idempotent, and exit non-zero when the graph is broken

## Pipeline

```
docs/specs/**/*.md   ──▶ parse markdown   ──▶ canonical spec ID set
                                                      │
src/, tests/, app/  ──▶ AST per file     ──▶ annotation list   ──▶ resolve   ──▶ report
                        (per-language)         (id, file, line,                     │
                                                owner_kind, owner_name)             │
                                                                                    ▼
                                                                       exit code 0 / 1
```

## Inputs

### Spec ID source

- Files matched: `docs/specs/**/*.md`
- ID extraction regex: `\*\*([A-Z][A-Z0-9]+(?:-[A-Z0-9]+)*-\d+)\*\*\s*:`
- Examples matched: `**AUTH-UI-001**:`, `**BILLING-001**:`, `**MKT-SITE-045**:`
- Examples NOT matched: `**foo**:`, `**AUTH**:` (no digit suffix), `**auth-ui-001**` (lowercase)

### Code/test source

- Walk roots: `src/`, `tests/`, `test/`, `app/`, `lib/`, `pkg/`, `cmd/`, `internal/`, `templates/`
- Excluded paths: `node_modules/`, `.git/`, `dist/`, `build/`, `.venv/`, `__pycache__/`, `target/`, `vendor/`, `.next/`, `coverage/`
- File extension dispatch:
  - `.ts`, `.tsx`, `.js`, `.jsx`, `.mjs`, `.cjs` → `ts_adapter`
  - `.py` → `python_adapter`
  - `.go` → `go_adapter`
  - `.rs` → `rust_adapter`
  - `.java` → `java_adapter`
  - `.html`, `.htm` → `html_adapter`
  - Other extensions → `regex_fallback_adapter` (comment-aware regex)

## Per-language adapter contract

Each adapter exposes one function:

```python
def extract_annotations(file_path: str, source: str) -> list[Annotation]:
    """Return all @spec annotations found in the source.

    Each Annotation MUST be on a comment node. The owner_kind and owner_name
    describe the AST node directly following the comment (the entity the
    annotation belongs to).
    """
```

`Annotation` is a dataclass:

```python
@dataclass
class Annotation:
    ids: list[str]              # ['AUTH-UI-001', 'AUTH-UI-002']
    file: str                   # 'src/auth/authenticate.ts'
    line: int                   # 1-indexed line of the comment
    owner_kind: str             # one of: function|class|method|route|component|module|test|none
    owner_name: str             # 'authenticate', 'LoginForm', or '' if owner_kind == 'none'
```

### Owner classification rules

The adapter inspects the AST node directly following the comment:

| AST node type | owner_kind |
|---|---|
| function declaration, arrow function assignment | `function` |
| class declaration | `class` |
| method definition inside class | `method` |
| route/handler decorator (e.g. `@app.route`, `app.get(...)`) | `route` |
| React/Vue/Svelte component (function or class returning JSX/template) | `component` |
| top-of-file annotation with no following entity | `module` |
| `it()`, `test()`, `describe()` block | `test` |
| anything else (variable, import, comment-only) | `none` |

`owner_kind == 'none'` is treated as a HELPER ANNOTATION warning in `--strict` mode.

### Test file detection

A file is classified as a test file (its annotations count toward `with_test`) if its path matches any of:

- `**/*.test.{ts,tsx,js,jsx,py,go,rs,java}`
- `**/*_test.{py,go}`
- `**/*.spec.{ts,tsx,js,jsx}`
- `**/test_*.py`
- `**/tests/**`
- `**/test/**`

Otherwise it's classified as code (counts toward `with_code`).

## tree-sitter integration

Default mode uses `tree-sitter` with `tree-sitter-languages` for accurate parsing.

When tree-sitter is unavailable (import fails, or `--no-tree-sitter` flag is passed):

- `.py` files fall back to stdlib `ast` module
- All other languages fall back to **comment-aware regex**: extract single-line and block comments via per-language regex, then run the `@spec` extractor over comment text only. This avoids matching `@spec` inside string literals or code body.

The fallback mode loses owner classification (owner_kind defaults to `none`) but still detects every annotation. ORPHAN detection works fully; HELPER ANNOTATION detection degrades to off.

## Annotation extraction regex

Within a comment, `@spec` annotations are extracted with:

```
@spec\s+([A-Z][A-Z0-9-]+(?:\s*,\s*[A-Z][A-Z0-9-]+)*)
```

The capture group is then split on `[\s,]+` to get the individual ID list.

Each ID is validated with: `^[A-Z][A-Z0-9]+(?:-[A-Z0-9]+)*-\d+$`

IDs that fail validation produce a `MALFORMED ID` warning (not blocking unless `--strict`).

## Output formats

### Text (default)

```
Spec coherence report (root: /path/to/repo)

  ✓ 12 specs defined in docs/specs/
  ✓ 11 specs with code annotations
  ✓ 10 specs with test annotations

  ✗ ORPHAN: src/auth/login.ts:8 cites @spec AUTH-999 (not in docs/specs/)
  ✗ MISSING TEST: AUTH-005 has code (src/auth/refresh.ts:12) but no test citation
  ⚠ MISSING CODE: AUTH-007 has test (tests/auth/edge.test.ts:42) but no code citation
  ⚠ HELPER ANNOTATION: src/auth/util.ts:5 @spec on owner_kind=none — annotation belongs on entry point, not helper

Summary: 1 orphan, 1 missing test, 1 missing code, 1 helper annotation
Exit code: 1 (orphan present)
```

### JSON (`--format json`)

```json
{
  "schema_version": 1,
  "generated_at": "2026-05-09T14:23:00Z",
  "root": "/path/to/repo",
  "summary": {
    "specs_defined": 12,
    "specs_with_code": 11,
    "specs_with_test": 10,
    "orphans": 1,
    "missing_tests": 1,
    "missing_code": 1,
    "helper_annotations": 1
  },
  "specs": {
    "AUTH-UI-001": {
      "status": "implemented",
      "source": "docs/specs/auth-specs.md:8",
      "code_citations": [
        {"file": "src/auth/authenticate.ts", "line": 15, "owner_kind": "function", "owner_name": "authenticate"}
      ],
      "test_citations": [
        {"file": "tests/auth/authenticate.test.ts", "line": 42, "owner_kind": "test", "owner_name": "returns scoped session"}
      ]
    }
  },
  "orphans": [
    {"id": "AUTH-999", "file": "src/auth/login.ts", "line": 8}
  ],
  "missing_tests": ["AUTH-005"],
  "missing_code": ["AUTH-007"],
  "helper_annotations": [
    {"file": "src/auth/util.ts", "line": 5, "ids": ["AUTH-001"], "owner_kind": "none", "owner_name": ""}
  ]
}
```

## Exit codes

| Exit | Meaning |
|---|---|
| 0 | Zero ORPHANS (warnings allowed) |
| 1 | At least one ORPHAN (always blocking) |
| 1 | In `--strict`, also: any MISSING TEST, MISSING CODE, HELPER ANNOTATION, or MALFORMED ID |
| 2 | Scanner internal error (file I/O, malformed input) |

## CLI

```
python scan-spec-coherence.py [options]

Options:
  --root PATH          Repo root (default: cwd)
  --strict             Fail on MISSING TEST/CODE/HELPER/MALFORMED warnings
  --no-tree-sitter     Force regex+stdlib fallback (CI containers without grammars)
  --format FORMAT      Output format: text (default) | json
  --quiet              Suppress non-error output
```

## Performance budget

- A repo with ~5000 source files and ~200 specs should complete in under 5 seconds with tree-sitter, under 2 seconds in fallback mode.
- The scanner walks files once. AST trees are not retained across files. No graph is built in this layer — that's the graph generator's job.
