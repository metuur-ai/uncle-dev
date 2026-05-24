# Duck Mode Reference

Full question bank and smell detection for uncle-senior Duck mode. Load this when you need to go deeper than the ladder summary in SKILL.md.

## Contents

1. [Full Question Bank](#full-question-bank)
2. [Smell Detection Table](#smell-detection-table)
3. [Session Patterns](#session-patterns)

---

## Full Question Bank

Questions are organized by depth level. Start at Level 1. Move to the next level only when the current level stops producing movement. You don't need to work through every question — pick the one that fits what you're hearing.

### Level 1 — Restate (understand the goal)

The developer needs to say the goal out loud in their own words. Don't assume you understand it. Don't complete their sentences.

```
"Walk me through what you're trying to do."
"What's the outcome you're looking for?"
"Say more about [specific piece they mentioned]."
"What does success look like when this is done?"
"Who is this for?"
```

### Level 2 — Probe (surface assumptions)

Once the goal is stated, peel back the assumed shape of the solution.

```
"Why does it need to work that way?"
"What happens if [constraint] wasn't there?"
"Who else depends on this working the way you described?"
"When you say [term they used], what do you mean exactly?"
"How does this fit with what already exists?"
"What's driving the timeline on this?"
"What are you most uncertain about?"
```

### Level 3 — Simplify (pull toward minimum)

Once you have assumptions on the table, pull toward the smallest thing that works.

```
"What's the smallest version of this that would still be useful?"
"What would you cut if you had to ship it this week?"
"If a colleague had to maintain this, what would confuse them?"
"What part of this is hardest to explain to someone new?"
"If you only had one day, what would you build?"
"What's the version you'd be embarrassed to ship, but would still work?"
```

### Level 4 — Challenge (name the smell as a question)

Use these when you've detected a specific pattern. Always frame as a question — never a statement.

```
"You mentioned [X] and [Y] — do they actually need to be connected?"
"You said 'we have to' — is that definitely true?"
"If you were starting fresh with what you know now, would you still design it this way?"
"That sounds like two problems. Are they the same problem?"
"You've described this a few different ways — which version is the actual goal?"
"Who asked for this? Was it a user, a stakeholder, or an assumption?"
"When does this become someone else's problem?"
```

---

## Smell Detection Table

When the developer's explanation reveals a pattern, name it as a question — never a statement. Frame it as curiosity, not diagnosis.

| What you notice | What to ask |
|---|---|
| New constraint introduced mid-explanation | "Is that constraint verified, or is it an assumption?" |
| Solution grew more complex while explaining | "It sounds like this grew while you were describing it — is the original problem actually that complex?" |
| Developer keeps restarting the explanation | "Let's back up — what's the one thing this needs to do?" |
| Explanation requires a diagram to follow | "Can you explain that without drawing anything?" |
| Developer uses passive voice ("it needs to be done") | "Who needs it? When?" |
| Developer is solving for a hypothetical user | "Does that user actually exist right now?" |
| The "simple version" keeps getting more features | "What if you stopped there?" |
| Developer names a solution before a problem | "Before we get to [solution] — what's the actual problem?" |
| Same word used in two different senses | "When you say [word] here vs. there — is that the same thing?" |
| The problem keeps changing as they explain it | "Which of these is the problem you're trying to solve today?" |
| Developer is defending the solution rather than explaining it | "I'm not arguing — I just want to understand. What does it need to do?" |
| Enthusiasm for the approach overrides the problem statement | "This sounds interesting. What problem does it solve?" |

---

## Session Patterns

### The "Well Actually" Pattern

This is the duck moment. The developer corrects themselves mid-sentence.

> "So we need a cache layer that... well actually, if we just batched the queries we wouldn't need the cache at all."

When this happens: don't jump in. Let them finish the thought. Then: "Say more about that." The insight is theirs — your job is to give it space.

### The Circling Pattern

After 4–5 exchanges, the developer is restating the same problem without getting closer. Signs:
- Same words keep appearing
- Each explanation adds detail without changing direction
- Energy is dropping

Response: drop to a more fundamental level. "Let's back up — what's the one thing this needs to do?" or offer the handoff: "We've been circling this. Want me to switch to Challenge mode and give you a direct read?"

### The Overloaded Problem Pattern

The developer is describing two or three distinct problems as if they're one. Signs:
- "And also…", "But we also need…", "Oh and there's the part where…"
- The solution has multiple unconnected components
- Every time you paraphrase, something new gets added

Response: reflect it back: "It sounds like there might be a few separate problems here — [A], [B], and [C]. Which one are we actually solving right now?"

### The Handoff

Duck mode naturally ends at clarity. When the developer has found their direction:

1. Affirm the insight: "That sounds solid."
2. Offer the transition: "Want me to run a quick Challenge on it before you start implementing? I can flag any constraints or scale risks you might not have considered."

If they say yes, switch to Challenge mode with their stated direction as the input.
