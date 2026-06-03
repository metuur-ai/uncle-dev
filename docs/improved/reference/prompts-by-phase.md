---
sidebar_position: 2
---

# 6. Templates and Prompts: By Phase

Use these prompt templates to run the core Uncle Dev slash-command lifecycle inside your agent chat. Copy a template, then fill in the bracketed placeholders.

## Phase 1: Define (`/uncle-dev-spec`)
**Goal:** Generate architecture, schema, and API boundaries.
> `/uncle-dev-spec`
> We need to build a new feature: [Feature Description: e.g., a real-time notification dropdown in the navbar]. 
> Key constraints: 
> 1. [Constraint 1: Must use WebSockets]
> 2. [Constraint 2: Must gracefully degrade on bad network connections]
> Create the proposal and design specs in `openspec/changes/`.

## Phase 2: Plan (`/uncle-dev-plan`)
**Goal:** Break the design down into actionable atomic checklists.
> `/uncle-dev-plan`
> Based on the approved design we just created for the [Feature name] feature, break this down into actionable, atomic tasks. Put the high-level tasks in the OpenSpec folder, and initialize a scratchpad execution checklist for yourself in `.devlocal/`.

## Phase 3: Build (`/uncle-dev-build`)
**Goal:** Write iterative vertical slices.
> `/uncle-dev-build`
> Let's implement Task [X] from our execution plan: [Task Name, e.g., "Build the backend WebSocket handler"]. Please slice this implementation thinly. Focus on safe defaults and do not move on to the next task until we have confirmed this slice works.

## Phase 4: Verify (`/uncle-dev-test`)
**Goal:** Prove the code works via tests.
> `/uncle-dev-test`
> Based on the code slice we just built, implement tests following the Testing Pyramid strategy. Ensure you have mocked the [External Service/Database Hook] and focus on edge cases like [Specific Edge Case: network timeouts]. Run the tests and confirm they pass.

## Phase 5: Review (`/uncle-dev-review`)
**Goal:** Quality gate before a merge.
> `/uncle-dev-review`
> Act as a Senior Staff Engineer and review the uncommitted changes for this codebase. Perform a 5-axis review focusing heavily on performance, readability, and security gaps. Let me know what needs fixing before we commit.
> 
> *(Optional cleanup)*: `/uncle-dev-code-simplify` Apply the Rule of 500 to the `[File name]` module. The logic is too hard to read. Simplify it while strictly maintaining exact behavior.

## Phase 6: Ship (`/uncle-dev-ship`)
**Goal:** Merge and deploy.
> `/uncle-dev-ship`
> The feature is complete. Help me walk through our pre-launch checklist. Reconcile our updates from the change artifact back into the main `openspec/specs/` directory to update our core documentation, and write a detailed commit message.
