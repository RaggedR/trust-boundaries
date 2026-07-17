# Trust Boundaries

A framework for epistemically honest AI agents. Every mathematical claim an agent makes is graded on a calibrated trust chain, validated by machine-checkable rules, and composable when agents cite each other across system boundaries.

This repo contains the theory, a sorry-free Lean 4 formalization, a generic validator, and the deployment configurations for four running agent systems.

## The problem

An AI agent doing mathematical research generates hundreds of claims across sessions: conjectures, computations, proofs, dead ends. Without structure, the agent's memory becomes an append-only log where confident assertions sit next to abandoned sketches with no way to tell them apart. Worse, when multiple agents cite each other's results, trust inflates silently — a browse-agent's paraphrase becomes "known" through repetition, not verification.

## The solution: trust systems

A **trust system** is a triple (D, T, s):

- **D** — a dependency structure (a DAG of claims, where children are sub-results a parent depends on)
- **T** — a totally ordered chain of trust levels that a claim can hold
- **s** — a grading function assigning each claim its current trust level

The **boundary rule** is the core invariant: a claim at level `proved` or above must have every non-dead-end dependency at least at `proved`. Dead ends are fine (they're abandoned, not required), but each must explain why it died. This is enforced by a validator, not by agent self-report.

The **certificate lemma** (Lemma 2.2 in the theory paper) proves there exists a greatest sound assignment &tau; — the canonical trust — computable by well-founded recursion over the DAG. Any valid grading is bounded above by &tau;, so over-claiming is detectable.

**Transport of trust** (Lemma 3.2) handles cross-agent citation: given a monotone map &phi; between two agents' trust chains, a claim imported at level `l` arrives at &phi;(l) in the receiver's system. The map &phi; can (and usually does) demote — Rick's `checked-sober` maps to Clio's `peer-claimed`, meaning she can see it but can't build on it without independent verification.

## Deployed agents

Four systems run on this framework, each with a JSON deployment descriptor in `deployments/`:

| Agent | Domain | Trust chain | Boundary |
|-------|--------|-------------|----------|
| **Clio** | Algebraic combinatorics, Hecke algebras | speculative &lt; computed &lt; peer-claimed &lt; proved &lt; peer-reviewed &lt; published &lt; lean-verified | proved |
| **MacBeth** | Category theory, compositional systems | (same as Clio) | proved |
| **Rick** | Combinatorial Hopf algebras, quantum groups | hunch &lt; sketched &lt; computed &lt; peer-claimed &lt; checked-sober &lt; proved &lt; lean-verified | checked-sober |
| **Warnaar loop** | Cylindric partitions (RAG workflow) | speculative &lt; computed &lt; proved &lt; verified &lt; lean-verified | proved |

Rick's system is deliberately stricter: `checked-sober` requires a dated re-derivation artifact (a hunch re-derived is not the hunch), and `proved` requires a written proof file. His boundary sits at `checked-sober` rather than `proved`, reflecting a "build earlier, document harder" philosophy.

### Cross-agent composition

When Clio cites a result from Rick, the interface map &phi; in her deployment descriptor translates his trust levels into hers:

```
Rick's checked-sober  -->  Clio's peer-claimed
Rick's proved         -->  Clio's proved
Rick's hunch          -->  Clio's speculative
```

The key asymmetry: Rick's `checked-sober` (above his boundary) maps to Clio's `peer-claimed` (below her boundary). She can reference it, but can't claim `proved` while depending on it. To upgrade, she reads the proof herself and promotes the citation — the trust is earned, not inherited.

The validator enforces this across namespace boundaries, including transitive chains (Clio cites Rick cites MacBeth) and cross-agent cycle detection.

## Repository structure

```
trust-boundaries/
├── theory/                          # Mathematical foundations
│   ├── TRUST_SYSTEMS_THEORY.md      # Main paper: definitions, lemmas, proofs
│   ├── TRUST_BOUNDARY.md            # Boundary design note
│   └── clio-trust-boundary-design.md
│
├── lean/                            # Sorry-free Lean 4 formalization
│   ├── Trust.lean                   # Certificate lemma, transport, consolidation
│   ├── TrustBoundary.lean           # Boundary rule stable under duplicate
│   ├── ProofSearchN.lean            # n-ary rose trees as directed containers
│   ├── Basic.lean                   # Containers, extensions, morphisms
│   ├── Directed.lean                # Directed container laws D1-D5, comonad
│   ├── DContCat.lean                # Directed containers as categories
│   ├── CoKleisli.lean               # coKleisli extension and composition
│   └── ZappaSzep.lean               # Zappa-Szep products
│
├── deployments/                     # Per-agent trust system descriptors
│   ├── clio.json
│   ├── macbeth.json
│   ├── rick.json
│   └── loop.json
│
├── trustcheck/                      # Generic validator
│   ├── trustcheck.py                # Parametrized over (T, phi)
│   └── tests/                       # Cross-agent composition fixtures
│       ├── cross-agent/             # 7 fixture cases (Clio <-> Rick)
│       └── three-agent-chain/       # Transitive: Clio -> Rick -> MacBeth
│
├── citations-provenance/            # Deployed agent infrastructure snapshots
│   ├── provenance-explained.tex     # How citation provenance works
│   ├── clio-citations/              # Clio's citation checker + prompts
│   ├── clio-registry/               # Clio's proof registry + validator
│   ├── macbeth-citations/           # MacBeth's citation system
│   ├── macbeth-registry/            # MacBeth's proof registries
│   ├── rick-citations/              # Rick's trust system prompts
│   ├── loop-citations/              # Warnaar loop citation system
│   └── loop-registry/               # Warnaar loop registry
│
├── verification-scripts/            # Original per-agent validators (superseded)
│   ├── citation_check.py
│   └── registry_validate.py
│
├── trust-boundary-citation-reference.tex  # Paper draft
├── COMPOSITION.md                   # Cross-agent composition explained
└── HANDOVER.md                      # Deployment handover notes
```

## Using the validator

The validator is a single Python script (stdlib only, no dependencies) parametrized over a deployment descriptor:

```bash
# Validate a registry against Clio's trust system
python3 trustcheck/trustcheck.py \
  --deployment deployments/clio.json \
  validate path/to/registry.json \
  --files-dir proofs

# Check citation sources
python3 trustcheck/trustcheck.py \
  --deployment deployments/clio.json \
  sources path/to/sources.json

# Reports
python3 trustcheck/trustcheck.py \
  --deployment deployments/clio.json \
  report successful-path path/to/registry.json   # proved/lean-verified skeleton
  report dead-ends path/to/registry.json          # every dead end with reason
  report frontier path/to/registry.json           # open nodes where work remains
  report cross-refs path/to/registry.json         # shared links across registries
  report certificate-gap path/to/registry.json    # where grading exceeds tau
```

Exit 0 means clean. The validator checks:

- **Boundary rule** — no node claims above its boundary unless all non-dead-end children meet the threshold
- **Acyclicity** — circular dependencies would pass every node-local check while proving nothing
- **Evidence requirements** — `peer-reviewed` needs a `review` field, `published` needs a `publication` field, etc.
- **Source blocking** — a node claiming `proved` whose literature citations are all at `agent-summary` gets flagged
- **Cross-agent trust cap** — shared stubs may not exceed the canonical node's trust level
- **Cross-agent cycles** — DFS across namespace boundaries detects circular citation chains

## The Lean formalization

The `lean/` directory contains sorry-free Lean 4 proofs of the core theory. Key results:

| File | Key theorems |
|------|-------------|
| `Trust.lean` | `tau_sound` (canonical trust satisfies the boundary rule), `sound_le_tau` (it's the greatest such), `tau_transport` (trust transports across &phi;), `tau_consolidate` (genuine position maps preserve &tau;) |
| `TrustBoundary.lean` | `ok_sub` (boundary rule stable under `duplicate` — validating the whole tree validates every subtree) |
| `ProofSearchN.lean` | n-ary rose trees as directed containers: `root`, `sub`, `shift`, all five laws |
| `Directed.lean` | Directed container axioms D1-D5, all three comonad laws (`extract_duplicate`, `duplicate_extract`, `duplicate_duplicate`) |

The formalization discovered two corrections to the theory paper: T must be a chain (not just a lattice) for the certificate lemma, and morphisms must satisfy &phi;(&perp;) = &perp; for transport.

## The mathematical reading

The proof registry is a **directed container** (Ahman-Chapman-Uustalu). Shapes are search trees, positions are paths through them:

- `root` — the conjecture (the empty path)
- `sub(t, p)` — the sub-search rooted at path p
- `shift(t, p, q)` — path composition: q inside the sub-search at p, seen globally

The induced **comonad**: `extract` reads the root's trust ("is it proved?"); `duplicate` replaces every node with the full sub-search below it. The validator's report modes are **coKleisli morphisms** W(Registry) &rarr; Report — strategies that inspect the whole tree before summarizing.

Cross-agent shared stubs are **container morphisms** between registries. The trust cap makes them trust-monotone. `TrustBoundary.lean` proves the boundary rule is stable under `duplicate`, so the check composes the way the registries do.

## Deployment descriptor anatomy

Each JSON descriptor declares a complete trust system:

```jsonc
{
  "name": "clio",
  "trust": {
    "chain": ["speculative", "computed", "peer-claimed", "proved", ...],
    "boundary_at": "proved",
    "refutation_chain": ["judgment", "computed", "proved", "lean-verified"],
    "evidence": {
      "peer-reviewed": { "field": "review", "severity": "error" },
      "published":     { "field": "publication", "severity": "error" },
      "lean-verified": { "field": "lean", "severity": "warning" }
    }
  },
  "sources": {
    "extraction_chain": ["agent-summary", "abstract", "deep-read", "verified-quote"],
    "blocking": [{ "below_extraction": "abstract", "blocks_trust": "proved" }]
  },
  "interfaces": {
    "rick": {
      "phi": {
        "hunch": "speculative",
        "checked-sober": "peer-claimed",
        "proved": "proved"
      }
    }
  }
}
```

The `interfaces` section defines the &phi; maps to peer systems. Each interface specifies where to find imported registries, how to translate trust levels, and what to do when artifacts are missing.

## Prior art and related work

The theory paper locates this work relative to:

- **Provenance semirings** (Green, Karvounarakis, Tannen 2007) — annotate query results with how they were derived; trust systems are the special case where annotations form a chain
- **Assurance 2.0** (Bloomfield, Rushby 2020) — structured assurance cases with confidence levels; trust boundaries add composability and machine-checkable validators
- **Quantitative argumentation** — weighted argument graphs; the certificate lemma gives a canonical grading rather than requiring adversarial evaluation

## License

MIT — see [LICENSE](LICENSE).
