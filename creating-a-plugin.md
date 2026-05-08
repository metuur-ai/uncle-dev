# Creating a Hermes Agent Plugin

Plugins extend Hermes Agent with new capabilities: memory providers, skill packs, tool integrations, or any combination. Each plugin lives in `plugins/<name>/` and is auto-discovered at startup.

---

## Plugin Anatomy

```
plugins/
└── my-plugin/
    ├── plugin.yaml      # Required — metadata, dependencies, hooks
    ├── __init__.py      # Required — can be empty; marks it as a Python package
    └── README.md        # Recommended — setup instructions, config reference
```

That's the minimum. Add Python modules, sub-packages, or data files as needed.

---

## `plugin.yaml` Reference

```yaml
name: my-plugin
version: 1.0.0
description: "One-line description of what this plugin does."

# Optional: pip packages to auto-install on first use
pip_dependencies:
  - some-package>=1.2.0
  - another-package

# Optional: environment variables the plugin needs (informational)
requires_env:
  - MY_PLUGIN_API_KEY

# Optional: lifecycle hooks the plugin registers
hooks:
  - on_session_end   # called when a conversation session ends
```

**Fields:**

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique identifier, matches the directory name |
| `version` | Yes | Semantic version string |
| `description` | Yes | Short description shown in `hermes plugins` |
| `pip_dependencies` | No | Packages installed automatically via `uv` |
| `requires_env` | No | Env vars the user must provide |
| `hooks` | No | Lifecycle hooks to register |

---

## Skill Pack Plugin

The most common plugin type — a set of skills bundled for a specific domain.

### 1. Create the plugin wrapper

```bash
mkdir -p plugins/my-skill-pack
touch plugins/my-skill-pack/__init__.py
```

```yaml
# plugins/my-skill-pack/plugin.yaml
name: my-skill-pack
version: 1.0.0
description: "Domain-specific skills for [purpose]."
```

### 2. Add skill files

Skills live in `skills/<category>/<skill-name>/SKILL.md` — separate from the plugin directory. Hermes discovers them by scanning the `skills/` tree.

```
skills/
└── software-development/
    └── my-skill/
        └── SKILL.md
```

### 3. SKILL.md frontmatter

```yaml
---
name: my-skill
description: >
  Use when [specific trigger condition]. Does [what it accomplishes].
version: 1.0.0
author: Your Name
license: MIT
metadata:
  hermes:
    tags: [tag-one, tag-two, relevant-domain]
    related_skills: [other-skill, another-skill]
---
```

### 4. SKILL.md body structure

```markdown
# Skill Title

## Overview
One or two sentences. What it does and the core principle behind it.

## When to Use
- Specific triggering conditions
- **Not** for: exclusions that prevent misuse

## The Process
Step-by-step workflow. Use numbered lists, code blocks, and ASCII
diagrams for decision points.

## Common Rationalizations
| Excuse | Why It's Wrong |
|--------|----------------|
| "I'll skip just this once" | That's rationalization. |

## Red Flags
Behavioral signals that mean stop and restart correctly.

## Verification Checklist
- [ ] Exit criterion one
- [ ] Exit criterion two

## Hermes Agent Integration
How to invoke this skill from the agent loop, with code examples.
```

See [skills/software-development/test-driven-development/SKILL.md](../../skills/software-development/test-driven-development/SKILL.md) for a complete reference example.

---

## Memory Provider Plugin

Memory plugins hook into the conversation lifecycle to store and retrieve context across sessions.

### Directory layout

```
plugins/
└── my-memory/
    ├── plugin.yaml
    ├── __init__.py
    ├── provider.py      # Memory provider implementation
    └── README.md
```

### `plugin.yaml` for memory plugins

```yaml
name: my-memory
version: 1.0.0
description: "Long-term memory via [backend]."
pip_dependencies:
  - my-memory-client>=1.0.0
requires_env:
  - MY_MEMORY_API_KEY
hooks:
  - on_session_end
```

### Setup command convention

Memory plugins should support:

```bash
hermes memory setup   # wizard selects "my-memory"
hermes config set memory.provider my-memory
```

Config is stored in `~/.hermes/config.yaml`. Sensitive values go in `~/.hermes/.env`.

---

## Tool Plugin

Add new tools that the LLM can call during a session.

Register tools in `__init__.py` using the central tool registry:

```python
# plugins/my-tool/  __init__.py
from tools.registry import register_tool

def _my_tool_handler(params: dict) -> str:
    # implementation
    return "result"

register_tool(
    name="my_tool",
    description="Does X when the user needs Y.",
    parameters={
        "type": "object",
        "properties": {
            "input": {"type": "string", "description": "The input value"}
        },
        "required": ["input"]
    },
    handler=_my_tool_handler,
)
```

---

## Installation

### Local development (this repo)

Place the plugin directory directly under `plugins/`. Hermes auto-discovers all directories with a `plugin.yaml` on startup. No registration step needed.

```bash
# Verify discovery
hermes --version   # startup logs will mention loaded plugins
```

### From a git repository

```bash
# Clone into plugins/
git clone https://github.com/org/my-plugin plugins/my-plugin

# Install pip dependencies manually if uv is not set up
uv pip install -r plugins/my-plugin/requirements.txt
```

### Marketplace / shared install

If the plugin is listed in `.agents/plugins/marketplace.json`, install via:

```bash
hermes plugins install my-plugin
```

---

## Configuration

### Enable / disable skills

```bash
hermes skills          # interactive toggle UI
```

Config stored in `~/.hermes/config.yaml`:

```yaml
skills:
  disabled: [skill-a, skill-b]        # globally disabled
  platform_disabled:
    telegram: [skill-c]               # disabled only on Telegram
    cli: []
```

### Environment variables

Sensitive plugin config goes in `~/.hermes/.env`:

```bash
echo "MY_PLUGIN_API_KEY=sk-..." >> ~/.hermes/.env
```

Non-sensitive config uses `hermes config set`:

```bash
hermes config set my_plugin.option value
```

---

## Lifecycle Hooks

| Hook | When it fires |
|------|---------------|
| `on_session_end` | After every conversation session ends |

Implement a hook by defining a function with the hook name in `__init__.py`:

```python
# plugins/my-plugin/__init__.py

def on_session_end(session: dict) -> None:
    """Called after each conversation ends."""
    # persist, summarize, sync, etc.
    pass
```

---

## Checklist: Shipping a Plugin

- [ ] `plugin.yaml` with `name`, `version`, `description`
- [ ] `__init__.py` present (can be empty)
- [ ] `pip_dependencies` listed for any non-stdlib imports
- [ ] `requires_env` documents needed API keys
- [ ] SKILL.md files have full Hermes frontmatter (name, version, author, license, metadata.hermes.tags)
- [ ] `README.md` covers prerequisites, setup steps, and config options
- [ ] Tested with `hermes skills` toggle UI
- [ ] No hardcoded paths — use `~/.hermes/` for user data

---

## Example: uncle-dev Skill Pack

The uncle-dev plugin is a reference implementation of a skill-pack plugin:

```
plugins/uncle-dev/
├── plugin.yaml
└── __init__.py

skills/software-development/
├── uncle-dev-spec/SKILL.md
├── uncle-dev-plan/SKILL.md
├── uncle-dev-build/SKILL.md
├── uncle-dev-test/SKILL.md
├── uncle-dev-review/SKILL.md
├── uncle-dev-code-simplify/SKILL.md
└── uncle-dev-ship/SKILL.md
```

```yaml
# plugins/uncle-dev/plugin.yaml
name: uncle-dev
version: 1.0.0
description: "Production-grade engineering skills — spec-driven development from idea to shipped feature."
```

No pip dependencies, no hooks, no env vars — pure skill definitions loaded at startup.
