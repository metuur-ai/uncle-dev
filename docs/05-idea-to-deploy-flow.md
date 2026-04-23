# 5. The Flow: From Idea to Deploy

The Uncle Dev lifecycle enforces a strict sequence of events. Each phase must be completed before moving to the next.

```text
  DEFINE            PLAN           BUILD          VERIFY         REVIEW          SHIP
 ┌──────┐      ┌──────────┐     ┌──────┐      ┌──────┐      ┌──────┐      ┌──────┐
 │ Idea │ ───▶ │ OpenSpec │ ───▶ │ Code │ ───▶ │ Test │ ───▶ │  QA  │ ───▶ │  Go  │
 │Refine│      │  Change  │     │ Impl │      │Debug │      │ Gate │      │ Live │
 └──────┘      └──────────┘     └──────┘      └──────┘      └──────┘      └──────┘
   /spec           /plan          /build        /test         /review       /ship
```

### Phase 1: Idea Refinement
Before you even touch code, you might need help figuring out *what* to build. Using the `uncle-dev-idea-refine` skill, you and the AI agent challenge assumptions, discover risk factors, and settle on a minimum viable product configuration.

### Phase 2: Define (`/uncle-dev-spec`)
Instead of beginning implementation, the AI agent authors a strict `proposal.md` and `design.md` stored inside the `openspec/changes/` directory. The developer reads the architecture, the database schema design, and the edge cases. Once the human developer approves, you move forward.

### Phase 3: Plan (`/uncle-dev-plan`)
The agent takes the approved spec and decomposes it into shared story-level tasks (`tasks.md`). It also sets up a temporary checklist inside `.devlocal/` to track its own implementation steps. At this stage, you now have a step-by-step roadmap to completion.

### Phase 4: Build (`/uncle-dev-build`)
The agent executes code implementation one vertical slice at a time. This phase automatically kicks off skills like `uncle-dev-incremental-implementation`, `uncle-dev-frontend-ui-engineering`, and `uncle-dev-api-and-interface-design` depending on what part of the stack is being touched.

### Phase 5: Verify (`/uncle-dev-test` & Debugging)
The AI writes unit, integration, and end-to-end tests to verify its build slice. If the tests break, it pivots to the `uncle-dev-debug-error` skill. It uses a scientific method to reproduce, localize, reduce, and fix bugs rather than blindly guessing syntax updates.

### Phase 6: Review (`/uncle-dev-review`)
Before committing, the agent dons the persona of a Senior Staff Engineer. It scans the diff using the `uncle-dev-code-review-and-quality` and `uncle-dev-security-and-hardening` frameworks, assigning NIT, Optional, or Block tags to its own code and refactoring appropriately. (This is also the phase to invoke `/uncle-dev-code-simplify`).

### Phase 7: Ship (`/uncle-dev-ship`)
The feature reaches completion. The agent updates main `openspec/specs/` to reconcile the changes, manages deprecation lifecycles if necessary, ensures the test pipeline passes, and prepares deployment configurations.
