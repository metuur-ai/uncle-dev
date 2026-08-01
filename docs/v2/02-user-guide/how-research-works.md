---
title: "How /uncle-dev-research Works"
description: "Understand how the research command investigates a codebase, why it forbids opinions, and how its findings feed the rest of the workflow"
sidebar_position: 8
---

# How `/uncle-dev-research` Works

This document explains the command that runs before you decide anything. After reading it you should understand what research actually does with a question, why it deliberately refuses to give advice, and how its output is meant to be consumed by the spec and build commands.

This is an explanation rather than a set of instructions. Read it when you want to understand the reasoning behind the design.

## Overview

`/uncle-dev-research` is the read half of the Uncle Dev workflow. Where spec and build write things, research only looks. It takes a question — "how does authentication work here?", "what would break if we changed this queue?" — and produces a dated document that answers it with evidence.

Two properties define it. First, it fans out: rather than reading files one after another in a single line of reasoning, it dispatches several parallel investigators, each with a narrow assignment, and then reconciles what they bring back. Second, it is a documentarian, not an advisor. It reports what the code does and what the sources say. It does not recommend, rank, or propose. That restriction is the point of the command, not a limitation of it.

The output is a single markdown file, timestamped and citation-bearing, that later commands can read as input.

## Background and Context

### The problem

Investigation is where agent work goes wrong quietly. Two patterns dominate.

The first is the confident summary. An agent reads three files, forms a theory, and describes the system with total assurance. The theory is coherent and partly wrong, and nothing in the output signals which parts came from reading code and which came from pattern-matching against similar systems it has seen. You cannot audit a conclusion whose evidence was never recorded.

The second is premature convergence. Asked "how should we do X?", the agent produces an answer in the first paragraph and spends the rest of its effort defending it. Alternatives that were never seriously considered appear in a comparison table, already losing. The decision was made before the investigation started.

Both problems share a root cause: mixing the act of finding out with the act of deciding. Once those are entangled, the finding-out is shaped by the deciding.

### Historical context

The intuitive fix is to ask for more thoroughness — "read everything before answering". This runs into a hard limit. A serial reader working through a large codebase either exhausts its context window or starts skimming, and skimming reproduces the confident-summary failure with more input.

The fix that works is structural: split the reading across several workers that do not share a context window, give each a scope narrow enough to be done properly, and keep the synthesis step separate from the collection step. That is the shape research has.

## How It Works

### Core concepts

**Fan-out and fan-in.** The question is decomposed into independent lines of inquiry, each handed to its own investigator. They run at the same time and do not see each other's work. When they finish, a single synthesis step reconciles their reports into one document.

The useful analogy is a newsroom. Reporters are sent to different sources; none of them writes the article. An editor reads all their filings and writes one piece, and — this is the part that matters — notices when two reporters contradict each other. A single reporter cannot notice that, because there is nothing to compare against.

**Isolation is what makes agreement meaningful.** Because investigators do not share context, two of them reaching the same conclusion is genuine corroboration rather than an echo. If they had been passed each other's notes, the second would simply be agreeing with the first. Contradictions are equally valuable: they mark the places where the codebase is genuinely ambiguous, and the synthesis is required to surface them rather than smooth them over.

**The documentarian constraint.** Research reports; it does not advise. Findings must be attributable to something — a file and line, a document, a source. Where the evidence runs out, the output says so instead of filling the gap with plausible reasoning. When a question genuinely has several viable answers, they are presented as a landscape with trade-offs rather than a ranking with a winner.

The reason for the constraint is that recommendation and investigation pull in opposite directions. An investigator trying to be helpful starts selecting evidence that supports the emerging recommendation. Removing the recommendation removes the incentive.

**Structure precedes search.** If the repository has a knowledge graph available, research consults it before grepping. A graph answers "what touches this?" directly, where text search answers "where does this string appear?" and leaves you to work out the rest. When no graph exists, the command falls back to ordinary search without complaint — the structural step is an optimisation, not a dependency.

### The mechanism

```
question
   │
   ├── scope ─────────────► what is in bounds, what is not
   ├── structure ─────────► consult the graph if one exists
   │
   ├── fan out ──────────┬─► investigator A  (isolated context)
   │                     ├─► investigator B  (isolated context)
   │                     └─► investigator C  (isolated context)
   │                              │
   ├── fan in ───────────────────►│ reconcile: agreements, conflicts, gaps
   │
   └── write ─────────────► dated research document with citations
```

The dispatch step is where most of the quality is determined. Overlapping assignments waste effort and manufacture false corroboration. Assignments that are too narrow miss the connections between areas. Getting the decomposition right is the skilled part; the parallel execution is mechanical.

The synthesis step has one job that a single investigator could not do: comparison. It looks for claims that agree, claims that conflict, and questions that nobody managed to answer. All three go into the output. The unanswered questions are not a failure of the run — they are often its most useful product, because they tell you exactly where the risk sits.

### Key components

**The scope statement.** Written before any reading happens, it records what the question covers and what it deliberately excludes. Without it, investigations expand until they run out of budget rather than until they are done.

**The investigators.** Short-lived workers with a single assignment each and no visibility into their peers. They return findings with citations, not conclusions.

**The synthesiser.** Reconciles the reports and writes the document. This is the only step that sees everything, and it is deliberately not the step that gathered anything, so it has no attachment to any particular finding.

**The research document.** A dated file containing the question, the scope, the findings with their sources, the contradictions, and the open questions. It is designed to be read by a person and by a later command, which is why it is a file rather than a chat response.

**Model routing.** The parts of the work differ in difficulty. Broad file collection is mechanical; reconciling contradictory evidence is not. The system allows different steps to run on differently capable models rather than paying the same premium for every keystroke.

### How the loader fits in

Research uses the same routing machinery as the other commands, in its simplest possible form. The command detects nothing complicated, prints a `SKILL:` line naming the research skill, and the agent reads that skill and follows it. If the project has overridden or extended the skill, the loader resolves that first; if it has not, the bundled default is used.

Seeing the machinery in this reduced form is a good way to understand it. In [How Spec and Build Work](how-spec-and-build-work.md) the same mechanism carries mode detection, gates, and a document chain on top. Underneath, it is the same thing: a small command naming a skill, and the skill supplying the method.

## Design Decisions and Trade-offs

### Why parallel isolation instead of one careful reader

A single reader has one context window and one line of reasoning. Both are limits you hit quickly on any real codebase, and both fail in ways that are invisible in the output. Several isolated readers give you more total reading and, more importantly, give you the ability to detect disagreement.

The costs are honest ones. Parallel investigation uses more tokens than a serial pass. Poorly split assignments produce overlapping, redundant reports. And the synthesis step becomes a single point of failure: if it reconciles badly, good findings are lost. The trade is worth it because the failure being avoided — a fluent, wrong answer with no evidence trail — is the expensive one.

### Why research refuses to recommend

This is the decision users push back on most. You asked a question; you wanted an answer; you got a landscape.

The separation exists because recommendation contaminates investigation. The moment an agent is trying to justify a conclusion, its reading becomes selective — not dishonestly, but structurally. Keeping the investigation opinion-free means the evidence you get is the evidence that exists, not the evidence that supports a position.

The decision still gets made. It gets made by you, or by `/uncle-dev-spec` reading the research, with the trade-offs visible instead of pre-resolved.

The cost is a slower path from question to action, and output that feels less satisfying to read. That is the price of evidence you can check.

### Why the output is a file

A chat answer is consumed once and then gone. A dated document can be re-read, cited in a spec, attached to a decision record, and compared against a later investigation of the same area to see what changed. Research is expensive enough that discarding its output after one reading is wasteful.

The cost is document sprawl. Research files accumulate, and old ones describe a codebase that has since moved. The dating is what makes them safe: a document that clearly states when it was written is usable evidence, where an undated one is a trap.

### Why the knowledge graph is optional

Requiring a graph would make research unusable in any repository that has not been prepared for it, which is most of them at the moment you most want to investigate. Making it optional means the command works everywhere and works better where structure is available. The cost is two code paths, and results that vary in quality depending on the repository's setup.

### What was prioritised, and what was given up

**Prioritised:** verifiability, coverage, and honest reporting of uncertainty.

**Sacrificed:** speed, token economy, and the immediate satisfaction of being told what to do. For a question whose answer you could find with one grep, research is the wrong tool and you should just grep.

## Alternatives Considered

### A single agent reading everything

Simpler, cheaper, and adequate for small questions. Rejected as the default because it degrades silently at scale: the output looks the same whether the agent read carefully or skimmed, and there is no second opinion to catch an error. It remains the right approach for narrow, well-bounded questions.

### Letting research recommend

Would compress two steps into one and feel more useful in the moment. Rejected because it reintroduces exactly the failure the command exists to prevent, and because the recommendation would be made without the design context that spec has.

### Investigators that share context

If workers could see each other's findings, they could avoid duplicated effort. Rejected because shared context destroys the independence that makes corroboration meaningful, and because agents that see an existing conclusion tend to converge on it rather than test it. Some redundancy is the price of a real second opinion.

## Implications and Consequences

**On cost.** Research is one of the more expensive commands in the toolkit, by design. Use it for questions where being wrong is costly — architectural decisions, unfamiliar subsystems, changes with a wide blast radius — and use ordinary search for everything else.

**On what a good question looks like.** Because the command decomposes the question before investigating, a vague question decomposes into vague assignments. "Tell me about the codebase" produces a survey. "What would break if we moved session storage out of the database?" produces something you can act on.

**On the value of open questions.** The section listing what could not be determined is frequently more actionable than the findings. It maps the areas where nobody — human or agent — currently understands the system, which is precisely where risk concentrates.

**On downstream use.** Because the output is a citation-bearing file, a spec written afterwards can reference it, and a reviewer can trace a design decision back to the evidence that informed it. The chain from evidence to requirement to code stays intact.

## Related Concepts

- [How Spec and Build Work](how-spec-and-build-work.md) — the write half, and the same machinery under more load
- [Concepts](concepts.md) — the vocabulary used across the workflow
- [Available Agents](../03-agent-guide/available-agents.md) — the personas that carry out investigation work
- [Common Workflows](../01-getting-started/common-workflows.md) — where research sits in the practical sequence
