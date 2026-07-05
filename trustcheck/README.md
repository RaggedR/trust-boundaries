# trustcheck — the generic trust-system validator

One validator, parametrized over (T, φ), replacing the per-deployment
Python ports (loop-experiment, Clio, MacBeth). The theory is
`notes/TRUST_SYSTEMS_THEORY.md`; this is its reference implementation.
A deployment is a JSON descriptor under `deployments/` — the check chain
T, the extraction chain, the interface map φ (as monotone blocking
thresholds), the evidence fields, the citation formats. A fourth
deployment is a fourth descriptor, not a fourth port.

Stdlib only. Advisory: readable messages, exit 0 = clean.

Note: the Clio and MacBeth deployment descriptors (clio.json,
macbeth.json) moved to the trust-boundaries repo (~/git/trust-boundaries)
— they are agent configuration, part of each agent's identity, and live
with Robin's personal agent infrastructure. Only loop.json remains here.

## The dictionary: check ↔ theory

| check | theory | notes |
|---|---|---|
| boundary rule (`validate`) | node-local soundness (†), Def 2.1 / Lemma 2.2 | a node claims ≥ `boundary_at` only if every non-dead-end child does; certifies t ≤ τ without computing τ |
| acyclicity (`validate`) | well-foundedness, Remark 2.3, Lean `cyc` | explicit DFS on the premise digraph over (registry, node-id), including `shared` edges. A single JSON tree is acyclic by format; `shared` links break tree-ness, and the one-hop rule does NOT exclude cycles — circular citation passes every node-local check while τ = ⊥ |
| source blocking (`validate`) | the interface map φ, Cor 3.4 | `blocking: [{below_extraction, blocks_trust}]` — thresholds of a monotone map T_extraction → T; a claim at `blocks_trust` may not rest only on sources extracted below `below_extraction` |
| `shared` stubs + trust cap | cross-agent citation, Cor 3.5 | stub trust is a cache that must not exceed the canonical node's trust; one-hop resolution |
| evidence fields | "a self-assigned label with no artifact is trust inflation" | per-level required fields from the descriptor (`review`, `publication`, `lean`, …); stubs exempt (evidence lives at the canonical node) |
| refutation sub-poset | §5 negative provenance | dead-ends graded `judgment < computed < proved < lean-verified` |
| `report certificate-gap` | §4, the two failure modes of consolidation | see below |

## The certificate-gap report

Classifies every outgoing reference of the given files:

- **(a) machine format, resolves** — a valid cached ρ (Def 4.1's position
  map, cached in the validator's format).
- **(b) machine format, dangling** — broken cache; the hallucinated-reference
  case.
- **(c) prose, resolves extensionally** — **mode 2**: a consolidation exists
  and τ is preserved (Theorem 4.2), but the *certified* trust t is below
  canonical τ (Lemma 2.2 (ii)) because no machine-parseable certificate was
  written. Backfill candidates: one more machine-only consolidation layer and
  mode 2 becomes mode 1 (unparseable ρ read as absent ρ).
- **(d) prose, unresolvable** — mode-1 candidates (ρ absent).

Prose detection is deliberately conservative: path-shaped tokens with text
extensions, resolved against the descriptor's `prose_roots` (direct join,
then recursive basename search preferring the longest trailing-component
match), with `lines N–M` locators length-checked; plus registered source ids
named without a machine citation. It is an existence check on candidate ρ
caches, not a parser.

This report mechanizes the G13 hand-trace of 2026-07-04
(`loop-experiment/2026-07-04/synthesis-layer4.md` and the seed-1 files):
zero machine-resolvable citations, yet the load-bearing prose citations —
Warnaar's `source.tex` lines 2672–2687, Uncu's `main.tex`, every seed and
verifier file — all resolve extensionally. The measured "degradation" is
the gap t < τ, not a drop in τ.

## Usage

```bash
# loop experiment (run from loop-experiment/, or set --root)
trustcheck.py --deployment deployments/loop.json \
    validate registry/warnaar.json
trustcheck.py --deployment deployments/loop.json \
    sources 2026-07-04/scratch/*.md
trustcheck.py --deployment deployments/loop.json \
    report certificate-gap 2026-07-04/synthesis-layer4.md

# Clio / MacBeth (run from their project root)
trustcheck.py --deployment deployments/clio.json \
    validate proofs/registry/three-row-even-jstar.json
trustcheck.py --deployment deployments/macbeth.json \
    report cross-refs proofs/registry/equivalence-chain.json
```

Reports: `successful-path`, `dead-ends`, `frontier`, `cross-refs`
(registry) and `footprint`, `shallow`, `certificate-gap` (files).
Overrides: `--root`, `--sources`, `--chunks-dir`, `--files-dir`,
`--registry-dir`; pass `skip` to disable a check family.

## Descriptor schema (informal)

```jsonc
{
  "name": "...",
  "trust": {
    "chain": ["weakest", "...", "strongest"],   // T, a finite chain
    "special": ["dead-end", "in-progress", "unclassified"],
    "boundary_at": "proved",                    // threshold for (†)
    "refutation_chain": ["judgment", "..."],    // §5
    "evidence": {"level": {"field": "...", "severity": "error|warning", "hint": "..."}}
  },
  "sources": {
    "format": "loop-sources-v1",                // index format tag
    "default_path": "sources.json",             // relative to --root
    "extraction_chain": ["...", "..."],         // T_extraction
    "blocking": [{"below_extraction": "...", "blocks_trust": "..."}],  // φ
    "corpus_dir": "../literature/chunks",       // chunk deployments only
    "corpus_exempt": ["recalled"]
  },
  "citation": {
    "machine_regex": "...",                     // the certificate format
    "machine_resolve": "corpus-file | index",
    "machine_suffix": ".tex",                   // corpus-file only
    "prose_roots": [".", "../literature"]       // certificate-gap search
  },
  "interfaces": {                               // cross-agent morphisms, Cor 3.5
    "<peer-name>": {
      "registry_dir": "peers/<peer>/registry",  // synced snapshot of peer registries
      "artifact_root": "peers/<peer>/artifacts",// synced evidence files
      "sources_path": "peers/<peer>/sources.json", // peer's sources index (snapshot)
      "on_missing_artifact": "error | warning",
      "phi": {"<peer-level>": "<own-level>"},   // monotone, strict at bottom, total
      "source_phi": {"<peer-extraction>": "<own-extraction>"}
    }
  }
}
```

Cross-agent reference formats: a stub's `shared` names a peer registry as
`"<peer>/<registry>#<node-id>"`; a node's `sources` entry names a peer's
source as `"<peer>:<slug>"` (resolved in the peer's index at
`sources_path`, extraction demoted through `source_phi`).

## Cross-agent interfaces (draft, 2026-07-05)

The `interfaces` section serializes a morphism of trust systems
(Definition 3.1): for each peer, a monotone map φ : T_peer → T_own on the
trust chains and a monotone map source_φ on the extraction chains. A
`shared` stub `"<peer>#<node-id>"` whose registry name matches an interface
key resolves against `registry_dir` (a *synced snapshot* — agents live in
separate containers, so citing a peer's registry means carrying a copy),
and the canonical trust is read **through φ** before any local check runs.

Validation semantics (implemented 2026-07-05; exercised by the fixture in
`tests/cross-agent/` — six positive/negative cases including a cross-agent
citation cycle, plus a descriptor-level negative test of a broken phi):

1. **φ is checked, not trusted.** The validator verifies φ is total on the
   peer's chain, monotone with respect to both chain orders, and strict at
   bottom (peer ⊥ ↦ own ⊥; specials map to specials). A non-monotone φ is
   a descriptor error, not a registry error.
2. **Effective trust of a cross-agent stub** = φ(canonical trust). The
   stub-cap rule (Cor 3.5) and the boundary rule (†) both operate on the
   transported value, in the consumer's chain. Lemma 3.2 says this is the
   best safe grade; the validator never grades an import higher.
3. **Trust transport requires artifact transport.** If φ(canonical trust)
   ≥ the consumer's `boundary_at`, the canonical node's evidence file must
   resolve under `artifact_root` — evidence that lives only in the peer's
   container is one OOM away from unchecked (registry lesson, 2026-07-04).
   Severity per `on_missing_artifact`.
4. **Extraction does not survive delegation at full strength.** A source
   cited *via* a peer's index enters at source_φ(peer extraction level) —
   the drafted maps demote one level (the consumer holds the peer's
   extraction record, not the extraction itself; a deep-read by proxy is
   an abstract-level check). Re-extracting locally restores the level:
   laxness in Definition 3.1 permits the re-check, forbids the free ride.

First deployed pair: rick ↔ clio (`~/git/trust-boundaries/deployments/`).
The two chains are deliberately non-isomorphic — Rick's
`hunch < sketched < computed < checked-sober < proved < lean-verified`
with `boundary_at: checked-sober` against Clio's standard chain with
`boundary_at: proved` — so that φ is a nontrivial monotone map and the
composed system exercises Lemma 3.2 rather than φ = id. Note the
asymmetry: Rick's `checked-sober` (his boundary) lands at Clio's
`computed` (below hers), so Rick can build on claims Clio may cite but
not build on. The interface is where the two standards actually meet.

## Regression status (2026-07-04)

Verified identical verdicts with the deployed ports on: the loop registry
(`warnaar.json`) and `sources.json`; Clio's `staircase-t-system.json` and
`three-row-even-jstar.json`; MacBeth's `equivalence-chain.json` and
`pairwise-zs.json` (incl. the `cross-refs` report, byte-identical); Clio's
sources index (same 29 advisory problems). Two deliberate differences:
evidence-field checks are descriptor-driven (adds the `lean` warning to
Clio/MacBeth, exempts shared stubs), and a cross-registry citation cycle —
which every deployed port accepts silently — is rejected with the cycle
path printed.
