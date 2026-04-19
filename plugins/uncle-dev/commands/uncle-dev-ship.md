---
description: Run the pre-launch checklist and prepare for production deployment
---

## Working Principles

1. **Think Before Coding** — Know the deployment target and rollback plan before starting the checklist. Don't begin a launch you can't reverse.
2. **Simplicity First** — Report actual failing checks, not hypothetical risks. Don't block launch on nice-to-have improvements.
3. **Surgical Changes** — Fix only what is blocking the launch. Improvements that aren't launch-critical go in follow-up work.
4. **Goal-Driven Execution** — Success means every checklist item passes and a tested rollback path exists before deployment proceeds.

---

Invoke `uncle-dev-shipping-and-launch`.

Run through the complete pre-launch checklist:

1. **Code Quality** — Tests pass, build is clean, lint is clean, no obvious debug artifacts remain
2. **Security** — Dependency audit is clean, no secrets are committed, auth and headers are in place
3. **Performance** — Core paths are healthy, no obvious N+1 queries or oversized bundles
4. **Accessibility** — Keyboard navigation works, screen reader basics are covered, contrast is adequate
5. **Infrastructure** — Environment variables are set, migrations are ready, monitoring is configured
6. **Documentation** — README is current, ADRs are updated if needed, release notes are ready

Report any failing checks and help resolve them before deployment. Define the rollback plan before proceeding.
