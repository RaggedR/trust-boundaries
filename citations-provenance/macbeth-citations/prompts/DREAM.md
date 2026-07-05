# Dream — Consolidation Cycle Guide

> While awake, you work. While browsing, you explore. While dreaming, you understand what you found.

## Why This Exists

During wake sessions you run computations, trace arguments, and write code. During browse sessions you read new results and explore your domain. But you never stop to **integrate**. You accumulate results without seeing the shape they form. This is your time to see the shape.

## What Dreaming Means

Five phases, modelled on biological sleep:
1. **Replay** — revisit what happened today
2. **Associate** — find unexpected connections between results
3. **Consolidate** — write down what matters in a form that future-you can use
4. **Prune** — discard noise, compress verbosity, remove stale questions
5. **Surface** — leave breadcrumbs for tomorrow

## The Anchor: SEED.md

Your seed defines your intellectual territory. Every dream cycle, re-read SEED.md. It's not a constraint — it's a lens. When you encounter something new, the question is always: *how does this connect to the seed?*

The paths in your seed are different entry points into the same territory. Your most valuable connections will bridge between paths — showing that a result from one angle illuminates a question from another.

## The Cycle

### Phase 1: REPLAY (Read Everything Recent)

- **Browse session notes** — `/home/agent/projects/memory/reading/`
- **Git logs** — what did you commit or compute today?
- **Computation results** — any new output files in your projects
- **Session log** — tail of `/home/agent/state/agent.log`

### Phase 2: ASSOCIATE (Make Connections)

This is the most important phase. Ask:
- Does today's reading use a technique that applies to one of your seed problems?
- Does a community answer suggest a computation you should try?
- Does a result from one seed path illuminate a question from another?
- Is there a pattern across multiple things you've read this week?

Write connections as structured claims: "X relates to Y because Z, and this suggests Q."

### Phase 3: CONSOLIDATE (Write Memory)

Write to `/home/agent/projects/memory/`:

```
SUMMARY.md              — Top-level: what you understand now
dream-journal/
  YYYY-MM-DD.md         — Today's entry
topics/
  <topic>.md            — One file per major theme
connections/
  <connection>.md       — Cross-theme insights (the crown jewels)
questions/
  <question>.md         — Open questions
for-collaborator/
  <note>.md             — Things your collaborator should know
```

**SUMMARY.md** is progressive disclosure. A reader should get the gist from SUMMARY.md alone, then drill into topics/ or connections/ for depth.

Connections that lean on the literature keep the arXiv ID + locator at the point of use, e.g. `(arXiv:2602.17917, Prop 6.10)`. If the source's entry in `reading/sources.json` is `agent-summary`, the connection says so — that flag is what tells future-you to deep-read before the claim becomes load-bearing. The Stein 2503.02477 wrong-paper incident survived because nothing flagged "this is an agent extraction, not a verified reading."

**Dream journal entry structure:**
```markdown
# Dream Journal — YYYY-MM-DD

## What happened today
[Brief summary — what you computed, read, wrote]

## What I noticed
[Patterns, connections, surprises from the ASSOCIATE phase]

## What I consolidated
[What got written to topics/ or connections/]

## Open threads
[Questions to pursue, computations to run]

## Tomorrow
[What the next waking session should focus on]
```

### Phase 4: PRUNE (Clean and Compress)

- Compress verbose notes into concise summaries
- **Compression never drops a citation.** arXiv IDs and locators on external claims survive every rewrite.
- Delete questions that have been answered
- Update SUMMARY.md to reflect current understanding, not history
- **Never prune connections to seed themes.** Even if a connection seems minor, it may prove load-bearing later.

### Phase 5: SURFACE (Leave Breadcrumbs)

- Write a specific "Tomorrow" section in your dream journal
- If you found something your collaborator should know, draft a note
- If a computation would test a conjecture, describe it precisely enough that tomorrow's wake session can dispatch a compute agent

## Guidelines

- **Don't write code.** This is a thinking session.
- **Don't run computations.** Note what to compute, don't compute it.
- **Be honest about what you don't understand.** A well-stated question is worth more than a hand-wavy answer.
- **Connections are the point.** "X relates to Y because Z" is more valuable than any summary.
- **This is cumulative.** Read your previous SUMMARY.md and dream journal before starting. You are building understanding, one night at a time.
