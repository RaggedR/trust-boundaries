import Containers.Trust
import Trajectory

/-!
# Composition of trajectory evaluation with trust evaluation

The trajectory-trust morphism `psi` maps trajectory grades to trust grades.
By `tau_transport` (Trust.lean, Lemma 3.2), trust transports laxly:

    psi(trajectory_tau(e)) ≤ trust_tau(psi_claim(e))

We define:
* `TrustLevel` — the seven-level trust chain
* `psi` — the monotone map from `TLevel` to `TrustLevel`
* `psi_bot` / `psi_mono` — chain-level requirements for a `Mor`
* Concrete transport: circular trajectory maps to `unchecked`,
  honest trajectory maps to `proved`.

No Mathlib. No sorry.
-/

namespace Trajectory

open Containers.Trust

/-! ### The trust chain (mirroring TrustBoundary.lean) -/

inductive TrustLevel where
  | unchecked
  | speculative
  | computed
  | proved
  | peerReviewed
  | published
  | leanVerified
deriving DecidableEq, Repr

def TrustLevel.le : TrustLevel → TrustLevel → Prop
  | .unchecked, _ => True
  | .speculative, .unchecked => False
  | .speculative, _ => True
  | .computed, .unchecked => False
  | .computed, .speculative => False
  | .computed, _ => True
  | .proved, .unchecked => False
  | .proved, .speculative => False
  | .proved, .computed => False
  | .proved, _ => True
  | .peerReviewed, .leanVerified => True
  | .peerReviewed, .published => True
  | .peerReviewed, .peerReviewed => True
  | .peerReviewed, _ => False
  | .published, .leanVerified => True
  | .published, .published => True
  | .published, _ => False
  | .leanVerified, .leanVerified => True
  | .leanVerified, _ => False

instance : LE TrustLevel where
  le := TrustLevel.le

instance (a b : TrustLevel) : Decidable (a ≤ b) := by
  cases a <;> cases b <;> (simp [LE.le, TrustLevel.le]; first | exact instDecidableTrue | exact instDecidableFalse)

instance : Chain TrustLevel where
  bot := .unchecked
  le_refl a := by cases a <;> simp [LE.le, TrustLevel.le]
  le_trans {a b c} hab hbc := by
    cases a <;> cases b <;> cases c <;> simp_all [LE.le, TrustLevel.le]
  le_antisymm {a b} hab hba := by
    cases a <;> cases b <;> simp_all [LE.le, TrustLevel.le]
  le_total a b := by
    cases a <;> cases b <;> simp [LE.le, TrustLevel.le]
  bot_le a := by cases a <;> simp [LE.le, TrustLevel.le]
  dec := inferInstance

/-! ### The trajectory-trust morphism psi -/

/-- The morphism from trajectory grades to trust grades. -/
def psi : TLevel → TrustLevel
  | .unsupported  => .unchecked
  | .shallow       => .computed
  | .independent   => .proved
  | .crossVerified => .peerReviewed
  | .mechChecked   => .leanVerified

/-- psi maps ⊥ to ⊥. -/
theorem psi_bot : psi (Chain.bot : TLevel) = (Chain.bot : TrustLevel) := rfl

/-- psi is monotone. -/
theorem psi_mono : ∀ {a b : TLevel}, a ≤ b → psi a ≤ psi b := by
  intro a b hab
  cases a <;> cases b <;> simp_all [psi, LE.le, TLevel.le, TrustLevel.le]

/-! ### Concrete transport results -/

/-- Circular trajectory through psi: everything maps to unchecked. -/
theorem psi_circularTraj_bot : ∀ (e : Evt),
    psi (tau circularTraj circularTraj_wf e) = TrustLevel.unchecked := by
  intro e
  rw [circularTraj_tau_bot]
  rfl

/-- Honest trajectory verify event through psi: maps to proved. -/
theorem psi_honest_e4 :
    psi (tau honestTraj honestTraj_wf Evt.e4) = TrustLevel.proved := by
  rw [honest_tau_e4]
  rfl

/-- Honest trajectory claim event through psi: maps to computed. -/
theorem psi_honest_e3 :
    psi (tau honestTraj honestTraj_wf Evt.e3) = TrustLevel.computed := by
  rw [honest_tau_e3]
  rfl

end Trajectory
