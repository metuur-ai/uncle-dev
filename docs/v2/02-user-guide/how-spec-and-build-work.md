---
title: "How /uncle-dev-spec and /uncle-dev-build Work"
description: "Understand how the spec and build commands route work, load skills, and move intent through files — and why they were designed this way"
sidebar_position: 7
---

# How `/uncle-dev-spec` and `/uncle-dev-build` Work

This document explains the two commands that carry a feature from idea to landed code. After reading it you should understand what actually happens when you type `/uncle-dev-spec`, where the resulting information lives, how `/uncle-dev-build` finds it again, and why the system is built out of files and gates instead of a long conversation.

This is an explanation, not a how-to. If you want the steps for using them, read [Your First Task](../01-getting-started/first-task.md) and [Common Workflows](../01-getting-started/common-workflows.md). Come here when you want to know *why* the commands behave the way they do.

## Overview

`/uncle-dev-spec` and `/uncle-dev-build` are the write half of the Uncle Dev workflow. Spec turns a vague request into durable, reviewable intent. Build turns that intent into code, one task at a time, without losing the thread.

The most surprising thing about both commands is how little they contain. Neither holds the engineering procedure it appears to run. A command is a short router: it works out which mode the project is in, prints a couple of lines naming the skills to load, and then gets out of the way. The actual method — how to write an EARS requirement, how to size a task, when to stop and ask — lives in skills under `skills/`, which the agent reads at the moment it needs them.

What connects the two commands is not the agent's memory. It is a chain of files on disk. Spec writes documents; plan writes a task list; build reads that list, writes code, and writes its progress back into the same list. Every handoff survives a context reset, a new session, or a different person picking the work up tomorrow.

## Background and Context

### The problem

AI agents produce code faster than teams can verify it. The bottleneck moved. When generating a thousand lines is nearly free, the expensive part becomes knowing whether those lines were the right ones, and being able to prove it later.

Three failure modes show up over and over in unstructured agent work:

**Intent evaporates.** You explain the requirement in a long conversation. The agent builds something reasonable. Two weeks later nobody can reconstruct which constraint drove which decision, because the reasoning only ever existed in a transcript that has since been cleared.

**Scope drifts silently.** Asked to add a field, the agent also refactors the validator, renames a helper, and adds a cache. Each change is defensible in isolation. Together they turn a five-minute review into an hour of archaeology.

**Ambiguity gets resolved by guessing.** A requirement has two readings. The agent picks one, does not mention that it picked, and the mismatch surfaces in review or in production.

### Historical context

The obvious first fix is a better prompt: write a long instruction that describes the whole process and paste it into every session. That works until the process needs to differ per project, or until the prompt grows past the point where the agent reliably follows all of it.

The second fix is a rigid pipeline that always produces the same artifacts. That works until you hit a one-line bug fix and the system demands a High-Level Design document for it.

Uncle Dev's shape is a response to both. The process is split into small skills that are loaded only when relevant. The commands that load them are configurable per project, and the pipeline runs at one of several strictness levels rather than a single fixed ceremony.

## How It Works

### Core concepts

Three ideas explain nearly all of the behaviour you will observe.

**A command is a router, not a procedure.** When `/uncle-dev-spec` runs, it emits lines like `SKILL: uncle-dev:uncle-dev-spec-driven-development` and, sometimes, `COMPANION: <path>`. The agent's standing instructions say: when you see those lines, read the referenced files and treat them as the active method. The command is the switchboard; the skill is the expertise.

Think of it like a hospital triage desk. The desk does not treat you. It establishes what kind of problem you have and routes you to the specialist who does. Keeping the desk small is what lets the specialists be detailed.

**Mode is detected, not asked.** Both commands support two ways of working: a documentation-chain mode (`lid-ears`) and a change-proposal mode (`openspec`). The command decides which one applies by checking, in order, an explicit flag, then project configuration, then what already exists on disk, then a default. You are not asked a question you have already answered by the shape of your repository.

**Files are the memory.** Every step's output is a file with a known path. The next step's input is that same path. Nothing important is carried only in the conversation, because conversations are the least durable storage in the system.

### The mechanism

Here is what happens, end to end, in the documentation-chain mode.

```
/uncle-dev-spec
  ├── detect mode ────────► lid-ears  (or openspec)
  ├── load skill ─────────► uncle-dev-spec-driven-development
  │                          (+ any project companion file)
  ├── write ──────────────► docs/hld/<feature>.md    architecture intent
  ├── write ──────────────► docs/lld/<feature>.md    component design
  ├── write ──────────────► docs/ears/<feature>.md   testable requirements
  ├── optional ───────────► pre-mortem pass
  └── HARD GATE ──────────► asks you to confirm, verbatim
                                │
                                ▼
/uncle-dev-plan
  └── write ──────────────► task list with IDs and acceptance checks
                                │
                                ▼
/uncle-dev-build
  ├── read ───────────────► next unclaimed task
  ├── read ───────────────► the EARS requirements it references
  ├── load skills ────────► incremental-implementation + TDD
  ├── write ──────────────► tests, then code
  └── write back ─────────► task marked done, with what landed
```

The direction of flow matters. Intent moves downhill only: high-level design constrains low-level design, which constrains requirements, which constrain tests, which constrain code. Code never edits the requirement that justifies it. If reality contradicts the spec, the loop goes back up through the spec rather than around it.

The change-proposal mode has the same shape with different filenames. Instead of a documents tree, everything for one change lands in `openspec/changes/<change-id>/` as a proposal, a design, a task list, and an execution record. The mode suits work that is naturally a discrete proposal — a migration, a breaking API change — where the useful unit is "this change" rather than "this area of the system".

### Key components

**The mode detector.** A small resolution step with a fixed precedence: explicit flag beats configuration, configuration beats filesystem evidence, filesystem evidence beats the default. Precedence is worth stating because it is the thing people get wrong when a project behaves unexpectedly. If your repo has an `openspec/` directory and you did not want that mode, the filesystem is why.

**The skill loader.** A shared script resolves a skill name to a concrete file, checking whether the project has overridden or extended it. Its two failure behaviours are deliberate and opposite. If a project's configuration names a skill that does not exist, the loader fails closed and stops, because silently running a different method than the one requested is worse than stopping. If configuration is simply absent, it fails open and uses the bundled default, because a missing optional file should never break a working install.

**Companion files.** A project can attach extra guidance to a skill without forking it. The companion is read after the skill and merged in. This is what lets one team's spec step insist on a threat model while another team's does not, with both still tracking upstream improvements to the underlying skill.

**The gates.** A gate is a point where the agent must stop and get a human answer before continuing. Spec has one before implementation planning begins. In the change-proposal mode, build has one at the acknowledgement step. Gates are scripted with exact wording rather than left to the agent's judgement, because an agent asked to "check in when appropriate" will reliably decide that now is not the moment.

**The dials.** Two settings change how much ceremony runs: an execution profile (how strict this session is) and a test-driven-development mode (how strictly tests lead). They exist so the same commands can serve a spike and a payments change without either feeling wrong.

**The ready set.** When multiple agents or people can pick up work, build selects from tasks that are unblocked and unclaimed, and claims one before starting. Without claiming, two workers converge on the same first task. This is a small mechanism with an outsized effect on parallel work.

## Design Decisions and Trade-offs

### Why files instead of conversation

The whole system leans on artifacts because artifacts survive. A session ends, context gets compacted, a colleague opens the repo cold — in all three cases the files are still there and still say the same thing. Conversation state fails all three.

The cost is real: you accumulate documents, and documents rot when nobody maintains them. The system's answer is that these particular documents are load-bearing. Build reads them. If they drift, the drift shows up as friction during implementation rather than as a stale wiki page nobody opens.

### Why intent flows in one direction

Allowing code to amend its own requirements sounds convenient and quietly destroys the value of having requirements. If the spec can be rewritten to match whatever was built, it stops being a constraint and becomes a transcript. Keeping the flow one-way means a mismatch is forced to surface as a decision rather than absorbed as an edit.

The cost is friction exactly when you least want it. Discovering mid-implementation that the design was wrong means going back up the chain instead of patching forward. That friction is the feature, but it is still friction.

### Why the confirmation gate is scripted word-for-word

This is the least intuitive decision in the system, and the most important. An agent instructed to "confirm with the user before proceeding" will produce a confirmation that is technically present and practically useless — a summary ending in "shall I continue?", which nobody reads carefully because it looks like every other summary.

Fixing the wording turns the gate into a landmark. It looks the same every time, so it is recognisable, and it names the specific decisions being locked in. The trade-off is that the interaction feels mechanical. That is acceptable: this is the moment where a wrong assumption becomes expensive, and mechanical beats missable.

### Why spec chains into plan automatically

Spec ends by handing off to planning rather than waiting to be asked. Users who have just approved a design almost always want the task breakdown next, and the pause between them was where sessions went to die — people approved, got distracted, and returned to a context that no longer held the design.

The cost is a small loss of control: you get the next step without requesting it. Since planning produces a list you can edit and does not touch code, the risk of doing it unprompted is low.

### Why configuration goes through one helper

Project settings live in a YAML file, but nothing reads that file directly except a single helper script. Every command, hook, and script asks the helper. This looks like indirection for its own sake until the schema needs to change: with one reader, a migration is one edit; with fifteen readers, it is fifteen edits and a long tail of stragglers that still parse the old shape.

### What was prioritised, and what was given up

**Prioritised:** reviewability, resumability, and traceability from a line of code back to the requirement that justifies it.

**Sacrificed:** speed on small changes, and a certain amount of agent autonomy. There is real overhead here, and on a two-line fix the overhead exceeds the work. That is why the profiles exist and why the guidance says to run spec for non-trivial features rather than for everything.

## Alternatives Considered

### One mode instead of two

A single artifact layout would be simpler to explain and simpler to maintain. It was rejected because the two modes answer genuinely different questions. A documentation chain describes what the system *is*; a change proposal describes what this particular change *does*. Teams doing continuous product work want the first; teams shipping discrete migrations want the second. Forcing either into the other's shape produces documents that nobody trusts.

The cost of supporting both is a mode-detection step and two sets of paths to keep straight — which is exactly the complexity you are reading about.

### Putting the procedure inside the command

Commands could carry their own instructions instead of loading skills. This removes a layer and makes each command self-contained. It was rejected because the same method is needed from several entry points, and because per-project customisation would then mean editing the command itself. Skills exist so that method can be shared and overridden independently of the routing.

### Letting the agent choose the order

A capable model can decide for itself when it has enough information to start coding. Sometimes it decides well. The problem is variance: the failure mode is silent and only visible after the code exists. Fixing the order trades some peak efficiency for a much narrower distribution of outcomes, which is the right trade when review capacity is the constraint.

## Implications and Consequences

**For review.** Reviewers get a requirement to review against instead of judging code on its own merits. The question shifts from "is this good code?" to "does this satisfy the stated behaviour?", which is a far easier question to answer confidently.

**For onboarding.** A new person can read the chain for a feature and reconstruct not just what was built but why. The documents were written before the code, so they contain the reasoning rather than a post-hoc rationalisation of it.

**For long-running work.** Because state lives in files, an interrupted session resumes cleanly. This is what makes multi-day work with an agent practical rather than an exercise in re-explaining.

**For small changes.** The overhead is genuinely not worth it below a certain size. Recognising that boundary is part of using the system well, and the profiles exist precisely so you do not have to choose between full ceremony and none.

**For customisation.** Because skills resolve through a loader with override and companion support, a team can adapt the method to its domain without forking the toolkit and without losing upstream fixes.

## Related Concepts

- [Common Workflows](../01-getting-started/common-workflows.md) — the full command sequence in practical order
- [How Research Works](how-research-works.md) — the read half of the system, and where its investigation lands
- [SDD and OpenSpec](sdd-and-openspec.md) — the two modes in more detail
- [Spec Annotations](spec-annotations.md) — how code links back to the requirement it satisfies
- [Next-Task Selection](next-task-selection.md) — how build picks and claims work
