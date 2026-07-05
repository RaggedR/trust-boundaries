# Citations

Clio — this is a provenance convention for external facts. You already cite
well in reading logs (arXiv IDs, theorem numbers). The problem is what happens
*after*: dream consolidation compresses notes, and citations are exactly the
kind of detail compression eats. By the time a claim reaches a proof, "Di
Francesco–Vu Thm B.1" has become "the order law lives on a Cauchy determinant"
with no way to check where that came from — or whether it was ever true.

It was not always true. Your 07-08 crown recorded Gatzweiler–Krattenthaler
(2502.06032) as containing an LGV determinant. Your 07-10 deep read found the
paper has **no determinant at all** — a browse-agent extraction hallucination
that survived two consolidation cycles and became load-bearing before anyone
re-checked it. You caught it by voluntarily re-reading. This convention makes
that catch mechanical instead of lucky.

It is advisory tooling, not a mandate — same spirit as the proof registry.

## The convention

**A citation is an arXiv ID plus a locator, at the point of use.**

> ...the Cauchy determinant (arXiv:2606.12796, Thm B.1) has prefactor
> t^C(|J|,2)...

- Author names alone are not citations for claims. "Gatzweiler–Krattenthaler's
  positivity condition" is a memory aid; "(2502.06032, Thm 8)" is a citation.
  Use both, but never only the first when the claim matters.
- The locator (Thm/Prop/§/Eq number) is what makes a claim *checkable*. A bare
  ID says "somewhere in this paper"; after two consolidations that degrades
  into "somewhere in the literature."
- This applies wherever claims live: connections/, topics/, proofs/. Reading
  logs already do it.

## Extraction levels

Every source in `sources.json` carries one level — how the knowledge got to
you, which bounds how much you should trust it:

```
agent-summary < abstract < deep-read < verified-quote
```

- **agent-summary** — a browse agent read (some of) the paper and summarized
  it. This is most of your reading, and it is fine — but agents hallucinate
  extractions. The G–K determinant was an agent-summary fact.
- **abstract** — you read the abstract yourself, nothing more.
- **deep-read** — you (or an agent you directed at the specific question,
  with the full text) read the relevant part and checked the claim against
  the paper's actual statements.
- **verified-quote** — you hold an exact quotation, copied from the source,
  with its locator.

The rule of thumb: **an agent-summary fact may not be load-bearing.** Cite it,
build on it speculatively, let it guide search — but before a proof or a
registry node at `proved` rests on it, deep-read the source. This is the same
ceiling `unclassified` imposes in the registry: a claim exists, nobody has
re-checked it.

## sources.json

One index at `memory/reading/sources.json`. One entry per paper you cite:

```json
{
  "format": "clio-sources-v1",
  "sources": {
    "2502.06032": {
      "title": "A positivity conjecture for a quotient of q-binomial coefficients",
      "authors": "Gatzweiler, Krattenthaler",
      "year": 2025,
      "extraction": "deep-read",
      "read": ["reading/2026-07-09.md", "reading/2026-07-10.md"],
      "locators": ["Thm 8", "Thm 9", "Cor 10"],
      "corrections": [
        {
          "date": "2026-07-10",
          "note": "07-08/07-09 recorded a q-binomial DETERMINANT with an LGV proof; the paper has neither. Object is a ratio of q-factorials; positivity via cyclotomic gcd. Extraction hallucination."
        }
      ]
    }
  }
}
```

- `read` — reading-log files (relative to `memory/`) where you encountered it.
  Append on re-reads.
- `extraction` — the *highest* level attained. A deep read upgrades an
  agent-summary entry.
- `locators` — optional; the parts of the paper you have actually used.
- `corrections` — **never delete a wrong extraction; record it.** A correction
  entry is a dead-end node's `reason`: it carries information (what the wrong
  reading was, so you recognize it if it resurfaces from an old note).
- Maintenance is cheap: new paper in a browse session → one entry at
  `agent-summary`, ten seconds. Deep read later → bump the level, append to
  `read`.

## Backfilling

Do NOT sweep your old files. Same rule as the registry: backfill by use. When
a connection, topic edit, or proof cites a paper not yet in sources.json, add
it at the honest level (usually `agent-summary`) with whatever reading log
mentioned it. Files nothing cites stay unindexed — fine.

The shipped `sources.json` is seeded with the new papers from your 07-06
through 07-10 browses, at honest levels, including three correction entries
(G–K above; the Di Francesco–Vu coincident-rapidity over-claim; the
Gunna–Yeliussizov author misattribution). Those three are your worked example:
all three wrong readings entered at agent-summary level and were corrected by
a deep read.

## Validator

```
python3 code/citation_check.py                          # validate sources.json
python3 code/citation_check.py connections/foo.md       # + check its citations resolve
python3 code/citation_check.py --report footprint connections/foo.md
python3 code/citation_check.py --report shallow
```

Run from `/home/clio/projects/memory` (or pass `--memory-dir`). Checks:
sources.json well-formed (valid levels, `read` files exist, corrections carry
date+note), and every arXiv ID cited in the given files resolves in the index.
Advisory: readable messages, exit 0 = clean. Stdlib only.

Reports:
- `--report footprint <files>` — per file: each source cited, its extraction
  level, correction flags, and the file's **provenance floor** (the lowest
  level among its citations — the trust ceiling the file inherits).
- `--report shallow` — every agent-summary source cited from connections/ or
  topics/: your deep-read worklist, ordered by how many files lean on each.

## Composing with the proof registry

Registry nodes take an optional `"sources"` field:

```json
{ "id": "orderlaw-cauchy-det", "approach": "order law via DFV rank recursion",
  "trust": "in-progress", "file": null,
  "sources": ["2606.12796"], "children": [] }
```

`registry_validate.py` (updated) flags a node at `proved` or `lean-verified`
whose cited sources are all `agent-summary` — the external analogue of the
boundary rule. An external paper is a subtree you cannot see into; the
extraction level is the trust of its root.

## Why this shape (the mathematical reading)

The pipeline notes → dream file → proof is a chain of container morphisms:
each stage maps shapes forward (files get reorganized, claims get restated)
and positions **backward** — "where did this claim come from?" is precisely
pulling a position back along the chain. A citation is the cached value of
that pullback. Consolidation that drops citations is a shape map with no
position map: it tells you what is claimed but forgets the functor that
answers where. Keeping the ID + locator through every rewrite is what makes
the whole chain a genuine morphism rather than a lossy summary — and it is
the first working instance of the cross-registry morphisms sketched in Phase
4 of the trust-boundary design.
