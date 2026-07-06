# Three-Agent Citation Chain Test

The first three-agent citation chain: Clio → Rick → MacBeth.

## The chain

```
MacBeth                    Rick                       Clio
┌─────────────────┐       ┌──────────────────┐       ┌─────────────────────┐
│ comonad-laws    │       │ boundary-stability│       │ trust-composition   │
│ [lean-verified] │◄──────│ [proved]         │◄──────│ [proved]            │
│                 │ shared│                  │ shared│                     │
│ D1-D5, counit,  │       │ ok_sub via D4    │       │ ok_sub + tau_transport│
│ coassociativity │       │ cites MacBeth's  │       │ cites Rick's proof  │
└─────────────────┘       │ comonad laws     │       │ (which cites MacBeth)│
                          └──────────────────┘       └─────────────────────┘
```

## Trust chain composition (phi)

Each agent has a different trust chain:

| Agent | Chain | Boundary |
|-------|-------|----------|
| MacBeth | speculative < computed < peer-claimed < proved < peer-reviewed < published < lean-verified | proved |
| Rick | hunch < sketched < computed < peer-claimed < checked-sober < proved < lean-verified | checked-sober |
| Clio | speculative < computed < peer-claimed < proved < peer-reviewed < published < lean-verified | proved |

The composed phi (Clio ← Rick ← MacBeth):

```
MacBeth's lean-verified  →  Rick's lean-verified  →  Clio's lean-verified
MacBeth's peer-reviewed  →  Rick's proved          →  Clio's proved
MacBeth's speculative    →  Rick's hunch            →  Clio's speculative
```

Monotonicity is preserved through both hops — Lemma 3.2 composes.

## Running the test

```bash
# Validate from Clio's perspective (resolves through Rick into MacBeth)
cd clio && python3 trustcheck.py --deployment clio.json --root . --sources skip \
  validate registry/trust-composition.json --files-dir skip

# Validate from Rick's perspective (resolves into MacBeth)
cd rick && python3 trustcheck.py --deployment rick.json --root . --sources skip \
  validate registry/boundary-stability.json --files-dir skip

# See the cross-agent refs
cd clio && python3 trustcheck.py --deployment clio.json --root . --sources skip \
  report cross-refs registry/trust-composition.json

# Cofree annotation (full comonadic context)
cd clio && python3 trustcheck.py --deployment clio.json --root . --sources skip \
  ops cofree registry/trust-composition.json
```

## What this tests

1. **Shared ref resolution across agent boundaries** — Clio's stub at `peer-claimed` resolves to Rick's canonical `proved` via phi
2. **Rick's internal shared ref to MacBeth** — Rick's `checked-sober` stub resolves to MacBeth's canonical `lean-verified` via phi
3. **The boundary rule with transported trust** — Clio claims `proved` at root; child `boundary-stability` is locally `peer-claimed` but transports to `proved` via phi; the boundary rule passes
4. **Non-isomorphic trust chains** — Rick's chain has `hunch`, `sketched`, `checked-sober` which don't exist in Clio's or MacBeth's; phi maps them correctly
5. **Monotonicity of composed phi** — the composite Clio ← Rick ← MacBeth is order-preserving

## What it proves about the system

The trust system's three-agent composition works: an autonomous agent (Clio) can build a proved claim on the work of another agent (Rick), who built on the formalization of a third (MacBeth), with the trust levels correctly translated through two different interface maps. The directed container structure — specifically, the fact that morphisms compose (cofunctor composition in `DContCat.lean`) — is what makes this safe.
