# 07 — Create or reroute phantom commands; fix agent identities (P1)

## Problem

The workflow routes through five slash commands that don't exist, references
a `plan-reviewer` agent defined nowhere, and 6 of 9 agent files have `name:`
frontmatter that doesn't match the spawn strings used by skills.

### Finding A — five referenced slash commands with no command file

All five have a backing **skill**, so the capability exists; the literal
`/command` invocation fails:

| Missing command | Referenced by |
|---|---|
| `/uncle-dev-pre-mortem` | `commands/uncle-dev-spec.md:162` (mandatory lid-ears Step 4.5); `skills/uncle-dev-spec-driven-development/SKILL.md:140,179` |
| `/uncle-dev-documentation-and-adrs` | `commands/uncle-dev-acknowledge.md:35` (entire lid-ears Path A); `skills/uncle-dev-acknowledge/SKILL.md:18`; `skills/uncle-dev-knowledge-capture/SKILL.md:39`; `skills/uncle-dev-initiative-map/README.md:113` |
| `/uncle-dev-feature-map` | `commands/uncle-dev-brownfield.md:2,25,201` ("stop and offer to run it first"); `skills/uncle-dev-brownfield/SKILL.md:22`; root `CLAUDE.md:11`; `README.md:43` |
| `/uncle-dev-using-agent-skills` | `commands/uncle-dev-custom-me.md:65` |
| `/uncle-dev-grill` | `skills/uncle-dev-initiative-map/README.md:114` |

### Finding B — phantom `plan-reviewer` agent

Referenced in 4 places, defined in 0:

- `agents/uncle-dev-ag-review-synthesizer.md:14,15,102,105` — expects input
  "From a plan-reviewer agent"
- `skills/uncle-dev-code-review-and-quality/SKILL.md:243,248,268,269` —
  architecture + change-impact reviews assigned to `plan-reviewer`

(The skill's own code at lines 286,292 papers over it with
`subagent_type="general-purpose"`.)

### Finding C — agent `name:` ≠ filename for 6 of 9 agents

Filenames carry the `uncle-dev-ag-` prefix; `name:` fields don't:
`code-reviewer`, `graph-analyst`, `repo-research-analyst`,
`review-synthesizer`, `security-auditor`, `test-engineer`
(each at line 2 of its file). `uncle-lead`, `uncle-po`, `uncle-senior` match.

Consequence: `skills/uncle-dev-code-review-and-quality/SKILL.md:280,306`
spawn `subagent_type="uncle-dev-ag-code-reviewer"` /
`"uncle-dev-ag-review-synthesizer"` — plugin agents resolve by their `name:`
field, so these strings **won't resolve**. Meanwhile the agents' own Example
Invocations (`review-synthesizer.md:91`, `graph-analyst.md:121`,
`repo-research-analyst.md:249`) use `subagent_type="general-purpose"` +
paste-the-file — two contradictory spawn patterns coexist.

### Finding D — dead / phantom-ecosystem agents

- `agents/uncle-dev-ag-test-engineer.md` — spawned by nothing (`/uncle-dev-test`
  and the TDD skill never invoke it). Only mentions: `scripts/README.md:18`
  and the Copilot copy list.
- `agents/uncle-lead.md` / `agents/uncle-po.md` — referenced by zero
  skills/commands; internal workflow references things that don't exist in
  this repo: `~/coding-projects/project-map.yaml` (machine-specific, lines
  30), `.ai/shared-memory/project-context.md` / `decision-log.md` /
  `current-focus.md` (line 32 — convention appears nowhere else), handoffs to
  a "Dev Manager" agent that doesn't exist (`uncle-po.md:18,43,79`,
  `uncle-lead.md:11,39`), and a "GCP deployment compatibility" review lens
  (`uncle-lead.md:94`) — project-specific leakage in a distributable plugin.
- `agents/uncle-po.md:32-33` — duplicate step numbering (two "3." steps).
- `uncle-senior` is defined **three times** (agents/, skills/, commands/)
  with duplicated mode-detection/duck-rules content — against the repo's own
  "never duplicate content" boundary.
- `agents/uncle-dev-ag-graph-analyst.md:25` reads
  `graphify-out/GRAPH_REPORT.md` unconditionally; no explicit branch for a
  missing graph (contrast `uncle-dev-ag-repo-research-analyst.md:54`, which
  handles it). Callers do guard ("Only when graphify is ON"), but the agent
  itself is undefined on orchestrator error.
- Copilot installer (`scripts/install-plugin.sh:262-277`) copies 5 of 9
  agents: omitting the three orchestrator-only agents is defensible, but it
  omits `uncle-senior` while including `uncle-lead`/`uncle-po` — all three
  are human-invoked personas.

## Change instructions

1. **Create the two workflow-critical commands** (thin wrappers that load the
   existing skill, following the pattern of e.g.
   `commands/uncle-dev-changelog.md`):
   - `commands/uncle-dev-pre-mortem.md` → loads `uncle-dev-pre-mortem`
   - `commands/uncle-dev-feature-map.md` → loads `uncle-dev-feature-map`
   These two are invoked as mandatory/first steps by other commands, so a
   command file is warranted. Remember: update `.claude-plugin` command
   count-sensitive docs and regenerate the plugin fork (audit file 03).
2. **Reroute the other three** (referenced only in prose): change the
   references to skill invocations instead of slash commands —
   `commands/uncle-dev-acknowledge.md:35` → "use the
   `uncle-dev-documentation-and-adrs` skill";
   `commands/uncle-dev-custom-me.md:65` → "consult the
   `uncle-dev-using-agent-skills` skill";
   `skills/uncle-dev-initiative-map/README.md:113-114` → skill wording.
   (Or create commands for them too, if you prefer symmetry — decide once and
   apply consistently.)
3. **Resolve `plan-reviewer`**: repoint
   `skills/uncle-dev-code-review-and-quality/SKILL.md:243,248,268,269` and
   `agents/uncle-dev-ag-review-synthesizer.md:14,15,102,105` at an existing
   agent (`code-reviewer` with an architecture-lens prompt, or
   `general-purpose` as the code already does), or create
   `agents/uncle-dev-ag-plan-reviewer.md` and add it to marketplace.json.
   Recommendation: repoint; the synthesizer only needs the *output shape*.
4. **Pick one agent-identity convention**: either rename `name:` fields to
   match filenames (`uncle-dev-ag-code-reviewer`) or update every
   `subagent_type=` string in skills to the short names
   (`code-reviewer`, `review-synthesizer`). Recommendation: keep short
   `name:` values (they're what the plugin registry exposes, cf. the session
   agent list `uncle-dev:code-reviewer`) and fix the skill spawn strings at
   `uncle-dev-code-review-and-quality/SKILL.md:280,306`. Then delete the
   contradictory "paste the file into general-purpose" example invocations,
   or label them as the fallback for non-plugin installs.
5. **Decide the persona agents**: for `uncle-lead`/`uncle-po`, remove the
   phantom references (`project-map.yaml`, `.ai/shared-memory/`,
   "Dev Manager", GCP lens) and ground them in the real conventions
   (`.uncle-dev/`, `.devlocal/`, openspec/) — or move them out of the
   distributed plugin. Fix `uncle-po.md:32-33` numbering.
6. **Wire or remove `test-engineer`**: add it as an optional deep-verify step
   in `commands/uncle-dev-test.md` / the TDD skill, or drop it from agents/ +
   marketplace.json.
7. **Harden graph-analyst**: add an explicit first step — "if
   `graphify-out/graph.json` does not exist, return
   `GRAPH UNAVAILABLE` immediately" (mirror repo-research-analyst line 54).
8. **Align the Copilot agent subset** (`install-plugin.sh:262-277`): include
   `uncle-senior` with the other personas (or document why not).

## Expected result after

- No command or skill routes the user to a slash command that doesn't exist;
  mandatory workflow steps (pre-mortem in spec, feature-map before
  brownfield) are actually invocable.
- The full-review flow (`/uncle-dev-review` full mode → 3 reviewers →
  synthesizer) resolves every subagent_type it names.
- Agents in the distributed plugin reference only artifacts the plugin
  creates.
- `grep -rn 'plan-reviewer' agents/ skills/ commands/` → empty (or matches a
  real agent file).

## Verification

```bash
for c in pre-mortem feature-map; do [ -f "commands/uncle-dev-$c.md" ] && echo "OK $c"; done
grep -rn '/uncle-dev-documentation-and-adrs\|/uncle-dev-using-agent-skills\|/uncle-dev-grill' commands/ skills/  # expect: none (rerouted)
grep -rn 'plan-reviewer' agents/ skills/ commands/                                   # expect: none or real agent
# every subagent_type in skills resolves to an agent name: field
grep -rhoE 'subagent_type="[^"]+"' skills/ | sort -u                                 # manually check against agents/*.md name: fields
grep -rn 'project-map.yaml\|shared-memory\|Dev Manager' agents/                      # expect: none
bash scripts/check-manifest.sh                                                       # green (counts updated)
```
