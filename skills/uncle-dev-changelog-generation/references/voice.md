# Changelog voice & mapping

## Scope → surface map

Conventional commits are scoped `type(scope):`. Map each scope to the surface the **user notices the change in**, not where the code lives. Build this table per project in Step 2 and show it in the draft.

Worked example (a project with a CLI, desktop app, and web UI):

| Scope(s) | Surface |
|---|---|
| `cli`, `installer`, `build-pkg` | CLI |
| `desktop`, `tray`, `reminder-daemon` | Desktop app |
| `web-ui`, `backend`, `guide` | Web UI |
| `onboarding`, *(unscoped product feat)* | General |

A backend fix that makes the web UI behave correctly belongs under Web UI. Single-surface projects (a library, one app) skip surfaces and group by impact only.

## Drop list (never appears in the changelog)

These are mechanism-only; they have no user-facing outcome:

- `chore:` anything (version bumps, dep bumps with no behavior change)
- `test:` / test-only changes
- `ci:` / `build:` — **unless** it changes what the user installs or runs
- `refactor:` and "improve readability/structure" commits
- Generated-artifact commits (knowledge-graph refreshes, lockfile-only changes)
- "update version to x", "bump to x", VERSION/manifest bumps
- Internal doc back-fills (`docs(spec)`, architecture notes)
- Audit-ID-only fixes where the user-visible effect is nil

## Strip from surviving lines

Even on commits that DO make the cut, remove the engineering residue:

- Audit IDs: `(M6, M7)`, `(H2)` → delete
- PR numbers `(#1234)`, author `@handles`, commit hashes
- Scope prefixes (`fix(cli):`) — the surface section already conveys this
- Internal mechanism nouns ("rglob/path join", "fsync helper", "LIMIT param") → translate to the effect, or drop if there is none

## Tone rules

- **Benefit-first.** Lead with what the user can now do / what now works.
- **One sentence per line.** No trailing rationale paragraphs.
- **Present tense, plain words.** "Reminders fire on time" not "Fixed an issue where reminders would fire at the incorrect time due to naive datetimes."
- **Security framing:** prefix with `**Security:**` and state the hardening in user terms ("tokens no longer written to logs"), never the CVE/audit ID.
- **Don't pad.** A version with two real changes gets two lines.
- Scannable: bold lead-ins for standout items, no walls of text.
