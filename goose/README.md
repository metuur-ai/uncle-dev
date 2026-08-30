# uncle-dev for Goose

Goose-specific packaging for the uncle-dev plugin. Everything in this directory
is Goose-only — the Claude Code manifest stays at `.claude-plugin/plugin.json`.

## What Goose supports

A Goose plugin provides **skills and hooks, and nothing else**:

```
uncle-dev/
├── plugin.json            ← name / version / description, at plugin root
├── skills/<name>/SKILL.md
└── hooks/hooks.json       ← optional
```

Plugins live in `~/.agents/plugins/<name>/` (user) or
`<project>/.agents/plugins/<name>/` (project).

## What ships today

| Asset | Status |
|---|---|
| 47 skills | ✅ Installed. Goose's `SKILL.md` contract (`name` + `description` frontmatter, colocated resource files) is identical to Claude Code's — the skill tree is copied verbatim. |
| `plugin.json` | ✅ Generated at plugin root, version synced from `.claude-plugin/plugin.json`. |
| 9 agent personas | ✅ Installed as Goose recipes, generated from `agents/`. |
| 31 slash commands | ✅ Installed as Goose recipes, generated from `commands/`. |
| 13 hooks | ❌ Not installed — see below. |

Skills are invoked the same way they are under OpenCode — by description
matching ("use the uncle-dev-spec skill…") or `/skills <name>`. Goose namespaces
plugin skills, so they appear as `uncle-dev:uncle-dev-spec`.

## Agents and commands as recipes

Goose has no plugin-level format for subagents *or* slash commands — both are
recipes, and recipes are **not** discovered inside plugin directories. So they
install alongside the plugin rather than inside it:

- user scope → `~/.config/goose/recipes/`
- project scope → `<workspace>/.goose/recipes/`

Recipe YAML is a **runtime artefact and is never checked in**. `agents/*.md` is
the only source of truth; `install-goose.sh` regenerates the YAML into a temp
directory on every run and installs from there, so a stale copy cannot exist.

To refresh recipes in an existing Goose install without a full reinstall:

```bash
bash scripts/gen-goose-recipes.sh \
  --out ~/.config/goose/recipes \
  --plugin-root ~/.agents/plugins/uncle-dev
```

`--out` is required and refuses any path inside this repository.

**Naming.** `agents/uncle-senior.md` and `commands/uncle-senior.md` both exist,
so the two kinds are namespaced apart:

| Source | Recipe file | Invocation |
|---|---|---|
| `commands/uncle-dev-spec.md` | `uncle-dev-spec.yaml` | `goose run --recipe uncle-dev-spec` |
| `agents/uncle-senior.md` | `uncle-dev-agent-uncle-senior.yaml` | `goose run --recipe uncle-dev-agent-uncle-senior` |

Command recipes keep their stem so the recipe name mirrors the Claude slash
command: `/uncle-dev-spec` → `--recipe uncle-dev-spec`.

**Field mapping:**

| Source | recipe field |
|---|---|
| agent frontmatter `name` / command filename stem | `title` |
| frontmatter `description` | `description` |
| markdown body | `instructions` |
| command frontmatter `argument-hint` | `arguments` parameter description |
| — | agents: `prompt: "{{ task }}"` + a `task` parameter (`user_prompt`) |
| — | commands: a kickoff `prompt` + an `arguments` parameter (`optional`, default `""`) |

**Body transforms.** Command bodies are not portable as-is; three rewrites are
applied to the generated YAML only, never to the source:

1. **Jinja escaping.** `commands/uncle-dev-design-docs.md` documents literal
   `{{segment}}` / `{{SEGMENT}}` placeholders. Goose renders `instructions`
   through Jinja, which would eat them. They are escaped so they render back
   byte-identically.
2. **`$ARGUMENTS` → `{{ arguments }}`.** Four commands take arguments; the
   Claude placeholder becomes the recipe parameter.
3. **`${CLAUDE_PLUGIN_ROOT}` gets a default.** 57 references across the command
   set resolve the skill loader and bundled Python helpers through a variable
   Goose never sets, with a `~/.claude/plugins/cache/...` fallback that does not
   exist for a Goose-only user. Both forms are rewritten to
   `${CLAUDE_PLUGIN_ROOT:-<installed plugin root>}`, so the fallback never
   fires. This is why `install-goose.sh` also stages `scripts/` into the plugin
   directory — the loader has to exist at that path.

**Usage:**

```bash
goose recipe list
goose run --recipe uncle-dev-spec --params arguments="add rate limiting"
goose run --recipe uncle-dev-agent-uncle-senior --params task="is this over-engineered?"
```

**Two things do not survive the conversion.** Agent frontmatter `model:`
(`opus`, `sonnet`) has no portable equivalent — Goose model ids are
provider-scoped, so guessing a mapping would silently pin the wrong model.
Frontmatter `tools:` (`uncle-senior` restricts to Read/Grep/Glob/WebSearch)
would need per-extension `available_tools` wiring. Both are emitted as comments
at the top of each recipe so the intent is recorded rather than lost.
`uncle-senior` therefore runs with the session's full toolset under Goose, not
its Claude read-only allowlist.

**Not done:** registering these as real `/slash` commands. That means adding
`slash_commands:` entries to `~/.config/goose/config.yaml`, which mutates your
global Goose config and caps each command at one parameter.

## Why hooks are not installed

Goose supports the events uncle-dev needs (`SessionStart`, `UserPromptSubmit`,
`PreToolUse`, `PostToolUse`, `Stop`), and blocking is wire-compatible — exit 2 +
stderr means the same thing in both hosts. Three things still differ:

1. **Advisory output collides with Goose's decision channel.** Every uncle-dev
   advisory goes to stdout as `{"hookSpecificOutput":{"additionalContext":…}}`
   (`hooks/lib/hook-contract.sh`). Goose reads stdout as the allow/block
   decision and requires it empty for a clean allow — our advisories would be
   parsed as malformed decisions.
2. **Matchers name different tools.** `Edit|Write` and `Bash` do not exist in
   Goose; the equivalents are `developer__text_editor` and `developer__shell`.
3. **Payload paths differ.** `tool_input.file_path` is `tool_input.path` under
   `developer__text_editor`.

Porting these means a `UNCLE_DEV_HOST=goose` branch in `hook-contract.sh` plus a
Goose-flavored `hooks.json`. Until that lands, shipping the Claude `hooks.json`
would inject malformed JSON into Goose's decision parser on every tool call, so
the installer leaves hooks out.

`Notification` has no Goose equivalent, so `permission-notify.sh` has no home
regardless. The other 12 hooks are portable.

## Project rules

Goose reads `AGENTS.md` and `.goosehints` from the project root (configurable
via `CONTEXT_FILE_NAMES`). This repo's root `AGENTS.md` is a stub pointer to
`CLAUDE.md`, so Goose picks up almost nothing by default. Either point Goose at
`CLAUDE.md`:

```bash
export CONTEXT_FILE_NAMES='["AGENTS.md","CLAUDE.md",".goosehints"]'
```

or run `scripts/install-goose.sh --rules <project-dir>` to copy the rules files
into the target project root.

## Install

```bash
# user scope — ~/.agents/plugins/uncle-dev/ + ~/.config/goose/recipes/
bash scripts/install-goose.sh

# project scope — <workspace>/.agents/plugins/uncle-dev/ + <workspace>/.goose/recipes/
bash scripts/install-goose.sh --scope project ~/code/my-app

# skills only, no persona recipes
bash scripts/install-goose.sh --no-recipes

# also drop AGENTS.md / AGENT_RULES.md / CLAUDE.md into a project root
bash scripts/install-goose.sh --rules ~/code/my-app

# let the Goose CLI clone and manage it instead (git URL only)
bash scripts/install-goose.sh --from-git --auto-update
```

`goose plugin install` accepts **git URLs only** — there is no local-path
install — so the default mode stages the plugin and copies it into the same
directory the CLI would have used. Re-running requires `--force`.

## Verify

```bash
goose skills list | grep uncle-dev
goose recipe list
```
