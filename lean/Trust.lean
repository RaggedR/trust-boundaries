/-!
# Trust systems: the certificate lemma and transport of trust

Formalization of Lemmas 2.2 and 3.2 of `notes/TRUST_SYSTEMS_THEORY.md`.

A *trust system* is a dependency structure (claims, checking steps with
premises) graded in a poset of checks `T`. The canonical trust `tau` of a
claim is the widest-bottleneck value: the best derivation's weakest link,
computed here in fixpoint form by well-founded recursion over the premise
relation.

Main results:

* `sound_le_tau` — every sound assignment is bounded by `tau`
  (Lemma 2.2 (ii)); node-local certificates imply the global bound.
* `tau_sound` — `tau` itself is sound (Lemma 2.2 (i)); together: `tau` is
  the greatest sound assignment.
* `derivGrade_le_tau` / `tau_le_derivGrade` — `tau` coincides with the
  max-over-derivations of min-over-grades semantics, so the fixpoint form
  and the derivation-sup form agree.
* `tau_transport` — morphisms of trust systems transport trust laxly:
  `phi (tau x) ≤ tau' (F x)` (Lemma 3.2).
* `cyc_sound_top` / `cyc_no_deriv` / `cyc_not_wf` — the circular-citation
  counterexample (Remark 2.3): in a two-claim cycle the constant-top
  assignment is sound, yet no derivation exists at all; well-foundedness of
  the premise relation is load-bearing.
* `tau_consolidate` — **Theorem 3 (consolidation preservation)**: a
  consolidation carrying a genuine position map (`Consolidation`) preserves
  canonical trust on the nose, `tau' (onClaim x) = tau x`.
* `ground_tau_hi` / `layer4_tau_bot` — the shape-only counterexample: a
  consolidation that restates claims but drops the checking steps degrades
  trust from `hi` to `bot` (the formal shadow of `synthesis-layer4.md`).

Two corrections to the prose note discovered by this formalization:

1. Lemma 2.2 (i) needs the check-poset to be a **chain** (or at least the
   relevant sups attained): in a general lattice a finite sup need not be
   attained by any element. All deployed check-posets are finite chains, so
   `Chain` is the honest ambient structure; (ii) would hold more generally.
2. Lemma 3.2 needs `phi bot = bot` ("a morphism maps *unchecked* to
   *unchecked*"): monotonicity alone fails when the source claim has no
   derivation but `phi bot` exceeds the target's bottom.

Everything is Lean 4 core, no Mathlib; the order theory is hand-rolled.
-/

namespace Containers.Trust

/-- A bounded chain of check strengths: a linearly ordered set of trust
levels with a bottom element (`bot` = "no check performed"). Decidability of
`≤` makes `cmin`/`cmax` computable. Antisymmetry is used exactly once, in
`tau_le_derivGrade`. -/
class Chain (T : Type) extends LE T where
  bot : T
  le_refl : ∀ a : T, a ≤ a
  le_trans : ∀ {a b c : T}, a ≤ b → b ≤ c → a ≤ c
  le_antisymm : ∀ {a b : T}, a ≤ b → b ≤ a → a = b
  le_total : ∀ a b : T, a ≤ b ∨ b ≤ a
  bot_le : ∀ a : T, bot ≤ a
  dec : ∀ a b : T, Decidable (a ≤ b)

instance {T : Type} [Chain T] (a b : T) : Decidable (a ≤ b) := Chain.dec a b

variable {T : Type} [Chain T]

/-- Meet of two levels (weaker of the two checks). -/
def cmin (a b : T) : T := if a ≤ b then a else b

/-- Join of two levels (stronger of the two checks). -/
def cmax (a b : T) : T := if a ≤ b then b else a

theorem cmin_le_left (a b : T) : cmin a b ≤ a := by
  unfold cmin; split
  · exact Chain.le_refl a
  · next h => exact (Chain.le_total a b).resolve_left h

theorem cmin_le_right (a b : T) : cmin a b ≤ b := by
  unfold cmin; split
  · next h => exact h
  · exact Chain.le_refl b

theorem le_cmin {a b c : T} (ha : c ≤ a) (hb : c ≤ b) : c ≤ cmin a b := by
  unfold cmin; split
  · exact ha
  · exact hb

theorem le_cmax_left (a b : T) : a ≤ cmax a b := by
  unfold cmax; split
  · next h => exact h
  · exact Chain.le_refl a

theorem le_cmax_right (a b : T) : b ≤ cmax a b := by
  unfold cmax; split
  · exact Chain.le_refl b
  · next h => exact (Chain.le_total a b).resolve_left h

/-- `cmax` is literally one of its arguments — no order facts needed. -/
theorem cmax_cases (a b : T) : cmax a b = a ∨ cmax a b = b := by
  unfold cmax; split
  · exact .inr rfl
  · exact .inl rfl

/-! ### Folds of `cmin` / `cmax` over lists -/

/-- A member bounds the `cmax`-fold from below. -/
theorem le_foldr_max {a : T} {l : List T} (h : a ∈ l) (init : T) :
    a ≤ l.foldr cmax init := by
  induction h with
  | head t => exact le_cmax_left a (t.foldr cmax init)
  | tail b _ ih => exact Chain.le_trans ih (le_cmax_right b _)

/-- Attainment: a `cmax`-fold over a list is the initial value or a member.
This is where linearity of the chain does its work (via `cmax_cases`). -/
theorem foldr_max_cases : ∀ (l : List T) (init : T),
    l.foldr cmax init = init ∨ l.foldr cmax init ∈ l
  | [], _ => .inl rfl
  | a :: t, init => by
    rcases cmax_cases a (t.foldr cmax init) with h | h
    · right
      show cmax a (t.foldr cmax init) ∈ a :: t
      rw [h]
      exact .head t
    · rcases foldr_max_cases t init with h' | h'
      · left
        show cmax a (t.foldr cmax init) = init
        rw [h]
        exact h'
      · right
        show cmax a (t.foldr cmax init) ∈ a :: t
        rw [h]
        exact .tail a h'

/-- The `cmin`-fold is below any member. -/
theorem foldr_min_le {a : T} {l : List T} (h : a ∈ l) (init : T) :
    l.foldr cmin init ≤ a := by
  induction h with
  | head t => exact cmin_le_left a (t.foldr cmin init)
  | tail b _ ih => exact Chain.le_trans (cmin_le_right b _) ih

/-- The `cmin`-fold is below its initial value. -/
theorem foldr_min_le_init : ∀ (l : List T) (init : T), l.foldr cmin init ≤ init
  | [], init => Chain.le_refl init
  | a :: t, init =>
      Chain.le_trans (cmin_le_right a (t.foldr cmin init)) (foldr_min_le_init t init)

/-- Pointwise domination of mapped `cmin`-folds. -/
theorem foldr_min_map_mono {α : Type} {f g : α → T} {i₁ i₂ : T} :
    ∀ (l : List α), (∀ a, a ∈ l → f a ≤ g a) → i₁ ≤ i₂ →
    (l.map f).foldr cmin i₁ ≤ (l.map g).foldr cmin i₂
  | [], _, hi => hi
  | a :: t, h, hi => by
    show cmin (f a) ((t.map f).foldr cmin i₁) ≤ cmin (g a) ((t.map g).foldr cmin i₂)
    exact le_cmin
      (Chain.le_trans (cmin_le_left _ _) (h a (.head t)))
      (Chain.le_trans (cmin_le_right _ _)
        (foldr_min_map_mono t (fun b hb => h b (.tail a hb)) hi))

/-- A monotone map is lax for `cmin`-folds: `phi (⋀ l) ≤ ⋀ (phi l)`.
Holds for any monotone `phi` — no meet-preservation required. -/
theorem phi_foldr_min {T' : Type} [Chain T'] {phi : T → T'}
    (hmono : ∀ {a b : T}, a ≤ b → phi a ≤ phi b) :
    ∀ (l : List T) (init : T),
    phi (l.foldr cmin init) ≤ (l.map phi).foldr cmin (phi init)
  | [], init => Chain.le_refl (phi init)
  | a :: t, init => by
    show phi (cmin a (t.foldr cmin init)) ≤ cmin (phi a) ((t.map phi).foldr cmin (phi init))
    exact le_cmin
      (hmono (cmin_le_left _ _))
      (Chain.le_trans (hmono (cmin_le_right _ _)) (phi_foldr_min hmono t init))

/-- Congruence for `List.map` on members. -/
theorem mapCongr {α β : Type} {f g : α → β} :
    ∀ (l : List α), (∀ a, a ∈ l → f a = g a) → l.map f = l.map g
  | [], _ => rfl
  | a :: t, h => by
    show f a :: t.map f = g a :: t.map g
    rw [h a (.head t), mapCongr t (fun b hb => h b (.tail a hb))]

/-! ### Trust systems -/

/-- A trust system over claims `C` graded in the chain `T`: checking steps
with a conclusion, a finite list of premises, and the grade of the check the
step actually received. `stepsInto x` enumerates the steps concluding `x`
(finitely many — the registry is a finite artifact). -/
structure System (C : Type) (T : Type) [Chain T] where
  Step : Type
  concl : Step → C
  prems : Step → List C
  grade : Step → T
  stepsInto : C → List Step
  mem_stepsInto : ∀ {x : C} {f : Step}, f ∈ stepsInto x → concl f = x
  stepsInto_mem : ∀ f : Step, f ∈ stepsInto (concl f)

variable {C : Type} (S : System C T)

/-- The premise relation: `y` is a premise of some checking step into `x`.
Well-foundedness of this relation is the standing hypothesis of the
certificate lemma — and it is **load-bearing**, see the `cyc` counterexample. -/
def System.Prem (y x : C) : Prop :=
  ∃ f, f ∈ S.stepsInto x ∧ y ∈ S.prems f

/-- The grade a step confers under an assignment `t`: the step's own check
meets the assigned levels of all its premises. -/
def stepGrade (t : C → T) (f : S.Step) : T :=
  ((S.prems f).map t).foldr cmin (S.grade f)

open Classical in
/-- Canonical trust in fixpoint form: the best step into `x`, valued at its
`stepGrade` under `tau` itself. Defined by well-founded recursion on the
premise relation; the `dite` patch (defaulting to `bot` off the premise
relation) is erased by `tau_eq`. Noncomputable only through `Classical`. -/
noncomputable def tau (wf : WellFounded S.Prem) : C → T :=
  wf.fix fun x rec =>
    ((S.stepsInto x).map fun f =>
      ((S.prems f).map fun y =>
        if h : S.Prem y x then rec y h else Chain.bot).foldr cmin (S.grade f)).foldr
      cmax Chain.bot

/-- The clean unfolding: `tau x` is the `cmax`-fold of `stepGrade tau` over
the steps into `x`. -/
theorem tau_eq (wf : WellFounded S.Prem) (x : C) :
    tau S wf x = ((S.stepsInto x).map (stepGrade S (tau S wf))).foldr cmax Chain.bot := by
  show wf.fix _ x = _
  rw [WellFounded.fix_eq]
  refine congrArg (fun l => List.foldr cmax Chain.bot l) (mapCongr _ fun f hf => ?_)
  refine congrArg (fun l => List.foldr cmin (S.grade f) l) (mapCongr _ fun y hy => ?_)
  rw [dif_pos ⟨f, hf, hy⟩]
  rfl

/-- A sound assignment: every claim trusted above `bot` carries a node-local
certificate — a checking step whose `stepGrade` under `t` dominates `t x`.
This is exactly the deployed boundary rule; the validators check precisely
this predicate. -/
def Sound (t : C → T) : Prop :=
  ∀ x : C, t x ≠ Chain.bot → ∃ f, f ∈ S.stepsInto x ∧ t x ≤ stepGrade S t f

/-- **Lemma 2.2 (ii)**: every sound assignment is bounded by canonical trust.
Node-local certificates imply the global bound; claiming above `tau` is
trust inflation, and it must fail the certificate somewhere. -/
theorem sound_le_tau (wf : WellFounded S.Prem) {t : C → T} (hs : Sound S t) :
    ∀ x, t x ≤ tau S wf x := by
  intro x
  induction x using WellFounded.induction wf with
  | _ x ih =>
    by_cases hx : t x = Chain.bot
    · rw [hx]; exact Chain.bot_le _
    · obtain ⟨f, hf, hle⟩ := hs x hx
      refine Chain.le_trans hle (Chain.le_trans
        (foldr_min_map_mono (S.prems f) (fun y hy => ih y ⟨f, hf, hy⟩) (Chain.le_refl _))
        ?_)
      rw [tau_eq]
      exact le_foldr_max (List.mem_map_of_mem (f := stepGrade S (tau S wf)) hf) _

/-- **Lemma 2.2 (i)**: canonical trust is itself sound. Uses attainment
(`foldr_max_cases`), hence linearity of the chain. Together with
`sound_le_tau`: `tau` is the greatest sound assignment. -/
theorem tau_sound (wf : WellFounded S.Prem) : Sound S (tau S wf) := by
  intro x hx
  rcases foldr_max_cases ((S.stepsInto x).map (stepGrade S (tau S wf))) Chain.bot with h | h
  · exact absurd ((tau_eq S wf x).trans h) hx
  · obtain ⟨f, hf, hfe⟩ := List.mem_map.mp h
    exact ⟨f, hf, by rw [tau_eq, ← hfe]; exact Chain.le_refl _⟩

/-! ### Derivations: the max-min semantics agrees with the fixpoint -/

/-- A derivation of a claim: a checking step together with derivations of
all its premises. These are the positions of the proof-search container
(`ProofSearchN.lean`) specialised to grading. -/
inductive Deriv (S : System C T) : C → Type where
  | node (f : S.Step) (sub : ∀ y, y ∈ S.prems f → Deriv S y) : Deriv S (S.concl f)

/-- Fold `cmin` over premise-indexed values (a membership-aware fold, so the
recursion in `derivGrade` stays structural). -/
def foldPrems : (l : List C) → (∀ y, y ∈ l → T) → T → T
  | [], _, init => init
  | y :: t, g, init =>
      cmin (g y (.head t)) (foldPrems t (fun z hz => g z (.tail y hz)) init)

/-- The grade of a derivation: the meet of every step-grade in the tree
(weakest link). -/
noncomputable def derivGrade : {x : C} → Deriv S x → T :=
  fun d =>
    Deriv.rec (motive := fun _ _ => T)
      (fun f _ ih => foldPrems (S.prems f) ih (S.grade f)) d

theorem derivGrade_node (f : S.Step) (sub : ∀ y, y ∈ S.prems f → Deriv S y) :
    derivGrade S (.node f sub) =
      foldPrems (S.prems f) (fun y hy => derivGrade S (sub y hy)) (S.grade f) := rfl

/-- `foldPrems` is dominated by the mapped `cmin`-fold when the
membership-aware values are pointwise below. -/
theorem foldPrems_le {t : C → T} {init : T} :
    ∀ (l : List C) (g : ∀ y, y ∈ l → T),
    (∀ y (hy : y ∈ l), g y hy ≤ t y) →
    foldPrems l g init ≤ (l.map t).foldr cmin init
  | [], _, _ => Chain.le_refl init
  | y :: l', g, h => by
    show cmin _ _ ≤ cmin (t y) ((l'.map t).foldr cmin init)
    exact le_cmin
      (Chain.le_trans (cmin_le_left _ _) (h y (.head l')))
      (Chain.le_trans (cmin_le_right _ _)
        (foldPrems_le l' _ (fun z hz => h z (.tail y hz))))

/-- Mirror of `foldPrems_le`. -/
theorem le_foldPrems {t : C → T} {init : T} :
    ∀ (l : List C) (g : ∀ y, y ∈ l → T),
    (∀ y (hy : y ∈ l), t y ≤ g y hy) →
    (l.map t).foldr cmin init ≤ foldPrems l g init
  | [], _, _ => Chain.le_refl init
  | y :: l', g, h => by
    show cmin (t y) ((l'.map t).foldr cmin init) ≤ cmin _ _
    exact le_cmin
      (Chain.le_trans (cmin_le_left _ _) (h y (.head l')))
      (Chain.le_trans (cmin_le_right _ _)
        (le_foldPrems l' _ (fun z hz => h z (.tail y hz))))

/-- Every derivation's grade is below canonical trust: `tau` dominates the
max-min semantics. -/
theorem derivGrade_le_tau (wf : WellFounded S.Prem) :
    ∀ {x : C} (d : Deriv S x), derivGrade S d ≤ tau S wf x := by
  intro x d
  induction d with
  | node f sub ih =>
    rw [derivGrade_node]
    refine Chain.le_trans (foldPrems_le (S.prems f) _ ih) ?_
    rw [tau_eq]
    exact le_foldr_max
      (List.mem_map_of_mem (f := stepGrade S (tau S wf)) (S.stepsInto_mem f)) _

/-- Canonical trust is attained by some derivation whenever it is above
`bot`: `tau` does not exceed the max-min semantics. With
`derivGrade_le_tau`, the fixpoint form and the derivation-sup form agree.
The derivation is assembled with choice, premise by premise. -/
theorem tau_le_derivGrade (wf : WellFounded S.Prem) :
    ∀ x : C, tau S wf x ≠ Chain.bot → ∃ d : Deriv S x, tau S wf x ≤ derivGrade S d := by
  intro x
  induction x using WellFounded.induction wf with
  | _ x ih =>
    intro hx
    rcases foldr_max_cases ((S.stepsInto x).map (stepGrade S (tau S wf))) Chain.bot with h | h
    · exact absurd ((tau_eq S wf x).trans h) hx
    · obtain ⟨f, hf, hfe⟩ := List.mem_map.mp h
      have htx : tau S wf x = stepGrade S (tau S wf) f := by rw [tau_eq, ← hfe]
      -- every premise of the attaining step is itself trusted above bot
      have hprem : ∀ y, y ∈ S.prems f → tau S wf y ≠ Chain.bot := by
        intro y hy hbot
        apply hx
        refine Chain.le_antisymm ?_ (Chain.bot_le _)
        rw [htx, ← hbot]
        exact foldr_min_le (List.mem_map_of_mem (f := tau S wf) hy) _
      obtain rfl : S.concl f = x := S.mem_stepsInto hf
      refine ⟨.node f (fun y hy => (ih y ⟨f, hf, hy⟩ (hprem y hy)).choose), ?_⟩
      rw [htx, derivGrade_node]
      exact le_foldPrems (S.prems f) _
        (fun y hy => (ih y ⟨f, hf, hy⟩ (hprem y hy)).choose_spec)

/-! ### Morphisms and transport of trust -/

variable {T' : Type} [Chain T'] {C' : Type}

/-- A morphism of trust systems: claims and steps map forward, the
check-posets map along a monotone `phi` that is lax on grades (the target
may re-check and grade higher, never higher for free) and **strict at
bottom** — "no check" must map to "no check". Strictness at `bot` is a
correction to the prose Definition 3.1, discovered by this formalization:
without it, transport fails on underivable claims. -/
structure Mor (S : System C T) (S' : System C' T') where
  onClaim : C → C'
  onStep : S.Step → S'.Step
  phi : T → T'
  phi_mono : ∀ {a b : T}, a ≤ b → phi a ≤ phi b
  phi_bot : phi Chain.bot = Chain.bot
  prems_eq : ∀ f, S'.prems (onStep f) = (S.prems f).map onClaim
  grade_le : ∀ f, phi (S.grade f) ≤ S'.grade (onStep f)
  steps_mem : ∀ {x : C} {f : S.Step}, f ∈ S.stepsInto x → onStep f ∈ S'.stepsInto (onClaim x)

/-- **Lemma 3.2**: trust transports laxly along morphisms —
`phi (tau x) ≤ tau' (F x)`. Importing along a morphism never claims more
than `phi` of the source's canonical trust. -/
theorem tau_transport {S : System C T} {S' : System C' T'} (M : Mor S S')
    (wf : WellFounded S.Prem) (wf' : WellFounded S'.Prem) :
    ∀ x : C, M.phi (tau S wf x) ≤ tau S' wf' (M.onClaim x) := by
  intro x
  induction x using WellFounded.induction wf with
  | _ x ih =>
    rcases foldr_max_cases ((S.stepsInto x).map (stepGrade S (tau S wf))) Chain.bot with h | h
    · rw [tau_eq, h, M.phi_bot]
      exact Chain.bot_le _
    · obtain ⟨f, hf, hfe⟩ := List.mem_map.mp h
      rw [tau_eq, ← hfe]
      -- phi (stepGrade tau f) ≤ stepGrade' tau' (onStep f)
      have hstep : M.phi (stepGrade S (tau S wf) f) ≤
          stepGrade S' (tau S' wf' ) (M.onStep f) := by
        refine Chain.le_trans (phi_foldr_min (fun h => M.phi_mono h) _ _) ?_
        unfold stepGrade
        rw [M.prems_eq, List.map_map, List.map_map]
        exact foldr_min_map_mono (S.prems f)
          (fun y hy => ih y ⟨f, hf, hy⟩) (M.grade_le f)
      refine Chain.le_trans hstep ?_
      rw [tau_eq]
      exact le_foldr_max
        (List.mem_map_of_mem (f := stepGrade S' (tau S' wf')) (M.steps_mem hf)) _

/-! ### The circular-citation counterexample (Remark 2.3)

Two claims, each justified by a top-graded checking step from the other, no
ground checks. The constant-top assignment passes every node-local
certificate, yet no derivation exists and the premise relation is not
well-founded. Circular citation is trust inflation that no local check can
see: well-foundedness is a global hypothesis and must be checked globally. -/

/-- The two-level chain of trust: `lo` (= bot) and `hi`. -/
inductive Two where
  | lo
  | hi
deriving DecidableEq

instance : Chain Two where
  le a b := a = .lo ∨ b = .hi
  bot := .lo
  le_refl a := by
    cases a with
    | lo => exact .inl rfl
    | hi => exact .inr rfl
  le_trans {a b c} hab hbc := by
    cases hab with
    | inl h => exact .inl h
    | inr h =>
      cases hbc with
      | inl h' => exact Two.noConfusion (h' ▸ h)
      | inr h' => exact .inr h'
  le_antisymm {a b} hab hba := by
    cases hab with
    | inl h =>
      cases hba with
      | inl h' => exact h.trans h'.symm
      | inr h' => exact Two.noConfusion (h ▸ h')
    | inr h =>
      cases hba with
      | inl h' => exact Two.noConfusion (h' ▸ h)
      | inr h' => exact h'.trans h.symm
  le_total a b := by
    cases a with
    | lo => exact .inl (.inl rfl)
    | hi => exact .inr (.inr rfl)
  bot_le a := .inl rfl
  dec a b := inferInstanceAs (Decidable (a = .lo ∨ b = .hi))

/-- The cycle: claims are booleans, and the (only) step into `x` has the
single premise `!x`, graded `hi`. -/
def cyc : System Bool Two where
  Step := Bool
  concl := id
  prems f := [!f]
  grade _ := .hi
  stepsInto x := [x]
  mem_stepsInto := by
    intro x f h
    cases h with
    | head => rfl
    | tail _ h => cases h
  stepsInto_mem f := .head []

/-- The constant-top assignment is sound on the cycle: every node-local
certificate passes. -/
theorem cyc_sound_top : Sound cyc (fun _ => Two.hi) := by
  intro x _
  exact ⟨x, .head [], .inr rfl⟩

/-- Yet no claim in the cycle has any derivation at all: its canonical
trust in the max-min semantics is vacuous. -/
theorem cyc_no_deriv : ∀ x : Bool, Deriv cyc x → False := by
  intro x d
  induction d with
  | node f _ ih => exact ih (!f) (.head [])

/-- The premise relation of the cycle is not well-founded, so the
certificate lemma does not apply — as it must not. -/
theorem cyc_not_wf : ¬ WellFounded cyc.Prem := by
  intro h
  exact h.induction (C := fun _ => False) true
    (fun x ih => ih (!x) ⟨x, .head [], .head []⟩)

/-! ### Theorem 3: consolidation preserves trust

Consolidation (scratch → synthesis → … → proof) restates claims — a *shape
map* on the underlying container — and, when done with provenance, also
carries a *position map*: every checking step into a consolidated claim
pulls back to a checking step into each of its source claims, premises
corresponding, the recorded grade a **cached** value not exceeding the
source grade. A citation is exactly this cached pullback value.

The theorem: with a genuine position map, canonical trust is preserved on
the nose. The definition of `Consolidation` never mentions `tau` — the
condition is bisimulation-style and node-local, so the preservation is a
theorem, not a definition (this is the non-trivialization requirement of
the prose note §4). The shape-only case is `ground`/`layer4` below. -/

/-- A consolidation between trust systems over the same check-chain:
shapes forward (`onStep` — so `onClaim` underlies a morphism at `phi = id`),
positions backward (`posn` — every target step into a consolidated claim
pulls back to a source step into each preimage). `posn_grade` is the
citation condition: the consolidated grade is cached, at most the source
grade. Note `posn` is indexed by the preimage `x`: when consolidation merges
claims, every justification of the merged claim must pull back on *each*
side — merging claims of unequal trust is not a consolidation. -/
structure Consolidation (S : System C T) (S' : System C' T) where
  onClaim : C → C'
  -- shapes forward
  onStep : S.Step → S'.Step
  prems_eq : ∀ f, S'.prems (onStep f) = (S.prems f).map onClaim
  grade_le : ∀ f, S.grade f ≤ S'.grade (onStep f)
  steps_mem : ∀ {x : C} {f : S.Step},
    f ∈ S.stepsInto x → onStep f ∈ S'.stepsInto (onClaim x)
  -- positions backward
  posn : ∀ {x : C} (f' : S'.Step), f' ∈ S'.stepsInto (onClaim x) → S.Step
  posn_mem : ∀ {x : C} {f' : S'.Step} (h : f' ∈ S'.stepsInto (onClaim x)),
    posn f' h ∈ S.stepsInto x
  posn_prems : ∀ {x : C} {f' : S'.Step} (h : f' ∈ S'.stepsInto (onClaim x)),
    S'.prems f' = (S.prems (posn f' h)).map onClaim
  posn_grade : ∀ {x : C} {f' : S'.Step} (h : f' ∈ S'.stepsInto (onClaim x)),
    S'.grade f' ≤ S.grade (posn f' h)

/-- The forward half of a consolidation is a morphism at `phi = id`. -/
def Consolidation.toMor {S : System C T} {S' : System C' T}
    (K : Consolidation S S') : Mor S S' where
  onClaim := K.onClaim
  onStep := K.onStep
  phi := id
  phi_mono := fun h => h
  phi_bot := rfl
  prems_eq := K.prems_eq
  grade_le := K.grade_le
  steps_mem := K.steps_mem

/-- The position map forbids trust inflation: the consolidated system cannot
claim more than the source. Induction is on the **source** well-foundedness
only — attainment picks the target's best step, `posn` pulls it back, and
the premise correspondence re-indexes the inductive hypothesis. -/
theorem Consolidation.tau_le {S : System C T} {S' : System C' T}
    (K : Consolidation S S')
    (wf : WellFounded S.Prem) (wf' : WellFounded S'.Prem) :
    ∀ x : C, tau S' wf' (K.onClaim x) ≤ tau S wf x := by
  intro x
  induction x using WellFounded.induction wf with
  | _ x ih =>
    rcases foldr_max_cases
      ((S'.stepsInto (K.onClaim x)).map (stepGrade S' (tau S' wf'))) Chain.bot with h | h
    · rw [tau_eq, h]
      exact Chain.bot_le _
    · obtain ⟨f', hf', hfe⟩ := List.mem_map.mp h
      rw [tau_eq, ← hfe]
      have hstep : stepGrade S' (tau S' wf') f' ≤
          stepGrade S (tau S wf) (K.posn f' hf') := by
        unfold stepGrade
        rw [K.posn_prems hf', List.map_map]
        exact foldr_min_map_mono (S.prems (K.posn f' hf'))
          (fun y hy => ih y ⟨K.posn f' hf', K.posn_mem hf', hy⟩)
          (K.posn_grade hf')
      refine Chain.le_trans hstep ?_
      rw [tau_eq]
      exact le_foldr_max
        (List.mem_map_of_mem (f := stepGrade S (tau S wf)) (K.posn_mem hf')) _

/-- **Theorem 3 (consolidation preservation)**: a consolidation with a
genuine position map preserves canonical trust on the nose. Forward
inequality: shapes transport trust (`tau_transport` at `phi = id`);
backward: positions pull every target justification back (`tau_le`). -/
theorem tau_consolidate {S : System C T} {S' : System C' T}
    (K : Consolidation S S')
    (wf : WellFounded S.Prem) (wf' : WellFounded S'.Prem) :
    ∀ x : C, tau S' wf' (K.onClaim x) = tau S wf x :=
  fun x => Chain.le_antisymm (K.tau_le wf wf' x) (tau_transport K.toMor wf wf' x)

/-! ### Consolidations compose

The pipeline scratch → synthesis → … → proof is a *chain* of consolidations,
and the composite is again a consolidation: shapes compose covariantly,
positions compose **contravariantly** (a citation of a citation resolves
outermost-first), caches compose by transitivity of `≤`. By
`tau_consolidate`, trust is preserved end-to-end iff it is preserved
layer by layer — the four-layer degradation of `synthesis-layer4.md` is the
failure of (at least) one factor to be a consolidation at all.

Note what this composition does **not** use: nothing comonadic. `posn`s
compose as plain functions between step types — this is cofunctor
composition in the sense of the DCont-as-category dictionary (`M4-plan.md`),
not an application of `duplicate`. See the note's §6 for what this decides.

Category laws (`comp` associative, `id` neutral) are true but not stated:
equality of `Consolidation`s would compare membership-indexed `posn` fields,
the same extensionality that `Deriv` avoids. All *uses* go through `tau`
values, where the laws are invisible anyway. -/

/-- The identity consolidation: shapes and positions both the identity,
caches exact. -/
protected def Consolidation.id (S : System C T) : Consolidation S S where
  onClaim := id
  onStep := id
  prems_eq f := (List.map_id (S.prems f)).symm
  grade_le f := Chain.le_refl (S.grade f)
  steps_mem h := h
  posn f' _ := f'
  posn_mem h := h
  posn_prems {_ f'} _ := (List.map_id (S.prems f')).symm
  posn_grade {_ f'} _ := Chain.le_refl (S.grade f')

variable {C'' : Type}

/-- Composition of consolidations: shapes forward through both, positions
backward through both (contravariantly — pull back through `L` first, then
through `K`), the cached grades chaining by transitivity. -/
protected def Consolidation.comp {S : System C T} {S' : System C' T}
    {S'' : System C'' T}
    (K : Consolidation S S') (L : Consolidation S' S'') :
    Consolidation S S'' where
  onClaim x := L.onClaim (K.onClaim x)
  onStep f := L.onStep (K.onStep f)
  prems_eq f := by
    rw [L.prems_eq, K.prems_eq, List.map_map]; rfl
  grade_le f := Chain.le_trans (K.grade_le f) (L.grade_le (K.onStep f))
  steps_mem h := L.steps_mem (K.steps_mem h)
  posn f'' h := K.posn (L.posn f'' h) (L.posn_mem h)
  posn_mem h := K.posn_mem (L.posn_mem h)
  posn_prems h := by
    rw [L.posn_prems h, K.posn_prems (L.posn_mem h), List.map_map]; rfl
  posn_grade h := Chain.le_trans (L.posn_grade h) (K.posn_grade (L.posn_mem h))

/-- End-to-end preservation through a two-layer pipeline: the composite
consolidation preserves `tau`, and it factors as the two layer-wise
preservations — the equation for the whole pipeline is the conjunction of
the equations per layer. -/
theorem tau_consolidate_comp {S : System C T} {S' : System C' T}
    {S'' : System C'' T}
    (K : Consolidation S S') (L : Consolidation S' S'')
    (wf : WellFounded S.Prem) (wf' : WellFounded S'.Prem)
    (wf'' : WellFounded S''.Prem) :
    ∀ x : C, tau S'' wf'' ((K.comp L).onClaim x) = tau S wf x :=
  fun x => ((tau_consolidate L wf' wf'' (K.onClaim x)).trans
    (tau_consolidate K wf wf' x))

/-! ### The shape-only counterexample (synthesis-layer4)

One claim, one `hi`-graded ground check. Consolidating shape-only — the
claim restated, every citation dropped — yields a system with no steps at
all: canonical trust degrades from `hi` to `bot`. This is the formal shadow
of `synthesis-layer4.md`, which after four shape-only consolidation layers
retains zero machine-resolvable citations. No `Consolidation ground layer4`
exists (there is no target step for `onStep` to hit), and none may: any
consolidation would force `tau layer4 _ () = .hi` by `tau_consolidate`,
contradicting `layer4_tau_bot`. -/

/-- Source: one claim with a single ground check graded `hi`. -/
def ground : System Unit Two where
  Step := Unit
  concl _ := ()
  prems _ := []
  grade _ := .hi
  stepsInto _ := [()]
  mem_stepsInto _ := rfl
  stepsInto_mem _ := .head []

/-- Shape-only consolidation target: the claim survives, the check does
not. No steps, no positions. -/
def layer4 : System Unit Two where
  Step := Empty
  concl := Empty.elim
  prems := Empty.elim
  grade := Empty.elim
  stepsInto _ := []
  mem_stepsInto := fun h => nomatch h
  stepsInto_mem := fun f => f.elim

/-- `ground`'s premise relation is empty, hence well-founded. -/
theorem ground_wf : WellFounded ground.Prem := by
  constructor
  intro x
  constructor
  intro y hy
  obtain ⟨f, _, hmem⟩ := hy
  exact nomatch hmem

/-- `layer4`'s premise relation is empty, hence well-founded. -/
theorem layer4_wf : WellFounded layer4.Prem := by
  constructor
  intro x
  constructor
  intro y hy
  obtain ⟨f, hf, _⟩ := hy
  exact nomatch hf

/-- Before consolidation: trust is `hi`. -/
theorem ground_tau_hi : tau ground ground_wf () = Two.hi := by
  rw [tau_eq]
  rfl

/-- After shape-only consolidation: trust degrades to `bot`. -/
theorem layer4_tau_bot : tau layer4 layer4_wf () = Two.lo := by
  rw [tau_eq]
  rfl

end Containers.Trust
