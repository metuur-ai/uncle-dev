# 1. What is Uncle Dev and Why it Works with SDD

## Overview

**Uncle Dev** is a production-grade engineering skills pack designed for AI coding agents. Native AI agents (like Claude Code, Cursor, Copilot, or OpenCode) default to the path of least resistance: they often skip writing specs, omit architecture design, skip testing, and aggressively generate giant unreviewed blocks of code. 

**Uncle Dev** transforms these chaotic AI agents into disciplined Senior Staff Engineers. It achieves this by overriding default behaviors with a structured, step-by-step workflow for every phase of software development.

## The Problem with Default AI Agents
When a developer says, "Build me a login page," a vanilla AI agent will immediately output HTML, CSS, and database queries. It guesses the architecture, guesses the edge cases, and often hallucinates business logic. This leads to:
- "Prototype-quality" code that breaks in production.
- Refactoring nightmares where the developer spends more time fixing AI code than they would have spent writing it from scratch.
- Loss of project context over time.

## The Solution: Spec-Driven Development (SDD)
Uncle Dev forces the agent to use **Spec-Driven Development (SDD)**. 

### Why SDD Works:
1. **Alignment Before Execution:** SDD mandates that the AI agent must write and agree upon a specification document with the developer *before* writing a single line of application code. This acts as a quality gate.
2. **Context Retention:** Instead of relying purely on conversational history (which degrades over time and uses massive amounts of tokens), SDD externalizes memory into markdown files (like `proposal.md` and `design.md`). The AI can re-read these documents to instantly regain total context.
3. **Controlled Scope:** The agent is required to break the specification down into a strict, atomic checklist (tasks). It implements one slice of the application at a time, testing and verifying at every boundary.
4. **Anti-Rationalization:** Uncle Dev skills contain specific "anti-rationalization tables." If an AI agent attempts to say, "This is too small for a test, I'll skip it," the Uncle Dev skill forcefully overrides this behavior, ensuring discipline is maintained.

By enforcing SDD, Uncle Dev aligns human intent with machine execution, guaranteeing that the final output is secure, well-tested, and built on a solid architectural foundation.
