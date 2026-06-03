---
sidebar_position: 5
---

# How to Use agent-skills with Windsurf

## Prerequisites

Before you begin, ensure you have:

- A local clone of the agent-skills repository
- Windsurf installed
- A target project where you want to install the rules

## Install the project rules

Windsurf uses `.windsurfrules` for project-specific agent instructions. From this repository, install the recommended rules into your project:

```bash
./scripts/install-plugin.sh windsurf /path/to/your-project
```

## Add global rules

To use skills across all projects, add them to Windsurf's global rules:

1. Open Windsurf, then go to Settings > AI > Global Rules.
2. Paste the content of your most-used skills.

## Recommended Configuration

Keep `.windsurfrules` focused on 2-3 essential skills to stay within context limits:

```
# .windsurfrules
# Essential agent-skills for this project

[Paste test-driven-development SKILL.md]

---

[Paste incremental-implementation SKILL.md]

---

[Paste code-review-and-quality SKILL.md]
```

## Verify it worked

Confirm the installation:

1. Check that your project root contains a `.windsurfrules` file with the installed skill content.
2. In Windsurf chat, ask it to "follow the test-driven-development rules" and confirm it references the loaded rules.

## Usage Tips

1. **Be selective** — Windsurf's context is limited. Choose skills that address your biggest quality gaps.
2. **Reference in conversation** — Paste additional skill content into the chat when working on specific phases (e.g., paste `security-and-hardening` when building auth).
3. **Use references as checklists** — Paste `references/security-checklist.md` and ask Windsurf to verify each item.
