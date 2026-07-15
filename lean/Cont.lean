import Containers.Basic

/-!
# The category `Cont` of containers

This file builds on `Containers.Basic`. It equips containers and their morphisms
(already defined there) with the structure of a **category**, `Cont`.

* **Objects** are containers `S ◁ P` (`Containers.Container`).
* **Morphisms** `(S ◁ P) ⟶ (S' ◁ P')` are `Containers.ContainerMorphism`: a
  forward map on shapes `f : S → S'` together with a *contravariant* map on
  positions `f♯ : (s : S) → P' (f s) → P s`.

The contravariance of the position map is the whole subtlety. It is what makes
the composite's position map run *backwards* and — crucially — it is why the
category laws hold *definitionally*: composing shape maps is ordinary function
composition (associative and unital up to `rfl` thanks to Lean's η for functions
and structures), and the backward position maps inherit associativity and
unitality from it without a single transport. Contrast the directed-container
comonad laws (`Containers.Directed`), where positions live in *different* fibres
and genuine `Sigma` transports appear.

We package the result two ways:

* the bare operations and law lemmas
  (`ContainerMorphism.id`, `ContainerMorphism.comp`, `id_comp`, `comp_id`,
  `assoc`), and
* a small hand-rolled `Category` typeclass with the instance `Cont : Category
  Container`, so "the category of containers" is a single named object. No
  Mathlib dependency — the typeclass mirrors `CategoryTheory.Category` but is
  defined here to keep the development self-contained.

Everything is `Type`-level, Lean 4 core, no Mathlib.
-/

namespace Containers

/-! ## Identity and composition of container morphisms -/

/-- The **identity** container morphism: identity on shapes, identity on
positions. -/
def ContainerMorphism.id (C : Container) : ContainerMorphism C C where
  onShapes := _root_.id
  onPos := fun _ => _root_.id

/-- **Composition** of container morphisms. Shape maps compose *forwards*
(`φ` then `ψ`); position maps compose *backwards* (`ψ`'s pullback then `φ`'s),
matching the contravariance. -/
def ContainerMorphism.comp {C D E : Container}
    (φ : ContainerMorphism C D) (ψ : ContainerMorphism D E) :
    ContainerMorphism C E where
  onShapes := fun s => ψ.onShapes (φ.onShapes s)
  onPos := fun s => φ.onPos s ∘ ψ.onPos (φ.onShapes s)

/-! ## Extensionality for morphisms

Two container morphisms are equal once their shape maps agree and their position
maps agree. Because the position map's *type* depends on the shape map, the
hypothesis on positions is stated with `HEq`; after substituting the shape
equality the two position maps live in the same type and the `HEq` collapses to
an ordinary equality. This is the one place the dependent typing of
`ContainerMorphism` surfaces, so we isolate it here. -/
theorem ContainerMorphism.ext {C D : Container} :
    ∀ {φ ψ : ContainerMorphism C D},
      φ.onShapes = ψ.onShapes → HEq φ.onPos ψ.onPos → φ = ψ
  | ⟨_, _⟩, ⟨_, _⟩, hs, hp => by
    cases hs
    cases hp
    rfl

/-- A `HEq`-free extensionality principle, more convenient when the position
maps are compared pointwise. Given that the shape maps agree (`hs`), two
morphisms are equal once their position maps agree after transporting the
`D`-position along `hs`. Because Lean has definitional proof irrelevance, when
the shape maps agree *definitionally* the transport `congrFun hs s ▸ p` is
defeq to `p`, so the hypothesis discharges by `rfl`. -/
theorem ContainerMorphism.ext' {C D : Container} :
    ∀ {φ ψ : ContainerMorphism C D} (hs : φ.onShapes = ψ.onShapes),
      (∀ s p, φ.onPos s p = ψ.onPos s (congrFun hs s ▸ p)) → φ = ψ
  | ⟨_, fp⟩, ⟨_, gp⟩, hs, hp => by
    cases hs
    have : fp = gp := funext fun s => funext fun p => hp s p
    cases this
    rfl

/-! ## The category laws

All three hold by `rfl`: with the variance set up correctly, the underlying
shape-map operations are ordinary function `id`/`∘`, which are unital and
associative definitionally, and the backward position maps follow suit. No
transports, no `Ext.ext_eq`. -/

/-- **Left unit law**: `id ≫ φ = φ`. -/
theorem ContainerMorphism.id_comp {C D : Container} (φ : ContainerMorphism C D) :
    (ContainerMorphism.id C).comp φ = φ := rfl

/-- **Right unit law**: `φ ≫ id = φ`. -/
theorem ContainerMorphism.comp_id {C D : Container} (φ : ContainerMorphism C D) :
    φ.comp (ContainerMorphism.id D) = φ := rfl

/-- **Associativity**: `(φ ≫ ψ) ≫ χ = φ ≫ (ψ ≫ χ)`. -/
theorem ContainerMorphism.comp_assoc {C D E F : Container}
    (φ : ContainerMorphism C D) (ψ : ContainerMorphism D E)
    (χ : ContainerMorphism E F) :
    (φ.comp ψ).comp χ = φ.comp (ψ.comp χ) := rfl

/-! ## Packaging: `Cont` as a `Category`

A minimal category typeclass (Mathlib-free), and the instance witnessing that
containers and container morphisms form a category. -/

universe u v

/-- A minimal, self-contained category typeclass, mirroring
`CategoryTheory.Category`: a `Hom`-family on objects with composition, identities,
and the unit and associativity laws. -/
class Category (Obj : Type u) where
  /-- Morphisms between two objects. -/
  Hom : Obj → Obj → Type v
  /-- The identity morphism on an object. -/
  id : (X : Obj) → Hom X X
  /-- Composition of morphisms (diagrammatic order: `comp f g` is "`f` then `g`"). -/
  comp : {X Y Z : Obj} → Hom X Y → Hom Y Z → Hom X Z
  /-- Left unit law. -/
  id_comp : ∀ {X Y : Obj} (f : Hom X Y), comp (id X) f = f
  /-- Right unit law. -/
  comp_id : ∀ {X Y : Obj} (f : Hom X Y), comp f (id Y) = f
  /-- Associativity. -/
  assoc : ∀ {W X Y Z : Obj} (f : Hom W X) (g : Hom X Y) (h : Hom Y Z),
    comp (comp f g) h = comp f (comp g h)

/-- **The category of containers.** Objects are containers, morphisms are
container morphisms, with the identity and composition defined above; the three
laws hold by `rfl`. -/
instance Cont : Category Container where
  Hom := ContainerMorphism
  id := ContainerMorphism.id
  comp := ContainerMorphism.comp
  id_comp := ContainerMorphism.id_comp
  comp_id := ContainerMorphism.comp_id
  assoc := ContainerMorphism.comp_assoc

/-! ## The coproduct of two containers

`Cont` has binary coproducts. The coproduct of `C = S ◁ P` and `D = T ◁ Q` has
shape type `S ⊕ T` and positions given case-wise: an `inl s`-shape has positions
`P s`, an `inr t`-shape has positions `Q t`. The injections are identity-on-
positions; the copairing of `φ : C ⟶ E` and `ψ : D ⟶ E` dispatches on the shape.

This serves the book's Chapter 3 (the algebra of container constructors). -/

/-- The **coproduct** container `C ⊕ D`: shapes `S ⊕ T`, positions case-wise. -/
def Container.coprod (C D : Container) : Container where
  Shape := C.Shape ⊕ D.Shape
  Pos := Sum.elim C.Pos D.Pos

/-- Left **injection** `C ⟶ C ⊕ D`: `Sum.inl` on shapes, identity on positions
(the positions of an `inl`-shape *are* the `C`-positions). -/
def Container.inl (C D : Container) : ContainerMorphism C (C.coprod D) where
  onShapes := Sum.inl
  onPos := fun _ => _root_.id

/-- Right **injection** `D ⟶ C ⊕ D`. -/
def Container.inr (C D : Container) : ContainerMorphism D (C.coprod D) where
  onShapes := Sum.inr
  onPos := fun _ => _root_.id

/-- The **copairing** `[φ, ψ] : C ⊕ D ⟶ E` of `φ : C ⟶ E` and `ψ : D ⟶ E`:
dispatch on the shape, using `φ` on `inl`-shapes and `ψ` on `inr`-shapes. -/
def ContainerMorphism.desc {C D E : Container}
    (φ : ContainerMorphism C E) (ψ : ContainerMorphism D E) :
    ContainerMorphism (C.coprod D) E where
  onShapes := Sum.elim φ.onShapes ψ.onShapes
  onPos := fun s => match s with
    | Sum.inl s => φ.onPos s
    | Sum.inr s => ψ.onPos s

/-- **Computation rule (left)**: `inl ≫ [φ, ψ] = φ`. Holds by `rfl`. -/
theorem ContainerMorphism.inl_desc {C D E : Container}
    (φ : ContainerMorphism C E) (ψ : ContainerMorphism D E) :
    (Container.inl C D).comp (φ.desc ψ) = φ := rfl

/-- **Computation rule (right)**: `inr ≫ [φ, ψ] = ψ`. Holds by `rfl`. -/
theorem ContainerMorphism.inr_desc {C D E : Container}
    (φ : ContainerMorphism C E) (ψ : ContainerMorphism D E) :
    (Container.inr C D).comp (φ.desc ψ) = ψ := rfl

/-- **Uniqueness / η-rule for the coproduct**: every morphism out of `C ⊕ D` is
the copairing of its restrictions along the injections. Together with the two
computation rules this is the full universal property: `Hom (C ⊕ D) E ≃
Hom C E × Hom D E` naturally. -/
theorem ContainerMorphism.desc_eta {C D E : Container}
    (χ : ContainerMorphism (C.coprod D) E) :
    ((Container.inl C D).comp χ).desc ((Container.inr C D).comp χ) = χ := by
  refine ContainerMorphism.ext' ?_ ?_
  · funext s; cases s <;> rfl
  · -- The position maps agree case-wise; the dependent `match` is handled by
    -- casing on the shape, and each branch is `rfl` (the transport is trivial
    -- by proof irrelevance, since the shape maps already agree definitionally).
    intro s p; cases s <;> rfl

/-- The universal property as an explicit statement: for every cocone `(φ, ψ)`
there is a *unique* `χ` mediating it. Existence is `desc`; the computation rules
and `desc_eta` give uniqueness. -/
theorem ContainerMorphism.desc_unique {C D E : Container}
    (φ : ContainerMorphism C E) (ψ : ContainerMorphism D E)
    (χ : ContainerMorphism (C.coprod D) E)
    (h₁ : (Container.inl C D).comp χ = φ) (h₂ : (Container.inr C D).comp χ = ψ) :
    χ = φ.desc ψ := by
  subst h₁; subst h₂
  exact (ContainerMorphism.desc_eta χ).symm

/-! ## The product of two containers

`Cont` also has binary products, dual to the coproduct above. The product of
`C = S ◁ P` and `D = T ◁ Q` has shape type `S × T` and positions given by the
*sum* of position sets: a `(s, t)`-shape has positions `P s ⊕ Q t`. This is the
categorical product of the underlying polynomials — note the positions are a
*coproduct*, `P s ⊕ Q t`, not a product `P s × Q t`.

The variance is the teaching point dual to the coproduct's. There the
injections were identity-on-positions; here the *projections* `π₁`, `π₂` carry a
coproduct **injection backward** on positions: `π₁ : C × D ⟶ C` sends a
`C`-position `P s` forward into the larger position set `P s ⊕ Q t` via
`Sum.inl`. The pairing `⟨f, g⟩` then case-splits a `P s ⊕ Q t` position with
`Sum.elim`.

This completes the book's Chapter 3 (products and coproducts of containers). -/

/-- The **product** container `C × D`: shapes `S × T`, positions `P s ⊕ Q t`
(the coproduct of position sets — this is the product of polynomials). -/
def Container.prod (C D : Container) : Container where
  Shape := C.Shape × D.Shape
  Pos := fun st => C.Pos st.1 ⊕ D.Pos st.2

/-- First **projection** `C × D ⟶ C`: `Prod.fst` on shapes; on positions it
carries a `C`-position forward into `P s ⊕ Q t` via the coproduct injection
`Sum.inl` (the backward position map of the projection). -/
def Container.fst (C D : Container) : ContainerMorphism (C.prod D) C where
  onShapes := Prod.fst
  onPos := fun _ => Sum.inl

/-- Second **projection** `C × D ⟶ D`, via `Sum.inr` on positions. -/
def Container.snd (C D : Container) : ContainerMorphism (C.prod D) D where
  onShapes := Prod.snd
  onPos := fun _ => Sum.inr

/-- The **pairing** `⟨f, g⟩ : R ⟶ C × D` of `f : R ⟶ C` and `g : R ⟶ D`: pair
the shape maps; on positions, `Sum.elim` dispatches a `P s ⊕ Q t` position to
`f`'s or `g`'s backward map. -/
def ContainerMorphism.pair {R C D : Container}
    (f : ContainerMorphism R C) (g : ContainerMorphism R D) :
    ContainerMorphism R (C.prod D) where
  onShapes := fun r => (f.onShapes r, g.onShapes r)
  onPos := fun r => Sum.elim (f.onPos r) (g.onPos r)

/-- **Computation rule (left)**: `⟨f, g⟩ ≫ π₁ = f`. Holds by `rfl`. -/
theorem ContainerMorphism.pair_fst {R C D : Container}
    (f : ContainerMorphism R C) (g : ContainerMorphism R D) :
    (f.pair g).comp (Container.fst C D) = f := rfl

/-- **Computation rule (right)**: `⟨f, g⟩ ≫ π₂ = g`. Holds by `rfl`. -/
theorem ContainerMorphism.pair_snd {R C D : Container}
    (f : ContainerMorphism R C) (g : ContainerMorphism R D) :
    (f.pair g).comp (Container.snd C D) = g := rfl

/-- **Uniqueness / η-rule for the product**: every morphism into `C × D` is the
pairing of its composites with the projections. Together with the two
computation rules this is the full universal property: `Hom R (C × D) ≃
Hom R C × Hom R D` naturally. -/
theorem ContainerMorphism.pair_eta {R C D : Container}
    (χ : ContainerMorphism R (C.prod D)) :
    (χ.comp (Container.fst C D)).pair (χ.comp (Container.snd C D)) = χ := by
  refine ContainerMorphism.ext' ?_ ?_
  · -- Shape maps agree by `Prod` structure η: `(fst (χ s), snd (χ s)) = χ s`.
    funext s; rfl
  · -- Positions agree case-wise. A `Sum.inl`/`Sum.inr` position is dispatched by
    -- `Sum.elim` back to the corresponding component of `χ.onPos`; each branch is
    -- `rfl` (the transport is trivial, the shape maps agreeing definitionally).
    intro s p; cases p <;> rfl

/-- The universal property as an explicit statement: for every cone `(f, g)`
there is a *unique* `χ` mediating it. Existence is `pair`; the computation rules
and `pair_eta` give uniqueness. -/
theorem ContainerMorphism.pair_unique {R C D : Container}
    (f : ContainerMorphism R C) (g : ContainerMorphism R D)
    (χ : ContainerMorphism R (C.prod D))
    (h₁ : χ.comp (Container.fst C D) = f) (h₂ : χ.comp (Container.snd C D) = g) :
    χ = f.pair g := by
  subst h₁; subst h₂
  exact (ContainerMorphism.pair_eta χ).symm

end Containers
