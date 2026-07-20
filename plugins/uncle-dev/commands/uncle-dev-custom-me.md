---
description: Scaffold a user-authored override or companion skill and print the YAML block to register it in .agents/uncle-dev-setup.yaml
argument-hint: "override <base-skill> <new-name> | companion <base-skill> <new-name>"
---

## Working Principles

1. **Think Before Coding** — Confirm the user wants override (full replacement) or companion (delta only). They are different patterns with different file shapes.
2. **Simplicity First** — Print the YAML block; do not silently mutate `.agents/uncle-dev-setup.yaml`. The user keeps control of their config.
3. **Surgical Changes** — Touch only `.agents/skills/<new-name>/`. Do not edit existing files except to scaffold the new SKILL.md.
4. **Goal-Driven Execution** — Done means the new SKILL.md exists, the YAML block is printed, the user has pasted it, `--validate` exits 0, and the loader prints the expected line.

---

## Step 0 — Parse arguments and resolve helpers

Expected usage:

```
/uncle-dev-custom-me override <base-skill> <new-name>
/uncle-dev-custom-me companion <base-skill> <new-name>
```

If the user provided fewer than 3 arguments, ask one blocking question to collect the missing pieces. Do not proceed until you have a mode (`override` or `companion`), a `<base-skill>` (e.g., `uncle-dev-test-driven-development`), and a `<new-name>` (a short slug for the new directory).

```bash
_cfg="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-config.sh"
[[ ! -f "$_cfg" ]] && _cfg=$(find "${HOME}/.claude/plugins" -name "uncle-dev-config.sh" 2>/dev/null | head -1)

_loader="${CLAUDE_PLUGIN_ROOT:-}/scripts/uncle-dev-load-skill.sh"
[[ ! -f "$_loader" ]] && _loader=$(find "${HOME}/.claude/plugins" -name "uncle-dev-load-skill.sh" 2>/dev/null | head -1)

# Locate the bundled templates and base-skill catalog
_plugin_root="${CLAUDE_PLUGIN_ROOT:-}"
if [[ -z "$_plugin_root" ]]; then
  _plugin_root=$(find "${HOME}/.claude/plugins" -type d -name "uncle-dev-agent-skills" 2>/dev/null | head -1)
fi
echo "PLUGIN_ROOT: $_plugin_root"
```

---

## Step 1 — Resolve the active uncle-dev-custom-me skill (honor overrides/companions)

```bash
bash "$_loader" uncle-dev-custom-me
```

Honor the `SKILL:` and `COMPANION:` lines emitted above per the skill-loading directive in your project CLAUDE.md.

---

## Step 2 — Validate `<base-skill>` exists

The base skill must be a real uncle-dev skill (or already-registered local skill). Check:

```bash
BASE="<base-skill>"   # substitute from arguments
if [[ -d "${_plugin_root}/skills/${BASE}" ]]; then
  echo "base: bundled (${_plugin_root}/skills/${BASE})"
elif [[ -d ".agents/skills/${BASE}" ]]; then
  echo "base: local (.agents/skills/${BASE})"
else
  echo "ERROR: base skill '${BASE}' not found in plugin or .agents/skills/" >&2
  echo "Consult the uncle-dev-using-agent-skills skill to list available skills." >&2
  exit 1
fi
```

If not found, stop and tell the user the base skill doesn't exist. Do not scaffold.

---

## Step 3 — Scaffold the new SKILL.md from the matching template

```bash
NEW="<new-name>"      # substitute from arguments
MODE="<override|companion>"  # substitute from arguments

mkdir -p ".agents/skills/${NEW}"

if [[ "$MODE" == "override" ]]; then
  TEMPLATE="${_plugin_root}/skills/uncle-dev-custom-me/templates/override-skill.md"
else
  TEMPLATE="${_plugin_root}/skills/uncle-dev-custom-me/templates/companion-skill.md"
fi

if [[ ! -f "$TEMPLATE" ]]; then
  echo "ERROR: template not found at $TEMPLATE" >&2
  exit 1
fi

# Substitute placeholders. Use a safe delimiter for sed (#) since base skill names contain dashes only.
sed -e "s#<BASE_SKILL>#${BASE}#g" -e "s#<NEW_SKILL_NAME>#${NEW}#g" "$TEMPLATE" > ".agents/skills/${NEW}/SKILL.md"

[[ -f ".agents/skills/${NEW}/SKILL.md" ]] || { echo "ERROR: scaffold failed" >&2; exit 1; }
echo "scaffolded: .agents/skills/${NEW}/SKILL.md"
```

---

## Step 4 — Print the YAML registration block (do NOT auto-edit the YAML)

For `override` mode, print:

```
PASTE THIS BLOCK INTO .agents/uncle-dev-setup.yaml UNDER `skills:`

skills:
  overrides:
    <base-skill>:
      path: .agents/skills/<new-name>/SKILL.md
      name: <new-name>
```

For `companion` mode, print:

```
PASTE THIS BLOCK INTO .agents/uncle-dev-setup.yaml UNDER `skills:`

skills:
  companions:
    <base-skill>:
      - path: .agents/skills/<new-name>/SKILL.md
        name: <new-name>
```

Substitute `<base-skill>` and `<new-name>` from the arguments. Print the block verbatim; the user pastes it. **Do not mutate `.agents/uncle-dev-setup.yaml` directly** — the user controls their config and a wrong indent breaks the schema.

---

## Step 5 — Run the validation loop

Print these steps and ask the user to confirm each one before declaring done:

1. Open `.agents/uncle-dev-setup.yaml` and paste the YAML block from Step 4.
   - If `skills.overrides:` or `skills.companions:` already has entries, **merge under the existing key** — do not duplicate the top-level key.
2. Run schema validation:
   ```bash
   bash scripts/uncle-dev-config.sh --validate
   ```
   Expected: exit 0, prints `valid`. If it fails, fix the indent/key path and re-run.
3. Run the loader to confirm registration:
   ```bash
   bash scripts/uncle-dev-load-skill.sh <base-skill>
   ```
   Expected:
   - Override mode: `SKILL: .agents/skills/<new-name>/SKILL.md` on stdout.
   - Companion mode: `SKILL: uncle-dev:<base-skill>` (or the existing override) followed by `COMPANION: .agents/skills/<new-name>/SKILL.md`.
   - No `WARN: missing skill file` on stderr.
4. Edit `.agents/skills/<new-name>/SKILL.md` and replace every `<TODO ...>` placeholder. Follow `docs/originals/skill-anatomy.md` strictly.
5. (Companion mode only) Confirm anti-duplication:
   ```bash
   grep -E "^## (Overview|When to Use|Process|Common Rationalizations|Red Flags|Verification)" .agents/skills/<new-name>/SKILL.md
   ```
   Expected: empty output. Any hit is a red flag — the base skill already provides those sections.

If any step fails, fix the underlying issue and re-run from that step. Do not declare success until step 3's loader output matches expectation.

---

## Step 6 — Report

When all steps pass, report:

- Path to the new SKILL.md.
- Registration mode (override / companion) and the base skill it targets.
- The loader's stdout output (proof the customization loads).
- One next step: "Edit `.agents/skills/<new-name>/SKILL.md` to fill in the body."

Do not commit or push anything. The user decides when to share the customization.
