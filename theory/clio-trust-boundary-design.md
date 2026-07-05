# Clio Trust Boundary: Directed Container Proof Registry

## The problem

Clio has 878 proof files in a flat directory. Dead ends (15 files), successful
proofs, and partial results all sit side by side with no structural relationship.
The proof search tree lives implicitly in SUMMARY.md (282KB, append-only) and
in cross-references buried in prose. When Robin asks "what did you try
and why did it fail?", Clio has to reconstruct the tree from memory.

## The proposal

A structured proof registry where each conjecture's proof search is a tree.
The directed container structure (root, sub, shift) gives composable navigation
through the search history. A trust boundary labels each node with a trust level.

## Registry format

Each conjecture gets a YAML tree in proofs/registry/:

```yaml
# proofs/registry/three-row-even-jstar.yaml
conjecture: "three-row (a,b,c): |J*| is even on every tie"
status: proved          # trust level of the ROOT
date_opened: 2026-04-15
date_closed: 2026-06-19

tree:
  id: root
  approach: "case split on c"
  trust: proved
  file: null             # the conjecture itself has no single proof file
  children:
    - id: c1
      approach: "c=1 direct computation"
      trust: lean-verified
      file: 2026-05-01-c1-boundary.tex
      lean: threerow_c1_boundary    # Lean declaration name
      children: []                  # leaf (success)

    - id: c4-interior
      approach: "c=4 interior: Number Lemma 16|H"
      trust: proved
      file: 2026-06-19-c4-number-lemma.tex
      children:
        - id: c4-linear-phi
          approach: "linear phi hypothesis"
          trust: dead-end
          file: null
          reason: "CODE.md's linear-phi hypothesis refuted by jobA"
          children: []    # leaf (dead end)

        - id: c4-constant-floor
          approach: "constant floor v2(H) >= 4"
          trust: proved
          file: 2026-06-19-c4-number-lemma.tex
          children: []    # leaf (success)

    - id: dodgson
      approach: "Dodgson condensation on T-system"
      trust: dead-end
      file: 2026-04-20-dodgson-dead-end.tex
      reason: "classical obstruction: sign pattern incompatible"
      children: []        # leaf (dead end)

    - id: pfaffian
      approach: "Pfaffian identity"
      trust: dead-end
      file: 2026-04-20-pfaffian-dead-end.tex
      reason: "dimension mismatch in antisymmetric part"
      children: []        # leaf (dead end)

    - id: general-c
      approach: "uniform Content Lemma for all c"
      trust: in-progress
      file: 2026-06-17-generalc-boundary.tex
      children:
        - id: dimension-hook
          approach: "dimension-hook q-lift"
          trust: dead-end
          reason: "jobB route-1 killed it with structural reason"
          children: []

        - id: lgv-det
          approach: "LGV Gaussian-binomial determinant"
          trust: speculative
          file: null
          children: []    # leaf (work in progress)
```

## Directed container operations on this format

The tree above IS a search tree shape (STree from ProofSearch.lean,
generalized to arbitrary branching). The operations:

  root: the top-level node (the conjecture)
  sub(tree, path): follow the path to get the sub-tree
    e.g. sub(tree, [general-c, dimension-hook]) = the dead-end leaf
    e.g. sub(tree, [c4-interior]) = the sub-tree with two children
  shift(tree, p, q): compose paths
    e.g. shift(tree, [general-c], [lgv-det]) = [general-c, lgv-det]

## Trust levels (ordered)

  speculative < computed < proved < lean-verified

The trust boundary is: at each node, the trust level must be justified by its
children. A node can be "proved" only if all its required sub-goals are at
least "proved" (and dead-end siblings are explicitly marked as abandoned,
not required).

## Comonadic operations in practice

extract(registry) = the trust level at the root
  "Is the conjecture proved?"

duplicate(registry) = at every node, replace the trust level with the
  full sub-registry from that point
  "At every step, what was the full search below it?"

A coKleisli morphism W(Registry) -> Report takes the full search tree
and produces a summary. Different morphisms = different reports:
  - "give me the successful path" (prune dead ends)
  - "give me the dead ends with reasons" (prune successes)  
  - "give me the trust frontier" (nodes where trust level < parent's)
  - "give me the cross-references" (nodes appearing in multiple trees)

## Implementation plan

Phase 1: Registry format
  - Define the YAML schema above
  - Write a script that generates a skeleton registry from Clio's existing
    proof files (parse filenames, dates, dead-end markers)
  - Clio updates the registry as part of each prove session

Phase 2: Trust boundary enforcement
  - A validator that checks: no node claims "proved" unless its children
    justify it (smart constructor = container morphism)
  - The validator is the trust boundary. Claims above the boundary are
    verified. Claims below are exploratory.

Phase 3: Lean connection
  - Nodes with trust: lean-verified must have a corresponding sorry-free
    Lean declaration. The validator checks this against the Lean build.
  - This closes the loop: the trust boundary is machine-checked at the top.

Phase 4: Cross-conjecture structure
  - Multiple registries (one per conjecture) linked by shared sub-trees
  - A shared node is a container morphism between registries
  - "The Content Lemma appears in both the three-row program and the
    order law" becomes a structural fact, not a prose remark
```

## What Clio would need to change

Current workflow:
  1. Start a prove session
  2. Try approaches, write LaTeX for each (including dead ends)
  3. Append results to SUMMARY.md
  4. Dream at end of session (consolidate into dream journal)

New workflow (Phase 1 only):
  1. Start a prove session
  2. Check the registry for the target conjecture
  3. Try approaches, write LaTeX as before
  4. Update the registry tree (add nodes, mark dead ends, update trust)
  5. Append to SUMMARY.md as before
  6. Dream, with the registry as structured input

The registry doesn't replace anything. It adds a structured index alongside
the existing flat files. The LaTeX proofs remain the primary artifacts.
The registry is the directed container that organizes them.
