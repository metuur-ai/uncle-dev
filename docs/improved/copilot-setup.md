# How to Use agent-skills with GitHub Copilot

## Prerequisites

Before you begin, ensure you have:

- A local clone of the agent-skills repository
- GitHub Copilot enabled for your editor or repository
- A target project where you want to install the skills

## Install the Copilot files

From this repository, install the recommended Copilot files into your project:

```bash
./scripts/install-plugin.sh copilot /path/to/your-project
```

This single command installs the agent skills into a `.github/skills`, `.claude/skills`, or `.agents/skills` directory and registers the agent personas. For background on Copilot agent skills, see [Creating agent skills for GitHub Copilot](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/create-skills).

## Invoke the agent personas

After installing, invoke the personas in Copilot Chat:
- `@code-reviewer Review this PR`
- `@test-engineer Analyze test coverage for this module`
- `@security-auditor Check this endpoint for vulnerabilities`
- `@uncle-lead Produce design.md for this change and assess migration risk`
- `@uncle-po Draft proposal.md and Given/When/Then acceptance criteria`

## Add user-level instructions

To use skills across all repositories:

1. Open VS Code, then go to Settings > GitHub Copilot > Custom Instructions.
2. Add your most-used skill summaries.

## Add project-level instructions

GitHub Copilot supports project-level instructions via `.github/copilot-instructions.md`. Add a file with this structure:

```markdown
# Project Coding Standards

## Testing
- Write tests before code (TDD)
- For bugs: write a failing test first, then fix (Prove-It pattern)
- Test hierarchy: unit > integration > e2e (use the lowest level that captures the behavior)
- Run `npm test` after every change

## Code Quality
- Review across five axes: correctness, readability, architecture, security, performance
- Every PR must pass: lint, type check, tests, build
- No secrets in code or version control

## Implementation
- Build in small, verifiable increments
- Each increment: implement → test → verify → commit
- Never mix formatting changes with behavior changes

## Boundaries
- Always: Run tests before commits, validate user input
- Ask first: Database schema changes, new dependencies
- Never: Commit secrets, remove failing tests, skip verification
```

## Verify it worked

Confirm the installation:

1. Check that the target project contains the skills directory the install command created (`.github/skills`, `.claude/skills`, or `.agents/skills`).
2. Open Copilot Chat and type `@code-reviewer`. The persona should be available for selection.

## Usage Tips

1. **Keep instructions concise** — Copilot instructions work best when focused. Summarize the key rules rather than including full skill files.
2. **Use agents for review** — The code-reviewer, test-engineer, security-auditor, uncle-lead, and uncle-po agents are designed for Copilot's agent model.
3. **Reference in chat** — When working on a specific phase, paste the relevant skill content into Copilot Chat for context.
4. **Combine with PR reviews** — Set up Copilot to review PRs using the code-reviewer agent persona.
