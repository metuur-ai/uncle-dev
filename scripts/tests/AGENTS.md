# scripts/tests

Bash test suite for the `scripts/` tooling. No framework — plain `*.test.sh` files.

## Entry Points
- `run-all.sh` — runs every test; the orchestrator wires new test files in here.
- `*.test.sh` — one file per unit under test (e.g. `config-env-override.test.sh`, `install-codex.test.sh`).

## Contracts & Invariants
- Each test file is self-contained, `set -euo pipefail`, prints `PASS:`/`FAIL:` lines, and exits non-zero on any failure.
- Resolve paths from `${BASH_SOURCE[0]}` (REPO_ROOT = `tests/../..`); never assume cwd.
- Tests that read config go through `scripts/uncle-dev-config.sh`, never the YAML directly.
- Tests must not mutate tracked files. Asserting against the real YAML is read-only; verify it stays byte-unchanged (shasum/sha1sum) after the run.

## Patterns
To add a test:
1. Create `<unit>.test.sh` here following the PASS/FAIL + exit-non-zero shape.
2. Source `../lib/manifest.sh` if asserting against the canonical inventories.
3. The orchestrator adds it to `run-all.sh` — do not edit `run-all.sh` for individual units unless that is the task.

## Anti-patterns
- Don't depend on host state, network, or a real `$HOME`; use `mktemp -d` + a trap for any writes.
- Don't read `.agents/uncle-dev-setup.yaml` directly.

## Related Context
- Tooling under test: `../AGENTS.md`
