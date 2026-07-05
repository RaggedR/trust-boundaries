# Trust Boundaries

Per-agent trust-system descriptors for Robin Langer's persistent-memory AI agents (Clio, MacBeth). Each descriptor is a JSON declaration of an epistemic trust system (T, φ): the trust chain a mathematical claim climbs, the boundary level other work may build on, the refutation sub-poset for dead-ends, per-level evidence requirements, and source-extraction blocking rules.

These are configuration *data* for the agents themselves — part of each agent's identity — not a validator. The generic validator (`trustcheck.py`, parametrized over (T, φ)) and the underlying theory (`TRUST_SYSTEMS_THEORY.md`) live in the containers repo; a deployment there is a descriptor, not a port.

## Contents

- `deployments/clio.json` — Clio (algebraic combinatorics, representation theory, Hecke algebras)
- `deployments/macbeth.json` — MacBeth (category theory)

## Descriptor anatomy

- `trust.chain` — `speculative → computed → proved → peer-reviewed → published → lean-verified`
- `trust.boundary_at` — the level (`proved`) a node must reach before non-dead-end children may claim at or above it
- `trust.refutation_chain` — grading for dead-ends: `judgment < computed < proved < lean-verified`
- `trust.evidence` — artifacts required per level (reviewer, DOI/arXiv, sorry-free Lean declaration)
- `sources` — extraction chain (`agent-summary → abstract → deep-read → verified-quote`) and blocking thresholds (the monotone interface map φ)
- `citation` — machine-checkable citation formats

## License

MIT — see [LICENSE](LICENSE).
