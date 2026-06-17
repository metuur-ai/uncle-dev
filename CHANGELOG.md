# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_Commit `045f983` (2026-06-02) — new skills for refactoring, design-concept synthesis, and ubiquitous language, plus the supporting wiring._

### Added

- **`uncle-dev-grill` skill** — builds a shared design concept by relentlessly interviewing the user (depth-first design-tree walk, no fixed question cap) and synthesizing the answers into a PRD that feeds `uncle-dev-spec`. New Define-phase entry.
- **`uncle-dev-ubiquitous-language` skill** — builds and maintains a DDD-style domain glossary (`docs/ubiquitous-language.md`) via codebase-scan or conversation mode, flagging ambiguities and synonyms; loaded as context during spec and planning. New Define-phase entry.
- **`request-refactor-plan` reference** (under `uncle-dev-dev-code-simplification`) — interviews the user and breaks a large refactor into a tiny-commit plan.
- **`design-an-interface` reference** (under `uncle-dev-dev-code-simplification`) — "Design It Twice": generates and compares radically different interface shapes by module depth.
- **Module Depth** section in `uncle-dev-api-and-interface-design` — deep vs shallow modules, with an AI-navigability rationale, rationalizations, a red flag, and a verification item.
- **Research docs** in `.uncle-dev/research/` — software-fundamentals principles mapping and the corresponding improvement plan.
- **Draft skills** staged under `tmp/` — `edit-article`, `to-prd`, and `improve-codebase-architecture` (with `DEEPENING.md`, `HTML-REPORT.md`, `INTERFACE-DESIGN.md`, `LANGUAGE.md`).

### Changed

- **`uncle-dev-dev-code-simplification`** — added an "Escalating Beyond Inline Simplification" section that routes interface-shape problems to `design-an-interface` (design phase) and too-large refactors to `request-refactor-plan` (build phase).
- **Glossary integration** — `uncle-dev-spec-driven-development` and `uncle-dev-planning-and-task-breakdown` now load the ubiquitous-language glossary and flag off-glossary terms.
- **Cross-phase wiring** — `design-architecture-docs` points to `design-an-interface` for uncertain module boundaries; `incremental-implementation` and `planning-and-task-breakdown` point to `request-refactor-plan` for large refactors.
- **Framing** — named "software entropy" in `dev-code-simplification`; added gray-box risk-tiering (strategic architect / tactical programmer) to `design-architecture-docs`; `idea-refine` now hands off to `grill`.
- **Code review** — added a module-depth check to the Architecture axis of `uncle-dev-code-review-and-quality`.
- **Registration** — added the two new skills to both marketplace manifests, the Define phase in `CLAUDE.md`, and `scripts/setup-project.sh`.

## [1.4.0] - 2026-05-30

_Commits `276f84b`, `a8c6754`, `6692486`._

### Added

- **`uncle-dev-custom-me` skill** — scaffolds user-authored override and companion skills, printing the YAML registration block for both modes. Includes companion/override templates and the `uncle-dev-load-skill.sh` loader that resolves active skills and companions from user config.
- **Durable-project-rules best practice** — `.uncle-dev/learns/best-practices/durable-rules-go-to-tracked-files-not-memory-2026-05-30.md`, guidance on putting durable rules in tracked files rather than memory.

### Changed

- Removed the "Documentation Index" section from SKILL.md files and refreshed descriptions across multiple skills.
- Bumped version to `1.4.0` across plugin manifests, install scripts, and related paths.

## [1.3.0]

_Baseline preceding `6692486` (overrides/companions support was added on top of this version)._

[Unreleased]: https://github.com/javierhbr/production-grade-agent-skills/compare/276f84b...HEAD
[1.4.0]: https://github.com/javierhbr/production-grade-agent-skills/compare/6692486~1...276f84b
[1.3.0]: https://github.com/javierhbr/production-grade-agent-skills/releases/tag/v1.3.0

this repo https://github.com/javierhbr/production-grade-agent-skills. its a fork from https://github.com/addyosmani/agent-skills .
the remote repo have https://github.com/addyosmani/agent-skills/releases and I want to know that change from version 0.5.0 til the latest version.
