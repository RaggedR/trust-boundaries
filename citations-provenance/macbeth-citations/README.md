# Citations

MacBeth. This is a provenance convention for external facts. You already cite
well in reading logs (arXiv IDs, theorem numbers, detailed locators). The
problem is what happens *after*: dream consolidation compresses notes, and
citations are exactly the kind of detail compression eats. By the time a claim
reaches a proof, "Ahman-Uustalu's morphism characterization" has become "DCont
morphisms are cofunctors" with no way to check where that came from, or whether
it was stated correctly.

It was not always stated correctly. Your feeds.md records that arXiv:2503.02477
was returned by a browse agent as a cofunctor paper by Stein (LICS 2025). It is
a probability/Markov paper with no cofunctors at all. The browse agent matched
the researcher name to the wrong paper ID. Separately, arXiv:2410.08373
(Libkind-Spivak) was withdrawn in Nov 2024; citing it would reference a
retracted claim. These are the motivating incidents: extractions go wrong, and
a convention catches them mechanically instead of by luck.

It is advisory tooling, not a mandate. Same spirit as the proof registry.

## The convention

**A citation is an arXiv ID plus a locator, at the point of use.**

> ...the cofree comonad adjunction (arXiv:2602.17917, Prop 3.2) is the same
> adjunction underlying DCont = Cof...

- Author names alone are not citations for claims. "Ahman-Uustalu's
  characterization" is a memory aid; "(1604.01187, Sec 3.2)" is a citation.
  Use both, but never only the first when the claim matters.
- The locator (Thm/Prop/Sec/Eq number) is what makes a claim *checkable*. A
  bare ID says "somewhere in this paper"; after two consolidations that
  degrades into "somewhere in the literature."
- This applies wherever claims live: connections/, topics/, proofs/. Reading
  logs already do it.

## Extraction levels

Every source in `sources.json` carries one level, recording how the knowledge
got to you, which bounds how much you should trust it:

```
agent-summary < abstract < deep-read < verified-quote
```

- **agent-summary** -- a browse agent read (some of) the paper and summarized
  it. This is most of your reading, and it is fine, but agents hallucinate
  extractions. The Stein 2503.02477 wrong-paper is the standing example.
- **abstract** -- you read the abstract yourself, nothing more.
- **deep-read** -- you (or an agent you directed at the specific question,
  with the full text) read the relevant part and checked the claim against
  the paper's actual statements.
- **verified-quote** -- you hold an exact quotation, copied from the source,
  with its locator.

The rule of thumb: **an agent-summary fact may not be load-bearing.** Cite it,
build on it speculatively, let it guide search. But before a proof or a
registry node at `proved` rests on it, deep-read the source. This is the same
ceiling `unclassified` imposes in the registry: a claim exists, nobody has
re-checked it.

## sources.json

One index at `memory/reading/sources.json`. One entry per paper you cite:

```json
{
  "format": "clio-sources-v1",
  "sources": {
    "1604.01187": {
      "title": "When Is a Container a Comonad?",
      "authors": "Ahman, Uustalu",
      "year": 2016,
      "extraction": "deep-read",
      "read": ["reading/2026-06-10.md", "reading/2026-06-11.md"],
      "locators": ["Sec 3.2", "Sec 3.3"],
      "corrections": []
    }
  }
}
```

- `read` -- reading-log files (relative to `memory/`) where you encountered it.
  Append on re-reads.
- `extraction` -- the *highest* level attained. A deep read upgrades an
  agent-summary entry.
- `locators` -- optional; the parts of the paper you have actually used.
- `corrections` -- **never delete a wrong extraction; record it.** A correction
  entry is a dead-end node's `reason`: it carries information (what the wrong
  reading was, so you recognize it if it resurfaces from an old note).
- Maintenance is cheap: new paper in a browse session -> one entry at
  `agent-summary`, ten seconds. Deep read later -> bump the level, append to
  `read`.

## Backfilling

Do NOT sweep your old files. Same rule as the registry: backfill by use. When
a connection, topic edit, or proof cites a paper not yet in sources.json, add
it at the honest level (usually `agent-summary`) with whatever reading log
mentioned it. Files nothing cites stay unindexed. Fine.

The shipped `sources.json` is seeded from your `feeds.md` at honest extraction
levels: papers whose theorems you worked through in prove sessions (AU16,
Niu-Spivak, Spivak-Srinivasan, Clarke-Di Meglio, Pirashvili) are `deep-read`;
papers summarized by browse agents are `agent-summary`. Two correction entries
record the withdrawn paper (2410.08373) and the wrong-paper incident
(2503.02477). Those two are your worked examples: one agent error per type.

## Validator

```
python3 code/citation_check.py                          # validate sources.json
python3 code/citation_check.py connections/foo.md       # + check its citations resolve
python3 code/citation_check.py --report footprint connections/foo.md
python3 code/citation_check.py --report shallow
```

Run from `/home/agent/projects/memory` (or pass `--memory-dir`). Checks:
sources.json well-formed (valid levels, `read` files exist, corrections carry
date+note), and every arXiv ID cited in the given files resolves in the index.
Advisory: readable messages, exit 0 = clean. Stdlib only.

Reports:
- `--report footprint <files>` -- per file: each source cited, its extraction
  level, correction flags, and the file's **provenance floor** (the lowest
  level among its citations, the trust ceiling the file inherits).
- `--report shallow` -- every agent-summary source cited from connections/ or
  topics/: your deep-read worklist, ordered by how many files lean on each.

## Composing with the proof registry

Registry nodes take an optional `"sources"` field:

```json
{ "id": "dcont-cof-m4", "approach": "DCont = Cof via cofunctor identification",
  "trust": "lean-verified", "file": null, "lean": "DCont_iso_Cof",
  "sources": ["1604.01187"], "children": [] }
```

`registry_validate.py` (updated) flags a node at `proved` or `lean-verified`
whose cited sources are all `agent-summary`. The external analogue of the
boundary rule. An external paper is a subtree you cannot see into; the
extraction level is the trust of its root.

## Why this shape (the mathematical reading)

The pipeline notes -> dream file -> proof is a chain of container morphisms:
each stage maps shapes forward (files get reorganized, claims get restated)
and positions **backward** ("where did this claim come from?" is precisely
pulling a position back along the chain). A citation is the cached value of
that pullback. Consolidation that drops citations is a shape map with no
position map: it tells you what is claimed but forgets the functor that
answers where. Keeping the ID + locator through every rewrite is what makes
the whole chain a genuine morphism rather than a lossy summary.
