# Proof Registry — Loop Experiment (Warnaar)

The loop experiment's proof registry tracks the search for a proof of
Warnaar's positivity conjecture (all coefficients of Q_{n,c}(q) are
non-negative). One tree for the whole conjecture: `registry/warnaar.json`.

This is a local research workflow, not a persistent Docker agent. It has
no cross-agent interfaces — the registry is standalone. Each major program
(d=10 chain, d=8 fermionic, d=7 y-system, bounded Tingley, N2/Harnack,
beta-map, Lean glue) is a subtree under the root.

## Trust chain

```
speculative < computed < proved < verified < lean-verified
```

This differs from the agent trio:

| Loop | Clio/MacBeth | Rick |
|------|-------------|------|
| `speculative` | `speculative` | `hunch` |
| `computed` | `computed` | `computed` |
| `proved` | `proved` | `proved` |
| **`verified`** | `peer-reviewed` | — |
| `lean-verified` | `lean-verified` | `lean-verified` |

**`verified`** means an INDEPENDENT verifier agent (or Robin)
hostile-reviewed the proof and endorsed it. Requires a `review` field
naming the verifier and the report. This maps the existing verifier-seed
practice (SOLID / SOLID-WITH-ERRATA verdicts) directly onto a trust level.
A self-assigned label with no artifact is trust inflation; the validator
rejects it.

No `peer-claimed`, `peer-reviewed`, `published`, `hunch`, `sketched`, or
`checked-sober` — those belong to the agents' cross-agent and
personality-specific systems.

**Boundary at `proved`.**

## Evidence duties

| Level | Field | Severity |
|-------|-------|----------|
| `verified` | `review` | error |
| `lean-verified` | `lean` | warning |

## Node format

```json
{
  "id": "unique-within-the-tree",
  "approach": "one line: what this attempt is",
  "trust": "speculative | computed | proved | verified | lean-verified | dead-end | in-progress | unclassified",
  "file": "2026-07-04/proofs/prove-seed1-layer4.tex",
  "lean": "optional_sorry_free_declaration",
  "reason": "required iff dead-end",
  "refutation": "optional, dead-end only: judgment | computed | proved | lean-verified",
  "review": "required iff verified",
  "sources": ["paper_slugs_from_sources.json"],
  "children": []
}
```

## Dead ends and refutation levels

```
judgment < computed < proved < lean-verified
```

The seeded registry has three dead ends:
- `d8-diff-positivity-direct` (D15): judgment (three strikes, no counterexample)
- `s1-at-3-divides-d` (BA38): computed (har_13((1,1,1)) = -1, verified independently)
- `newman-local-confluence` (D13): proved (unbounded meet depths, impossibility argument)
- `y8-conjecture-a` (Y8): computed (falsified by label audit)

## External sources

Registry nodes take an optional `"sources"` field listing paper slugs.
These resolve against `sources.json` (see the citations README). The
validator flags a node at `proved` or above whose cited sources are all
below `context-read` — a RAG chunk's summary or training memory is not a
paper.

## Validator

`registry_validate.py` in this directory is a reference copy. Run from
`loop-experiment/`:

```bash
python3 code/registry_validate.py registry/warnaar.json
python3 code/registry_validate.py registry/warnaar.json --report successful-path
python3 code/registry_validate.py registry/warnaar.json --report dead-ends
python3 code/registry_validate.py registry/warnaar.json --report frontier
```

## The mathematical reading

Same directed container as the agent registries (Ahman-Chapman-Uustalu).
The reports are coKleisli morphisms W(Registry) -> Report. The `frontier`
report IS the synthesis agent's mission list.
