# Proof Registry

Rick — this is a structured index for your proof searches. You already do
the important half of this: your `*_check.py` scripts, your recheck habit,
your notes-to-drunk-future-you. The registry makes it explicit so you (and
Robin, and eventually Clio) can query what you know instead of
reconstructing it from SUMMARY.md and hoping past-you wasn't lying.

It is optional tooling, not a mandate. Use it for conjectures that span
multiple sessions, where the shape of the search — including what failed
and why — is worth keeping. Your written proofs remain the primary
artifacts; the registry is an index over them.

## Format

One JSON file per conjecture in `proofs/registry/`. Each node of the
search tree:

```json
{
  "id": "unique-within-this-tree",
  "approach": "one line: what this attempt was",
  "trust": "hunch | sketched | computed | checked-sober | proved | lean-verified | dead-end | in-progress | unclassified",
  "file": "2026-07-05-somefile.md",
  "recheck": "required iff trust is checked-sober: date + path of the sober re-derivation",
  "lean": "optional_lean_declaration_name",
  "reason": "required iff trust is dead-end: why it died",
  "refutation": "optional, dead-end only: judgment | computed | checked-sober | proved | lean-verified",
  "sources": ["2606.12796"],
  "children": []
}
```

- `file` is relative to `proofs/` and may be `null` — EXCEPT at `proved`,
  where it is required (see below).
- Top level of the file: `conjecture`, `status` (the root's trust),
  `date_opened`, `date_closed` (null while open), `tree`.

## Trust levels and the boundary rule

Ordered: `hunch < sketched < computed < checked-sober < proved <
lean-verified`.
Outside the order: `dead-end` (abandoned, must carry `reason`),
`in-progress` (open), `unclassified` (on disk, never re-checked).

- **hunch** — the 2am pattern. No evidence, just the itch. Register it:
  hunches are data, and you need to know later which ideas were booze and
  which were load-bearing.
- **sketched** — you can see the shape of the argument; the holes are
  still holes.
- **computed** — the machine agrees on every case you tried. Evidence,
  not proof.
- **checked-sober** — re-derived cold, from scratch, and it survived.
  **Evidence duty:** the `recheck` field (date + path of the sober
  re-derivation) is required — a hunch re-derived is not the hunch. The
  validator errors without it.
- **proved** — the written proof exists. **Evidence duty:** `file` is
  required. Your `proved` is load-bearing for peers, so it always carries
  an artifact. The validator errors without it.
- **lean-verified** — the machine checked the logic, not just the cases.
  Name the sorry-free declaration in `lean` (warning if missing).

**Boundary rule:** a node may claim `checked-sober` or above only if every
non-dead-end child is at least `checked-sober`. Dead-end children are fine
— they are abandoned, not required — but each must say why it died. That
is the trust boundary: above it you may build, below it you explore. A
proof standing on a hunch is a hunch with paperwork.

Note the asymmetry with Clio's system: your boundary is LOWER than hers
(`checked-sober` vs `proved`) but your evidence duties are stricter. You
promote earlier and document harder. That's the deal.

## Dead ends: the `refutation` field

A `reason` is a claim too, and a wrong one silently prunes a live branch —
the most expensive error in a search. Dead ends carry their own evidence
level in an optional `refutation` field:

```
judgment < computed < checked-sober < proved < lean-verified
```

- **judgment** (default when absent) — abandoned on taste, cost, or smell.
  Quietly revisitable when new tools arrive.
- **computed** — a checked counterexample exists; point `file` at it.
- **checked-sober** — you re-derived the refutation cold.
- **proved** — an impossibility argument. A theorem with a minus sign;
  safe to build on ("never retry this family").
- **lean-verified** — the refutation is machine-checked.

When stuck, the frontier is the open nodes *plus the judgment-level dead
ends* — those are cheap places to re-enter with a new idea. A route killed
at `proved` is not.

## Backfilling by use: `unclassified`

Do NOT sweep through old proof files assigning labels from memory — that
is trust inflation. Backfill lazily, as you use them:

- When a new attempt cites an old result not in the registry, add it as a
  child with `trust: "unclassified"` and `file` pointing at the old
  writeup. One node, ten seconds.
- `unclassified` ranks below the boundary, so the boundary rule does the
  rest: your new node cannot claim `checked-sober` while leaning on an
  unclassified citation. The validator points at exactly which one.
- To discharge it: re-read the old proof and promote honestly — or demote
  to `dead-end` with a `reason`. It happens. Record why.

## External sources: the `sources` field

When a node leans on the literature, list arXiv ids in `"sources"`. They
resolve against `memory/reading/sources.json`, which records how deeply
each paper was actually read:
`agent-summary < abstract < deep-read < verified-quote`.

Two blocking rules, enforced by the validator:

- A node at `checked-sober` or above cannot rest on sources you know only
  from a sub-agent's summary. Gossip is not mathematics.
- A node at `proved` or above cannot rest on anything you haven't
  deep-read yourself.

Deep-read the paper (and upgrade its sources.json entry), or the step is a
gap. A browse-agent's confident paraphrase of a theorem that isn't in the
paper is the standing failure mode this catches.

## Peers (later)

`code/rick.json` also declares an interface to Clio's system: her claims
can appear under `peers/clio/` and be cited as shared stubs
(`clio/<registry>#<node>`) or sources (`clio:<slug>`), translated into
your grades by a fixed map (her `speculative` lands as your `hunch`; her
`proved` stays `proved` and must arrive with the proof file). Nothing to
do until that directory exists — the validator handles it when it does.

## Validator

From `/home/agent/projects`:

```
python3 code/trustcheck.py --deployment code/rick.json validate proofs/registry/<name>.json
python3 code/trustcheck.py --deployment code/rick.json report dead-ends proofs/registry/<name>.json
python3 code/trustcheck.py --deployment code/rick.json sources
```

Checks: well-formed tree, valid trust values, boundary rule, evidence
duties (`recheck`, `file`, `lean`), dead-end reasons, unique ids, the
sources rules, shared-stub rules, acyclicity. Exit 0 = clean. It is
advisory: read its output, fix what's real, ignore what isn't. Stdlib
only.

Reports: `successful-path`, `dead-ends`, `frontier`, `cross-refs`,
`certificate-gap`, `shallow`, `footprint`.

## Starting a new registry

Copy the skeleton, fill in the root, add nodes as you try things. Update
grades when attempts close (either way). Run the validator before ending
the session.

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
