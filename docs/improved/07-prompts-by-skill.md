# 7. Templates and Prompts: By Skill

In the Uncle Dev plugin pack, you can invoke skills explicitly when you hit a specific problem that falls outside the main SDD lifecycle.

## Idea Refinement (`uncle-dev-idea-refine`)
**Use when refining a rough idea before you spec it.**
> `Use the uncle-dev-idea-refine skill.`
> I have a rough idea for [Idea: a real-time collaborative dashboard] but I'm not sure about the [Aspect: backend architecture]. Help me stress-test the assumptions and find the riskiest parts.

## Frontend UI Engineering (`uncle-dev-frontend-ui-engineering`)
**Use when building accessible, responsive UI.**
> `Use the uncle-dev-frontend-ui-engineering skill.`
> I need to build a responsive [Component: Dashboard Sidebar] component. Ensure that it aligns with our current design tokens, passes WCAG 2.1 AA accessibility (keyboard navigation and ARIA), and manages state cleanly without unnecessary top-level re-renders.

## API and Interface Design (`uncle-dev-api-and-interface-design`)
**Use when designing module boundaries, APIs, or database interactions.**
> `Invoke uncle-dev-api-and-interface-design.`
> Help me design the REST endpoints for a [Service/Feature: shopping cart checkout service]. Apply contract-first design principles. What should the request payloads, response bodies, and specific HTTP error semantics look like?

## Context Engineering (`uncle-dev-context-engineering`)
**Use when the AI agent starts losing track of what it's doing.**
> `Invoke uncle-dev-context-engineering.`
> We're shifting focus from the backend architecture to the frontend UI. Let's dump our current context limit. Please retrieve the necessary architectural rules from `openspec/specs/` relevant to the UI state management and summarize our current execution steps so we can continue cleanly.

## Browser Testing with DevTools (`uncle-dev-browser-testing-with-devtools`)
**Use when there is a runtime bug on the web interface.**
> `Trigger uncle-dev-browser-testing-with-devtools.`
> The web application is throwing an error when I try to submit the [Form: Payment configuration] form. Use the MCP to inspect the DOM state during the click, read the console logs, and review the failed network payloads. Describe the issue.

## Security & Hardening (`uncle-dev-security-and-hardening`)
**Use when touching auth, payments, or sensitive data.**
> `Run the uncle-dev-security-and-hardening skill.`
> Review the new [File: user-session.ts] API route we just created. Audit it for OWASP Top 10 vulnerabilities, ensure database interactions are parameterized against SQL injection, and review boundary validation logic.

## Knowledge Capture (`uncle-dev-knowledge-capture`)
**Use after a difficult debugging session to capture the solution.**
> `We fixed the bug. Trigger uncle-dev-knowledge-capture.`
> Document the exact root cause of the [Bug description: caching race-condition we faced in Redis] and lay out the solution as a formal learning in `.uncle-dev/learns/`.

## Performance Optimization (`uncle-dev-performance-optimization`)
**Use when the application performs sluggishly.**
> `Use uncle-dev-performance-optimization.`
> The [Page Name: Product Listing] page is reporting bad Core Web Vitals, specifically LCP and CLS. Suggest a measurement strategy, help me profile the component's bundle, and identify React re-render anti-patterns or blocking scripts.

## Graphify-Aware Analysis (`uncle-dev-graphify-aware-analysis`)
**Use to understand how semantic graph queries work, interpret confidence levels, or decide whether to use hyperedges. Requires `graphify-out/graph.json` to be built first.**

> *(Enable graph-first search for any research task):*
> I've just run `/graphify` on this project. Use `uncle-dev-graphify-aware-analysis` to check availability and run graph-first orientation before we start researching the [Module/Feature] area.

> *(Architecture impact query):*
> Before we spec the [Feature] change, run a graphify scope mapping. Use `graphify explain "[PrimaryModule]"` and read GRAPH_REPORT.md to identify god nodes and community boundaries the change might touch.

> *(Debug with graph):*
> The [Module] is failing intermittently and has few obvious pairwise callers. Check whether it belongs to a flow hyperedge in `graphify-out/graph.json` — that might explain the cross-cutting blast radius.

> *(Story boundary detection):*
> Before writing tasks.md, read the graphify hyperedges for the [Feature Area] to see if there are named flows that map naturally to stories.
