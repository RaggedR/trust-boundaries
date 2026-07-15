import Containers.Basic
import Containers.Directed

/-!
# From a container comonad back to a directed container (M2b)

This file proves the **converse** of the Ahman–Chapman–Uustalu equivalence
(*When is a container a comonad?*, LMCS 10(3):2014). `Containers.Directed`
establishes the forward direction: a directed container `⟨S, P, o, ↓, ⊕⟩`
satisfying D1–D5 induces a comonad on its extension `Ext C`. Here we run the
construction backwards: from a comonad structure on `Ext C` we **recover** the
directed-container operations and prove D1–D5.

By the representation theorem (`Containers.Basic`), a natural transformation of
container extensions is exactly a container morphism, so the comonad's counit and
comultiplication are determined by combinatorial data:

* the counit `ε ⟨s, v⟩ = v (e s)` is a root choice `e : (s) → P s`;
* the comultiplication
  `δ ⟨s, v⟩ = ⟨cShape s, fun p => ⟨cSub s p, fun q => v (cVal s p q)⟩⟩`
  is a triple `(cShape, cSub, cVal)`.

We bundle this data as `ContainerComonad` and the three comonad laws as
`IsComonad`. The crux is that the **right counit law forces `cShape = id`**
(`cShape_eq`): the comultiplication cannot change the outer shape. Once the outer
shape collapses, `(e, cSub, cVal)` are exactly a root, a sub-shape and a shift,
and the three comonad laws become D1–D5 — the same partition as the forward
direction, read in reverse.

Because `cShape s` is only *propositionally* equal to `s`, the recovered `sub`
and `shift` carry transports along `cShape_eq`, exactly as the forward direction's
D2/D5 carry transports along D1/D4. All dependent casts are isolated in the
`Pos`-transport helpers and in `Ext.ext_eq` (reused from `Containers.Directed`).

Everything is `Type`-level, Lean 4 core, no Mathlib.
-/

namespace Containers

/-- Normalisation of a comultiplication-shaped `Ext` value along a shape equality
`hc : t = s`. With free `t`, `s`, `sub`, `val` this proves by `cases hc`,
sidestepping the occurs-check that blocks substituting `cShape s = s` directly.
This is the single lemma that absorbs every `cShape` transport in `comult_norm`. -/
theorem Ext.norm_aux {C : Container} {X : Type} {s t : C.Shape} (hc : t = s)
    (sub : C.Pos t → C.Shape) (val : (p : C.Pos t) → C.Pos (sub p) → C.Pos s)
    (v : C.Pos s → X) :
    (⟨t, fun p => ⟨sub p, fun q => v (val p q)⟩⟩ : Ext C (Ext C X))
      = ⟨s, fun p => ⟨sub (hc.symm ▸ p), fun q => v (val (hc.symm ▸ p) q)⟩⟩ := by
  cases hc
  rfl

/-- `Ext.map` on a literal pair. Stated as a rewrite that only fires once the
argument is in pair form, so normalisation rewrites the inner comultiplication
*before* unfolding `Ext.map` (avoiding stuck `Sigma` projections). -/
theorem Ext.map_mk {C : Container} {X Y : Type} (f : X → Y) (s : C.Shape)
    (g : C.Pos s → X) : Ext.map f (⟨s, g⟩ : Ext C X) = ⟨s, fun i => f (g i)⟩ :=
  rfl

/-- Injectivity of `Ext`'s dependent pair: an equality of `Ext` elements yields a
shape equality together with a value equality transported along it. This is the
extraction (destructor) dual to `Ext.ext_eq`, used to read directed-container
laws out of the comonad-law equalities. -/
theorem Ext.mk_inj {C : Container} {X : Type} {s₁ s₂ : C.Shape}
    {v₁ : C.Pos s₁ → X} {v₂ : C.Pos s₂ → X}
    (h : (⟨s₁, v₁⟩ : Ext C X) = ⟨s₂, v₂⟩) :
    ∃ hs : s₁ = s₂, ∀ q : C.Pos s₁, v₁ q = v₂ (hs ▸ q) := by
  injection h with hs hv
  subst hs
  exact ⟨rfl, fun q => congrFun (eq_of_heq hv) q⟩

/-- The combinatorial data of a **comonad on a container extension**, in the form
guaranteed by the representation theorem. `e` is the counit's root choice;
`cShape`, `cSub`, `cVal` are the three components of the comultiplication's
defining container morphism `C ⇒ C ∘ C`. -/
structure ContainerComonad extends Container where
  /-- Counit data: `ε ⟨s, v⟩ = v (e s)`. -/
  e : (s : Shape) → Pos s
  /-- Outer shape of the comultiplication. Forced to be `id` by the counit laws. -/
  cShape : Shape → Shape
  /-- Inner shapes of the comultiplication (the future sub-shapes). -/
  cSub : (s : Shape) → Pos (cShape s) → Shape
  /-- Values of the comultiplication (the future shift). -/
  cVal : (s : Shape) → (p : Pos (cShape s)) → Pos (cSub s p) → Pos s

namespace ContainerComonad

variable (M : ContainerComonad) {X : Type}

/-- The comonad **counit** `ε ⟨s, v⟩ = v (e s)`. -/
def counit : Ext M.toContainer X → X :=
  fun t => t.2 (M.e t.1)

/-- The comonad **comultiplication**
`δ ⟨s, v⟩ = ⟨cShape s, fun p => ⟨cSub s p, fun q => v (cVal s p q)⟩⟩`. -/
def comult : Ext M.toContainer X → Ext M.toContainer (Ext M.toContainer X) :=
  fun t => ⟨M.cShape t.1, fun p => ⟨M.cSub t.1 p, fun q => t.2 (M.cVal t.1 p q)⟩⟩

/-- The three **comonad laws** for `(counit, comult)`: left counit, right counit,
and coassociativity. Stated exactly dual to `Containers.Directed`'s forward laws. -/
structure IsComonad (M : ContainerComonad) : Prop where
  /-- `ε ∘ δ = id`. -/
  left_counit : ∀ {X : Type},
    M.counit ∘ M.comult = (id : Ext M.toContainer X → Ext M.toContainer X)
  /-- `(map ε) ∘ δ = id`. -/
  right_counit : ∀ {X : Type},
    Ext.map M.counit ∘ M.comult = (id : Ext M.toContainer X → Ext M.toContainer X)
  /-- `(map δ) ∘ δ = δ ∘ δ`. -/
  coassoc : ∀ {X : Type},
    Ext.map M.comult ∘ M.comult
      = (M.comult ∘ M.comult :
          Ext M.toContainer X →
            Ext M.toContainer (Ext M.toContainer (Ext M.toContainer X)))

/-- **The linchpin.** The right counit law forces the comultiplication to preserve
the outer shape: `cShape s = s`. Probe `(map ε) ∘ δ = id` at the generic element
`⟨s, id⟩ : Ext C (P s)` and read off the shape. -/
theorem cShape_eq (h : M.IsComonad) (s : M.Shape) : M.cShape s = s := by
  have hr := congrFun (h.right_counit (X := M.Pos s)) (⟨s, id⟩ : Ext M.toContainer (M.Pos s))
  exact congrArg Sigma.fst hr

/-! ### Recovered directed-container operations

Using `cShape_eq` to transport positions into the `cShape s` fibre, we read the
root, sub-shape and shift directly off `e`, `cSub`, `cVal`. -/

variable (h : M.IsComonad)

/-- Recovered **root** `o s = e s`. -/
def rRoot (_h : M.IsComonad) (s : M.Shape) : M.Pos s := M.e s

/-- Recovered **sub-shape** `s ↓ p = cSub s p`, transporting `p : P s` into the
`cShape s` fibre along `cShape_eq`. -/
def rSub (s : M.Shape) (p : M.Pos s) : M.Shape :=
  M.cSub s ((M.cShape_eq h s).symm ▸ p)

/-- Recovered **shift** `p ⊕ q = cVal s p q`, transporting `p` into the `cShape s`
fibre along `cShape_eq`. -/
def rShift (s : M.Shape) (p : M.Pos s) (q : M.Pos (M.rSub h s p)) : M.Pos s :=
  M.cVal s ((M.cShape_eq h s).symm ▸ p) q

/-- **Normalised comultiplication.** The right counit law collapses the outer
shape (`cShape_eq`), so the comultiplication is, up to the `cShape` transport,
already in directed-container form. This single lemma absorbs every `cShape`
cast; downstream the comonad laws yield D1–D5 with only the intrinsic D1/D4
transports, exactly mirroring the forward direction. -/
theorem comult_norm (s : M.Shape) (v : M.Pos s → X) :
    M.comult (⟨s, v⟩ : Ext M.toContainer X)
      = ⟨s, fun p => ⟨M.rSub h s p, fun q => v (M.rShift h s p q)⟩⟩ :=
  Ext.norm_aux (M.cShape_eq h s) (M.cSub s) (M.cVal s) v

/-! ### D1–D5 for the recovered operations

Each directed-container law is read off the corresponding comonad law by probing
at the generic element `⟨s, id⟩` and rewriting the comultiplication into its
normalised form. The partition matches the forward direction run in reverse:
left counit ⟹ D1 + D2, right counit ⟹ D3, coassociativity ⟹ D4 + D5. -/

/-- **D1** (sub under the root): `s ↓ (o s) = s`. From the left counit law. -/
theorem rD1 (s : M.Shape) : M.rSub h s (M.rRoot h s) = s := by
  have hL := congrFun (h.left_counit (X := M.Pos s)) (⟨s, id⟩ : Ext M.toContainer (M.Pos s))
  rw [Function.comp_apply, M.comult_norm h] at hL
  obtain ⟨hs, _⟩ := Ext.mk_inj hL
  exact hs

/-- **D2** (shift by the root is the identity): `(o s) ⊕ q = q`, transported along
`rD1`. The value half of the left counit law. -/
theorem rD2 (s : M.Shape) (q : M.Pos (M.rSub h s (M.rRoot h s))) :
    M.rShift h s (M.rRoot h s) q = (M.rD1 h s) ▸ q := by
  have hL := congrFun (h.left_counit (X := M.Pos s)) (⟨s, id⟩ : Ext M.toContainer (M.Pos s))
  rw [Function.comp_apply, M.comult_norm h] at hL
  obtain ⟨_, hv⟩ := Ext.mk_inj hL
  exact hv q

/-- **D3** (shift by the sub-shape's root is the identity): `p ⊕ o(s ↓ p) = p`.
The value half of the right counit law. -/
theorem rD3 (s : M.Shape) (p : M.Pos s) :
    M.rShift h s p (M.rRoot h (M.rSub h s p)) = p := by
  have hR := congrFun (h.right_counit (X := M.Pos s)) (⟨s, id⟩ : Ext M.toContainer (M.Pos s))
  rw [Function.comp_apply, M.comult_norm h] at hR
  obtain ⟨_, hv⟩ := Ext.mk_inj hR
  exact hv p

/-- **D4** (sub-shapes nest along the shift): `s ↓ (p ⊕ q) = (s ↓ p) ↓ q`. The
shape half of coassociativity. -/
theorem rD4 (s : M.Shape) (p : M.Pos s) (q : M.Pos (M.rSub h s p)) :
    M.rSub h s (M.rShift h s p q) = M.rSub h (M.rSub h s p) q := by
  have hC := congrFun (h.coassoc (X := M.Pos s)) (⟨s, id⟩ : Ext M.toContainer (M.Pos s))
  simp only [Function.comp_apply, M.comult_norm h, Ext.map_mk] at hC
  obtain ⟨_, hv1⟩ := Ext.mk_inj hC
  obtain ⟨_, hv2⟩ := Ext.mk_inj (hv1 p)
  obtain ⟨hs3, _⟩ := Ext.mk_inj (hv2 q)
  exact hs3.symm

/-- **D5** (the shift is associative), transported along `rD4`. The value half of
coassociativity. -/
theorem rD5 (s : M.Shape) (p : M.Pos s) (q : M.Pos (M.rSub h s p))
    (q' : M.Pos (M.rSub h (M.rSub h s p) q)) :
    M.rShift h s (M.rShift h s p q) ((M.rD4 h s p q).symm ▸ q')
      = M.rShift h s p (M.rShift h (M.rSub h s p) q q') := by
  have hC := congrFun (h.coassoc (X := M.Pos s)) (⟨s, id⟩ : Ext M.toContainer (M.Pos s))
  simp only [Function.comp_apply, M.comult_norm h, Ext.map_mk] at hC
  obtain ⟨_, hv1⟩ := Ext.mk_inj hC
  obtain ⟨_, hv2⟩ := Ext.mk_inj (hv1 p)
  obtain ⟨_, hv3⟩ := Ext.mk_inj (hv2 q)
  exact (hv3 q').symm

/-- **The recovery (M2b).** A container comonad yields a directed container, with
operations read off the counit and comultiplication and laws D1–D5 derived from
the comonad laws. -/
def toDirectedContainer (h : M.IsComonad) : DirectedContainer where
  toContainer := M.toContainer
  root := M.rRoot h
  sub := M.rSub h
  shift := M.rShift h
  d1 := M.rD1 h
  d4 := M.rD4 h
  d2 := M.rD2 h
  d3 := M.rD3 h
  d5 := M.rD5 h

/-- The recovered directed container induces **the same counit** as the comonad we
started from — on the nose. -/
theorem toDirectedContainer_counit (h : M.IsComonad) {X : Type}
    (t : Ext M.toContainer X) :
    (M.toDirectedContainer h).counit (X := X) t = M.counit t :=
  rfl

/-- The recovered directed container induces **the same comultiplication** as the
comonad we started from. This is `comult_norm`, and together with
`toDirectedContainer_counit` it says: applying the forward construction
(`Containers.Directed`) to the recovered directed container returns the original
comonad. One half of the equivalence `DirectedContainer ≃ container comonad`. -/
theorem toDirectedContainer_comult (h : M.IsComonad) {X : Type}
    (t : Ext M.toContainer X) :
    (M.toDirectedContainer h).comult (X := X) t = M.comult t := by
  obtain ⟨s, v⟩ := t
  exact (M.comult_norm h s v).symm

end ContainerComonad

namespace DirectedContainer

/-- The comonad of a directed container (the forward direction of
`Containers.Directed`), packaged as `ContainerComonad` data: the outer shape map
is the identity, and `e`, `cSub`, `cVal` are the root, sub-shape and shift. -/
def toContainerComonad (D : DirectedContainer) : ContainerComonad where
  toContainer := D.toContainer
  e := D.root
  cShape := id
  cSub := D.sub
  cVal := D.shift

/-- A directed container's packaged comonad satisfies the comonad laws — these are
exactly the forward laws proved in `Containers.Directed`. -/
theorem toContainerComonad_isComonad (D : DirectedContainer) :
    D.toContainerComonad.IsComonad where
  left_counit := fun {_} => D.left_counit
  right_counit := fun {_} => D.right_counit
  coassoc := fun {_} => D.coassoc

/-- **The other half of the equivalence.** Packaging a directed container as a
comonad and recovering it returns the original directed container — definitionally
(`cShape = id`, so every `cShape_eq` transport is `rfl` by proof irrelevance). -/
theorem toContainerComonad_toDirectedContainer (D : DirectedContainer) :
    D.toContainerComonad.toDirectedContainer D.toContainerComonad_isComonad = D :=
  rfl

end DirectedContainer

end Containers
