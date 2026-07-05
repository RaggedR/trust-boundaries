# Cross-Agent Trust Composition

Two autonomous agents — Clio and Rick — each run their own trust system
inside a Docker container. Each grades mathematical claims on a different
chain, with a different boundary and different evidence duties. This
document explains how their systems compose: what the interface maps are,
what the validator enforces, what has been tested, and what remains.

## The problem

Clio has a claim graded `proved`. Rick has a claim graded `checked-sober`.
Clio wants to cite Rick's work. Three things can go wrong:

1. **Trust inflation.** Clio calls Rick's `checked-sober` claim `proved`
   in her system — different word, higher grade. Now her downstream work
   stands on a grade Rick never assigned.

2. **Missing artifact.** Rick's `proved` claim has a proof file sitting
   in his container at `/home/agent/projects/proofs/q-hecke.md`. Clio
   points at it. Her validator can't read it — it's inside a different
   container. Trust without the artifact is a dangling pointer.

3. **Circular citation.** Clio cites Rick. Rick cites Clio. Each node
   passes its own local check. The circle is invisible to either
   validator running in isolation.

All three are real failure modes. The composition system exists to
prevent them structurally, not by convention.

## The two trust systems

### Clio

```
speculative < computed < proved < peer-reviewed < published < lean-verified
                         ^^^^^^
                         boundary
```

Evidence: `peer-reviewed` requires a `review` field, `published` requires
a `publication` field, `lean-verified` warns without `lean`.

Source blocking: a `proved` claim cannot rest on a paper known only from
an `agent-summary` (a sub-agent's paraphrase is not a paper).

### Rick

```
hunch < sketched < computed < checked-sober < proved < lean-verified
                              ^^^^^^^^^^^^^^
                              boundary
```

Evidence: `checked-sober` requires a `recheck` field (date + path of the
sober re-derivation), `proved` requires a `file` field (the proof
artifact), `lean-verified` warns without `lean`.

Source blocking: `checked-sober` cannot rest on `agent-summary` sources;
`proved` cannot rest on anything below `deep-read`.

### The asymmetry

Rick's boundary is **lower** than Clio's (`checked-sober` vs `proved`) —
he builds on things earlier. But his evidence duties are **stricter** —
`checked-sober` requires paperwork (the recheck), and `proved` always
requires the written proof file. He promotes earlier and documents harder.

## The interface maps (φ)

Each descriptor declares a `phi` map translating the other agent's grades
into its own. These are monotone maps between the two chains, strict at
bottom (unchecked maps to unchecked).

### Clio receiving Rick's grades (`clio.json` → `interfaces.rick.phi`)

| Rick's grade     | Clio sees    | Note |
|------------------|--------------|------|
| `hunch`          | `speculative`| below both boundaries |
| `sketched`       | `speculative`| two Rick grades collapse to one Clio grade |
| `computed`       | `computed`   | |
| `checked-sober`  | **`computed`** | **the key demotion** — below Clio's boundary |
| `proved`         | `proved`     | at Clio's boundary; requires artifact transport |
| `lean-verified`  | `lean-verified` | |

The critical row: Rick's `checked-sober` (above *his* boundary, build-worthy
in *his* system) maps to Clio's `computed` (below *her* boundary). Clio can
cite it. She cannot build on it. This is not a bug — it is the composition
being honest about what "re-derived it sober" means to someone who hasn't
seen the re-derivation.

### Rick receiving Clio's grades (`rick.json` → `interfaces.clio.phi`)

| Clio's grade     | Rick sees    | Note |
|------------------|--------------|------|
| `speculative`    | `hunch`      | |
| `computed`       | `computed`   | |
| `proved`         | `proved`     | Rick trusts Clio's proved |
| `peer-reviewed`  | `proved`     | Rick has no peer-reviewed grade |
| `published`      | `proved`     | |
| `lean-verified`  | `lean-verified` | |

This direction is more trusting: Clio's `proved` stays `proved` for Rick.
Whether Robin prefers `proved → checked-sober` (suspicious) is an open
question, preserved as a disagreement until it matters in practice.

### Source-extraction demotion (`source_phi`)

When Clio cites a paper through Rick's sources index (e.g. `rick:qpaper`),
the extraction level also demotes: deep-read by proxy becomes
abstract-level check locally. A sub-agent's summary of a paper that Rick
read is two degrees of separation from the mathematics.

| Rick's extraction | Clio sees locally |
|-------------------|-------------------|
| `agent-summary`   | `agent-summary`   |
| `abstract`        | `agent-summary`   |
| `deep-read`       | `abstract`        |
| `verified-quote`  | `deep-read`       |

Re-extraction locally (Clio reads the paper herself) restores the level.

## How composition works in the validator

`trustcheck.py` handles three cross-agent mechanisms, all driven by the
descriptor's `interfaces` section:

### 1. Shared stubs (registry → registry)

A Clio registry node can point at a Rick registry node via the `shared`
field:

```json
{ "id": "rick-lemma", "trust": "proved",
  "shared": "rick/hecke#q-hecke-main", "children": [] }
```

The validator resolves `rick/hecke#q-hecke-main` by:

1. Finding `peers/rick/registry/hecke.json` (the synced snapshot)
2. Looking up node `q-hecke-main` in that registry's tree
3. Applying φ to the canonical node's trust: Rick's `proved` → Clio's `proved`
4. Checking that the stub's local trust ≤ φ(canonical trust) — **trust cap**
5. If the canonical trust (after φ) is at or above Clio's boundary and
   the node has a `file`, checking that the file exists under
   `peers/rick/artifacts/` — **artifact transport**

The boundary rule then sees the stub at its φ-translated trust, so
downstream nodes that build on it are validated against the correct grade.

### 2. Peer sources (sources index → sources index)

A Clio registry node can cite a paper from Rick's sources index:

```json
{ "id": "my-node", "trust": "proved", "sources": ["rick:qpaper"] }
```

The validator resolves `rick:` prefixed sources by:

1. Reading `peers/rick/sources.json` (the synced snapshot)
2. Looking up the slug in Rick's index
3. Applying `source_phi` to Rick's extraction level

If the demoted extraction is below Clio's blocking threshold for the
claimed trust level, it errors.

### 3. Acyclicity (cross-agent cycle detection)

The validator builds a global dependency graph across all agent namespaces.
Shared stubs create edges: `main#good-import` → `rick/hecke#q-hecke-main`.
If Rick's snapshot contains a stub back to Clio, the cycle is detected by
DFS across the namespace boundary and printed with the full path.

## The φ descriptor is lint-checked

When both descriptors are available (`clio.json` alongside `rick.json`),
the validator checks the φ side conditions from the theory (Definition 3.1):

- **Total:** every grade in the source chain has a mapping
- **Monotone:** a ≤ b in the source chain ⇒ φ(a) ≤ φ(b) in the target
- **Strict at ⊥:** the bottom of the source chain maps to the bottom of
  the target chain (unchecked maps to unchecked — Lemma 3.2 needs this)

These are checked at validation time, not just at authoring time.

## What has been tested

### Fixture tests (Level 0 — code correctness)

`trustcheck/tests/cross-agent/clio-home/` contains a fixture with Clio's
validator running against a synthetic Rick snapshot. Six test cases:

| Case | What it tests | Expected | Result |
|------|--------------|----------|--------|
| `good-import` | Rick `proved` with artifact synced | pass | ✓ pass |
| `ok-src` | Rick `verified-quote` source, demotes to `deep-read` | pass | ✓ pass |
| `bad-cap` | Stub claims `proved` for Rick's `checked-sober` (φ → `computed`) | error: trust cap | ✓ error |
| `bad-boundary` | Clio `proved` building on φ-demoted `computed` child | error: boundary | ✓ error |
| `bad-artifact` | Rick `proved` but proof file not in `peers/rick/artifacts/` | error: artifact transport | ✓ error |
| `shallow-src` | `rick:qpaper` at `abstract`, source_φ → `agent-summary` | error: shallow source | ✓ error |
| `cycle` (main2) | Clio → Rick → Clio cycle | error: cycle detected | ✓ error |

### Deployment tests (Level 0 — Rick's environment)

Run 2026-07-05 on OCI, both host-side (sudo into volume) and in-container:

- Clean seed registry: exit 0 ✓
- Empty sources index: exit 0 ✓
- `checked-sober` without `recheck` field: exit 1, correct message ✓
- `trustcheck.py` runs in Rick's container python environment ✓

## What has NOT been tested

### Level 1 — solo use (pending)

Rick running his own validator on real claims inside his workflow. Does
the grade vocabulary stick? Does he use `hunch`/`sketched` at all? Does
`checked-sober` map onto his existing recheck-script culture? This is
where the descriptor design gets falsified or confirmed — expect
amendments to `rick.json`.

### Level 2 — offline composition on real data (blocked on Level 1)

Pick one Rick `proved` claim with its proof file. Sync a snapshot to
Clio's volume:

```
peers/rick/
├── registry/<name>.json     (the registry containing the proved node)
├── artifacts/proofs/<file>  (the actual proof file)
└── sources.json             (Rick's reading index)
```

Clio adds a stub + a building node in her registry. Run her validator.
Then the adversarial variants — each must fail on real data the way they
fail on fixtures:

- (a) Delete the synced proof file → artifact-transport error
- (b) Cite `checked-sober` Rick claim, Clio claims `proved` → boundary error
- (c) Forge a stub pointing back at Clio → cycle detected
- (d) Clio cites `rick:<slug>` at `abstract`, claims `proved` → source blocked

### Level 3 — live loop (the paper's evidence)

Both agents running. Rick produces a claim in his workflow; Clio cites it
in hers, unprompted beyond the standing prompts. Validators run in both
loops. Then the long-horizon measurement: after each agent's next
dream/consolidation, run `report certificate-gap` on both sides — does the
cross-agent citation survive consolidation in machine format, or does it
decay to prose? That number — certificate survival across consolidation,
across a container boundary — is the composition result. Nobody has
measured it.

## Known risks and open questions

1. **Stale snapshots.** Clio validates against a snapshot that lags Rick's
   canonical registry. Currently unhandled. A `synced-at` timestamp +
   max-age warning is the minimal mitigation.

2. **Namespace collision.** Rick's registry names must not collide with
   Clio's in the acyclicity key namespace. Currently safe: keys are
   `rick/<name>` vs `<name>`. The snapshot sync script must preserve
   names exactly.

3. **φ direction for `proved`.** Rick → Clio maps `proved → proved`
   (trusting). Robin may prefer `proved → checked-sober` (suspicious).
   Preserved as a disagreement until it first matters in practice.

4. **Agent uptime.** Rick was down for two weeks (expired OAuth) before
   anyone noticed. A stale peer snapshot (risk 1) can be caused by
   exactly this — the sync mechanism cannot out-run the credential
   expiry problem.

## The theory behind this

Composition is Corollary 3.5 of the trust systems theory
(`theory/TRUST_SYSTEMS_THEORY.md`): cross-agent citation is composition of
morphisms. Lemma 3.2 (transport of trust, Lean-verified as
`tau_transport`) gives the safe import grade: φ(τ(x)) ≤ τ′(Fx).
The φ descriptor is exactly the data of Definition 3.1 — a monotone map
between check-posets, strict at bottom, laxly compatible with grading —
and the validator is a certificate checker for the sound assignment of
Lemma 2.2, extended to check well-foundedness across agent namespaces
(Remark 2.3: circular citation passes every node-local check).

The formalization lives in `lean/Trust.lean` (the core trust system,
certificate lemma, transport) and `lean/TrustBoundary.lean` (boundary
rule stability under `duplicate`). Both build with no sorry.

## File map

| File | Role |
|------|------|
| `deployments/rick.json` | Rick's descriptor: chain, boundary, evidence, interfaces |
| `deployments/clio.json` | Clio's descriptor |
| `trustcheck/trustcheck.py` | Generic validator implementing all of the above |
| `trustcheck/tests/cross-agent/` | Fixture: 7 test cases for cross-agent validation |
| `citations-provenance/rick-citations/` | Rick's prompt amendments + registry README |
| `theory/TRUST_SYSTEMS_THEORY.md` | The mathematics |
| `lean/Trust.lean` | Lean formalization of transport (τ_transport) |
