# Discoverability Check

After writing or refreshing a learning, check whether the project's instruction files would lead
an agent to discover and search `.uncle-dev/learns/` before starting work in a documented area.
This check runs every time — the knowledge store only compounds value when agents can find it.

## Steps

1. **Identify instruction files.** Find which root-level instruction files exist (AGENTS.md, CLAUDE.md,
   or both). Determine which holds substantive content — one may be a shim that `@`-includes the other
   (e.g., `CLAUDE.md` containing only `@AGENTS.md`). Target the substantive file for assessment and any
   edits. If neither file exists, skip this check entirely.

2. **Assess discoverability.** An agent reading the instruction files should learn three things:
   - That a searchable knowledge store of documented solutions exists
   - Enough about its structure to search effectively (category organization, YAML frontmatter fields
     like `module`, `tags`, `problem_type`)
   - When it is relevant (implementing features, debugging issues, making decisions in documented areas)

   This is a semantic assessment, not a string match. The information could be in an architecture
   section, a gotchas block, a directory listing, or spread across multiple places — and may not use
   the exact path `.uncle-dev/learns/`. Use judgment: if an agent would reasonably discover and use the
   knowledge store after reading the file, the check passes.

3. **If the spirit is already met,** no action needed — move on.

4. **If not:**

   a. Based on the file's existing structure, tone, and density, identify where a mention fits
      naturally. Before creating a new section, check whether a single line in the closest related
      section (architecture tree, directory listing, documentation section, conventions block) would
      work. A line added to an existing section is almost always better than a new headed section.
      Only add a new section as a last resort.

   b. Draft the smallest addition that communicates the three things. Match the file's existing style
      and density. The addition should describe the knowledge store itself, not the skill that writes
      to it — an agent without the skill should still find value in it.

      Keep tone informational, not imperative. Express timing as description, not instruction —
      "relevant when implementing or debugging in documented areas" rather than "always check before
      implementing." Imperative directives cause redundant reads when a workflow already includes a
      dedicated search step.

      Examples of calibration (not templates — adapt to the file):

      When there's an existing directory listing or architecture section — add a line:
      ```
      .uncle-dev/learns/  # documented solutions to past problems (bugs, best practices, workflow patterns), organized by category with YAML frontmatter (module, tags, problem_type)
      ```

      When nothing in the file is a natural fit — a small headed section is appropriate:
      ```markdown
      ## Documented Solutions

      `.uncle-dev/learns/` — documented solutions to past problems (bugs, best practices, workflow
      patterns), organized by category with YAML frontmatter (`module`, `tags`, `problem_type`).
      Relevant when implementing or debugging in documented areas.
      ```

   c. **Caller-specific behavior for step 4c:**

      - **`uncle-dev-knowledge-capture` (interactive / full mode):** Show the proposed change and
        where it would go, then use the platform's blocking question tool (`AskUserQuestion` in
        Claude Code, `request_user_input` in Codex, `ask_user` in Gemini) to get consent before
        editing. If no question tool is available, present the proposal and wait for a reply.
        In lightweight mode, output a one-liner tip and move on — no consent step.

      - **`uncle-dev-knowledge-maintenance` (interactive mode):** Same consent flow as above.
        In autofix mode, include a "Discoverability recommendation" line in the report and do NOT
        attempt to edit instruction files — autofix scope is doc maintenance, not project config.

5. **Commit the edit when it produces changes.** If step 4 resulted in an instruction-file edit
   and `uncle-dev-knowledge-maintenance` Phase 5 already committed refresh changes, stage the newly
   edited file and either amend the existing commit (if still on the same branch and not yet pushed)
   or create a small follow-up commit:

   ```
   docs: add .uncle-dev/learns/ discoverability to AGENTS.md
   ```

   If the branch was already pushed, push the follow-up commit so the open PR includes the
   discoverability change. If the user chose "Don't commit" in Phase 5, leave the edit unstaged
   alongside other uncommitted refresh changes — no separate commit logic needed.

   This step applies only when called from `uncle-dev-knowledge-maintenance`. When called from
   `uncle-dev-knowledge-capture`, committing the instruction-file edit is the user's responsibility
   as part of their normal commit workflow.
