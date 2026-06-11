---
name: uncle-dev-verbalized-sampling
description: >
  Applies Verbalized Sampling — asking for N distinct options each tagged by typicality —
  to escape mode collapse during analysis and spec generation. Defines the shared
  diverge → tag → converge → discard protocol and maps exactly where in the uncle-dev
  pipeline to inject it. Use when enumerating edge cases or failure modes, generating
  design alternatives for an LLD, checking an EARS spec for omitted requirements,
  brainstorming idea variations, or generating root-cause hypotheses — any moment where
  the first answer is likely the conventional one and the valuable answer is in the tail.
user-invocable: true
---

# Verbalized Sampling

## Overview

RLHF training rewards the conventional, safe answer. Ask a model for edge cases and it
lists the three obvious ones; ask for design alternatives and it backfills strawmen after
already choosing. This is **mode collapse**, and in spec work it has a price: the missed
edge case becomes a production bug discovered after the spec is locked, and the LLD's
"rejected alternatives" section becomes theater.

**Verbalized Sampling (VS)** breaks the collapse by asking for the *distribution* instead
of the instance: generate N **distinct** options and tag each by **typicality** — how
likely a typical answer to this prompt would include it. Forcing the tag pushes the model
past its first (modal) answer into the tail of its knowledge, where the missed edge cases
and genuine alternatives live.

uncle-dev is a **diverge → converge funnel** (`idea-refine → grill → spec → plan → build`).
VS amplifies the diverge steps only. The iron rule:

> **Tags drive divergence, then die at convergence. Nothing locked — EARS tables, PRDs,
> task lists, glossaries — ever carries a probability or typicality label.**

`uncle-dev-pre-mortem` is the existing proof this pattern works here: it already generates
8–12 unfiltered failure causes and scores them — VS with domain framing.

## When to Use

- Enumerating **edge cases / failure modes** during a grill or spec session
- Generating **design alternatives** before committing an LLD "Key Decisions" entry
- Running a **completeness check** on a drafted EARS spec before the HARD GATE
- Producing **idea variations** during ideation
- Generating **root-cause hypotheses** while debugging
- Any analysis step where you catch yourself accepting the first plausible enumeration

**When NOT to use:**

- Writing or editing **locked artifacts**: EARS statements, PRD decisions, committed tasks
- `uncle-dev-research` documentation passes — a documentarian describes what IS; the sole
  exception is reporting a genuinely ambiguous code path as "N possible readings"
- `uncle-dev-ubiquitous-language` — its job is convergence to one canonical term
- When options are externally fixed (config enums, API contracts) — there is no
  distribution to sample

## The Core Protocol

Every application follows the same four steps:

1. **Diverge** — "Generate N **distinct** {options} for {target}. Span different
   categories; do not stop at the obvious ones." Default N=4–6. Distinctness beats
   volume: 5 genuinely different options beat 12 paraphrases.
2. **Tag** — label each option `typical` / `less common` / `rare`: how likely a typical
   answer would include it. Use ordinal tags, **not numbers** — the model's
   self-estimates are uncalibrated, and `0.85` is false precision (see Gotchas).
3. **Converge** — the tags direct attention, they don't decide. Interrogate or
   stress-test the `rare` options explicitly — they are the ones mode collapse was
   hiding. Then let the existing skill's convergence mechanism (depth-first interview,
   stress-test, pre-mortem, HARD GATE) judge on merit.
4. **Discard** — the survivors enter the downstream artifact *without their tags*.
   Audit: `grep -ri "typical\|less common\|rare\|probability" docs/ears/ docs/prd/`
   should return nothing VS-shaped.

## Injection Map — where to add or complement uncle-dev analysis

Primary injection points, ranked by expected value. Each row is a step in an existing
skill where the model currently produces a single (modal) enumeration; the prompt column
is ready to use verbatim.

### 1. `uncle-dev-grill` — edge cases & failure modes (highest value)

**Where:** design-tree branch 5 ("Edge cases & failure modes"), before the depth-first walk.
**What improves:** the spec gaps. The depth-first interview is excellent at *resolving*
branches but only walks branches that get enumerated — and unaided enumeration is modal.

> Generate 6 distinct failure modes for this flow — span input, state, integration,
> timing, and human categories. Tag each typical / less common / rare. We interrogate
> the rare ones first, depth-first as usual.

The `rare` survivors are the requirements a conventional grill never surfaces. Apply only
to branch 5 (and branch 6 non-functionals if contentious) — running VS on all eight
branches turns a 40-question grill into interview fatigue.

### 2. `uncle-dev-spec-driven-development` / `uncle-dev-design-architecture-docs` — LLD alternatives

**Where:** before writing the LLD "Key Decisions" section; this gives the
"Design It Twice" guidance a concrete mechanism (and a third and fourth design).
**What improves:** decisions get tested against real competitors generated *before*
commitment, and the rejected-alternatives record becomes genuine instead of backfilled.

> Generate 4 distinct architectures satisfying these EARS requirements. Tag each
> typical / less common / rare and state why it is a valid pathway. Choose one; record
> the other three — with their rejection reasons — as the LLD's rejected alternatives.

(Rejection reasons survive into the LLD; the tags do not.)

### 3. EARS gap-check — completeness pass before the HARD GATE

**Where:** `uncle-dev-spec-driven-development`, after the EARS draft, alongside the
pre-mortem at the gate. The EARS statements themselves stay deterministic — VS aims
*at* the spec, not into it.
**What improves:** the omissions. This is the purest anti-mode-collapse move: it asks
directly "what did the safe answer leave out?"

> Read the drafted EARS spec. Generate 5 requirements that a typical spec for this kind
> of feature omits, ranked by how likely the omission causes a production bug. Surface
> the top 3 for the user to accept or reject before locking.

### 4. `uncle-dev-idea-refine` — tag the existing divergence

**Where:** Phase 1 already generates 5–8 lensed variations; it just doesn't tag them.
**What improves:** Phase 2's convergence gains a signal for which variation is the
mode-collapsed default vs genuinely novel — and one rule: deliberately stress-test at
least one `rare` direction instead of converging on the safest cluster. Keep the
existing 5–8 cap; VS wants distinct, not many.

### 5. `uncle-dev-pre-mortem` — enforce the diversity it already implies

Already VS-shaped (8–12 unfiltered causes + Likelihood/Impact scoring). The complement:
require that the causes span the typicality range —

> Include at least 2 failure modes a typical pre-mortem for this kind of plan would
> not list.

### Complementary applications (apply ad hoc, no skill changes required)

| Skill / moment | VS application |
|---|---|
| `uncle-dev-debug-error` — before committing to a root cause | Generate 4 distinct root-cause hypotheses spanning code, data, environment, and timing; tag by typicality; design the cheapest experiment that discriminates between the top two before fixing the obvious one. |
| `uncle-dev-feature-map` / `uncle-dev-brownfield` — ambiguous behavior | When code supports multiple readings, report 2–3 distinct interpretations with typicality tags in Open Questions, instead of silently picking the modal reading. |
| `uncle-senior` Challenge mode | Generate 3 distinct framings of the proposal (as stated, inverted, 10x-simpler) before issuing the verdict — guards the verdict itself against mode collapse. |
| Test design (`uncle-dev-test`) | Enumerate N distinct ways the implementation could satisfy the test yet still be wrong; tag; add the rare ones as extra cases. |

## Gotchas

- **The tags are uncalibrated.** A verbalized "probability" is a model self-estimate,
  not a measured frequency — its only legitimate jobs are (a) forcing generation past
  the mode and (b) showing the human which options are safe defaults vs unexplored tail.
  This is why the protocol mandates ordinal tags over numbers.
- **Diversity is not quality.** A `rare` option is not a good option; it is an
  *unexamined* one. VS only works because uncle-dev's convergence gates exist to judge
  what it surfaces. Never skip the converge step.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I already listed several edge cases, that's diverse enough" | Unforced enumeration is modal — the first 3 items are the ones every spec lists. The tag requirement is what pushes generation into the tail. |
| "Numbers are more precise than typical/rare labels" | The numbers are uncalibrated self-estimates. 0.85 vs 0.80 encodes nothing; it just looks rigorous. Ordinal tags are honest about the resolution. |
| "Keeping the scores in the spec preserves useful information" | A locked artifact with probabilities is an unresolved decision wearing a costume. Convergence means choosing; tags die at the gate. |
| "More options is better — generate 15" | Past ~6, options stop being distinct and start being paraphrases. Distinctness across categories is the diversity that matters. |
| "VS everywhere — run it on every grill branch" | Divergence has a cost (interview fatigue, token burn). Inject at the mapped points where mode collapse is expensive; skip where the answer space is small or externally fixed. |

## Red Flags

- A typicality tag, probability, or confidence score appearing in an EARS table, PRD,
  glossary, or task list (score leakage past convergence)
- Numeric probabilities (`0.85`) presented to the user as if calibrated
- N options that are paraphrases of one idea rather than category-distinct
- Converging on the `typical` option every time without interrogating any `rare` one
  (VS performed as ritual, ignored as signal)
- Applying VS inside a documentarian pass (`uncle-dev-research`) as evaluation
- Replacing a convergence mechanism with the tags ("highest typicality wins")

## Verification

After applying VS at any injection point:

- [ ] Each generated option set spans distinct categories (not paraphrases)
- [ ] Tags are ordinal (`typical` / `less common` / `rare`), not numeric probabilities
- [ ] At least one `rare` option was explicitly interrogated or stress-tested
- [ ] The downstream artifact (EARS, PRD, LLD decision, task) contains **zero**
      typicality/probability language — survivors entered untagged
- [ ] The existing skill's own convergence gate (depth-first resolution, stress-test,
      pre-mortem, HARD GATE) still ran — VS supplemented it, never replaced it
