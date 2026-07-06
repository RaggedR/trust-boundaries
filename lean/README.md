# Lean 4 Formalization

Sorry-free Lean 4 proofs of the trust system's core theorems.

## Files

| File | What it proves |
|------|---------------|
| `Basic.lean` | Containers, extensions, morphisms, representation theorem (Yoneda) |
| `Directed.lean` | Directed containers (D1-D5), all three comonad laws |
| `DContCat.lean` | Directed containers as categories, cofunctors, composition |
| `ProofSearch.lean` | Binary proof search trees as a directed container |
| `ProofSearchN.lean` | N-ary rose trees (the actual shape of registries) |
| `Trust.lean` | Certificate lemma, canonical trust (tau), transport, consolidation |
| `TrustBoundary.lean` | Boundary rule stable under duplicate, deployed trust chain |
| `CoKleisli.lean` | CoKleisli extension, composition, associativity, strength |
| `ZappaSzep.lean` | Zappa-Szép products of directed containers |

## Building

These files are **reference copies** from the buildable Lean project in
`macbeth-seed/lean/Containers/`. The import paths (`import Containers.X`)
match that project's module structure. To build:

```bash
cd macbeth-seed/lean/Containers
lake build
```

## Key theorems

- `sound_le_tau` — every sound assignment is bounded by canonical trust (Lemma 2.2 ii)
- `tau_sound` — canonical trust is itself sound (Lemma 2.2 i): tau is the greatest sound assignment
- `tau_transport` — trust transports laxly along morphisms: phi(tau(x)) <= tau'(F(x)) (Lemma 3.2)
- `tau_consolidate` — consolidation with position maps preserves trust on the nose (Theorem 3)
- `ok_sub` — the boundary rule is stable under duplicate (the comonad's comultiplication)
- `extend_extend` — coKleisli composition is associative
- `left_counit` / `right_counit` / `coassoc` — the three comonad laws
