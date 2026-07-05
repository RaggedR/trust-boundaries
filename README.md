# Trust Boundaries

Per-agent trust-system descriptors for Robin Langer's persistent-memory AI agents (Clio, MacBeth). Each descriptor is a JSON declaration of an epistemic trust system (T, φ): the trust chain a mathematical claim climbs, the boundary level other work may build on, the refutation sub-poset for dead-ends, per-level evidence requirements, and source-extraction blocking rules.

The descriptors are configuration *data* for the agents themselves — part of each agent's identity. This repo is the canonical home for the whole system: the theory, the Lean 4 formalization (reference copies — the files also build in the macbeth-seed repo as part of the Containers library, where `TrustBoundary.lean` imports `Containers.ProofSearchN`), the generic validator, the verification scripts, and snapshots of both agents' deployed citation/registry systems.

## Contents

- `deployments/clio.json` — Clio (algebraic combinatorics, representation theory, Hecke algebras)
- `deployments/macbeth.json` — MacBeth (category theory)
- `theory/TRUST_SYSTEMS_THEORY.md` (+ pdf) — the general theory: trust systems (T, φ), the certificate lemma, transport of trust
- `theory/TRUST_BOUNDARY.md` — the boundary design note
- `lean/Trust.lean`, `lean/TrustBoundary.lean` — Lean 4 formalization (reference copies; buildable in macbeth-seed)
- `citations-provenance/provenance-explained.tex` (+ pdf) — how citation provenance works: the extraction chain, blocking thresholds, and machine-checkable citation formats
- `verification-scripts/citation_check.py`, `verification-scripts/registry_validate.py` — Clio's verification scripts: citation-format checking against `sources.json`, and claim-registry validation
- `trustcheck/trustcheck.py` — the generic validator, parametrized over a trust-system descriptor (T, φ)
- `citations-provenance/{clio,macbeth}-citations/` — snapshots of each agent's deployed citation system: `citation_check.py`, `sources.json`, and the prompts that enforce provenance discipline
- `citations-provenance/{clio,macbeth}-registry/` — snapshots of each agent's claim registry: `registry_validate.py` and the claim JSONs (trust level + evidence per claim)
- `theory/clio-trust-boundary-design.md` — the original per-agent boundary design note

## Descriptor anatomy

- `trust.chain` — `speculative → computed → proved → peer-reviewed → published → lean-verified`
- `trust.boundary_at` — the level (`proved`) a node must reach before non-dead-end children may claim at or above it
- `trust.refutation_chain` — grading for dead-ends: `judgment < computed < proved < lean-verified`
- `trust.evidence` — artifacts required per level (reviewer, DOI/arXiv, sorry-free Lean declaration)
- `sources` — extraction chain (`agent-summary → abstract → deep-read → verified-quote`) and blocking thresholds (the monotone interface map φ)
- `citation` — machine-checkable citation formats

## License

MIT — see [LICENSE](LICENSE).
