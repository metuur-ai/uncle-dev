# 7. Templates and Prompts: By Skill

In the Uncle Dev plugin pack, skills can be explicitly invoked when you run into a specific niche problem that isn't tied directly to the main SDD flow sequence.

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
**Use after an excruciating debugging session to secure the win.**
> `We finally fixed the bug! Trigger uncle-dev-knowledge-capture.`
> Document the exact root cause of the [Bug description: caching race-condition we faced in Redis] and lay out the solution as a formal learning in `.uncle-dev/learns/`.

## Performance Optimization (`uncle-dev-performance-optimization`)
**Use when the application performs sluggishly.**
> `Use uncle-dev-performance-optimization.`
> The [Page Name: Product Listing] page is reporting bad Core Web Vitals, specifically LCP and CLS. Suggest a measurement strategy, help me profile the component's bundle, and identify React re-render anti-patterns or blocking scripts.
