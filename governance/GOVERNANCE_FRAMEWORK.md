# Governance Framework for Trust System Upgrades

Date: 2026-07-11. Status: proposal.

Inspired by [LalaSkye/start-here](https://github.com/LalaSkye/start-here) —
Ricky Jones's execution-boundary AI governance framework (TrinityOS/AlvianTech).

---

## The problem

The trust system has no governance layer over itself. Trust levels, boundary
rules, interface maps (φ), and deployment descriptors can all be modified by
any Claude instance with file access. There is no decision record, no commit
gate, and no replay protection for changes to the system's own configuration.

Today, a single instance can:
- Add or remove trust levels from a chain
- Move the boundary (e.g., from `proved` to `computed`)
- Modify a φ map so that imported grades inflate silently
- Deploy a new agent descriptor with no review

The trust system enforces epistemic honesty on mathematical claims. It does
not enforce epistemic honesty on changes to itself.

---

## Core invariant

Borrowing from LalaSkye's execution-boundary principle:

> **No valid governance record → no system mutation.**

A change to any trust system component (chain, boundary, φ map, evidence
rules, deployment descriptor) requires a governance record before the change
takes effect. The record is immutable, hashed, and auditable.

---

## Mapping: execution boundary → trust boundary

| LalaSkye concept | Trust system analogue |
|------------------|----------------------|
| Action (read/write/delete/deploy) | System mutation (add-level, move-boundary, edit-φ, deploy-agent) |
| Authority claim | Who proposes the change (agent identity + human approval) |
| Policy (allowed/forbidden) | Governance rules (see §3 below) |
| DecisionRecord | GovernanceRecord (see §4) |
| CommitGate | The check that a GovernanceRecord exists before descriptor is written |
| Verdict (ALLOW/DENY/ESCALATE) | Same three outcomes |
| Paradox detection | Consistency checks (φ monotonicity, chain acyclicity, boundary coherence) |
| Fail-closed | Default DENY: if governance record is absent or invalid, mutation is blocked |

---

## 1. What is governed

### 1.1 Trust chain modifications

Adding, removing, or reordering levels in an agent's trust chain T.

**Why this matters:** Removing a level can orphan existing claims. Adding a
level below the boundary inflates what counts as "trusted." Reordering
changes the semantics of every grade comparison.

### 1.2 Boundary moves

Changing which level sits at the boundary.

**Why this matters:** Moving the boundary down (e.g., `proved` → `computed`)
means weaker evidence crosses into the trusted core. Moving it up
(e.g., `proved` → `lean-verified`) may invalidate existing above-boundary
claims that lack the new evidence.

### 1.3 Interface map (φ) changes

Modifying how one agent's grades translate into another's.

**Why this matters:** A φ change can silently inflate or deflate imported
trust. The key asymmetry (Rick's `checked-sober` → Clio's `peer-claimed`)
is a deliberate demotion. Changing it to `proved` would let Clio build on
Rick's work without independent verification.

### 1.4 Evidence rule changes

Modifying what evidence is required at each trust level.

**Why this matters:** Weakening evidence rules (e.g., removing the
requirement that `proved` needs a proof file) undermines the entire
system silently.

### 1.5 New agent deployment

Adding a new deployment descriptor.

**Why this matters:** A new agent enters the composition. Its φ maps
with existing agents must be defined, monotone, and strict at ⊥.

---

## 2. Authority model

### 2.1 Roles

| Role | Can propose | Can approve |
|------|-------------|-------------|
| Agent (Clio, Rick, MacBeth, etc.) | Own descriptor changes | No |
| Robin (human) | Any change | Yes |
| Peer agent | φ map changes affecting them | Advisory only |

### 2.2 The human-in-the-loop requirement

All governance mutations require human approval. An agent may propose a
change (e.g., "I think my boundary should move to `peer-claimed` because
I now have a registry of peer reviews"), but the change does not take effect
until Robin approves it.

This is not a limitation — it is the design. The trust system governs
agent claims about mathematics. The governance system governs agent claims
about the trust system itself. The latter requires a higher authority.

### 2.3 The four-agent rule

Every trust-system change must be deployed to all four systems (Clio, Rick,
MacBeth, and dreaming-agent). A change deployed to one agent but not the
others creates a composition inconsistency that the validator cannot detect
in isolation.

---

## 3. Governance rules (policy)

### 3.1 Monotonicity preservation

A φ map change must preserve monotonicity: if a ≤ b in the source chain,
then φ(a) ≤ φ(b) in the target chain. The validator already checks this
for new descriptors. The governance rule extends it to modifications.

### 3.2 Strict-at-⊥ preservation

φ(⊥) = ⊥. The bottom of one chain must map to the bottom of the other.
Without this, an unchecked claim in one system could arrive as something
non-trivial in another.

### 3.3 Boundary coherence

If agent A's boundary is at level `b_A`, and φ maps a grade `g` from
agent B such that φ(g) ≥ b_A, then agent B's boundary `b_B` must
satisfy g ≥ b_B. In words: a grade that crosses A's boundary via φ must
have already crossed B's boundary. Trust does not teleport.

### 3.4 Evidence monotonicity

Evidence requirements can be strengthened (more evidence at a given level)
but not weakened without explicit justification. Weakening is an ESCALATE,
not a DENY — it requires documented rationale.

### 3.5 Chain extension only

New levels may be added to a chain. Existing levels may not be removed if
any claim currently holds that level. Rename is an add-then-migrate-then-remove
sequence, not an atomic operation.

### 3.6 No self-governance

An agent cannot approve changes to its own trust system. This prevents the
obvious attack: an agent lowers its own boundary to make its claims appear
more trustworthy.

---

## 4. GovernanceRecord

```
GovernanceRecord {
    record_id:      SHA-256 of canonical fields
    timestamp:      ISO-8601
    proposer:       AgentID | "robin"
    mutation_type:  "chain" | "boundary" | "phi" | "evidence" | "deploy"
    target:         DeploymentDescriptor path
    before:         Hash of descriptor before change
    after:          Hash of descriptor after change
    diff:           Human-readable description of what changed
    rationale:      Why this change is needed
    approved_by:    "robin" (required)
    approval_date:  ISO-8601
    checks_passed:  List<GovernanceCheck>
}
```

The record is a frozen object. It is never mutated after construction.
The `record_id` is computed from the canonical JSON of all other fields.

### 4.1 Checks

Before approval, the following automated checks run:

| Check | What it verifies |
|-------|-----------------|
| `monotone_phi` | All φ maps in the modified descriptor are monotone |
| `strict_bottom` | φ(⊥) = ⊥ for all φ maps |
| `boundary_coherent` | Boundary coherence (§3.3) holds across all agent pairs |
| `evidence_monotone` | No evidence requirement was weakened without ESCALATE |
| `chain_superset` | New chain is a superset of old chain (no removals of in-use levels) |
| `four_agent_sync` | Change is staged for all four agents |
| `validator_clean` | `trustcheck.py` passes on all registries with the new descriptor |

---

## 5. Implementation path

### Phase 0: Document (this file)

Establish the governance vocabulary and rules. No code changes.

### Phase 1: GovernanceRecord schema

Add a `governance/` directory to each deployment. Each change to a
descriptor is accompanied by a GovernanceRecord JSON file.

### Phase 2: Pre-commit validation

Extend `trustcheck.py` to validate GovernanceRecords: check that every
descriptor modification has a corresponding record, that the record's
`before` hash matches the previous commit, and that all checks passed.

### Phase 3: Audit trail

GovernanceRecords are append-only. The sequence of records for a
descriptor tells the full history of its evolution. This is the trust
system's own provenance chain.

---

## 6. Relationship to LalaSkye's execution-boundary governance

LalaSkye/start-here (Ricky Jones, TrinityOS/AlvianTech) is an
execution-boundary AI governance framework. Its canonical invariant:

> **No valid decision record → no state mutation on the demonstrated path.**

Our trust system's canonical invariant:

> **No valid evidence → no claim crosses the boundary.**

Both are gate-before-mutation architectures. The comparison below
maps out where they converge, where they diverge, and where
composition would be valuable.

### 6.1 Structural convergence

The two systems share five design commitments:

**1. Fail-closed by default.** LalaSkye's engine returns DENY for
unknown actions, malformed inputs, ambiguous authority, and any case
not explicitly allowed. Our `trustcheck.py` treats missing evidence
as a boundary violation. Neither system lets uncertainty pass silently.

**2. Immutable records.** LalaSkye uses frozen dataclasses
(`@dataclass(frozen=True)`) with canonical SHA-256 hashing. Our trust
grades are bound to claims in JSON registries and validated against
the canonical τ (Lemma 2.2). Both systems treat the record as a
sealed artifact: once emitted, never mutated.

**3. Pure-function gates.** LalaSkye's `commit_gate()` is explicitly
documented as "pure function, no hidden state, no side effects, no
mutation." Our boundary rule is a well-founded recursion over a DAG
— equally pure, equally deterministic. Same inputs → same outputs.

**4. Separation of evaluation from execution.** LalaSkye's
GovernanceEngine evaluates scenarios and produces DecisionRecords.
The CommitGate is a separate layer that checks those records before
permitting state mutation. Our system separates grading (assign trust
levels) from enforcement (the boundary rule blocks under-evidenced
claims). In both systems, the decision and the action are distinct
steps with an inspectable gap between them.

**5. Bounded claims.** LalaSkye's PRINCIPLES.md states: "A repo that
claims one narrow thing, and proves it, is defensible. A repo that
claims everything, and proves nothing, is noise." Our system enforces
the same discipline on mathematical claims — a `proved` grade on a
narrow lemma is worth more than a `speculative` grade on a sweeping
conjecture. LalaSkye's CLAIM_BOUNDARY.md even lists "forbidden claims"
(adoption, certification, production readiness) alongside "allowed
claims." Our system has an analogous structure: the trust chain is an
explicit list of what can and cannot be claimed at each level.

### 6.2 Structural divergence

**1. Authorization vs epistemics.** This is the fundamental difference.
LalaSkye gates **actions** — read, write, delete, deploy. The question
is "does this agent have authority to do this thing?" Our system gates
**claims** — speculative, computed, proved. The question is "does this
claim have enough evidence to be at this level?" LalaSkye is about
power. We are about knowledge.

**2. The verdict space.** LalaSkye has three verdicts: ALLOW, DENY,
ESCALATE. Clean and sufficient for authorization. Our system has a
richer diagnostic space. `trustcheck.py` reports:

- **TIGHT** — grade matches the canonical τ exactly
- **CONSERVATIVE** — grade is below τ, safe to upgrade
- **INFLATED** — grade is above τ, must downgrade

This is not just pass/fail — it is a *measurement*. It tells you how
far off you are and in which direction. LalaSkye's gate is a boolean
with an escape hatch. Ours is a calibrated instrument.

**3. The authority model.** LalaSkye uses role-based access control:
admin, operator, reviewer. Standard RBAC with scope tables. Our system
uses **identity-based** authority with asymmetric trust chains. Clio
and Rick don't have "roles" — they have *different epistemologies*.
Rick promotes earlier but documents harder (`checked-sober` requires
a dated re-derivation artifact). Clio demands more before crossing
the boundary but accepts peer claims. The φ maps encode this
asymmetry structurally, not as policy metadata.

**4. Paradox detection vs consistency checking.** LalaSkye has a
pre-gate paradox sink (`paradox.py`) that catches contradictions before
evaluation: temporal paradoxes (authority expired before action
requested), structural paradoxes (contradictory fields), authority
paradoxes. These are *syntactic* contradictions — detectable from
a single record in isolation.

Our consistency checking is *semantic*: φ monotonicity (order
preservation across chains), strict-at-⊥ (bottom maps to bottom),
boundary coherence (a grade that crosses A's boundary via φ must
have already crossed B's boundary), and transitive cycle detection
across agent namespaces. These invariants require reasoning about
the composition of multiple agents, not just a single record.

**5. Composability.** This is where the gap is widest. LalaSkye
explicitly acknowledges no cross-agent composition story. His gate
checks each agent independently. The NON-CLAIMS.md lists
"path-universal governance" and "cross-decision hash chaining" as
things the system does not claim.

Our system's entire architecture is built around composition: the
φ maps define how trust translates between agents, the three-agent
chain test verifies transitive trust transport (MacBeth → Rick → Clio
through non-isomorphic chains), and the validator detects cross-agent
cycles. This is the contribution that LalaSkye's framework lacks
and that ours provides.

**6. Formalization.** LalaSkye has Python implementation + pytest.
We have Python implementation + pytest + sorry-free Lean 4 proofs.
The certificate lemma (Lemma 2.2), transport of trust (Lemma 3.2),
and consolidation preservation (Theorem 4.3) are mechanically
verified. This is a categorically stronger guarantee — not just
"the tests pass" but "the theorem holds for all possible inputs."

**7. Replay protection.** LalaSkye has explicit replay detection:
the EventLog tracks seen request IDs and blocks duplicates. Our
system does not currently have replay protection for trust-level
changes. This is a gap we should close (see §7.1).

### 6.3 Summary table

| Dimension | LalaSkye (start-here) | Trust boundaries |
|-----------|----------------------|-----------------|
| Domain | Execution boundary | Epistemic boundary |
| Core question | "Is this action authorized?" | "Is this claim warranted?" |
| What is gated | State mutation (any) | Trust-level assignment |
| Gate mechanism | CommitGate (pure function) | Boundary rule (well-founded recursion) |
| Record type | DecisionRecord (frozen, hashed) | Trust grade (in JSON registry, validated against τ) |
| Verdict space | ALLOW / DENY / ESCALATE | TIGHT / CONSERVATIVE / INFLATED |
| Authority model | RBAC (admin/operator/reviewer) | Identity-based (agents + human, asymmetric φ) |
| Consistency checks | Syntactic paradox sink | Semantic φ-consistency (monotone, strict-at-⊥, boundary-coherent) |
| Composability | Per-agent only | Cross-agent φ composition with cycle detection |
| Replay protection | Yes (EventLog) | No (gap) |
| Hash chaining | Per-record only (acknowledged gap) | Not yet (proposed in §7.1) |
| Formalization | Python + pytest | Lean 4 (sorry-free) + Python + pytest |
| Provenance model | PROVENANCE.md (git history) | Citation chains (sources.json, registry nodes) |
| Disclosure discipline | CLAIM_BOUNDARY.md, NON-CLAIMS.md | Trust levels are the disclosure discipline |

### 6.4 What each system could learn from the other

**LalaSkye → Trust boundaries:**
- Replay protection. LalaSkye's EventLog pattern is simple and
  effective. We should add request-ID tracking to governance records.
- Scenario-driven testing. LalaSkye's `scenarios/` directory with
  expected outputs is a clean pattern. We have fixtures in
  `trustcheck/tests/` but not scenario-level governance tests.
- The paradox sink is a good idea even for our system. Catching
  contradictions *before* running the full validator would give
  faster, clearer error messages.

**Trust boundaries → LalaSkye:**
- Cross-agent composition. LalaSkye needs a story for what happens
  when Agent A's ALLOW feeds into Agent B's evaluation. The φ maps
  are a proven pattern for this.
- The CONSERVATIVE/INFLATED diagnostic. Telling a user "you're
  denied, and here's specifically how far off you are" is more
  useful than a bare DENY.
- Formal verification. A Lean proof that the commit gate's invariant
  holds for all inputs would be a stronger claim than 12 scenario
  tests.

### 6.5 Composition: how the two systems could work together

The systems address different layers of the same stack:

```
Layer 3: Governance of governance     ← this document
Layer 2: Execution boundary           ← LalaSkye's commit gate
Layer 1: Epistemic boundary           ← our trust system
Layer 0: Mathematical claims          ← the actual work
```

LalaSkye's commit gate could wrap our trust system's descriptor
writes, providing execution-boundary enforcement (authorization,
replay protection, audit trail) while our system provides the
epistemic-boundary semantics (φ consistency, boundary coherence,
evidence duties).

Concretely: before `trustcheck.py` writes a modified deployment
descriptor, it would submit the change as a Packet to LalaSkye's
GovernanceEngine. The engine evaluates authority (is this agent
allowed to propose this change?), policy (does the change violate
governance rules?), and paradox (does the change contradict itself?).
Only an ALLOW verdict with a valid DecisionRecord permits the write.

The DecisionRecord becomes the GovernanceRecord from §4, gaining
the additional fields specific to trust-system mutations (before/after
hashes, φ consistency checks, boundary coherence). The record is then
stored in `governance/` as an append-only audit trail.

This composition is the reflexive application: the trust system
that governs mathematical claims is itself governed by an execution
boundary that governs state mutations.

---

## 7. Open questions

1. **Should GovernanceRecords be hash-chained?** LalaSkye notes
   per-record hashing without cross-decision chaining as a "current
   hardening gap" in start-here. For our system, chaining would
   provide tamper-evidence across the sequence of descriptor changes.
   Both systems share this gap.

2. **Replay protection.** LalaSkye's EventLog tracks seen request IDs
   and blocks duplicates. Our system has no equivalent. A malicious or
   confused instance could re-propose a previously rejected change.
   Adding request-ID tracking to GovernanceRecords would close this.

3. **Should agents be able to ESCALATE governance changes to Neil?** The
   current model has Robin as the sole approver. For Kodamai work,
   Neil might be an additional authority for MacBeth-related changes.
   LalaSkye's RBAC model (admin/operator/reviewer) is simpler but
   less expressive than our identity-based model.

4. **How does this interact with the Lean formalization?** Changes to the
   trust chain T are changes to the type parameter of the certificate
   lemma. The Lean proofs are parametric in T, so they hold for any chain
   — but a governance record documenting *why* a chain changed would be
   valuable provenance for the formalization itself.

5. **Should we adopt LalaSkye's paradox sink?** Pre-gate contradiction
   detection (temporal, structural, authority paradoxes) would catch
   malformed governance proposals before running the full φ-consistency
   checks. This is cheap to implement and provides better error messages.

6. **Is there a natural φ map between the two systems?** If LalaSkye's
   verdict space (ALLOW/DENY/ESCALATE) and our diagnostic space
   (TIGHT/CONSERVATIVE/INFLATED) are both bounded chains, there may be
   a monotone map between them — making the two systems composable in
   the same sense that Clio and Rick are composable. This is speculative
   but worth investigating.
