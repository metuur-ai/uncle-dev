# Why uncle-dev — Posts

**Date:** 2026-06-04
**Source:** `.uncle-dev/research/2026-06-04-uncle-dev-golden-circle.md` (all claims grounded there)
**Contents:** Long post · README intro · LinkedIn post · One-paragraph elevator pitch

---

## 1. Long Post

### Why Developers, Product Owners, and Teams Should Use uncle-dev

#### The shortest path is the problem

AI coding agents are fast. That's the appeal — and the trap. Left to their defaults, agents **take the shortest path**, and the shortest path usually means skipping the unglamorous work: specs, tests, security reviews, the practices that actually make software reliable.

uncle-dev was built to counter exactly that tendency. Its core belief:

> Production-quality software comes from disciplined engineering judgment — so "seems right" should never pass for "verified."

The mission is to give agents *structured workflows that enforce the same discipline a senior engineer brings to production code.* That single idea is the dividing line between **prototype-quality work and production-quality work**.

#### Why it works: discipline you can't skip

Most "best practices" documents are aspirational. uncle-dev's are *enforced*. Three mechanisms make that real:

**1. Anti-rationalization tables.** This is the most distinctive thing in the system. Every skill ships a table of the excuses agents use to dodge steps, paired with a rebuttal:

> *"I'll write tests after the code works" → "You won't. And tests written after the fact test implementation, not behavior."*

The agent literally cannot rationalize its way out of the process, because the rationalizations are already written down and answered.

**2. Verification is non-negotiable.** Every state-mutating skill ends in a `validate → fix → re-validate` loop anchored on a real, deterministic command. *"Every verification checkbox requires proof."* Specificity is the rule — *"Run `npm test`" beats "verify the tests."* "Seems right" is never accepted as done.

**3. It's not a yes-machine.** *"Honest technical disagreement is more valuable than false agreement."* The system is built to surface uncertainty early instead of confidently running with a wrong assumption — which is named as the single most common failure mode.

Underneath all of this is a design philosophy of **process, not prose**: skills are workflows with concrete steps, not reference docs full of facts.

#### Why a developer benefits

- Your agent's natural tendency is to overcomplicate — *"If you build 1000 lines and 100 would suffice, you have failed."* uncle-dev pushes back on that, every change.
- Tests stop being an afterthought: *"A codebase with good tests is an AI agent's superpower; a codebase without tests is a liability."*
- Real engineering practices are **embedded in the steps**, not preached abstractly — Hyrum's Law, the Test Pyramid, Chesterton's Fence, Trunk-Based Development, Shift-Left.

#### Why a product owner or lead benefits

- **Spec-first by default.** *"Code without a spec is guessing."* Significant work begins from a specification, not a vibe.
- **Traceability from intent to code.** Product intent flows HLD → LLD → EARS specs → tests → code, with `@spec` annotations forming *"one edge in a graph that connects durable product intent to the code that implements it."* A requirement can be followed all the way to the line that implements it.
- **A real lifecycle.** Define → Plan → Build → Verify → Review → Ship — each phase auto-activates the right skills.
- **Mechanical guardrails.** Hooks enforce the rules: the spec-coherence guard *blocks* edits or commits that cite undefined spec IDs — yet skips silently when specs don't exist, so teams adopt it gradually instead of all at once.

#### What you actually get

A portable, cross-tool plugin: **39 skill workflows, 9 specialist agent personas** (code reviewer, test engineer, security auditor, technical lead, product owner, and more), **22 slash commands, and 14 lifecycle hooks** — running across **Claude Code, Cursor, Gemini, Windsurf, OpenCode, Copilot, and Codex**. It ships with a single source of truth for config, layered workspaces (`openspec/` for shared truth, `.devlocal/` for personal scratch), and a place for team knowledge to accrue over time in `.uncle-dev/learns/`.

#### The bottom line

- **WHY** — Production-quality software requires senior-engineer discipline; agents default to skipping it. uncle-dev makes agents that don't cut corners.
- **HOW** — Process-not-prose skill workflows with anti-rationalization tables and non-negotiable verification, chained across Define→Ship and traced from intent to code.
- **WHAT** — 39 skills, 9 agents, 22 commands, 14 hooks — one plugin, seven tools.

If your agent ships code, uncle-dev is what keeps it honest.

---

## 2. README Intro

### uncle-dev

**Production-grade engineering skills for AI coding agents.**

AI coding agents default to the shortest path — which often means skipping specs, tests, security reviews, and the practices that make software reliable. uncle-dev gives agents structured workflows that enforce the same discipline senior engineers bring to production code.

These are opinionated, process-driven workflows that separate production-quality work from prototype-quality work. Every skill is a workflow with concrete steps — not a reference doc — and ships with a table of the excuses agents use to skip steps, each paired with a documented rebuttal. Verification is non-negotiable: every checkbox requires proof, and "seems right" is never sufficient.

What's inside: **39 skill workflows, 9 specialist agent personas, 22 slash commands, and 14 lifecycle hooks**, chained across a Define → Plan → Build → Verify → Review → Ship lifecycle and traced from product intent to code (HLD → LLD → EARS specs → tests → code). Works with **Claude Code, Cursor, Gemini CLI, Windsurf, OpenCode, GitHub Copilot, and Codex**.

---

## 3. LinkedIn Post

AI coding agents are fast. That's the trap.

Left to their defaults, they take the shortest path — skipping specs, tests, and reviews. The work *looks* done. It isn't.

That's the problem uncle-dev was built to solve. The belief behind it is simple:

→ Production-quality software comes from disciplined engineering judgment. "Seems right" should never pass for "verified."

So instead of hoping the agent behaves, uncle-dev enforces it:

🔹 **Anti-rationalization tables** — every skill lists the excuses agents use to skip steps, with rebuttals. *"I'll write tests after" → "You won't. And tests written after the fact test implementation, not behavior."*

🔹 **Non-negotiable verification** — every workflow ends in validate → fix → re-validate on a real command. Every checkbox requires proof.

🔹 **Spec-first** — because code without a spec is guessing. Intent flows from HLD → LLD → specs → tests → code, fully traceable.

For developers: an agent that resists overcomplication and treats tests as a superpower, not an afterthought.

For product owners and leads: a real Define → Ship lifecycle, traceability from requirement to line of code, and guardrails that block work citing specs that don't exist.

39 skills. 9 agent personas. 22 commands. 14 hooks. One plugin — across Claude Code, Cursor, Gemini, Windsurf, OpenCode, Copilot, and Codex.

If your agent ships code, this is what keeps it honest.

#AIcoding #SoftwareEngineering #DeveloperTools #AIagents

---

## 4. One-Paragraph Elevator Pitch

uncle-dev is a cross-tool plugin that makes AI coding agents work like senior engineers instead of taking the shortest path. AI agents default to skipping the specs, tests, and reviews that make software reliable — uncle-dev counters that with opinionated, process-driven skill workflows that build in anti-rationalization rebuttals and non-negotiable verification, so "seems right" never passes for "verified." It chains 39 skills, 9 agent personas, 22 commands, and 14 hooks across a Define→Ship lifecycle with full traceability from product intent to code, and runs on Claude Code, Cursor, Gemini, Windsurf, OpenCode, Copilot, and Codex.
