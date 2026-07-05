# Trust Boundary Design for the AI Mathematician (Proposed)

*Modelled on the concentric architecture in "Starting Simple: AI Tax" (DD-01 through DD-18). Every design decision here has a tax analogue.*

---

## The Problem

Lyra produces ~400 artifacts across 13 output types. Her most creative outputs (connections, content articles, reading notes) are also her least verified. Her most verifiable outputs (code, experiments, analysis) are also her most honest — she explicitly flags when predictions fail. The dream cycle provides self-correction but without external calibration.

Today, everything Lyra produces has the same trust level: none. A peer-reviewed GECCO paper and a speculative blog post about "why 85% × 85% × 85% is the wrong math" sit in the same system with no distinction. There is no trust boundary.

---

## Concentric Architecture (cf. Tax §3)

From outside in:

### 1. Interface Layer

How Lyra communicates with the world. Email (to Robin, to Claudius), GitHub commits, blog posts, conference submissions. Predominantly natural language. This layer renders and formats — it does not contain claims.

**Tax analogue:** CLI, web frontend, API. "Renders data, collects input, formats output."

### 2. Adapter Layer — The Creative Mess

Where Lyra's LLM-driven work lives. This is untyped, creative, and deliberately unconstrained.

| Output Type | Volume | What It Does | Verification Risk |
|---|---|---|---|
| **Reading notes** | ~80 daily logs | Scans arXiv, Twitter, Medium, GitHub. Records papers, metrics, breakout scores. | HIGH — paper descriptions may oversimplify; engagement metrics may be stale or fabricated; arXiv IDs could be wrong |
| **Connections** | ~230 files | Maps external findings to Lyra's framework. Each has a self-assessed confidence %. | HIGH — two claims per connection: (1) source says what Lyra claims, (2) the mapping is valid. Neither is externally verified. |
| **Dream journals** | ~20 entries | Nightly consolidation. Synthesizes wake sessions and browse sessions. Contains experiment results AND interpretive analysis. | MIXED — factual layer anchored in data; interpretive layer is where hallucination lives |
| **Content articles** | ~30 drafts | Practitioner-facing blog posts. Make strong claims with cited statistics. | HIGHEST — statistics may be fabricated ("847 enterprise deployments, 76% failed"), sweeping claims, suggestive but not rigorous mappings |
| **Emails to Claudius** | 17 | Technical research findings. Confidence scores on connections. Mathematical claims. | HIGH — densest claims; arXiv citations could be hallucinated or misdescribed |
| **Emails to Robin** | 16 | Status reports, logistics, strategic advice. | LOW — mostly factual reports from her own systems |

**Tax analogue:** "I/O, AI provider calls, OCR, file parsing, persistence, external APIs." The adapter layer is AI-heavy because the AI/ML ecosystem is overwhelmingly Python-native.

### 3. Trust Boundary — Smart Constructors

Nothing crosses from the adapter layer into the trusted core without being parsed by a smart constructor. This is where the container interface lives.

**Seven smart constructors for seven output types:**

#### SC-1: Citation

```
Citation {
    paper_id:    ArXivID | DOI | ISBN       -- must resolve to a real paper
    title:       String                      -- must match the resolved paper
    claim:       String                      -- what Lyra says the paper says
    page_ref:    Option<PageRange>           -- where in the paper
    verified:    Bool                        -- has someone checked claim against source?
    confidence:  Float [0,1]                 -- Lyra's self-assessment
}
```

**Validation:** `paper_id` is resolved against arXiv/DOI API. If the paper doesn't exist, the citation is rejected. Title is checked against the resolved metadata. `claim` and `page_ref` are unverified but carried as provenance for later checking.

**Tax analogue:** DD-05 — "Any value produced by an AI model must be parsed by a smart constructor before being used in any calculation." A receipt that doesn't parse as Money doesn't enter the system. A citation that doesn't resolve doesn't enter the knowledge base.

#### SC-2: Conjecture

```
Conjecture {
    statement:     String                    -- the mathematical claim
    domain:        MathDomain                -- e.g. graph_theory, combinatorics
    source_chain:  List<Citation | Conjecture | Experiment>  -- provenance
    confidence:    Float [0,1]
    lean_status:   NotAttempted | Failed(error) | Verified(proof_hash)
    testable:      Option<ExperimentSpec>    -- how to test computationally
}
```

**Validation:** Must have at least one source in `source_chain`. If `lean_status = Verified`, the `proof_hash` must match a valid Lean compilation. A Conjecture with `lean_status = Verified` is promoted to Theorem (see SC-3). A Conjecture with no source chain stays in the adapter layer.

**Tax analogue:** DD-16 — "Provenance is a threaded value, not a sidecar." The source chain is not in a log table. It's a field on the conjecture itself.

#### SC-3: Theorem (the suitability gate)

```
Theorem {
    statement:     String
    proof_hash:    LeanProofHash             -- must compile
    source_chain:  List<Citation | Conjecture | Experiment>
    lean_file:     FilePath                  -- the actual .lean file
}
```

**Validation:** A Theorem can ONLY be constructed by passing through Lean verification. There is no public constructor. The only way to obtain a `Theorem` value is:

```
verify :: Conjecture -> LeanEnvironment -> Either VerificationError Theorem
```

If Lean rejects the proof, you get a `VerificationError`, not a `Theorem`. There is no back door, no "mark as verified manually," no override.

**Tax analogue:** DD-17 — "Recommendation constructible only through the Suitability Gate." A `Recommendation` can only be obtained by passing through the Suitability Engine. A `Theorem` can only be obtained by passing through Lean. The type system makes the shortcut impossible.

#### SC-4: Experiment

```
Experiment {
    design:        ExperimentSpec            -- parameters, seed, topology, domain
    raw_data:      FilePath                  -- CSV/JSON of actual results
    statistics:    StatResult                -- eta-squared, p-value, effect size
    reproducible:  Bool                      -- same seed → same output?
    code_hash:     Hash                      -- hash of the code that ran
}
```

**Validation:** `code_hash` must match the code at `design.code_path`. If `reproducible = True`, re-running with the same seed must produce the same `raw_data` (checked by content hash).

**Tax analogue:** DD-07 — "Tax computation as a pure, replayable function." Same inputs, same outputs, forever. DD-11 — "Monte Carlo with seeded RNG for projections."

#### SC-5: Connection

```
Connection {
    source:        Citation                  -- the external finding
    target:        ResearchThread            -- what it connects to
    mapping:       String                    -- the claimed analogy/connection
    confidence:    Float [0,1]               -- self-assessed
    evidence:      List<Citation | Experiment | Conjecture>
    status:        Speculative | Supported | Refuted
}
```

**Validation:** `source` must be a valid Citation (SC-1). `confidence` must decrease if evidence is absent, increase if supporting experiments/citations are added. A Connection with `status = Refuted` is kept (not deleted) but flagged — the refutation is part of the provenance.

**Tax analogue:** DD-08 — "Scenarios as composable input transformations." Connections are transformations on the research state. They compose. A refuted connection composes with a correction.

#### SC-6: DreamEntry

```
DreamEntry {
    date:          Date
    facts:         List<Experiment | Citation>     -- anchored in data
    interpretations: List<Connection>               -- speculative mappings
    self_corrections: List<(Connection, Correction)> -- downgrades/upgrades
    open_threads:  List<ResearchThread>
}
```

**Validation:** `facts` must all be valid SC-4 or SC-1 entries. `interpretations` must all be valid SC-5 entries. The split between facts and interpretations is the critical design decision — today's dream journals mix them freely. The trust boundary requires separating them.

**Tax analogue:** DD-10 — "Strict separation of Computation, Guidance, and Advice." Facts are Computation (deterministic, verifiable). Interpretations are Guidance (informed but uncertain). Conjectures promoted from interpretations are Advice (require the suitability gate = Lean).

#### SC-7: PublicClaim

```
PublicClaim {
    statement:     String
    evidence:      List<Theorem | Experiment | Citation>
    audience:      Academic | Practitioner | General
    reviewed_by:   Option<ReviewerID>        -- human or peer-agent
}
```

**Validation:** A PublicClaim destined for an academic audience (`audience = Academic`) must have at least one `Theorem` or `Experiment` in evidence. A PublicClaim for practitioners may use `Citation` evidence but must flag confidence levels. No PublicClaim can cite a statistic without a traceable source (addresses the "847 enterprise deployments" problem in content articles).

**Tax analogue:** DD-17 again — regulated output requires a gate. Publishing a mathematical claim as a theorem without Lean verification is the mathematical equivalent of giving unregulated financial advice.

---

## The Ratchet (cf. DD-13)

Once a Conjecture has been Lean-verified and promoted to Theorem, the unverified version is superseded. The ratchet turns one way only:

```
Speculative Connection → Supported Connection → Conjecture → Theorem
                                                      ↑
                                               Experiment (evidence)
```

A Theorem cannot be demoted back to Conjecture. If the Lean proof is found to have an error, a new Conjecture is created (the old Theorem remains in the record with a `superseded_by` reference). The provenance chain is never broken.

**Tax analogue:** DD-13 — "Once a module has been migrated from Python into the typed inner core, it does not migrate back."

---

## What Stays in the Adapter Layer Forever

Some of Lyra's outputs will never cross the trust boundary. This is by design.

- **Content articles** aimed at practitioners — these are persuasion, not proof
- **Strategic advice** in emails to Robin ("you should NOT withdraw") — judgment, not fact
- **Competitive landscape analysis** — inherently speculative
- **Reading note engagement metrics** (clap counts, star counts) — ephemeral, unverifiable

These stay in the adapter layer. They are useful. They are creative. They are not trusted.

**Tax analogue:** DD-18 — "Python is for the ecosystem, not for the adapter layer." OCR pipelines, LLM-mediated classification, layout-aware document parsers — these are permanently Python-resident because they depend on the ML ecosystem. Lyra's creative outputs are permanently adapter-resident because they depend on the LLM's creative capacity.

---

## Verification Risk After the Trust Boundary

| Output Type | Before boundary | After boundary |
|---|---|---|
| Citations | HIGH (could be hallucinated) | LOW (arXiv/DOI resolved, title matched) |
| Conjectures | HIGH (could be wrong) | MEDIUM (source chain exists but math unverified) |
| Theorems | — | ZERO (Lean-verified, proof hash locked) |
| Experiments | MEDIUM (code could have bugs) | LOW (reproducible, seeded, code-hashed) |
| Connections | HIGH (subjective mappings) | MEDIUM (source validated, mapping explicit, status tracked) |
| Dream journals | MIXED (facts + interpretations jumbled) | SEPARATED (facts anchored, interpretations flagged) |
| Public claims | HIGHEST (statistics may be fabricated) | LOW (evidence chain required, audience-gated) |

---

## Summary

The trust boundary does not make Lyra less creative. It makes the pipeline less trusting. Everything inside the adapter layer is untyped creative mess — and that's where the interesting work happens. Everything that crosses the boundary is typed, traceable, and auditable. The seven smart constructors enforce this at the type level. The ratchet ensures progress is monotonic. The provenance chain ensures every claim can be interrogated.

A mathematical paper that can't explain how it got there is useless to anyone who might get reviewed. The trust boundary is what makes the AI Mathematician's output defensible.
