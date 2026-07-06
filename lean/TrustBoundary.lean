import Containers.ProofSearchN
import Containers.Trust

/-!
# The trust boundary on registry trees is stable under `duplicate`

Phase 4 of the trust-boundary design (`scratch/clio-trust-boundary-design.md`)
links proof registries by shared nodes and asks the validator to enforce the
boundary rule across links. This file proves the structural fact that makes
that enforcement compositional: **validating the whole tree validates every
subtree**.

The deployed registries (`proofs/registry/*.json` on Clio and MacBeth) are
finitely-branching rose trees whose nodes carry a trust label. The boundary
rule (`registry_validate.py`) is node-local: a node may claim `proved` or
above only if every non-dead-end child is at least `proved`. The validator
checks this at every node — i.e. it checks the *coKleisli* condition: apply
a local predicate to every sub-search produced by `duplicate`.

Main results:

* `LTree` / `LPos` — trust-labelled rose trees and their positions;
  `trustRegistry` packages them as a directed container (labels do not
  disturb the navigation laws, so D1–D5 are word-for-word `ProofSearchN`).
* `LTree.ok_sub` — **duplicate-stability**: if `Ok θ t` (the boundary rule
  at threshold `θ`, at every position) then `Ok θ (t.sub p)` for every
  position `p`. The proof is a one-line transport along D4: the positions
  of a subtree embed by `shift`, and `sub_shift` carries the local check
  across. This is the precise sense in which the boundary rule "composes
  the way the registries do": a shared node importing a subtree imports a
  *validated* subtree, no re-check required.
* `TrustLevel` — the deployed chain (schema v3/v4):
  `unchecked < speculative < computed < proved < peerReviewed < published
  < leanVerified`, as an instance of `Trust.Chain`. `unchecked` is `bot`
  and models both `in-progress` and `unclassified` (the validator's
  CAP_RANK −1: a claim exists, nobody has re-checked it). `dead-end` is
  not a chain element — it is the `dead` flag on labels, because dead ends
  are *exempt* from the boundary rule (abandoned, not required), which no
  order relation expresses.

The cross-registry **trust cap** (a shared stub's local trust must not
exceed the canonical trust) is the morphism condition of `Trust.Mor`, and
its soundness is `Trust.tau_transport`: importing along a morphism never
claims more than the image of the source's canonical trust. Together:
`ok_sub` says validated trees decompose, `tau_transport` says trust moves
laxly between trees — which is everything the Python validator enforces at
runtime, now with the two halves proved to fit.
-/

namespace Containers

/-- A trust label: a level in the chain `T`, plus a dead-end flag. Dead ends
are outside the chain by design — the boundary rule *exempts* them (an
abandoned approach is not a required premise), and an order relation cannot
express an exemption. -/
structure TrustLabel (T : Type) where
  trust : T
  dead : Bool

/-- A trust-labelled finitely-branching rose tree: the shape of a deployed
registry (`proofs/registry/*.json`). Same `Fin n` encoding as
`ProofSearchN.RTree`, with a label at every node. -/
inductive LTree (T : Type) where
  | node : TrustLabel T → (n : Nat) → (Fin n → LTree T) → LTree T

namespace LTree

variable {T : Type}

/-- The label at the root. Under `duplicate` this is the coKleisli
`extract` for labels: `lab (t.sub p)` reads the label at position `p`. -/
def lab : LTree T → TrustLabel T
  | .node l _ _ => l

/-- A position (path) in a labelled tree. Identical to `ProofSearchN.RPos`;
labels play no role in navigation. -/
inductive LPos : LTree T → Type where
  | here : LPos t
  | child : (i : Fin n) → LPos (children i) → LPos (.node l n children)

/-- The sub-tree at a position. -/
def sub : (t : LTree T) → LPos t → LTree T
  | t, .here => t
  | .node _ _ children, .child i p => (children i).sub p

/-- Path concatenation: a position in a sub-tree, seen globally. -/
def shift : (t : LTree T) → (p : LPos t) → LPos (t.sub p) → LPos t
  | _, .here, q => q
  | .node _ _ children, .child i p, q => .child i ((children i).shift p q)

/-- **D3**: `shift p here = p`. -/
def shift_root : (t : LTree T) → (p : LPos t) → t.shift p .here = p
  | _, .here => rfl
  | .node _ _ children, .child i p =>
      congrArg (LPos.child i) ((children i).shift_root p)

/-- **D4**: sub-trees nest along the shift. -/
def sub_shift : (t : LTree T) → (p : LPos t) → (q : LPos (t.sub p)) →
    t.sub (t.shift p q) = (t.sub p).sub q
  | _, .here, _ => rfl
  | .node _ _ children, .child i p, q => (children i).sub_shift p q

/-- **D5**: shift is associative, with transport along D4. -/
def shift_assoc : (t : LTree T) → (p : LPos t) → (q : LPos (t.sub p)) →
    (r : LPos ((t.sub p).sub q)) →
    t.shift (t.shift p q) ((t.sub_shift p q).symm ▸ r) =
      t.shift p ((t.sub p).shift q r)
  | _, .here, _, _ => rfl
  | .node _ _ children, .child i p, q, r =>
      congrArg (LPos.child i) ((children i).shift_assoc p q r)

end LTree

/-- Trust-labelled registries as a directed container. Labels ride along;
the navigation structure — and hence the comonad — is exactly
`proofSearchN`'s. -/
def trustRegistry (T : Type) : DirectedContainer where
  Shape := LTree T
  Pos := LTree.LPos
  root := fun _ => .here
  sub := LTree.sub
  shift := LTree.shift
  d1 := fun _ => rfl
  d4 := LTree.sub_shift
  d2 := fun _ _ => rfl
  d3 := LTree.shift_root
  d5 := LTree.shift_assoc

namespace LTree

open Containers.Trust (Chain)

variable {T : Type} [Chain T]

/-- The node-local boundary rule at threshold `θ` (deployed: `θ = proved`):
if this node claims `θ` or above, every non-dead child claims `θ` or above.
No recursion — this inspects one node and its immediate children, exactly
what `registry_validate.py` checks at each step of its walk. -/
def localOk (θ : T) : LTree T → Prop
  | .node l n children =>
      θ ≤ l.trust → ∀ i : Fin n,
        (children i).lab.dead = true ∨ θ ≤ (children i).lab.trust

/-- The global boundary rule, in coKleisli form: the local check holds at
**every** position, i.e. on every sub-search produced by `duplicate`. -/
def Ok (θ : T) (t : LTree T) : Prop := ∀ p : LPos t, (t.sub p).localOk θ

/-- **Duplicate-stability of the trust boundary**: a validated registry has
validated sub-registries. The proof is transport along D4 — positions of
`t.sub p` embed into positions of `t` by `shift p`, and `sub_shift`
identifies the sub-trees, so the global check at `shift p q` *is* the check
at `q`. This is the load-bearing fact for shared nodes: a stub pointing
into a validated registry inherits a validated subtree, and the validator
never needs to descend across the link. -/
theorem ok_sub (θ : T) (t : LTree T) (h : Ok θ t) (p : LPos t) :
    Ok θ (t.sub p) :=
  fun q => t.sub_shift p q ▸ h (t.shift p q)

/-- Validity of the whole is validity at the root of every duplicate. The
forward direction is `ok_sub` at each `p`; the backward direction reads the
root component. Packaged as an iff so `Ok` can be checked either way. -/
theorem ok_iff_all_sub (θ : T) (t : LTree T) :
    Ok θ t ↔ ∀ p : LPos t, Ok θ (t.sub p) :=
  ⟨ok_sub θ t, fun h p => h p .here⟩

end LTree

namespace Trust

/-- The deployed trust chain (registry schema v3/v4):

`unchecked < speculative < computed < proved < peerReviewed < published <
leanVerified`.

`unchecked` is the bottom — it models both `in-progress` and `unclassified`
("a claim exists on disk; nobody has re-checked it", the validator's
CAP_RANK −1). `dead-end` is deliberately absent: it is the `dead` flag on
`TrustLabel`, not a strength of check. -/
inductive TrustLevel where
  | unchecked
  | speculative
  | computed
  | proved
  | peerReviewed
  | published
  | leanVerified
deriving DecidableEq

/-- Numeric rank; matches `TRUST_ORDER` in `registry_validate.py` shifted
by one to make room for the bottom. -/
def TrustLevel.rank : TrustLevel → Nat
  | .unchecked => 0
  | .speculative => 1
  | .computed => 2
  | .proved => 3
  | .peerReviewed => 4
  | .published => 5
  | .leanVerified => 6

/-- The deployed chain is a `Chain` in the sense of `Trust.lean`, so the
certificate lemma (`sound_le_tau`), attainment (`tau_sound`) and lax
transport (`tau_transport`) all apply to real registry labels. -/
instance : Chain TrustLevel where
  le a b := a.rank ≤ b.rank
  bot := .unchecked
  le_refl a := Nat.le_refl a.rank
  le_trans := Nat.le_trans
  le_antisymm {a b} hab hba := by
    cases a <;> cases b <;>
      first
        | rfl
        | exact absurd hab (by decide)
        | exact absurd hba (by decide)
  le_total a b := Nat.le_total a.rank b.rank
  bot_le a := Nat.zero_le a.rank
  dec a b := Nat.decLe a.rank b.rank

/-- The deployed boundary rule: threshold `proved`. A registry passing
`registry_validate.py` satisfies exactly this predicate, and by
`LTree.ok_sub` every one of its subtrees does too. -/
abbrev RegistryOk (t : LTree TrustLevel) : Prop :=
  t.Ok TrustLevel.proved

/-- Duplicate-stability at the deployed threshold, stated concretely. -/
theorem registryOk_sub (t : LTree TrustLevel) (h : RegistryOk t)
    (p : LTree.LPos t) : RegistryOk (t.sub p) :=
  LTree.ok_sub TrustLevel.proved t h p

end Trust

-- ===================================================================
-- The loop experiment's trust chain
-- ===================================================================

namespace LoopTrust

open Containers.Trust (Chain)

/-- The loop experiment's trust chain (Warnaar positivity conjecture):

`unchecked < speculative < computed < proved < verified < leanVerified`.

This differs from the agent chain (`TrustLevel`) in one position:
`verified` replaces `peerReviewed` and `published`. A `verified` node
means an independent verifier agent (or Robin) hostile-reviewed the
proof — the loop's analogue of peer review, without the social-process
grades.

`unchecked` models `in-progress` and `unclassified` (same as
`TrustLevel`). `dead-end` is the `dead` flag on `TrustLabel`, not a
chain element. -/
inductive LoopTrustLevel where
  | unchecked
  | speculative
  | computed
  | proved
  | verified
  | leanVerified
deriving DecidableEq

def LoopTrustLevel.rank : LoopTrustLevel → Nat
  | .unchecked => 0
  | .speculative => 1
  | .computed => 2
  | .proved => 3
  | .verified => 4
  | .leanVerified => 5

instance : Chain LoopTrustLevel where
  le a b := a.rank ≤ b.rank
  bot := .unchecked
  le_refl a := Nat.le_refl a.rank
  le_trans := Nat.le_trans
  le_antisymm {a b} hab hba := by
    cases a <;> cases b <;>
      first
        | rfl
        | exact absurd hab (by decide)
        | exact absurd hba (by decide)
  le_total a b := Nat.le_total a.rank b.rank
  bot_le a := Nat.zero_le a.rank
  dec a b := Nat.decLe a.rank b.rank

/-- The loop experiment's boundary rule: threshold `proved`. By
`LTree.ok_sub` (parametric in `T` and `θ`), validated loop registries
have validated subtrees — same structural fact, different chain. -/
abbrev LoopRegistryOk (t : Containers.LTree LoopTrustLevel) : Prop :=
  t.Ok LoopTrustLevel.proved

theorem loopRegistryOk_sub (t : Containers.LTree LoopTrustLevel)
    (h : LoopRegistryOk t) (p : Containers.LTree.LPos t) :
    LoopRegistryOk (t.sub p) :=
  Containers.LTree.ok_sub LoopTrustLevel.proved t h p

end LoopTrust

end Containers
