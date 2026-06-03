---
sidebar_position: 1
---

# 1. What is Uncle Dev and Why it Works with SDD

## Overview

**Uncle Dev** is a production-grade engineering skills pack for AI coding agents. AI agents such as Claude Code, Cursor, Copilot, and OpenCode default to the path of least resistance: they skip writing specs, omit architecture design, skip testing, and generate large blocks of unreviewed code.

Uncle Dev overrides these default behaviors with a structured workflow for every phase of software development, so the agent works more like a disciplined senior engineer than a fast code generator.

## The Problem with Default AI Agents

When you say "Build me a login page," a default AI agent immediately outputs HTML, CSS, and database queries. It guesses the architecture, guesses the edge cases, and often invents business logic. This leads to:

- Prototype-quality code that breaks in production.
- Rework where you spend more time fixing AI code than you would have spent writing it from scratch.
- Loss of project context over time.

## How Uncle Dev Solves It: Spec-Driven Development (SDD)

Uncle Dev requires the agent to use **Spec-Driven Development (SDD)**. Four properties make SDD work:

1. **Alignment before execution.** The agent writes a specification document and agrees on it with you *before* writing any application code. The spec acts as a quality gate.
2. **Context retention.** Instead of relying on conversational history, which degrades over time and consumes many tokens, SDD externalizes memory into Markdown files such as `proposal.md` and `design.md`. The agent re-reads these documents to regain full context.
3. **Controlled scope.** The agent breaks the specification into an atomic checklist of tasks. It implements one slice at a time, testing and verifying at every boundary.
4. **Anti-rationalization.** Uncle Dev skills include anti-rationalization tables. If an agent tries to say "This is too small for a test, I'll skip it," the skill overrides that behavior and keeps discipline intact.
