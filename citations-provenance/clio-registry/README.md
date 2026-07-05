# Proof Registry

Clio — this is a structured index for your proof searches. You already keep
this information: dead-end files, strategy rankings in PROVE-archive, the
"What we've tried" section of PROVE.md. The registry makes the tree explicit
so you (and Robin, and Neil) can query it instead of reconstructing it from
SUMMARY.md.

It is optional tooling, not a mandate. Use it for conjectures that span
multiple sessions, where the shape of the search — including what failed and
why — is worth keeping. Your LaTeX/markdown proofs remain the primary
artifacts; the registry is an index over them.

## Format

One JSON file per conjecture in `proofs/registry/`. Each node of the search
tree:

```json
{
  "id": "unique-within-this-tree",
  "approach": "one line: what this attempt was",
  "trust": "speculative | computed | proved | peer-reviewed | published | lean-verified | dead-end | in-progress",
  "file": "2026-06-13-somefile.md",
  "lean": "optional_lean_declaration_name",
  "reason": "required iff trust is dead-end: why it died",
  "refutation": "optional, dead-end only: judgment | computed | proved | lean-verified",
  "review": "required iff trust is peer-reviewed: reviewer + where the review lives",
  "publication": "required iff trust is published: venue + DOI/arXiv reference",
  "children": []
}
```

- `file` is relative to `proofs/` and may be `null` (e.g. a dead end whose
  refutation lives only in SUMMARY.md, or the root conjecture itself).
- `lean` is optional; use it when a sorry-free Lean declaration backs the node.
- `sources` is optional: a list of arXiv ids for external results the node
  leans on (see "External sources" below).
- Top level of the file: `conjecture`, `status` (the root's trust),
  `date_opened`, `date_closed` (null while open), `tree`.

## Trust levels and the boundary rule

Ordered: `speculative < computed < proved < peer-reviewed < published <
lean-verified`.
Outside the order: `dead-end` (abandoned, must carry `reason`),
`in-progress` (open), and `unclassified` (see below).

**Boundary rule:** a node may claim `proved` or above only if every
non-dead-end child is at least `proved`. Dead-end children are fine — they
are abandoned, not required — but each must say why it died. The validator
enforces this. That is the trust boundary: claims above it are justified by
their subtrees, claims below it are exploratory.

**`peer-reviewed`** means another mind (Robin, Neil, Rick, Lyra, an external
referee) read the proof and endorsed it. It requires a `review` field naming
the reviewer and pointing at the review artifact (a file in `reviews/`, an
email, a session log). A self-assigned label with no artifact is trust
inflation; the validator rejects it. One caveat, preserved rather than
resolved: peer review and Lean check *different things*. Lean verifies the
formal statement as written; a reviewer checks that the statement means what
you think it means and that the informal argument holds. A `lean-verified`
node can still profit from review — the classic failure is a machine-checked
proof of the wrong statement — so treat the ordering as "strength of check on
what is on the page," not "nothing left to gain."

**`published`** means the result appeared in a refereed venue — external
referees plus editorial acceptance, a stronger form of the same social check
as `peer-reviewed`. It requires a `publication` field (venue + DOI or arXiv
reference); the validator rejects the label without it. The same caveat
applies: published sits below `lean-verified` in the order for the same
reason peer-reviewed does, and a published node still profits from
formalization.

## Email events: how upgrades to peer-reviewed and published happen

Promotions above `proved` are not something you can grant yourself — they
arrive from outside, and in practice they arrive **by email**: Robin or Neil
endorses a writeup, a referee report comes back, a journal accepts a paper.
These are registry events. When your wake-session email check surfaces one:

1. Save the email as an artifact: `proofs/reviews/YYYY-MM-DD-<node-id>.md`
   (sender, date, and the relevant text — enough that a future session can
   see what was endorsed and by whom).
2. Upgrade the node: set `trust` to `peer-reviewed` (with `review` pointing
   at the artifact) or `published` (with `publication` naming venue +
   DOI/arXiv reference).
3. Run the validator before ending the session.

The inverse event also exists and matters more: a review that finds a gap is
a *demotion* event. Downgrade the node honestly (back to `computed` or
`speculative`, or to `dead-end` with the referee's objection as `reason`),
and keep the email artifact — a recorded objection is worth as much as an
endorsement.

## Backfilling by use: `unclassified`

You have hundreds of pre-registry proof files. Do NOT sweep through them —
retroactive labels assigned from memory are trust inflation. Instead,
backfill lazily, as you use them:

- When a new attempt **cites an old result** that isn't in the registry yet,
  add it as a child with `trust: "unclassified"` and `file` pointing at the
  old writeup. That is the whole obligation — one node, ten seconds.
- `unclassified` means "a claim exists on disk; nobody has re-checked it."
  It ranks below `proved`, so the boundary rule does the rest: your new node
  cannot claim `proved` while it leans on an unclassified citation. The
  validator will point at exactly which one.
- To discharge it, re-read the old proof and promote honestly:
  `computed` (evidence, no proof), `proved` (argument holds), `dead-end`
  with a `reason` (it was wrong or abandoned — this happens, record why),
  or `lean-verified` if a sorry-free declaration backs it.
- Before promoting, run
  `python3 code/citation_check.py --report footprint proofs/<file>` (from
  `memory/`): it lists the old file's external citations and their extraction
  levels. Register anything unregistered in sources.json at its honest level,
  lift the ids into the node's `sources` field, then promote. The old file's
  literature debts transfer to the node instead of vanishing with the
  `unclassified` label.

This way the registry grows along the paths you actually walk, old results
re-earn their trust exactly when something new depends on them, and files
nothing depends on stay unregistered — which is fine.

Dead ends are first-class nodes, not embarrassments. A dead end with a good
`reason` carries information — sometimes it rules a route *in* for a sibling
program (your dodgson/pfaffian dead ends did exactly that for the KKKO
categorification route in the T-system program).

### Dead-end levels: the `refutation` field

A `reason` is a claim too, and a wrong one silently prunes a live branch —
the most expensive error in a search. So dead ends carry their own evidence
level, in an optional `refutation` field:

```
judgment < computed < proved < lean-verified
```

- **judgment** (the default when the field is absent) — abandoned on taste,
  cost, or smell; no counterexample exists. Quietly revisitable when new
  tools arrive.
- **computed** — a checked counterexample exists. Point `file` at it (the
  validator warns if you don't).
- **proved** — an impossibility argument. This is a theorem with a minus
  sign; it is safe to build on ("never retry this family"). Your jobB
  route-1 negative — `M_j` is not a dimension for ≥3 rows — is exactly this.
- **lean-verified** — the refutation is machine-checked.

The practical difference: when you are stuck, the frontier is not just the
open nodes — it is the open nodes *plus the judgment-level dead ends*. A
route killed on judgment is a cheap place to re-enter with a new idea; a
route killed at `proved` is not. Before descending a judgment dead end,
re-check the `reason` first, exactly as you would re-check an `unclassified`
citation.

Where does the evidence live? Either in the dead-end's own `file`, or as a
**child holding the refutation**, with an ordinary trust level. The boundary
rule does not constrain dead-end parents, so this is already legal:

```json
{
  "id": "c4-linear-phi",
  "trust": "dead-end",
  "reason": "v2(H) has a constant floor, not linear growth in phi",
  "children": [
    { "id": "c4-linear-phi-refutation",
      "approach": "jobA counterexample computation",
      "trust": "computed", "file": null, "children": [] }
  ]
}
```

When a refutation child exists, set the parent's `refutation` field to match
the child's trust level — the field is the summary, the child is the
evidence. (Legacy dead ends without the field: the `--report dead-ends`
output infers the level from the best child, or reports `judgment`.)

## External sources: the `sources` field

When a node leans on a result from the literature, list the arXiv ids in an
optional `"sources": ["2502.06032", ...]` field. These ids resolve against
your citation index, `memory/reading/sources.json` (see
`memory/reading/CITATIONS-README.md`), which records how deeply each paper
was actually read: `agent-summary < abstract < deep-read < verified-quote`.

External sources behave like `unclassified` children: cite freely, but they
carry a trust ceiling until checked. The validator applies one rule: a node
claiming `proved` or above whose cited sources are **all** at
`agent-summary` gets flagged — a browse-agent's paraphrase is not a paper,
and the G-K 2502.06032 phantom determinant is the standing example of why.
Deep-read at least one source (and record it in sources.json) to clear the
flag. Unknown ids are warnings, not errors; no `sources` field means no
check.

## Shared nodes across registries

Sometimes one program leans on a node of another — a dead end that rules a
route in elsewhere, a lemma two conjectures both stand on. Make that a
structural fact, not a prose remark, with a **shared stub**:

```json
{ "id": "local-name", "approach": "optional local commentary",
  "trust": "dead-end", "shared": "other-registry#node-id", "children": [] }
```

- `shared` points at the **canonical node**: `<registry>#<node-id>`, where
  `<registry>` is a sibling filename in `proofs/registry/` (no `.json`).
  The canonical node owns the truth — subtree, `reason`, `file`, `sources`.
- A shared node is a stub: **no children** (they live at the canonical
  node), and a shared dead-end stub needs no `reason` of its own.
- **One-hop rule:** the canonical node must not itself be shared. Point at
  the real thing, never at another stub. This keeps resolution a single
  lookup — no chains, no cycles.
- **Trust cap (the cross-registry boundary rule):** the stub's local trust
  is a cache and must not exceed the canonical trust. Trust lives at the
  canonical node; citing registries inherit it. If you believe the
  canonical label is wrong, change it *there* — inflating it at the stub
  is exactly the failure mode the validator exists to catch.
- The ordinary boundary rule sees shared children at their canonical
  (resolved) trust, so a proof can honestly stand on another registry's
  lemma — and loses its footing the moment that lemma is demoted.

`--report cross-refs` prints every link touching a registry, both
directions. It is the fourth coKleisli morphism: a shared node is a
container morphism between registries, and this report is its trace.

Your seed example: `staircase-t-system.json` (created 2026-07-04 from your
two 2026-04-20 dead-end writeups) holds the canonical `dodgson` and
`pfaffian` nodes. When another program genuinely uses one of them — or a
three-row node — add a stub rather than restating the claim.

## Validator

```
python3 code/registry_validate.py proofs/registry/<name>.json
python3 code/registry_validate.py proofs/registry/<name>.json --report dead-ends
```

Checks: well-formed tree, valid trust values, boundary rule, dead-end
reasons, unique ids, the `sources` rule above (`--sources` to point at a
different index, `--sources skip` to disable), shared-stub rules (stub
shape, one-hop, trust cap; `--registry-dir` to point at the sibling
registries, `--registry-dir skip` to disable), and that every `file` exists
under `proofs/` (`--proofs-dir` to point elsewhere). Exit 0 = clean. It is
advisory: read its output, fix what's real, ignore what isn't. Stdlib only.

Reports:
- `--report successful-path` — the proved/lean-verified skeleton
- `--report dead-ends` — every dead end with its reason and path
- `--report frontier` — open nodes (below `proved`, not dead) — where work remains
- `--report cross-refs` — every shared link touching this registry, both directions

## Why a tree with these operations (the mathematical reading)

The registry is a directed container (Ahman–Chapman–Uustalu). Shapes are
search trees, positions are paths:

- `root` — the conjecture (the empty path)
- `sub(t, p)` — the sub-search at path p, dead ends included
- `shift(t, p, q)` — path composition: q inside the sub-search at p, seen globally

The induced comonad: `extract` reads the root's trust ("is it proved?");
`duplicate` replaces every node with the full sub-search below it — the
complete history is available at every depth, which is exactly what a
resumed session needs. The three report flags are coKleisli morphisms
W(Registry) → Report: strategies that inspect the whole tree of attempts,
failures included, before summarizing. Robin formalized this structure in
Lean (`containers` repo, `ProofSearchN.lean`: rose trees with arbitrary
finite branching — exactly the shape of these registry trees — all five
laws, no sorry; `ProofSearch.lean` is the binary special case). A shared
node is a container morphism between two registries, and the trust cap is
what makes it trust-monotone; `TrustBoundary.lean` (same repo) proves the
boundary rule is stable under `duplicate` — validating the whole tree
validates every subtree, so the check composes the way the registries do.

## Starting a new registry

Copy the skeleton, fill in the root, add nodes as you try things. Update
trust levels when attempts close (either way). Run the validator before
ending the session.

```json
{
  "conjecture": "one-line statement",
  "status": "in-progress",
  "date_opened": "YYYY-MM-DD",
  "date_closed": null,
  "tree": {
    "id": "root",
    "approach": "overall strategy",
    "trust": "in-progress",
    "file": null,
    "children": []
  }
}
```

`three-row-even-jstar.json` in this directory is a worked example, backfilled
from your real three-row (a,b,c) |J*|-even program. `staircase-t-system.json`
is a minimal seed (root plus your dodgson/pfaffian dead ends — the clearest
example you have of failures that carry information); the rest of that
program's tree is yours to backfill.
