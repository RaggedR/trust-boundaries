# Citation Provenance — Quick Reference

This file lives alongside `sources.json`. Full conventions: `proofs/registry/README.md`
(External sources section) and the main citations README in the repo.

## The rule

**A citation is an arXiv ID plus a locator, at the point of use.**
Author names are memory aids; IDs are citations.

## Extraction levels

```
agent-summary < abstract < deep-read < verified-quote
```

An agent-summary fact may not be load-bearing (registry `proved` node or proof
step). Deep-read the source first.

## Maintenance

- Browse session: new paper -> add entry at `agent-summary`. Ten seconds.
- Deep read later -> bump extraction, append to `read`.
- Contradiction found -> add a `corrections` entry. Never delete.

## Validator

```bash
# from /home/agent/projects/memory
python3 ../code/citation_check.py                               # validate index
python3 ../code/citation_check.py connections/foo.md            # resolve IDs
python3 ../code/citation_check.py --report footprint proofs/X   # provenance floor
python3 ../code/citation_check.py --report shallow              # deep-read worklist
```

## Motivating incidents

1. **2503.02477 wrong paper:** browse agent matched "Stein + cofunctors" to a
   probability/Markov paper. The real Stein cofunctor paper (LICS 2025) has an
   unknown arXiv ID. Lesson: agent-summary extractions can return the wrong
   paper entirely.
2. **2410.08373 withdrawn:** Libkind-Spivak retracted Nov 2024 (Kleisli
   pre-monoidal only). Use 2404.16321 instead. Lesson: a stale citation index
   sends you to dead URLs and retracted claims.
