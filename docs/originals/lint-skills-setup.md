# How to Set Up SKILL.md Linting (nori-lint)

Set up and run `scripts/lint-skills.sh`, the wrapper around [nori-lint](https://github.com/tilework-tech/nori-lint) that checks every `skills/*/SKILL.md` against the agentskills.io specification. After this guide you can lint skills locally, get advisory reports on commit, and see lint results in CI.

## Prerequisites

- Node.js 18+ with `npx` on your PATH (nori-lint is fetched on demand; nothing is added to the repo)
- `jq` installed (`brew install jq`)
- For LLM-based rules only: an Anthropic API key exported as `ANTHROPIC_API_KEY`

## Setup

The integration is already wired into the repo. A fresh clone needs no installation — verify it works:

```bash
bash scripts/lint-skills.sh skills/uncle-dev-wrap
```

You should see a list of violations (or none) followed by a summary line:

```
lint-skills: N violation(s) in 1 of 1 skill(s)
lint-skills: static rules only (use --deep with ANTHROPIC_API_KEY for LLM rules)
```

If the script prints `npx not found` or `jq not found`, install the missing prerequisite and re-run.

## Usage

### 1. Lint all skills (report-only)

```bash
bash scripts/lint-skills.sh
```

Prints every violation as `path:line [rule] message` and always exits 0. This is the default mode everywhere until the baseline (977 violations as of 2026-06-11) is triaged.

### 2. Lint specific skills

```bash
bash scripts/lint-skills.sh skills/uncle-dev-research skills/uncle-dev-wrap
```

Accepts skill directories or direct paths to `SKILL.md` files.

### 3. Gate on violations

```bash
bash scripts/lint-skills.sh --enforce skills/my-new-skill
```

Exits 1 if any violations are found. Use this for new skills, which should start clean even while existing skills are grandfathered.

### 4. Run LLM-based rules

```bash
export ANTHROPIC_API_KEY=sk-ant-...
bash scripts/lint-skills.sh --deep skills/my-new-skill
```

Adds semantic checks (obvious instructions, redundant explanations, duplicate sections). The key is merged into a temporary config file and never written to a tracked file. Each run costs API tokens, so prefer running on individual skills.

### 5. Auto-fix violations

```bash
bash scripts/lint-skills.sh --fix --dry-run skills/my-skill   # preview
bash scripts/lint-skills.sh --fix skills/my-skill             # apply in place
```

> **Warning:** `--fix` applies nori-lint's opinions wholesale — it strips all `**bold**`/`*italics*` and deletes "When to Use" sections, which this repo's skill-anatomy format requires. Without `--deep`, the disabled-rules list is not honored by `fix`. Always run on a clean git tree, preview with `--dry-run`, and review the diff before committing.

## Configuration

Rule configuration lives in `scripts/nori-lint.config.json`:

```json
{
  "rules": {
    "disabled": []
  }
}
```

Add rule names to `disabled` to suppress them (run `npx --yes nori-lint list` for all rules). In static mode the wrapper filters disabled rules from the output itself; in `--deep` mode the config is passed to nori-lint directly.

Two constraints to know:

- Do **not** create a `.nori-lint.json` at the repo root without an `anthropic_api_key` field — nori-lint auto-discovers it and hard-errors on any config missing a key, which breaks even static runs. The root filename is gitignored so a local key file can never be committed.
- The wrapper runs nori-lint once per skill directory because large single runs lose JSON output past 64KB on process exit.

## Where it runs automatically

| Trigger | What happens | Blocking? |
|---|---|---|
| `git commit` with staged `skills/**/SKILL.md` | `hooks/pre-commit-guard.sh` emits an advisory report | No (INFO only) |
| PR / push to `main` touching `skills/**` | `.github/workflows/lint-skills.yml` writes the report to the job summary | No |
| `bash scripts/tests/run-all.sh` | Lint summary printed after the install test suites | No |

The pre-commit advisory is opt-in by design: it only fires when `scripts/nori-lint.config.json` exists in the working repo, so end-user projects that install the uncle-dev plugin never trigger it.

## Verify it worked

Create a deliberately bad skill and confirm the linter catches it:

```bash
mkdir -p /tmp/lint-check/skills/demo
printf -- '---\nname: demo\ndescription: Demo.\n---\nbad line   \n' > /tmp/lint-check/skills/demo/SKILL.md
bash scripts/lint-skills.sh --enforce /tmp/lint-check/skills/demo; echo "exit=$?"
rm -rf /tmp/lint-check
```

Expected: a `trailing_whitespace` violation (among others) and `exit=1`.

## Troubleshooting

- **`error: Config missing required field: anthropic_api_key`** — a `.nori-lint.json` exists in the current directory without a key. Delete it or add your key; the committed config belongs in `scripts/nori-lint.config.json`.
- **`lint-skills: unparseable output for <dir>`** — nori-lint crashed on that file (often malformed frontmatter). Run `npx --yes nori-lint lint <dir>` directly to see the raw error.
- **`--deep` exits with "requires ANTHROPIC_API_KEY"** — export the key in your shell first; it is read from the environment, never from a tracked file.
- **Hook prints nothing on commit** — it only fires when SKILL.md files are staged and the rule config exists at the repo root; it is also skipped entirely if earlier pre-commit checks block the commit.

## Next steps

- Triage the baseline: decide which convention-conflicting rules (`bold_italics`, `when_to_use`, `redundant_title`, `description_action`, `required_tags`, `line_count`) to add to `rules.disabled`
- After triage, flip CI and the test suite to `--enforce` to gate merges
- Skill format conventions: `docs/originals/skill-anatomy.md`
