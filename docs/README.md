# docs/ — Documentation Tree

## Canonical structure

The `docs/originals/` directory is the **canonical** documentation tree. It contains the
authoritative setup guides, skill anatomy reference, and supporting material that ships with
the plugin. Use files from this directory when authoring new skills or pointing users to
setup guides.

`docs/improved/` and `docs/v2/` are **draft / experimental** trees produced during a
documentation restructuring effort. They are not yet canonical and may contain stale or
speculative content. Do not reference these directories from skills, commands, or README
until a formal migration decision is made. They are retained for comparison purposes only.

## Directory map

| Directory | Status | Contents |
|-----------|--------|----------|
| `docs/originals/` | **Canonical** | Setup guides (cursor, windsurf, copilot, opencode, gemini), skill anatomy reference, lint setup, getting-started |
| `docs/hld/` | Active | High-level design documents for uncle-dev itself |
| `docs/lld/` | Active | Low-level design documents for uncle-dev itself |
| `docs/ears/` | Active | EARS behavioral requirements for uncle-dev itself |
| `docs/audit/` | Active | Audit findings (01–10) driving the remediation work |
| `docs/tasks/` | Active | Task files for lid-ears track |
| `docs/reference/` | Active | Shared reference material |
| `docs/drafts/` | Draft | Work-in-progress documents (not yet reviewed) |
| `docs/improved/` | Draft | Experimental restructuring of originals — not canonical |
| `docs/v2/` | Draft | Second experimental restructuring — not canonical |
