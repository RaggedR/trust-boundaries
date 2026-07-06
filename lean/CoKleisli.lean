import Containers.Directed

/-!
# CoKleisli structure and strength for directed container comonads

This file extends `Directed.lean` with the coKleisli operations and the
canonical strength of a directed container comonad. These are the formal
counterparts of the Python operations in `trustcheck.py ops`:

* `extend` — the coKleisli extension: given `f : W(X) → Y`, produce
  `W(X) → W(Y)` by applying `f` at every position (via `duplicate`).
  This is `W(f) ∘ δ`, or equivalently the unique lift making `ε ∘ extend f = f`.
* `cokleisli_comp` — composition in the coKleisli category:
  `g .* f = g ∘ extend f`. The Python `compose_cokleisli` function.
* `strength` — the canonical strength `W(A × B) → A × W(B)`, which
  factors a uniform context out of a labelled tree. The Python `dc_strength`.

## Main results

* `extend_counit` — `extend ε = id` (the counit is the identity of the
  coKleisli category)
* `counit_extend` — `ε ∘ extend f = f` (the counit is a left inverse of
  extension — this is what makes `extend` the unique lift)
* `extend_extend` — `extend (g ∘ extend f) = extend g ∘ extend f`
  (extension respects coKleisli composition — the associativity law)
* `strength_natural` — the strength is natural in both variables
* `strength_counit` — `(id × ε) ∘ σ = ε` (strength + extract = extract)

Everything is `Type`-level, Lean 4 core, no Mathlib.
-/

namespace Containers

namespace DirectedContainer

variable (D : DirectedContainer)

/-! ### CoKleisli extension -/

/-- The **coKleisli extension** of `f : Ext D X → Y`: apply `f` at every
position via `duplicate`, producing `Ext D Y`.

`extend f ⟨s, v⟩ = ⟨s, λp. f ⟨s ↓ p, λq. v (p ⊕ q)⟩⟩`

This is `Ext.map f ∘ comult`, i.e. `W(f) ∘ δ`. -/
def extend {X Y : Type} (f : Ext D.toContainer X → Y) :
    Ext D.toContainer X → Ext D.toContainer Y :=
  fun p => ⟨p.1, fun q => f ⟨D.sub p.1 q, fun r => p.2 (D.shift p.1 q r)⟩⟩

/-- Extension equals `map f ∘ comult`, definitionally. -/
theorem extend_eq_map_comult {X Y : Type} (f : Ext D.toContainer X → Y) :
    D.extend f = Ext.map f ∘ D.comult := by
  rfl

/-- **`extend ε = id`**: extending the counit is the identity. This is the
right unit law of the coKleisli category, and it follows from the right
counit law of the comonad.

Proof: `extend ε ⟨s, v⟩ = ⟨s, λp. ε ⟨s ↓ p, λq. v (p ⊕ q)⟩⟩`
`= ⟨s, λp. v (p ⊕ o(s ↓ p))⟩ = ⟨s, λp. v p⟩` by D3. -/
theorem extend_counit {X : Type} :
    D.extend (D.counit (X := X)) = id := by
  funext p
  obtain ⟨s, v⟩ := p
  show (⟨s, fun q => v (D.shift s q (D.root (D.sub s q)))⟩ : Ext D.toContainer X) = ⟨s, v⟩
  exact Ext.ext_eq rfl (fun q => congrArg v (D.d3 s q))

/-- **`ε ∘ extend f = f`**: the counit is a left inverse of extension.
This characterizes `extend f` as the unique map with `ε ∘ h = f` and
`comult ∘ h = (map h) ∘ comult` (the universal property of extension).

Proof: `ε (extend f ⟨s, v⟩) = ε ⟨s, λp. f ⟨s ↓ p, ...⟩⟩`
`= f ⟨s ↓ o(s), λq. v (o(s) ⊕ q)⟩ = f ⟨s, v⟩` by D1 and D2. -/
theorem counit_extend {X Y : Type} (f : Ext D.toContainer X → Y) :
    D.counit ∘ D.extend f = f := by
  funext p
  obtain ⟨s, v⟩ := p
  show f ⟨D.sub s (D.root s), fun r => v (D.shift s (D.root s) r)⟩ = f ⟨s, v⟩
  congr 1
  exact Ext.ext_eq (D.d1 s) (fun q => congrArg v (D.d2 s q))

/-- **`extend (g ∘ extend f) = extend g ∘ extend f`**: extension respects
coKleisli composition. This is the associativity law of the coKleisli
category. It follows from coassociativity of the comonad.

Proof: both sides evaluate at `⟨s, v⟩` to
`⟨s, λp. g ⟨s ↓ p, λq. f ⟨s ↓ (p ⊕ q), λr. v ((p ⊕ q) ⊕ r)⟩⟩⟩`,
using D4 for shape equality and D5 for value equality. -/
theorem extend_extend {X Y Z : Type}
    (f : Ext D.toContainer X → Y)
    (g : Ext D.toContainer Y → Z) :
    D.extend (g ∘ D.extend f) = D.extend g ∘ D.extend f := by
  funext p
  obtain ⟨s, v⟩ := p
  apply Ext.ext_eq rfl
  intro q
  show g ⟨D.sub s q, fun r =>
      f ⟨D.sub (D.sub s q) r,
        fun t => v (D.shift s q (D.shift (D.sub s q) r t))⟩⟩
    = g ⟨D.sub s q, fun r =>
      f ⟨D.sub s (D.shift s q r),
        fun t => v (D.shift s (D.shift s q r) ((D.d4 s q r).symm ▸ t))⟩⟩
  congr 1
  apply Ext.ext_eq rfl
  intro r
  congr 1
  exact Ext.ext_eq (D.d4 s q r).symm
    (fun t => (congrArg v (D.d5 s q r t)).symm)

/-! ### CoKleisli composition -/

/-- **CoKleisli composition**: `g .* f = g ∘ extend f`.

Given coKleisli morphisms `f : W(X) → Y` and `g : W(Y) → Z`, their
composite is a coKleisli morphism `W(X) → Z`. This is the `compose_cokleisli`
function in `trustcheck.py`. -/
def cokleisli_comp {X Y Z : Type}
    (f : Ext D.toContainer X → Y)
    (g : Ext D.toContainer Y → Z) :
    Ext D.toContainer X → Z :=
  g ∘ D.extend f

/-- CoKleisli composition with the counit on the right is `f`:
`f .* ε = f`. (Right unit.) -/
theorem cokleisli_comp_counit {X Y : Type}
    (f : Ext D.toContainer X → Y) :
    D.cokleisli_comp (D.counit) f = f := by
  unfold cokleisli_comp
  rw [extend_counit]
  rfl

/-- CoKleisli composition with the counit on the left is `f`:
`ε .* f = f`. (Left unit.) -/
theorem cokleisli_counit_comp {X Y : Type}
    (f : Ext D.toContainer X → Y) :
    D.cokleisli_comp f D.counit = f := by
  unfold cokleisli_comp
  exact D.counit_extend f

/-- CoKleisli composition is **associative**:
`(h .* g) .* f = h .* (g .* f)`. -/
theorem cokleisli_assoc {X Y Z W : Type}
    (f : Ext D.toContainer X → Y)
    (g : Ext D.toContainer Y → Z)
    (h : Ext D.toContainer Z → W) :
    D.cokleisli_comp (D.cokleisli_comp f g) h
      = D.cokleisli_comp f (D.cokleisli_comp g h) := by
  unfold cokleisli_comp
  show h ∘ D.extend (g ∘ D.extend f) = h ∘ D.extend g ∘ D.extend f
  rw [D.extend_extend f g]

/-! ### Strength -/

/-- The **canonical strength** of the comonad: `σ : W(A × B) → A × W(B)`.

`σ ⟨s, v⟩ = (fst (v (o s)), ⟨s, snd ∘ v⟩)`

The first component extracts the `A`-part at the root; the second keeps
the shape and strips to `B`-parts. This is the Python `dc_strength`:
it factors a uniform context `A` out of the labelled tree `W(A × B)`.

The strength exists for *every* directed container comonad (indeed, for
every comonad on a cartesian category — comonads are canonically strong). -/
def strength (A B : Type) :
    Ext D.toContainer (A × B) → A × Ext D.toContainer B :=
  fun p => (p.2 (D.root p.1)).1, ⟨p.1, fun q => (p.2 q).2⟩⟩

/-- Strength is natural in `A`: `(f × id) ∘ σ = σ ∘ W(f × id)`. -/
theorem strength_natural_left {A A' B : Type} (f : A → A') :
    (fun p : A × Ext D.toContainer B => (f p.1, p.2)) ∘ D.strength A B
      = D.strength A' B ∘ Ext.map (fun ab : A × B => (f ab.1, ab.2)) := by
  funext p
  rfl

/-- Strength is natural in `B`: `(id × W(g)) ∘ σ = σ ∘ W(id × g)`. -/
theorem strength_natural_right {A B B' : Type} (g : B → B') :
    (fun p : A × Ext D.toContainer B => (p.1, Ext.map g p.2)) ∘ D.strength A B
      = D.strength A B' ∘ Ext.map (fun ab : A × B => (ab.1, g ab.2)) := by
  funext p
  rfl

/-- Strength interacts with counit: `(id × ε) ∘ σ = ε`.
Extracting from the `B`-component of the strength gives the same as
extracting directly from the `A × B` tree. -/
theorem strength_counit {A B : Type} :
    (fun p : A × Ext D.toContainer B => (p.1, D.counit p.2)) ∘ D.strength A B
      = D.counit (X := A × B) := by
  funext p
  rfl

end DirectedContainer

end Containers
