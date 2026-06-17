# Ponytail Patterns Adoption — Tasks

Source of truth: `docs/ears/ponytail-patterns-adoption.md`. Stories are grouped by EARS unit and ordered into the 4 phases from the HLD. Cross-phase dependencies are expressed as story `deps:`. Each phase is independently shippable; gate Phase N+1 work on Phase N being merged + green.

---

## Phase 1 — Mechanical foundations

### Unit 1: Drift guard

- [x] 1.1 Classify current divergences & declare allowlist (est: ~30m)
  - acceptance: R-1.8 — THE SYSTEM SHALL declare any deliberately-excluded asset in an allowlist co-located with `manifest.sh`, and the guard SHALL print the allowlist it honored.
  - verify: each of the 4 marketplace-omitted skills + the 17 missing commands is labeled `stale` (reconcile) or `intentional` (allowlist) in a written classification; allowlist file exists next to `scripts/lib/manifest.sh`.

- [x] 1.2 `check-manifest.sh` asserts marketplace.json skill/agent lists (deps: 1.1, est: ~40m)
  - acceptance: R-1.1, R-1.2 — assert `.claude-plugin/marketplace.json` skill+agent lists == canonical roots minus allowlist.
  - verify: script reads `manifest.sh` roots; passes on reconciled tree; flips to fail when a skill is removed from marketplace.json.

- [x] 1.3 Assert README counts (deps: 1.2, est: ~20m)
  - acceptance: R-1.3 — README skill/command counts match canonical counts.
  - verify: editing README count by hand makes the guard fail.

- [x] 1.4 Assert `plugins/uncle-dev/commands/` set (deps: 1.2, est: ~20m)
  - acceptance: R-1.4 — committed command set == canonical command list minus allowlist.
  - verify: deleting a command file makes the guard fail; passes after reconcile.

- [x] 1.5 Per-divergence messaging + honored-allowlist print (deps: 1.2, est: ~20m)
  - acceptance: R-1.5, R-1.8 — non-zero exit with per-divergence message naming copy + missing/extra entries; print honored allowlist.
  - verify: forced drift prints the specific copy and entry; allowlist lines appear in output.

- [x] 1.6 Wire guard into test + verify entrypoints (deps: 1.2, est: ~15m)
  - acceptance: R-1.6 — invoked from `scripts/tests/run-all.sh` and `install.sh verify`.
  - verify: running each entrypoint executes `check-manifest.sh`.

- [x] 1.7 Reconcile current drift to green (deps: 1.1, 1.2, 1.3, 1.4, est: ~45m)
  - acceptance: R-1.7 — `check-manifest.sh` exits zero on a clean checkout.
  - verify: fresh checkout → `bash scripts/check-manifest.sh` exits 0.

### Unit 2: Env-var config override tier

- [x] 2.1 Add env override resolution to `uncle-dev-config.sh` (est: ~30m)
  - acceptance: R-2.1, R-2.3 — resolve `UNCLE_DEV_<KEY>` → YAML → caller default; env set ⇒ no YAML mutation.
  - verify: `UNCLE_DEV_PREFERENCES_SDD_MODE=openspec bash uncle-dev-config.sh preferences.sdd_mode` returns `openspec` while YAML is unchanged.

- [x] 2.2 Key derivation from dotted path (deps: 2.1, est: ~15m)
  - acceptance: R-2.2 — `<KEY>` = uppercased dotted path with dots→underscores.
  - verify: `preferences.sdd_mode` resolves to `UNCLE_DEV_PREFERENCES_SDD_MODE`.

- [x] 2.3 Preserve sole-YAML-reader invariant (deps: 2.1, est: ~15m)
  - acceptance: R-2.4 — audit grep over `scripts/ .claude/ hooks/` returns only the helper.
  - verify: `grep -rn 'open.*setup\.yaml\|cat.*setup\.yaml\|yq.*setup\.yaml' scripts/ .claude/ hooks/` returns only `uncle-dev-config.sh`.

### Unit 3: Install-time mode-branch split

- [x] 3.1 Add stable section markers to dual-branch skills (est: ~30m)
  - acceptance: R-3.1 — canonical sources keep both lid-ears + openspec branches behind stable markers.
  - verify: each affected skill (`spec-driven-development`, `next-task`, `planning-and-task-breakdown`, `acknowledge`, `wrap`, `knowledge-capture`, `shipping-and-launch`) contains both markers.

- [x] 3.2 Splitter selects active branch at install (deps: 3.1, est: ~45m)
  - acceptance: R-3.2, R-3.3 — install selects single-mode variant by resolved `sdd_mode`, dropping the inactive branch from the installed copy.
  - verify: install with `sdd_mode=lid-ears` ⇒ installed copy has only lid-ears branch; `openspec` ⇒ only openspec branch.

- [x] 3.3 Install-time only, no runtime cost (deps: 3.2, est: ~10m)
  - acceptance: R-3.4 — split happens at install, not per-invocation.
  - verify: no skill-read/runtime hook added; split logic lives in install path only.

- [x] 3.4 Fail loud on missing/unmatched markers (deps: 3.2, est: ~20m)
  - acceptance: R-3.5 — absent markers ⇒ fail loud, never ship a partially-trimmed copy.
  - verify: renaming a marker makes the splitter error out instead of writing a half file.

- [x] 3.5 Opt-in default to verbatim copy (deps: 3.2, est: ~15m)
  - acceptance: R-3.6 — default verbatim until split proven on all affected skills.
  - verify: with split disabled, installed copies are byte-identical to canonical.

- [x] 3.6 Round-trip split test (deps: 3.2, est: ~25m)
  - acceptance: R-3.7 — test asserts both markers present in source and split yields the active branch.
  - verify: test passes for all affected skills; fails if a branch is dropped from source.

---

## Phase 2 — Audit & self-application

### Unit 4: Over-engineering audit skill

- [ ] 4.1 Scaffold `uncle-dev-over-engineering-audit` per skill-anatomy (est: ~40m)
  - acceptance: R-4.1, R-4.6 — distinct audit capability; Overview/When to Use/Process/Common Rationalizations/Red Flags/Verification sections.
  - verify: SKILL.md has valid frontmatter (name, description) and all six required sections.

- [ ] 4.2 Define output contract — tagged findings (deps: 4.1, est: ~20m)
  - acceptance: R-4.2 — one line per finding tagged exactly one of `delete|stdlib|native|yagni|shrink`.
  - verify: sample run output: every finding line carries exactly one tag.

- [ ] 4.3 Ranking + `net:` summary (deps: 4.2, est: ~15m)
  - acceptance: R-4.3 — findings ranked biggest-cut-first, ending `net: -N lines, -M deps possible`.
  - verify: sample output ordered by cut size; final line matches the `net:` format.

- [ ] 4.4 Diff + whole-repo scopes via existing orchestration (deps: 4.1, est: ~30m)
  - acceptance: R-4.4 — both scopes supported, reusing parallel-orchestration + review-synthesizer.
  - verify: skill documents both scopes and references the existing synthesizer pattern (no new orchestration engine).

- [ ] 4.5 Non-destructive to existing skills (deps: 4.1, est: ~10m)
  - acceptance: R-4.5 — clarity-first simplify and 5-axis review unchanged.
  - verify: git diff shows no edits to `uncle-dev-dev-code-simplification` or `uncle-dev-code-review-and-quality`.

### Unit 5: Self-application of the audit

- [ ] 5.1 Run whole-repo audit on uncle-dev config/manifest surface (deps: 4.3, 4.4, est: ~30m)
  - acceptance: R-5.1 — produce a ranked, tagged cut-list artifact for uncle-dev's own surface.
  - verify: artifact saved (e.g. `.devlocal/<user>/audit/uncle-dev-self-audit.md`) with ranked tagged findings + `net:` line.

- [ ] 5.2 Scope deletions out (deps: 5.1, est: ~5m)
  - acceptance: R-5.2 — cut-list is the deliverable; acting on deletions is out of scope.
  - verify: artifact states deletions are deferred to a separate change; no deletions made in this change.

---

## Phase 3 — Developer conventions & reach

### Unit 6: `@debt` marker + harvest command

- [ ] 6.1 Define `@debt` grammar with mandatory ceiling+upgrade (est: ~25m)
  - acceptance: R-6.1 — `// @debt <ceiling>, <upgrade>` convention, both fields mandatory, distinct from `@spec`/`[D]`.
  - verify: convention documented in `uncle-dev-spec-annotations`; grammar rejects a marker missing ceiling or upgrade.

- [ ] 6.2 `/uncle-dev-debt` harvest into ledger (deps: 6.1, est: ~35m)
  - acceptance: R-6.2 — command lists every marker with location, ceiling, upgrade path.
  - verify: seeded `@debt` markers appear in the ledger with all three fields (machinery modeled on `scan-spec-coherence.py`).

- [ ] 6.3 Flag untriggered markers as rot risk (deps: 6.2, est: ~15m)
  - acceptance: R-6.3 — markers lacking a trigger/upgrade path flagged and sorted to top.
  - verify: a non-conforming marker is reported as silent-rot risk above conforming ones.

- [ ] 6.4 Frame as conscious debt, not TODO dump (deps: 6.1, est: ~10m)
  - acceptance: R-6.4 — skill text scopes `@debt` to deliberately-kept shortcuts.
  - verify: skill includes the one-line distinction from `[D]`/TODO and a Red Flag against deferral use.

### Unit 7: Session-switchable strictness + statusline (Claude-only)

- [ ] 7.1 `/uncle-dev-mode` hook writes session flag (deps: 2.1, est: ~30m)
  - acceptance: R-7.1 — `/uncle-dev-mode <strict|balanced|fast>` writes a session flag recording the profile.
  - verify: invoking the command writes the expected flag file with the chosen profile.

- [ ] 7.2 Guards consult flag via config tier (deps: 7.1, est: ~30m)
  - acceptance: R-7.2 — `spec-coherence-guard.sh` + `pre-commit-guard.sh` read the flag (through config override tier) instead of YAML `execution_profile`.
  - verify: with flag=fast, guards behave as fast even though YAML says strict.

- [ ] 7.3 No YAML mutation on mode change (deps: 7.1, est: ~5m)
  - acceptance: R-7.3 — `.agents/uncle-dev-setup.yaml` unchanged on session mode switch.
  - verify: git diff of the YAML is empty after `/uncle-dev-mode`.

- [ ] 7.4 Optional statusline badge (deps: 7.1, est: ~20m)
  - acceptance: R-7.4 — where a statusline is configured, show active mode badge (e.g. `[UNCLE-DEV:STRICT]`).
  - verify: configured statusline renders the badge matching the active flag.

- [ ] 7.5 Claude-only install gating (deps: 7.1, est: ~10m)
  - acceptance: R-7.5 — non-Claude hosts get no mode hook or statusline.
  - verify: `install-codex.sh`/`install-opencode.sh` do not install the hook/statusline.

### Unit 8: Full-coverage instruction adapters

- [ ] 8.1 AGENTS.md-derived always-on rule + on-demand copies (est: ~30m)
  - acceptance: R-8.1 — instruction-only host install writes an always-on rule from canonical `AGENTS.md` plus on-demand skill copies.
  - verify: install for an instruction host produces the AGENTS.md-derived rule file.

- [ ] 8.2 Add copilot/clinerules/kiro/pi targets (deps: 8.1, est: ~40m)
  - acceptance: R-8.2 — generate `copilot-instructions.md`, `.clinerules/`, `.kiro/steering/`, pi adapters alongside existing Cursor/Windsurf/Copilot copies.
  - verify: install emits each adapter at its host-correct path.

- [ ] 8.3 Register adapters with drift guard (deps: 8.2, 1.2, est: ~20m)
  - acceptance: R-8.3 — generated adapters covered by `check-manifest.sh`; divergence fails the suite.
  - verify: hand-editing a generated adapter makes the guard fail.

---

## Phase 4 — Evidence

### Unit 9: Benchmark harness

- [ ] 9.1 Scaffold `benchmarks/` no-skill vs uncle-dev harness (est: ~50m)
  - acceptance: R-9.1 — promptfoo harness comparing no-skill vs uncle-dev arms on a representative task set.
  - verify: `benchmarks/` runs and produces per-arm results; promptfoo + model IDs pinned.

- [ ] 9.2 Representative task set (deps: 9.1, est: ~40m)
  - acceptance: R-9.2 — ≥1 task each for spec-first feature, refactor, review catch-rate (e.g. injected `@spec` orphans / planted bugs).
  - verify: task set includes all three categories; the review task is validated to detect a known planted bug.

- [ ] 9.3 Reproducible comparison table (deps: 9.2, est: ~20m)
  - acceptance: R-9.3 — harness emits a reproducible comparison table across arms × tasks.
  - verify: two runs with pinned versions emit the same table structure/values.

---

## Coordination notes

- **Phase gates:** do not open Phase N+1 stories until Phase N is merged and `check-manifest.sh` is green.
- **Cross-phase deps:** 5.x → 4.x (audit before self-audit); 7.1 → 2.1 (session flag rides the env tier); 8.3 → 1.2 (adapters drift-guarded).
- **Mutex:** 1.7 reconciles the same files (`marketplace.json`, README, `plugins/uncle-dev/commands/`) that 1.2/1.3/1.4 assert — sequence 1.7 after them, do not run concurrently `(mutex: manifest-copies)`.
- **AGENTS.md:** directories touched (`scripts/`, `scripts/lib/`, `skills/<new>`, `hooks/`, `benchmarks/`) have none today; create the directory's `AGENTS.md` as the first sub-step of the first story that edits it (project code-context rule).
- Private technical breakdown per story → `.devlocal/<user>/<story-id>/scratchpad.md`.
