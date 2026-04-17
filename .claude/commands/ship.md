---
description: Run the pre-launch checklist and prepare for production deployment
---

## Working Principles

1. **Think Before Coding** — Know the deployment target and rollback plan before starting the checklist. Don't begin a launch you can't reverse.
2. **Simplicity First** — Report actual failing checks, not hypothetical risks. Don't block launch on "nice to have" improvements.
3. **Surgical Changes** — Fix only what is blocking the launch. Improvements that aren't launch-critical go in a follow-up task.
4. **Goal-Driven Execution** — Success means every checklist item passes and a tested rollback path exists before deployment proceeds.

---

Invoke the agent-skills:shipping-and-launch skill.

Run through the complete pre-launch checklist:

1. **Code Quality** — Tests pass, build clean, lint clean, no TODOs, no console.logs
2. **Security** — npm audit clean, no secrets in code, auth in place, headers configured
3. **Performance** — Core Web Vitals good, no N+1 queries, images optimized, bundle sized
4. **Accessibility** — Keyboard nav works, screen reader compatible, contrast adequate
5. **Infrastructure** — Env vars set, migrations ready, monitoring configured
6. **Documentation** — README current, ADRs written, changelog updated

Report any failing checks and help resolve them before deployment.
Define the rollback plan before proceeding.
