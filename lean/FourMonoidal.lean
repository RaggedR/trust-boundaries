import Containers.Dirichlet

/-!
# The four monoidal structures on `Cont`

`Cont` carries (at least) **four** monoidal structures of interest, and this file
completes the Lean account of all four:

| structure | tensor of `C = S ◁ P`, `D = T ◁ Q` | unit | Lean |
|---|---|---|---|
| **coproduct** `+` | `(S ⊕ T) ◁ Sum.elim P Q` | `0 = Empty ◁ …` | `contCoprodMonoidal` (here) |
| **product** `×` | `(S × T) ◁ (fun (s,t) => P s ⊕ Q t)` | `1 = Unit ◁ (fun _ => Empty)` | `contProdMonoidal` (here) |
| **Dirichlet** `⊗` | `(S × T) ◁ (fun (s,t) => P s × Q t)` | `y = Unit ◁ (fun _ => Unit)` | `contDirichletMonoidal` (`Dirichlet.lean`) |
| **sequential** `◁` | `(Σ s, P s → T) ◁ (fun (s,f) => Σ p, Q (f p))` | `I = y` | `ContMonoidal` (`Monoidal.lean`) |

Only **one** of the four can be the canonical `MonoidalCategory Container`
*instance* — four instances on the same type would collide in instance
resolution. We keep `ContMonoidal` (the sequential operator `◁`, the spine of the
development: its comonoids are the directed containers) as *the* instance, and
give the other three as named `def`s, used explicitly. **Four monoidal structures
on one category is the mathematical point**; this is how the code says it.

## The product/Dirichlet contrast

The product and the Dirichlet tensor have *the same shapes* `S × T` and differ
only in their positions:

* product `×`: positions `P s ⊕ Q t` — a **sum**;
* Dirichlet `⊗`: positions `P s × Q t` — a **product**.

Yet the *extensions* invert the reading: the container whose positions are a
**sum** has the pointwise **product** of functors as its extension,

  `⟦C × D⟧ X ≅ ⟦C⟧ X × ⟦D⟧ X`   (`Container.prodExt` below),

because of the exponential law `y^(A+B) ≅ y^A × y^B`: a labelling of `P s ⊕ Q t`
*is* a pair of a labelling of `P s` and a labelling of `Q t`. The Dirichlet
tensor's positions `P s × Q t` admit no such splitting (`y^(A×B)` does not split),
and correspondingly `⟦C ⊗ D⟧` is **not** any pointwise combination of `⟦C⟧` and
`⟦D⟧` — see the taxonomy in `Dirichlet.lean`.

## `⟦−⟧` as a monoidal functor

This file proves the comparison isomorphisms that make the extension functor
`⟦−⟧` *strong* monoidal for the coproduct and the product:

* `⟦C + D⟧ X ≅ ⟦C⟧ X ⊕ ⟦D⟧ X` and `⟦0⟧ X ≅ Empty`;
* `⟦C × D⟧ X ≅ ⟦C⟧ X × ⟦D⟧ X` and `⟦1⟧ X ≅ Unit`;
* `⟦y⟧ X ≅ X` (the unit comparison shared by `⊗` and `◁`).

(The `◁` comparison `⟦G ◁ F⟧ X ≅ ⟦G⟧ (⟦F⟧ X)` is `Container.seqExt` in
`Sequential.lean`. For `⊗` there is *no* pointwise comparison: see
`Dirichlet.lean`.) None of these comparison maps is an identity — each is a
genuine isomorphism, which is exactly what "strong, not strict" means.

Everything is `Type`-level, Lean 4 core, no Mathlib.
-/

namespace Containers

universe u v

/-! ## The units `0` and `1`

`0` is the empty container: no shapes (hence, vacuously, no positions). Its
extension is the constantly-empty functor.

`1` is the one-shape, no-position container. Its extension is the constantly-one
functor. Note `1 = y⁰` and `y = y¹`: `1` is the unit for `×`, `y` for `⊗`. -/

/-- The **empty container** `0 = Empty ◁ (fun e => e.elim)`: the unit for the
coproduct and the initial object of `Cont`. -/
def Container.zero : Container where
  Shape := Empty
  Pos := fun e => e.elim

/-- The **one-shape, no-position container** `1 = Unit ◁ (fun _ => Empty)` — the
polynomial `y⁰`. It is the unit for the categorical product, and the terminal
object of `Cont`. -/
def Container.one : Container where
  Shape := Unit
  Pos := fun _ => Empty

/-! # 1. The coproduct `(Cont, +, 0)` -/

/-! ## Bifunctoriality of `+`

The morphism action is the copairing of the two injections precomposed with the
given morphisms — i.e. it is *derived from the universal property* already proved
in `Cont.lean`, not defined afresh. The functor laws need a case split on the
shape (`Sum.elim` composed with `Sum.elim` is only *pointwise* a `Sum.elim`), so
they are `cases`-then-`rfl` rather than bare `rfl`. -/

/-- The **action of `+` on a pair of morphisms**, `coprod₂ μ ν : C + D ⟶ C' + D'`,
obtained from the coproduct's universal property. -/
def Container.coprod₂ {C C' D D' : Container}
    (μ : ContainerMorphism C C') (ν : ContainerMorphism D D') :
    ContainerMorphism (C.coprod D) (C'.coprod D') :=
  (μ.comp (Container.inl C' D')).desc (ν.comp (Container.inr C' D'))

/-- `coprod₂` preserves identities. -/
theorem Container.coprod₂_id (C D : Container) :
    Container.coprod₂ (ContainerMorphism.id C) (ContainerMorphism.id D)
      = ContainerMorphism.id (C.coprod D) := by
  refine ContainerMorphism.ext' ?_ ?_
  · funext s; cases s <;> rfl
  · intro s p; cases s <;> rfl

/-- `coprod₂` preserves composition (interchange). -/
theorem Container.coprod₂_comp {C C' C'' D D' D'' : Container}
    (μ : ContainerMorphism C C') (μ' : ContainerMorphism C' C'')
    (ν : ContainerMorphism D D') (ν' : ContainerMorphism D' D'') :
    Container.coprod₂ (μ.comp μ') (ν.comp ν')
      = (Container.coprod₂ μ ν).comp (Container.coprod₂ μ' ν') := by
  refine ContainerMorphism.ext' ?_ ?_
  · funext s; cases s <;> rfl
  · intro s p; cases s <;> rfl

/-! ## Structural isomorphisms for `+`

On shapes: the standard `Sum`-reassociation and the `Empty`-collapses. On
positions: the *identity* in every branch — the positions of an injected shape
*are* the positions of the summand. -/

/-- The **associator** `(C + D) + E ≅ C + (D + E)`: `Sum`-reassociation on shapes,
identity on positions. -/
def Container.coprodAssociator (C D E : Container) :
    ContainerIso ((C.coprod D).coprod E) (C.coprod (D.coprod E)) where
  hom :=
    { onShapes := fun x => match x with
        | Sum.inl (Sum.inl a) => Sum.inl a
        | Sum.inl (Sum.inr b) => Sum.inr (Sum.inl b)
        | Sum.inr c => Sum.inr (Sum.inr c)
      onPos := fun x => match x with
        | Sum.inl (Sum.inl _) => _root_.id
        | Sum.inl (Sum.inr _) => _root_.id
        | Sum.inr _ => _root_.id }
  inv :=
    { onShapes := fun x => match x with
        | Sum.inl a => Sum.inl (Sum.inl a)
        | Sum.inr (Sum.inl b) => Sum.inl (Sum.inr b)
        | Sum.inr (Sum.inr c) => Sum.inr c
      onPos := fun x => match x with
        | Sum.inl _ => _root_.id
        | Sum.inr (Sum.inl _) => _root_.id
        | Sum.inr (Sum.inr _) => _root_.id }
  hom_inv := by
    refine ContainerMorphism.ext' ?_ ?_
    · funext x; rcases x with (a | b) | c <;> rfl
    · intro x p; rcases x with (a | b) | c <;> rfl
  inv_hom := by
    refine ContainerMorphism.ext' ?_ ?_
    · funext x; rcases x with a | (b | c) <;> rfl
    · intro x p; rcases x with a | (b | c) <;> rfl

/-- The **left unitor** `0 + C ≅ C`: there is nothing in the left summand. -/
def Container.coprodLeftUnitor (C : Container) :
    ContainerIso (Container.zero.coprod C) C where
  hom :=
    { onShapes := fun x => match x with
        | Sum.inl e => e.elim
        | Sum.inr s => s
      onPos := fun x => match x with
        | Sum.inl e => e.elim
        | Sum.inr _ => _root_.id }
  inv :=
    { onShapes := Sum.inr
      onPos := fun _ => _root_.id }
  hom_inv := by
    refine ContainerMorphism.ext' ?_ ?_
    · funext x; cases x with
      | inl e => exact e.elim
      | inr s => rfl
    · intro x p; cases x with
      | inl e => exact e.elim
      | inr s => rfl
  inv_hom := rfl

/-- The **right unitor** `C + 0 ≅ C`. -/
def Container.coprodRightUnitor (C : Container) :
    ContainerIso (C.coprod Container.zero) C where
  hom :=
    { onShapes := fun x => match x with
        | Sum.inl s => s
        | Sum.inr e => e.elim
      onPos := fun x => match x with
        | Sum.inl _ => _root_.id
        | Sum.inr e => e.elim }
  inv :=
    { onShapes := Sum.inl
      onPos := fun _ => _root_.id }
  hom_inv := by
    refine ContainerMorphism.ext' ?_ ?_
    · funext x; cases x with
      | inl s => rfl
      | inr e => exact e.elim
    · intro x p; cases x with
      | inl s => rfl
      | inr e => exact e.elim
  inv_hom := rfl

/-! ## Naturality and coherence for `+` -/

/-- **Naturality of the coproduct associator.** -/
theorem Container.coprodAssociator_naturality {X₁ Y₁ X₂ Y₂ X₃ Y₃ : Container}
    (f₁ : ContainerMorphism X₁ Y₁) (f₂ : ContainerMorphism X₂ Y₂)
    (f₃ : ContainerMorphism X₃ Y₃) :
    (Container.coprod₂ (Container.coprod₂ f₁ f₂) f₃).comp
        (Container.coprodAssociator Y₁ Y₂ Y₃).hom
      = (Container.coprodAssociator X₁ X₂ X₃).hom.comp
          (Container.coprod₂ f₁ (Container.coprod₂ f₂ f₃)) := by
  refine ContainerMorphism.ext' ?_ ?_
  · funext x; rcases x with (a | b) | c <;> rfl
  · intro x p; rcases x with (a | b) | c <;> rfl

/-- **Naturality of the coproduct left unitor.** -/
theorem Container.coprodLeftUnitor_naturality {X Y : Container}
    (f : ContainerMorphism X Y) :
    (Container.coprod₂ (ContainerMorphism.id Container.zero) f).comp
        (Container.coprodLeftUnitor Y).hom
      = (Container.coprodLeftUnitor X).hom.comp f := by
  refine ContainerMorphism.ext' ?_ ?_
  · funext x; cases x with
    | inl e => exact e.elim
    | inr s => rfl
  · intro x p; cases x with
    | inl e => exact e.elim
    | inr s => rfl

/-- **Naturality of the coproduct right unitor.** -/
theorem Container.coprodRightUnitor_naturality {X Y : Container}
    (f : ContainerMorphism X Y) :
    (Container.coprod₂ f (ContainerMorphism.id Container.zero)).comp
        (Container.coprodRightUnitor Y).hom
      = (Container.coprodRightUnitor X).hom.comp f := by
  refine ContainerMorphism.ext' ?_ ?_
  · funext x; cases x with
    | inl s => rfl
    | inr e => exact e.elim
  · intro x p; cases x with
    | inl s => rfl
    | inr e => exact e.elim

/-- **Pentagon** for the coproduct. -/
theorem Container.coprodPentagon (C₁ C₂ C₃ C₄ : Container) :
    ((Container.coprod₂ (Container.coprodAssociator C₁ C₂ C₃).hom
          (ContainerMorphism.id C₄)).comp
        (Container.coprodAssociator C₁ (C₂.coprod C₃) C₄).hom).comp
        (Container.coprod₂ (ContainerMorphism.id C₁)
          (Container.coprodAssociator C₂ C₃ C₄).hom)
      = (Container.coprodAssociator (C₁.coprod C₂) C₃ C₄).hom.comp
          (Container.coprodAssociator C₁ C₂ (C₃.coprod C₄)).hom := by
  refine ContainerMorphism.ext' ?_ ?_
  · funext x; rcases x with ((a | b) | c) | d <;> rfl
  · intro x p; rcases x with ((a | b) | c) | d <;> rfl

/-- **Triangle** for the coproduct. -/
theorem Container.coprodTriangle (C₁ C₂ : Container) :
    (Container.coprodAssociator C₁ Container.zero C₂).hom.comp
        (Container.coprod₂ (ContainerMorphism.id C₁)
          (Container.coprodLeftUnitor C₂).hom)
      = Container.coprod₂ (Container.coprodRightUnitor C₁).hom
          (ContainerMorphism.id C₂) := by
  refine ContainerMorphism.ext' ?_ ?_
  · funext x; rcases x with (a | e) | c
    · rfl
    · exact e.elim
    · rfl
  · intro x p; rcases x with (a | e) | c
    · rfl
    · exact e.elim
    · rfl

/-- **`(Cont, +, 0)` is a monoidal category.** A named `def`, not an instance —
see the module docstring: `Cont` has four monoidal structures and only one of
them can be *the* instance. -/
@[reducible] def contCoprodMonoidal : MonoidalCategory Container where
  tensorObj := Container.coprod
  tensorHom := Container.coprod₂
  tensorHom_id := Container.coprod₂_id
  tensorHom_comp := fun f₁ g₁ f₂ g₂ => Container.coprod₂_comp f₁ g₁ f₂ g₂
  tensorUnit := Container.zero
  associator := fun X Y Z => (Container.coprodAssociator X Y Z).toCatIso
  leftUnitor := fun X => (Container.coprodLeftUnitor X).toCatIso
  rightUnitor := fun X => (Container.coprodRightUnitor X).toCatIso
  associator_naturality := fun f₁ f₂ f₃ => Container.coprodAssociator_naturality f₁ f₂ f₃
  leftUnitor_naturality := fun f => Container.coprodLeftUnitor_naturality f
  rightUnitor_naturality := fun f => Container.coprodRightUnitor_naturality f
  pentagon := Container.coprodPentagon
  triangle := Container.coprodTriangle

/-! # 2. The product `(Cont, ×, 1)`

Dual to the coproduct, and the subtle one: shapes multiply, but **positions add**
(`P s ⊕ Q t`). The morphism action comes from the universal property (`pair` of
the projections composed with the given morphisms); the associator and unitors are
`Prod`-reassociation on shapes and `Sum`-reassociation *backwards* on positions. -/

/-- The **action of `×` on a pair of morphisms**, `prod₂ μ ν : C × D ⟶ C' × D'`,
obtained from the product's universal property. -/
def Container.prod₂ {C C' D D' : Container}
    (μ : ContainerMorphism C C') (ν : ContainerMorphism D D') :
    ContainerMorphism (C.prod D) (C'.prod D') :=
  ((Container.fst C D).comp μ).pair ((Container.snd C D).comp ν)

/-- `prod₂` preserves identities. (Shapes by `Prod` η; positions need a case split,
`Sum.elim Sum.inl Sum.inr` being only pointwise the identity.) -/
theorem Container.prod₂_id (C D : Container) :
    Container.prod₂ (ContainerMorphism.id C) (ContainerMorphism.id D)
      = ContainerMorphism.id (C.prod D) := by
  refine ContainerMorphism.ext' rfl ?_
  intro s p; cases p <;> rfl

/-- `prod₂` preserves composition (interchange). -/
theorem Container.prod₂_comp {C C' C'' D D' D'' : Container}
    (μ : ContainerMorphism C C') (μ' : ContainerMorphism C' C'')
    (ν : ContainerMorphism D D') (ν' : ContainerMorphism D' D'') :
    Container.prod₂ (μ.comp μ') (ν.comp ν')
      = (Container.prod₂ μ ν).comp (Container.prod₂ μ' ν') := by
  refine ContainerMorphism.ext' rfl ?_
  intro s p; cases p <;> rfl

/-- The **associator** `(C × D) × E ≅ C × (D × E)`: `Prod`-reassociation on shapes,
`Sum`-reassociation (backwards) on positions. -/
def Container.prodAssociator (C D E : Container) :
    ContainerIso ((C.prod D).prod E) (C.prod (D.prod E)) where
  hom :=
    { onShapes := fun x => (x.1.1, (x.1.2, x.2))
      onPos := fun _ p =>
        Sum.elim (fun a => Sum.inl (Sum.inl a))
          (Sum.elim (fun b => Sum.inl (Sum.inr b)) (fun c => Sum.inr c)) p }
  inv :=
    { onShapes := fun x => ((x.1, x.2.1), x.2.2)
      onPos := fun _ p =>
        Sum.elim (Sum.elim (fun a => Sum.inl a) (fun b => Sum.inr (Sum.inl b)))
          (fun c => Sum.inr (Sum.inr c)) p }
  hom_inv := by
    refine ContainerMorphism.ext' rfl ?_
    intro x p; rcases p with (a | b) | c <;> rfl
  inv_hom := by
    refine ContainerMorphism.ext' rfl ?_
    intro x p; rcases p with a | (b | c) <;> rfl

/-- The **left unitor** `1 × C ≅ C`: the `1`-shape contributes no positions. -/
def Container.prodLeftUnitor (C : Container) :
    ContainerIso (Container.one.prod C) C where
  hom :=
    { onShapes := fun x => x.2
      onPos := fun _ p => Sum.inr p }
  inv :=
    { onShapes := fun s => ((), s)
      onPos := fun _ p => Sum.elim (fun e => e.elim) _root_.id p }
  hom_inv := by
    refine ContainerMorphism.ext' rfl ?_
    intro x p; cases p with
    | inl e => exact e.elim
    | inr q => rfl
  inv_hom := rfl

/-- The **right unitor** `C × 1 ≅ C`. -/
def Container.prodRightUnitor (C : Container) :
    ContainerIso (C.prod Container.one) C where
  hom :=
    { onShapes := fun x => x.1
      onPos := fun _ p => Sum.inl p }
  inv :=
    { onShapes := fun s => (s, ())
      onPos := fun _ p => Sum.elim _root_.id (fun e => e.elim) p }
  hom_inv := by
    refine ContainerMorphism.ext' rfl ?_
    intro x p; cases p with
    | inl q => rfl
    | inr e => exact e.elim
  inv_hom := rfl

/-! ## Naturality and coherence for `×` -/

/-- **Naturality of the product associator.** -/
theorem Container.prodAssociator_naturality {X₁ Y₁ X₂ Y₂ X₃ Y₃ : Container}
    (f₁ : ContainerMorphism X₁ Y₁) (f₂ : ContainerMorphism X₂ Y₂)
    (f₃ : ContainerMorphism X₃ Y₃) :
    (Container.prod₂ (Container.prod₂ f₁ f₂) f₃).comp
        (Container.prodAssociator Y₁ Y₂ Y₃).hom
      = (Container.prodAssociator X₁ X₂ X₃).hom.comp
          (Container.prod₂ f₁ (Container.prod₂ f₂ f₃)) := by
  refine ContainerMorphism.ext' rfl ?_
  intro x p; rcases p with a | (b | c) <;> rfl

/-- **Naturality of the product left unitor.** -/
theorem Container.prodLeftUnitor_naturality {X Y : Container} (f : ContainerMorphism X Y) :
    (Container.prod₂ (ContainerMorphism.id Container.one) f).comp
        (Container.prodLeftUnitor Y).hom
      = (Container.prodLeftUnitor X).hom.comp f := rfl

/-- **Naturality of the product right unitor.** -/
theorem Container.prodRightUnitor_naturality {X Y : Container} (f : ContainerMorphism X Y) :
    (Container.prod₂ f (ContainerMorphism.id Container.one)).comp
        (Container.prodRightUnitor Y).hom
      = (Container.prodRightUnitor X).hom.comp f := rfl

/-- **Pentagon** for the product. -/
theorem Container.prodPentagon (C₁ C₂ C₃ C₄ : Container) :
    ((Container.prod₂ (Container.prodAssociator C₁ C₂ C₃).hom
          (ContainerMorphism.id C₄)).comp
        (Container.prodAssociator C₁ (C₂.prod C₃) C₄).hom).comp
        (Container.prod₂ (ContainerMorphism.id C₁)
          (Container.prodAssociator C₂ C₃ C₄).hom)
      = (Container.prodAssociator (C₁.prod C₂) C₃ C₄).hom.comp
          (Container.prodAssociator C₁ C₂ (C₃.prod C₄)).hom := by
  refine ContainerMorphism.ext' rfl ?_
  intro x p; rcases p with a | (b | (c | d)) <;> rfl

/-- **Triangle** for the product. -/
theorem Container.prodTriangle (C₁ C₂ : Container) :
    (Container.prodAssociator C₁ Container.one C₂).hom.comp
        (Container.prod₂ (ContainerMorphism.id C₁) (Container.prodLeftUnitor C₂).hom)
      = Container.prod₂ (Container.prodRightUnitor C₁).hom (ContainerMorphism.id C₂) := by
  refine ContainerMorphism.ext' rfl ?_
  intro x p; cases p <;> rfl

/-- **`(Cont, ×, 1)` is a monoidal category.** A named `def`, not an instance. -/
@[reducible] def contProdMonoidal : MonoidalCategory Container where
  tensorObj := Container.prod
  tensorHom := Container.prod₂
  tensorHom_id := Container.prod₂_id
  tensorHom_comp := fun f₁ g₁ f₂ g₂ => Container.prod₂_comp f₁ g₁ f₂ g₂
  tensorUnit := Container.one
  associator := fun X Y Z => (Container.prodAssociator X Y Z).toCatIso
  leftUnitor := fun X => (Container.prodLeftUnitor X).toCatIso
  rightUnitor := fun X => (Container.prodRightUnitor X).toCatIso
  associator_naturality := fun f₁ f₂ f₃ => Container.prodAssociator_naturality f₁ f₂ f₃
  leftUnitor_naturality := fun f => Container.prodLeftUnitor_naturality f
  rightUnitor_naturality := fun f => Container.prodRightUnitor_naturality f
  pentagon := Container.prodPentagon
  triangle := Container.prodTriangle

/-! # 3. `⟦−⟧` as a monoidal functor: the comparison isomorphisms

For a monoidal functor we need, for each monoidal structure on the source, a
tensor on the target (functors `Type → Type`) and comparison maps. Here:

* `+` ↦ **pointwise coproduct** of functors, `0 ↦ constantly `Empty`;
* `×` ↦ **pointwise product** of functors, `1 ↦ constantly `Unit`;
* `◁` ↦ **composition** of functors, `I ↦ Id` (`Sequential.lean`);
* `⊗` ↦ *no pointwise tensor exists* (`Dirichlet.lean`).

Each comparison below is a genuine isomorphism of types, given by explicit maps
with both round trips proved — `⟦−⟧` is **strong** monoidal, not strict. Following
`Container.seqExt`/`seqExtInv` in `Sequential.lean`, we present each iso as a pair
of maps plus two round-trip theorems rather than bundling it. -/

/-! ## Coproduct: `⟦C + D⟧ X ≅ ⟦C⟧ X ⊕ ⟦D⟧ X` -/

/-- Forward comparison for the coproduct: a `C + D`-structure is a `C`-structure or
a `D`-structure, according to which injection its shape came from. -/
def Container.coprodExt {C D : Container} {X : Type} :
    Ext (C.coprod D) X → Ext C X ⊕ Ext D X :=
  fun p => match p with
    | ⟨Sum.inl s, f⟩ => Sum.inl ⟨s, f⟩
    | ⟨Sum.inr t, f⟩ => Sum.inr ⟨t, f⟩

/-- Backward comparison for the coproduct. -/
def Container.coprodExtInv {C D : Container} {X : Type} :
    Ext C X ⊕ Ext D X → Ext (C.coprod D) X :=
  fun p => match p with
    | Sum.inl q => ⟨Sum.inl q.1, q.2⟩
    | Sum.inr q => ⟨Sum.inr q.1, q.2⟩

theorem Container.coprodExtInv_coprodExt {C D : Container} {X : Type}
    (p : Ext (C.coprod D) X) :
    Container.coprodExtInv (Container.coprodExt p) = p := by
  obtain ⟨s, f⟩ := p
  cases s <;> rfl

theorem Container.coprodExt_coprodExtInv {C D : Container} {X : Type}
    (p : Ext C X ⊕ Ext D X) :
    Container.coprodExt (Container.coprodExtInv p) = p := by
  cases p with
  | inl q => obtain ⟨s, f⟩ := q; rfl
  | inr q => obtain ⟨t, g⟩ := q; rfl

/-- Unit comparison for the coproduct: `⟦0⟧ X ≅ Empty`. There is no shape, so no
structure. -/
def Container.zeroExt {X : Type} : Ext Container.zero X → Empty := fun p => p.1.elim

theorem Container.zeroExt_iso {X : Type} (p : Ext Container.zero X) :
    (Container.zeroExt p).elim = p := p.1.elim

/-! ## Product: `⟦C × D⟧ X ≅ ⟦C⟧ X × ⟦D⟧ X`

**The pleasing cross-check.** The product container's positions are a *sum*,
`P s ⊕ Q t`, and yet its extension is the pointwise *product* of the extensions.
The reason is the exponential law `y^(A+B) ≅ y^A × y^B`: a labelling
`P s ⊕ Q t → X` *is* a pair of labellings `(P s → X, Q t → X)`. Currying the sum
is what turns the position-level `⊕` into a functor-level `×`. The forward map
precomposes with the two injections; the backward map is `Sum.elim`. -/

/-- Forward comparison for the product: split the labelling of `P s ⊕ Q t` along the
two injections. -/
def Container.prodExt {C D : Container} {X : Type} :
    Ext (C.prod D) X → Ext C X × Ext D X :=
  fun p => (⟨p.1.1, fun i => p.2 (Sum.inl i)⟩, ⟨p.1.2, fun j => p.2 (Sum.inr j)⟩)

/-- Backward comparison for the product: pair the shapes, `Sum.elim` the
labellings. -/
def Container.prodExtInv {C D : Container} {X : Type} :
    Ext C X × Ext D X → Ext (C.prod D) X :=
  fun p => ⟨(p.1.1, p.2.1), Sum.elim p.1.2 p.2.2⟩

theorem Container.prodExtInv_prodExt {C D : Container} {X : Type}
    (p : Ext (C.prod D) X) :
    Container.prodExtInv (Container.prodExt p) = p := by
  obtain ⟨⟨s, t⟩, f⟩ := p
  have h : Sum.elim (fun i => f (Sum.inl i)) (fun j => f (Sum.inr j)) = f := by
    funext x; cases x <;> rfl
  show (⟨(s, t), Sum.elim (fun i => f (Sum.inl i)) (fun j => f (Sum.inr j))⟩
        : Ext (C.prod D) X) = ⟨(s, t), f⟩
  rw [h]

theorem Container.prodExt_prodExtInv {C D : Container} {X : Type}
    (p : Ext C X × Ext D X) :
    Container.prodExt (Container.prodExtInv p) = p := by
  obtain ⟨⟨s, f⟩, ⟨t, g⟩⟩ := p
  rfl

/-- Unit comparison for the product: `⟦1⟧ X ≅ Unit`. One shape, no positions, so
exactly one structure. -/
def Container.oneExt {X : Type} : Ext Container.one X → Unit := fun _ => ()

/-- Backward: the unique `1`-structure. -/
def Container.oneExtInv {X : Type} : Unit → Ext Container.one X :=
  fun _ => ⟨(), fun e => e.elim⟩

theorem Container.oneExtInv_oneExt {X : Type} (p : Ext Container.one X) :
    Container.oneExtInv (Container.oneExt p) = p := by
  obtain ⟨u, f⟩ := p
  have h : (fun e : Empty => e.elim) = f := by funext e; exact e.elim
  show (⟨(), fun e : Empty => e.elim⟩ : Ext Container.one X) = ⟨u, f⟩
  rw [h]
  rfl

theorem Container.oneExt_oneExtInv {X : Type} (u : Unit) :
    Container.oneExt (Container.oneExtInv (X := X) u) = u := rfl

/-! ## The shared unit: `⟦y⟧ X ≅ X`

`y = I` is the unit for both `⊗` and `◁`; its extension is the identity functor.
This is the unit comparison for both of those monoidal structures. -/

/-- `⟦y⟧ X ≅ X`, forward: read the label at the unique position. -/
def Container.yExt {X : Type} : Ext Container.y X → X := fun p => p.2 ()

/-- `⟦y⟧ X ≅ X`, backward. -/
def Container.yExtInv {X : Type} : X → Ext Container.y X := fun x => ⟨(), fun _ => x⟩

theorem Container.yExtInv_yExt {X : Type} (p : Ext Container.y X) :
    Container.yExtInv (Container.yExt p) = p := rfl

theorem Container.yExt_yExtInv {X : Type} (x : X) :
    Container.yExt (Container.yExtInv x) = x := rfl

end Containers
