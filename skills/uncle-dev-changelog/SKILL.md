---
name: uncle-dev-changelog
description: Generates a user-facing changelog from git history — translating technical commits into feature/improvement/fix entries grouped by product surface, in Keep a Changelog format. Use when the user says "update the changelog", "write release notes", "what changed in this release", "changelog for vX.Y", or before tagging and shipping a version (pairs with /uncle-dev-ship).
---

# Changelog Generation

## Overview

Turn git history into a changelog a **user** understands — someone using the product, not an engineer reading diffs. Every entry answers "what changed for me?" Code-level churn (refactors, test fixes, CI tweaks, version bumps) is dropped.

This is **assisted**: scan → draft → the user reviews/trims → write. Never write the file without a review pause unless explicitly told to.

The core move is translating the **mechanism** (commit) into the **outcome** (changelog line):

| Commit (code-focused) | Changelog entry (user-focused) |
|---|---|
| `fix(cli): timezone-aware datetimes across scanners` | Reminders now fire at the correct local time across timezones |
| `feat(web): add Guide page with how-to docs` | New in-app Guide explaining how to get started |
| `fix(auth): redact tokens from URL log lines` | Hardened: tokens are no longer written to logs |
| `chore: refresh knowledge graph` | *(dropped — no user impact)* |

If you can't state why a user would care, the line doesn't belong.

## When to Use

**Use when:**
- The user says "update the changelog", "write release notes", "what changed in this release", or "draft the changelog for v0.x"
- A release is about to be tagged or shipped (`/uncle-dev-ship` pre-launch flow)
- A `CHANGELOG.md` exists and trails the released versions

**NOT for:**
- Commit messages or PR descriptions — see `uncle-dev-git-workflow-and-versioning`
- Internal engineering notes or ADRs — see `uncle-dev-documentation-and-adrs`
- Marketing copy or launch announcements — this produces factual release notes; for announcement prose, see `uncle-dev-speech`

## Core Process

### Step 1: Determine the range and target version

- Last released version: `git tag --sort=-creatordate | head -1`; fall back to the last `## [x.y.z]` header in `CHANGELOG.md`.
- Target version: read the project's version source (`package.json`, `pyproject.toml`, `Cargo.toml`, `VERSION`, or plugin manifest). Confirm with the user if ambiguous.
- Collect commits: `git log <last-tag>..HEAD --pretty="%s%n%b%n---"`.

### Step 2: Build the scope → surface map

Surfaces are the product areas a user recognizes (CLI, desktop app, web UI, API, docs site...). Derive them per project:

1. List the scopes in range: `git log <last-tag>..HEAD --pretty="%s" | grep -oE '^[a-z]+\([a-z-]+\)' | sort | uniq -c`
2. Map each scope to the surface where the **user notices the change**, not where the code lives (a backend fix that changes web behavior → web surface).
3. Single-surface projects skip surface grouping and use impact buckets directly.

Record the map in the draft so the user can correct it. See `references/voice.md` for a worked example.

### Step 3: Filter noise

Drop entirely: `chore:`, `test:`, `ci:`, `build:` (unless it changes what users install), refactors, dependency/version bumps, internal doc back-fills, and fixes whose user-visible effect is nil. Full drop list in `references/voice.md`.

### Step 4: Draft — group by surface, then by impact

Within each surface, bucket by Keep a Changelog impact: `Added` / `Changed` / `Fixed` / `Security` / `Removed`. Translate every surviving line from mechanism to outcome, stripping engineering residue (scope prefixes, PR numbers, author handles, commit hashes, audit IDs). Tone rules and few-shot examples: `references/voice.md`, `references/highlights-examples.md`.

3–8 lines per version is healthy. If a surface has nothing user-facing, omit it — don't pad.

### Step 5: Review pause

Show the draft to the user. Wait for trims, corrections to the surface map, and approval before touching the file.

### Step 6: Write

- Write to the root `CHANGELOG.md` in Keep a Changelog format, newest version on top, under `## [Unreleased]` if not yet tagged.
- Match the existing file's heading style. Keep the `[Unreleased]` section at the top for the next cycle.
- Show the diff before committing.

## Output Format

```markdown
## [0.7.26] — 2026-06-11

### Desktop app
- Menu-bar notifications are more reliable
- **Security:** runtime tokens are no longer written to logs

### CLI
- Reminders fire at the correct local time across timezones
- Vault paths with spaces now install correctly
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Just list the commits, it's faster" | A commit list is a build artifact, not a changelog. Users can't act on `fix(core): null guard in resolver`. |
| "Every commit deserves a line" | Padding buries the changes users care about. A two-change release gets two lines. |
| "I'll write the file directly, review slows things down" | The user knows which changes matter to their audience; the draft pause is where wrong surfaces and leaked internals get caught. |
| "The refactor was a lot of work, it should be mentioned" | Effort is not user impact. If behavior didn't change, the line doesn't belong. |
| "Audit IDs / PR numbers add traceability" | They add noise. Traceability lives in git history; the changelog is for users. |

## Red Flags

- Changelog entries that read like commit subjects (scope prefixes, mechanism nouns)
- PR numbers, commit hashes, author handles, or audit IDs in entries
- A version section with 20+ lines — the noise filter wasn't applied
- Writing `CHANGELOG.md` without showing the draft first
- Surfaces organized by repo directory layout instead of what the user sees
- An empty `Security` bucket while security fixes hide under `Fixed`

## Verification

- [ ] Every line states a user-visible outcome (the "so what" test passes)
- [ ] No scope prefixes, PR numbers, hashes, handles, or audit IDs remain
- [ ] Version and date match the tag / version source
- [ ] Format matches the existing `CHANGELOG.md` style and Keep a Changelog ordering
- [ ] The user reviewed the draft before the file was written

## See Also

- `references/voice.md` — drop list, scope→surface mapping, tone rules
- `references/highlights-examples.md` — few-shot examples of good and bad entries
- `uncle-dev-git-workflow-and-versioning` — commit hygiene and release tagging that feed this skill
- `uncle-dev-shipping-and-launch` — the ship flow this slots into
