# Citations — Loop Experiment (Warnaar)

The loop experiment is a local research workflow for Warnaar's A2
Andrews-Gordon positivity conjecture, running at
`~/git/experiments/waarnar/loop-experiment/`. Unlike Clio, Rick, and
MacBeth — persistent Docker agents whose citations must survive dream
consolidation — the loop's citations must survive **RAG retrieval**.

The knowledge pipeline is:
```
RAG query -> chunk retrieval -> scratch files -> synthesis layers -> proof .tex
```

Each stage compresses. Citations are exactly the kind of detail compression
eats. By layer 4, `(uncu_proofs_modulo11_13.../chunk_031, thm:m13)` has
degraded into "Uncu's proved identity" — and after one more layer there is
no way to check where it came from.

## The RAG-specific failure mode

The characteristic failure mode is **chunk windowing**: a retrieved chunk is
a window into a paper. The theorem's hypotheses, variable conventions, and
normalizations may live in a chunk that was NOT retrieved. Misapplying a
theorem whose standing conventions were set two chunks earlier is the RAG
analogue of Clio's phantom-determinant hallucination — but structurally
different: the text is real, the reading is wrong because the context is
missing.

## Extraction chain

```
recalled < rag-summary < chunk-read < context-read < paper-read
```

| Level | What it means | RAG analogue of |
|-------|---------------|-----------------|
| `recalled` | Training memory; no chunk behind it | (no agent analogue) |
| `rag-summary` | Only the chunk's one-line `[Summary:]` tag | `agent-summary` |
| `chunk-read` | Retrieved chunk read verbatim | `abstract` |
| `context-read` | Surrounding chunks read; hypotheses checked | `deep-read` |
| `paper-read` | Relevant section worked through at line level | `verified-quote` |

**Blocking rule:** below `context-read` blocks `proved`. A fact below
`context-read` may not be load-bearing — the hypotheses may live in an
unretrieved chunk.

## Source format: `loop-sources-v1`

Sources are keyed by **paper slug** (the directory name under
`../literature/chunks/`), not arXiv ID. The slug resolves on disk:
`../literature/chunks/<slug>/chunk_NNN.tex`. Checking a citation costs one
Read, not a library trip.

```json
{
  "format": "loop-sources-v1",
  "sources": {
    "uncu_proofs_modulo11_13_cylindric_kanade_russell": {
      "title": "Proofs of modulo 11 and 13 cylindric Kanade-Russell conjectures",
      "authors": "Uncu",
      "extraction": "paper-read",
      "read": ["2026-07-04/scratch/prove-seed1-layer4.md"],
      "locators": ["thm:m13", "S11(e_s|e_t)"],
      "corrections": [
        { "date": "2026-07-04",
          "note": "N1: thm:m13 is computer-assisted (ideal-membership certificates); results resting on it inherit that dependency." }
      ]
    }
  }
}
```

Trust qualifiers (like N1 above) also live in `corrections` — anything that
must not be compressed away. A deleted wrong claim can be re-hallucinated by
the next synthesis; a recorded wrong claim cannot.

## Citation format

**A citation is a chunk reference plus a locator, at the point of use.**

> ...the Pochhammer split lands verbatim on Uncu's H identity
> (uncu_proofs_modulo11_13.../chunk_031, thm:m13)...

The machine regex matches `paper_slug/chunk_NNN`. The on-disk check catches
hallucinated chunk references outright — a cited chunk that does not exist
in the corpus is an error.

## Validator

`citation_check.py` in this directory is a reference copy of the loop
experiment's per-experiment checker. Run from `loop-experiment/`:

```bash
python3 code/citation_check.py                              # validate index
python3 code/citation_check.py <files...>                   # + resolve refs
python3 code/citation_check.py --report footprint <files>   # provenance floor
python3 code/citation_check.py --report shallow <files>     # context-read worklist
```

## Motivating incident

The Uncu N1 provenance caveat: `thm:m13` is a computer-assisted proof
(ideal-membership certificates). Every result resting on it (G13, G14)
inherits that dependency. This is not a wrong reading — it is a trust
qualifier that must not be compressed away across synthesis layers. The
corrections mechanism records it.

## The mathematical reading

The pipeline scratch -> synthesis -> proof is a chain of container
morphisms: each stage maps shapes forward (claims get restated, files
reorganized) and positions **backward** — "where did this claim come from?"
is precisely pulling a position back along the chain. A citation is the
cached value of that pullback. A synthesis that drops citations is a shape
map with no position map: it tells you what is claimed but forgets the
functor that answers where.
