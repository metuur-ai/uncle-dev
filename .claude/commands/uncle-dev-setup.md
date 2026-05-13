Load and execute the `uncle-dev-setup` skill located at `skills/uncle-dev-setup/SKILL.md`.

Run all six setup steps for the current working directory, covering all detected tools (Claude Code, Codex, OpenCode):

1. Detect active tools — check for Claude Code, Codex, and OpenCode installations
2. Install uncle-dev plugin for each detected tool (install-claude.sh / install-codex.sh / install-opencode.sh)
3. Scaffold shared directories (`openspec/`, `.uncle-dev/learns/`, `.devlocal/`, `.agents/`) and write `.agents/uncle-dev-setup.yaml`
4. Wire uncle-dev hooks into `.claude/settings.json` (Claude Code only — Codex and OpenCode skip this step)
5. Inject uncle-dev rules into `CLAUDE.md` (Claude Code) or verify `AGENTS.md` (OpenCode); Codex needs no rules file
6. Add `.devlocal/` to `.gitignore` and print the per-tool verification summary

After completing setup, open `.agents/uncle-dev-setup.yaml` and set `project.type`, `language`, and `framework` to match the project. Restart Claude Code for hooks to take effect.
