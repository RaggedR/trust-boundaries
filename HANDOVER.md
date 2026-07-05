# HANDOVER — Rick deployment + first cross-agent composition test

Written 2026-07-05 by the instance that built the cross-agent φ support.
State: **committed and pushed** (`a137bb0` on main). Working tree clean.

## What exists (done, do not redo)

- `deployments/rick.json` — Rick's trust system, deliberately non-isomorphic
  to Clio's: chain `hunch < sketched < computed < checked-sober < proved <
  lean-verified`, `boundary_at: checked-sober` (LOWER than Clio's `proved`),
  but stricter evidence: `checked-sober` requires a `recheck` field (error),
  `proved` requires a `file` (error). Two source-blocking rules.
- `interfaces` sections in `rick.json` and `clio.json` — the (φ, source_φ)
  data of Def 3.1 / Cor 3.5, both directions. Key asymmetry: φ sends Rick's
  `checked-sober ↦ computed` (below Clio's boundary — she can cite but not
  build on it). source_φ demotes extraction one level (deep-read by proxy
  is an abstract-level check). Re-extraction locally restores it.
- `trustcheck/trustcheck.py` — full φ implementation: descriptor lint
  (total/monotone/strict-at-⊥), `shared: "<peer>/<registry>#<node-id>"`
  resolved through peer snapshots at φ(canonical), artifact-transport rule
  (import ≥ own boundary ⇒ evidence file under `artifact_root`, severity
  `on_missing_artifact`), peer sources `"<peer>:<slug>"` via `sources_path`
  demoted through source_φ, acyclicity DFS across agent namespaces.
- `trustcheck/tests/cross-agent/` — fixture: 4 failing cases + 2 clean +
  cross-agent cycle. Regression vs HEAD^ was byte-identical on all four
  Clio/MacBeth registries. README documents schema + semantics.

## Rick's actual state (verified 2026-07-05)

- **Container `Rick` is STOPPED** on OCI ("container ... is not running").
  Nobody investigated why. Check `docker logs Rick --tail 50` before
  restarting; compose file at `~/agents/grandpa-rick/docker-compose.yml`.
- **He has NO trust infrastructure.** No sources.json, no registry dir, no
  trust vocabulary in prompts. The `*_check.py` files in his volume are his
  own ad-hoc per-proof verification scripts — an existing recheck culture
  that `checked-sober` formalizes. Good sign, not infrastructure.
- Host layout: config/prompts at `/home/ubuntu/agents/grandpa-rick/`
  (Dockerfile, prompts/, scripts/, skills/, identity/). Projects volume:
  `/var/lib/docker/volumes/grandpa-rick_agent-projects/_data` (host sudo)
  = `/home/agent/projects` in-container. Structure: `code/ proofs/ papers/
  reading/ reviews/ scratch/ memory/` — memory has SUMMARY.md,
  dream-journal/, connections/, questions/, topics/.
- Template for the deployment: `citations-provenance/clio-citations/`
  (prompts + sources.json + CITATIONS-README.md) and
  `citations-provenance/clio-registry/` (registry + clio-loop.sh). Clio's
  prompts live in her host config; Rick's amendments go in
  `~/agents/grandpa-rick/prompts/` (boot/prove/write/dream, whichever
  exist — check first).

## Phase 0 — give Rick the base system (before any composition)

1. **Prompt amendments** — teach the trust vocabulary in HIS chain and HIS
   voice (`hunch`/`sketched`/`checked-sober` need explaining; do not
   copy-paste Clio's `speculative`/`proved` text). Model on
   `citations-provenance/clio-citations/prompts/`. Robin reviews before
   install — prompts are identity.
2. **Install** into his projects volume: `trustcheck.py` + `rick.json`
   (NOT ports of citation_check.py/registry_validate.py — Rick is the
   first deployment born on the generic validator; that's the theory's
   "fourth deployment is a fourth descriptor" claim tested at deploy
   time). Plus `proofs/registry/` skeleton and empty
   `memory/reading/sources.json` (`clio-sources-v1`, empty sources).
3. **Bring the container up** (after reading logs for why it stopped).
4. **Let him run.** Composition needs real Rick claims at honest grades.
   Do not rush to Phase 1 with an empty registry.

## The test plan (Robin asked; answer in full)

**Level 0 — install sanity (Rick's container, day one).** `trustcheck.py
--deployment rick.json validate` on a seed registry; `sources` on the empty
index. Exit 0. Then seed ONE deliberate violation (a `checked-sober` node
without `recheck`) and confirm it errors — the evidence duties must bite in
his environment, not just ours.

**Level 1 — his system, solo (first few cycles).** Rick registers a real
q-Hecke conjecture, grades honestly, runs the validator in his loop (model
on `clio-loop.sh`). Watch: does he use `hunch`/`sketched` at all, does
`checked-sober` map onto his existing recheck scripts, do the two blocking
rules fire on his actual reading habits? This is where the descriptor
design gets falsified or confirmed — expect to amend `rick.json`.

**Level 2 — composition, offline (the real test of φ).** Pick ONE Rick
claim at `proved` with its proof file. Sync a snapshot to Clio's side:
`peers/rick/{registry/,artifacts/,sources.json}` in her projects volume
(host-side rsync between volumes; the sync script IS the artifact-transport
mechanism — write it once, cron later). Clio adds a stub + a building node.
Run HER validator. Then the adversarial variants, each must fail correctly:
  a. delete the synced proof file → artifact-transport error
  b. point at a `checked-sober` Rick claim, Clio claims `proved` above it
     → boundary error (φ demotion doing real work)
  c. forge a stub in the snapshot pointing back at Clio's node → cycle
     printed with the container boundary in the path
  d. Clio cites `rick:<slug>` where Rick's extraction is `abstract`, claims
     `proved` → blocked (source_φ demotion)
These are the fixture cases re-run on REAL data — the fixture proves the
code, Level 2 proves the deployment.

**Level 3 — live loop (the paper's evidence).** Both agents running. Rick
produces a claim inside his own workflow; Clio cites it inside hers,
unprompted beyond the standing prompts. Validators run in both loops. Then
the long-horizon measurement: after each agent's next dream/consolidation,
run `report certificate-gap` on both sides — does the cross-agent citation
survive consolidation in machine format, or does it decay to prose (mode 2)
within one cycle? That number — certificate survival across consolidation,
across a container boundary — is the composition result for the arXiv
preprint. Nobody has measured it.

**Known risks.** (i) Stale snapshots: Clio validates against a snapshot
that lags Rick's canonical registry — currently unhandled; consider a
synced-at timestamp + max-age warning in a follow-up. (ii) Rick's registry
names must not collide with Clio's local registry names in the acyclicity
key namespace (keys are `rick/<name>` vs `<name>`, so they can't — but the
snapshot sync script must preserve names exactly). (iii) `phi` maps Clio's
`proved ↦ proved` for Rick (trusting); Robin may prefer `proved ↦
checked-sober` (suspicious) — preserved disagreement, ask him when it
first matters in practice.

## Sequencing note

Phase 0 step 1 (prompts) needs Robin's review; step 3 (container restart)
may need Robin if the stop reason is resource/config. Everything else is
autonomous. Read `~/.claude/AGENT.md` first if you spawn sub-agents.
