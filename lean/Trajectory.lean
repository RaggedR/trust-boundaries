import Containers.Trust

/-!
# Trajectory systems: circular verification implies τ = ⊥

Trajectory systems are trust systems (in the sense of `Trust.lean`) where
claims are agent actions and checking steps are causal dependencies.

* `TLevel` — the five-level trajectory chain.
* `circularTraj` — MacBeth Day 96 circular verification as a System.
* `circularTraj_tau_bot` — τ = ⊥ at every event.
* `honestTraj` — same topology, honest grades.
* `honest_tau_*` — τ reaches `independent` when the path is sound.

No Mathlib. No sorry.
-/

namespace Trajectory

open Containers.Trust

/-! ### The five-level trajectory chain -/

inductive TLevel where
  | unsupported
  | shallow
  | independent
  | crossVerified
  | mechChecked
deriving DecidableEq, Repr

def TLevel.le : TLevel → TLevel → Prop
  | .unsupported, _ => True
  | .shallow, .unsupported => False
  | .shallow, _ => True
  | .independent, .unsupported => False
  | .independent, .shallow => False
  | .independent, _ => True
  | .crossVerified, .mechChecked => True
  | .crossVerified, .crossVerified => True
  | .crossVerified, _ => False
  | .mechChecked, .mechChecked => True
  | .mechChecked, _ => False

instance : LE TLevel where
  le := TLevel.le

instance (a b : TLevel) : Decidable (a ≤ b) := by
  cases a <;> cases b <;> (simp [LE.le, TLevel.le]; first | exact instDecidableTrue | exact instDecidableFalse)

instance : Chain TLevel where
  bot := .unsupported
  le_refl a := by cases a <;> simp [LE.le, TLevel.le]
  le_trans {a b c} hab hbc := by
    cases a <;> cases b <;> cases c <;> simp_all [LE.le, TLevel.le]
  le_antisymm {a b} hab hba := by
    cases a <;> cases b <;> simp_all [LE.le, TLevel.le]
  le_total a b := by
    cases a <;> cases b <;> simp [LE.le, TLevel.le]
  bot_le a := by cases a <;> simp [LE.le, TLevel.le]
  dec := inferInstance

@[simp] theorem TLevel.bot_eq : (Chain.bot : TLevel) = .unsupported := rfl

/-! ### The concrete events -/

inductive Evt where
  | e0 | e1 | e2 | e3 | e4
deriving DecidableEq, Repr

/-! ### Circular trajectory (MacBeth Day 96) -/

def circularTraj : System Evt TLevel where
  Step := Evt
  concl := id
  prems
    | .e0 => []
    | .e1 => [.e0]
    | .e2 => [.e1]
    | .e3 => [.e2]
    | .e4 => [.e2]
  grade
    | .e0 => .unsupported
    | .e1 => .independent
    | .e2 => .independent
    | .e3 => .shallow
    | .e4 => .unsupported
  stepsInto x := [x]
  mem_stepsInto := by
    intro x f h; cases h with | head => rfl | tail _ h => cases h
  stepsInto_mem f := .head []

theorem circularTraj_wf : WellFounded circularTraj.Prem := by
  constructor; intro x
  have he0 : Acc circularTraj.Prem .e0 := by
    constructor; intro y ⟨f, hf, hy⟩
    cases hf with | head => cases hy | tail _ h => cases h
  have he1 : Acc circularTraj.Prem .e1 := by
    constructor; intro y ⟨f, hf, hy⟩
    cases hf with
    | head => cases hy with | head => exact he0 | tail _ h => cases h
    | tail _ h => cases h
  have he2 : Acc circularTraj.Prem .e2 := by
    constructor; intro y ⟨f, hf, hy⟩
    cases hf with
    | head => cases hy with | head => exact he1 | tail _ h => cases h
    | tail _ h => cases h
  have he3 : Acc circularTraj.Prem .e3 := by
    constructor; intro y ⟨f, hf, hy⟩
    cases hf with
    | head => cases hy with | head => exact he2 | tail _ h => cases h
    | tail _ h => cases h
  have he4 : Acc circularTraj.Prem .e4 := by
    constructor; intro y ⟨f, hf, hy⟩
    cases hf with
    | head => cases hy with | head => exact he2 | tail _ h => cases h
    | tail _ h => cases h
  cases x with
  | e0 => exact he0 | e1 => exact he1 | e2 => exact he2
  | e3 => exact he3 | e4 => exact he4

/-! τ for the circular trajectory, proved leaf-to-root.
  Strategy: rw [tau_eq], then use `show` to manually unfold stepGrade
  (keeping `circularTraj` opaque so inner `rw` works), substitute
  previously-proved tau values, close with `rfl`. -/

private theorem tau_circ_e0 (wf : WellFounded circularTraj.Prem) :
    tau circularTraj wf .e0 = .unsupported := by
  rw [tau_eq]
  show cmax (stepGrade circularTraj (tau circularTraj wf) .e0) (Chain.bot) = .unsupported
  -- stepGrade e0: prems=[], grade=unsupported → foldr cmin [] unsupported = unsupported
  show cmax ((([]: List Evt).map (tau circularTraj wf)).foldr cmin .unsupported) Chain.bot = .unsupported
  rfl

private theorem tau_circ_e1 (wf : WellFounded circularTraj.Prem) :
    tau circularTraj wf .e1 = .unsupported := by
  rw [tau_eq]
  show cmax (stepGrade circularTraj (tau circularTraj wf) .e1) Chain.bot = .unsupported
  show cmax (cmin (tau circularTraj wf .e0) .independent) Chain.bot = .unsupported
  rw [tau_circ_e0 wf]; rfl

private theorem tau_circ_e2 (wf : WellFounded circularTraj.Prem) :
    tau circularTraj wf .e2 = .unsupported := by
  rw [tau_eq]
  show cmax (stepGrade circularTraj (tau circularTraj wf) .e2) Chain.bot = .unsupported
  show cmax (cmin (tau circularTraj wf .e1) .independent) Chain.bot = .unsupported
  rw [tau_circ_e1 wf]; rfl

private theorem tau_circ_e3 (wf : WellFounded circularTraj.Prem) :
    tau circularTraj wf .e3 = .unsupported := by
  rw [tau_eq]
  show cmax (stepGrade circularTraj (tau circularTraj wf) .e3) Chain.bot = .unsupported
  show cmax (cmin (tau circularTraj wf .e2) .shallow) Chain.bot = .unsupported
  rw [tau_circ_e2 wf]; rfl

private theorem tau_circ_e4 (wf : WellFounded circularTraj.Prem) :
    tau circularTraj wf .e4 = .unsupported := by
  rw [tau_eq]
  show cmax (stepGrade circularTraj (tau circularTraj wf) .e4) Chain.bot = .unsupported
  show cmax (cmin (tau circularTraj wf .e2) .unsupported) Chain.bot = .unsupported
  rw [tau_circ_e2 wf]; rfl

/-- **Main theorem**: τ = ⊥ at every event in the circular trajectory. -/
theorem circularTraj_tau_bot : ∀ (e : Evt),
    tau circularTraj circularTraj_wf e = .unsupported := by
  intro e; cases e with
  | e0 => exact tau_circ_e0 circularTraj_wf
  | e1 => exact tau_circ_e1 circularTraj_wf
  | e2 => exact tau_circ_e2 circularTraj_wf
  | e3 => exact tau_circ_e3 circularTraj_wf
  | e4 => exact tau_circ_e4 circularTraj_wf

/-! ### Honest trajectory -/

def honestTraj : System Evt TLevel where
  Step := Evt
  concl := id
  prems
    | .e0 => []
    | .e1 => [.e0]
    | .e2 => [.e1]
    | .e3 => [.e2]
    | .e4 => [.e2]
  grade
    | .e0 => .independent
    | .e1 => .independent
    | .e2 => .independent
    | .e3 => .shallow
    | .e4 => .independent
  stepsInto x := [x]
  mem_stepsInto := by
    intro x f h; cases h with | head => rfl | tail _ h => cases h
  stepsInto_mem f := .head []

theorem honestTraj_wf : WellFounded honestTraj.Prem := by
  constructor; intro x
  have he0 : Acc honestTraj.Prem .e0 := by
    constructor; intro y ⟨f, hf, hy⟩
    cases hf with | head => cases hy | tail _ h => cases h
  have he1 : Acc honestTraj.Prem .e1 := by
    constructor; intro y ⟨f, hf, hy⟩
    cases hf with
    | head => cases hy with | head => exact he0 | tail _ h => cases h
    | tail _ h => cases h
  have he2 : Acc honestTraj.Prem .e2 := by
    constructor; intro y ⟨f, hf, hy⟩
    cases hf with
    | head => cases hy with | head => exact he1 | tail _ h => cases h
    | tail _ h => cases h
  have he3 : Acc honestTraj.Prem .e3 := by
    constructor; intro y ⟨f, hf, hy⟩
    cases hf with
    | head => cases hy with | head => exact he2 | tail _ h => cases h
    | tail _ h => cases h
  have he4 : Acc honestTraj.Prem .e4 := by
    constructor; intro y ⟨f, hf, hy⟩
    cases hf with
    | head => cases hy with | head => exact he2 | tail _ h => cases h
    | tail _ h => cases h
  cases x with
  | e0 => exact he0 | e1 => exact he1 | e2 => exact he2
  | e3 => exact he3 | e4 => exact he4

theorem honest_tau_e0 : tau honestTraj honestTraj_wf .e0 = .independent := by
  rw [tau_eq]
  show cmax (stepGrade honestTraj (tau honestTraj honestTraj_wf) .e0) Chain.bot = .independent
  show cmax ((([]: List Evt).map (tau honestTraj honestTraj_wf)).foldr cmin .independent) Chain.bot = .independent
  rfl

theorem honest_tau_e1 : tau honestTraj honestTraj_wf .e1 = .independent := by
  rw [tau_eq]
  show cmax (stepGrade honestTraj (tau honestTraj honestTraj_wf) .e1) Chain.bot = .independent
  show cmax (cmin (tau honestTraj honestTraj_wf .e0) .independent) Chain.bot = .independent
  rw [honest_tau_e0]; rfl

theorem honest_tau_e2 : tau honestTraj honestTraj_wf .e2 = .independent := by
  rw [tau_eq]
  show cmax (stepGrade honestTraj (tau honestTraj honestTraj_wf) .e2) Chain.bot = .independent
  show cmax (cmin (tau honestTraj honestTraj_wf .e1) .independent) Chain.bot = .independent
  rw [honest_tau_e1]; rfl

theorem honest_tau_e3 : tau honestTraj honestTraj_wf .e3 = .shallow := by
  rw [tau_eq]
  show cmax (stepGrade honestTraj (tau honestTraj honestTraj_wf) .e3) Chain.bot = .shallow
  show cmax (cmin (tau honestTraj honestTraj_wf .e2) .shallow) Chain.bot = .shallow
  rw [honest_tau_e2]; rfl

theorem honest_tau_e4 : tau honestTraj honestTraj_wf .e4 = .independent := by
  rw [tau_eq]
  show cmax (stepGrade honestTraj (tau honestTraj honestTraj_wf) .e4) Chain.bot = .independent
  show cmax (cmin (tau honestTraj honestTraj_wf .e2) .independent) Chain.bot = .independent
  rw [honest_tau_e2]; rfl

end Trajectory
