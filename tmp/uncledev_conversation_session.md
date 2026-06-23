# Uncle Dev Content Exploration Session

Yes. I do have prior context about Uncle Dev, and your clarification matches what I remember.

My current understanding is that Uncle Dev is:

- A plugin/harness for agentic development tools, including Claude Code, Codex, Copilot, Windsurf, OpenCode, and similar tools.
- Intended to guide and execute development from requirements using a spec-driven approach.
- Portable across different AI coding environments instead of being tied to one vendor.
- Built around reusable skills, rules, and companions.
- Evolving beyond code generation into a Product Behavioral Operating System, where behavior and specifications come before implementation.

I also remember related concepts:

Uncle Domain

The product and domain companion that analyzes:

- Requested changes
- Current vs expected behavior
- Bugs and regressions
- Business rules
- Platform drift

It acts as the behavioral source of truth.

Uncle Expert

A configurable specialist that can load:

- Domain packs
- Framework packs
- Operational skills
- Policies and rules
- Behavior maps

Product Mode

The workflow is:

Behavior
↓
Product Intent
↓
Domain Rules
↓
Traceability
↓
Platform Alignment
↓
Specification
↓
Architecture
↓
Code
↓
Tests

Skills

I also remember recent discussions around:

- Observability skill
  - Identifies where business and operational metrics are valuable.
  - Avoids over-instrumenting every class or method.
  - Delegates implementation to project-specific telemetry companions through something like uncledev.config.yaml.
- Research skill
- Apply Comments skill
- Visual Spec
- Shared skills that can be installed across multiple agentic tools.

So, my current mental model is:

Uncle Dev is a portable plugin ecosystem that provides a common harness, skills, workflows, and behavioral intelligence for agentic coding tools (Claude Code, Copilot, Windsurf, Codex, etc.), allowing them to operate with a shared spec-driven and product-driven methodology.

That aligns with what you just described.

---

---

I think the tone should be more like a product launch than a blog post. Short sentences. Clear benefits. A memorable ending.

Uncle Dev is an open plugin framework for AI coding tools.

It brings reusable engineering skills, workflows, and best practices to tools like Claude Code, Copilot, Windsurf, Codex, and others, helping teams turn ideas into production-ready software with more consistency and less friction.

Unlike traditional frameworks, Uncle Dev adapts to the way you work. You can customize everything, combine it with external plugins, or completely replace built-in skills with your own. Your team’s knowledge, standards, and workflows become reusable building blocks that work across agents and tools.

You don’t have to change your process to fit the tool. The tool adapts to fit your process.

- Tool agnostic — works across multiple AI coding assistants.
- Extensible — integrate community plugins, company plugins, or custom skills.
- Replaceable — swap commands and skills with the ones you prefer.
- Reusable — capture engineering knowledge once and use it everywhere.
- Customizable — make it fit your team, your stack, and your standards.
- Scalable — create a shared engineering system that grows with your organization.

Uncle Dev transforms AI coding assistants from isolated code generators into customizable engineering partners.

Build your own engineering system. Not someone else’s.

---

---

This addition strengthens the message because it emphasizes interoperability without lock-in. I’d phrase it like this:

Uncle Dev

Uncle Dev is an open plugin framework for AI coding tools.

It brings reusable engineering skills, workflows, and best practices to tools like Claude Code, Copilot, Windsurf, Codex, and others, helping teams turn ideas into production-ready software with more consistency and less friction.

Unlike traditional frameworks, Uncle Dev adapts to the way you work. You can customize everything, combine it with external plugins, or completely replace built-in skills with your own. Your team’s knowledge, standards, and workflows become reusable building blocks that work across agents and tools.

Uncle Dev also integrates seamlessly with the broader ecosystem. Plugins such as Team PR, Local Search, Graphify, and other companion tools work out of the box to provide richer reviews, code understanding, and search capabilities. When those plugins aren’t available, Uncle Dev gracefully falls back to the native capabilities of your AI coding assistant and development environment. No special configuration. No hard dependencies. Just a better experience when the ecosystem is present.

You don’t have to change your process to fit the tool. The tool adapts to fit your process.

Key Features

- Tool agnostic — works across multiple AI coding assistants.
- Plugin-first — seamlessly integrates with Team PR, Local Search, Graphify, and other ecosystem plugins.
- Graceful fallback — automatically uses the native review, search, and analysis capabilities provided by your coding assistant when external plugins are unavailable.
- Extensible — integrate community plugins, company plugins, or custom skills.
- Replaceable — swap commands and skills with the ones you prefer.
- Reusable — capture engineering knowledge once and use it everywhere.
- Customizable — make it fit your team, your stack, and your standards.
- Scalable — create a shared engineering system that grows with your organization.

Uncle Dev transforms AI coding assistants from isolated code generators into customizable engineering partners.

Build your own engineering system. Not someone else’s.

I think “No lock-in. No hard dependencies. Your tools, your workflows, your rules.” could become one of the core taglines. It reinforces the idea that Uncle Dev augments existing tools instead of replacing them.

---

---

I like that. It’s short, memorable, and reinforces the philosophy of no lock-in and customization.

Uncle Dev

Uncle Dev is an open plugin framework for AI coding tools.

It brings reusable engineering skills, workflows, and best practices to tools like Claude Code, Copilot, Windsurf, Codex, and others, helping teams deliver production-ready software with greater consistency and less friction.

Built around openness and customization, Uncle Dev adapts to the way you work—not the other way around. Extend it with your own skills, integrate third-party plugins, or replace built-in commands entirely. Your team’s knowledge, standards, and workflows become reusable building blocks that work across agents and tools.

Uncle Dev integrates seamlessly with ecosystem plugins such as Team PR, Local Search, Graphify, and other companions. When these plugins are available, they are used automatically. When they’re not, Uncle Dev gracefully falls back to the native review, search, and analysis capabilities already available in your AI coding assistant and development environment. No hard dependencies. No lock-in. Just a better experience.

Key Features

- Tool agnostic — Works with multiple AI coding assistants.
- Plugin-first — Seamlessly integrates with Team PR, Local Search, Graphify, and other ecosystem plugins.
- Graceful fallback — Uses native capabilities when plugins are unavailable.
- Extensible — Add community, company, or custom plugins.
- Replaceable — Use the commands, skills, and workflows you prefer.
- Reusable — Capture engineering knowledge once and use it everywhere.
- Customizable — Adapt it to your team, stack, and standards.
- Scalable — Build a shared engineering system that grows with your organization.

Uncle Dev transforms AI coding assistants from isolated code generators into customizable engineering partners.

No lock-in.

Your process. Your tools. Your rules.

I actually think the ending is strong enough that it can stand alone on a slide:

No lock-in.
Your process. Your tools. Your rules.

Three short lines. Easy to remember. Easy to repeat. Perfect for a conference or launch announcement.

---

---
