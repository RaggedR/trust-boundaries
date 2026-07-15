import Containers.Sequential

/-!
# `(Cont, ◁, I)` is a monoidal category

This file builds on `Containers.Sequential`, which equips the category `Cont`
(from `Containers.Cont`) with the **sequential operator** `◁`, the unit
container `I`, and the structural isomorphisms — left/right unitors and the
associator — all *transport-free*. What was missing to certify
`(Cont, ◁, I)` as a genuine **monoidal category** are the bifunctoriality of
`◁` on morphisms and the two coherence laws, the **pentagon** and the
**triangle**. This file supplies them and assembles the whole into a
machine-checked monoidal-category instance.

The remaining structural ingredient is the *bifunctoriality* of `◁`: its action
`Container.seq₂` on a pair of morphisms, from which the two **whiskerings**
`G ◁ ν` and `μ ◁ F` are special cases (whiskering by an identity). Like
everything in `Sequential.lean`, the action is transport-free — the position
fibres line up definitionally — so the bifunctor laws, the naturality squares,
the pentagon, and the triangle all hold by `rfl` (structure/`Sigma`/`Unit` η
once the data is laid bare).

Mathematically (companion write-up
`proofs/2026-06-13-monoidal-coherence-four-structures.tex`) the associator's
shape map is *currying* and its position map is *Σ-reassociation*; both pentagon
legs equal a single *flattening* of the fourfold composite
`((C₁ ◁ C₂) ◁ C₃) ◁ C₄` to its bracket-free normal form
`C₁ ◁ (C₂ ◁ (C₃ ◁ C₄))`, and on positions every map is the identity on the
underlying flat tuple. In Lean this is witnessed by the proofs reducing to `rfl`.

We package the structure into a small, self-contained `MonoidalCategory`
typeclass (extending `Containers.Category` from `Cont.lean`; Mathlib-free, and
reusable for the other three monoidal structures on `Cont`) and produce the
instance `ContMonoidal`.

Everything is `Type`-level, Lean 4 core, no Mathlib — matching the rest of the
development.
-/

namespace Containers

universe u v

/-! ## Bifunctoriality of `◁` on morphisms

`◁` is a functor `Cont × Cont ⟶ Cont`. Its action on a pair of morphisms
`μ : G ⟶ G'` and `ν : F ⟶ F'` produces `G ◁ F ⟶ G' ◁ F'`. On shapes it sends an
outer shape and inner-shape assignment `(t, f)` to `(μ t, ν ∘ f ∘ μ♯)`; on
positions it runs both backward position maps. As ever, the fibres agree
definitionally, so no transport appears. -/

/-- The **action of `◁` on a pair of morphisms** (its bifunctoriality):
`seq₂ μ ν : G ◁ F ⟶ G' ◁ F'` for `μ : G ⟶ G'` and `ν : F ⟶ F'`. -/
def Container.seq₂ {G G' F F' : Container}
    (μ : ContainerMorphism G G') (ν : ContainerMorphism F F') :
    ContainerMorphism (G ◁ F) (G' ◁ F') where
  onShapes := fun tf => ⟨μ.onShapes tf.1, fun q' => ν.onShapes (tf.2 (μ.onPos tf.1 q'))⟩
  onPos := fun tf qr => ⟨μ.onPos tf.1 qr.1, ν.onPos (tf.2 (μ.onPos tf.1 qr.1)) qr.2⟩

/-- **Left whiskering** `G ◁ ν : G ◁ F ⟶ G ◁ F'`: act by `ν` on the inner
container, leaving the outer container `G` fixed. -/
def Container.whiskerLeft (G : Container) {F F' : Container}
    (ν : ContainerMorphism F F') : ContainerMorphism (G ◁ F) (G ◁ F') :=
  Container.seq₂ (ContainerMorphism.id G) ν

/-- **Right whiskering** `μ ◁ F : G ◁ F ⟶ G' ◁ F`: act by `μ` on the outer
container, leaving the inner container `F` fixed. -/
def Container.whiskerRight {G G' : Container} (μ : ContainerMorphism G G')
    (F : Container) : ContainerMorphism (G ◁ F) (G' ◁ F) :=
  Container.seq₂ μ (ContainerMorphism.id F)

/-- `seq₂` preserves identities: `seq₂ id id = id`. -/
theorem Container.seq₂_id (G F : Container) :
    Container.seq₂ (ContainerMorphism.id G) (ContainerMorphism.id F)
      = ContainerMorphism.id (G ◁ F) := rfl

/-- `seq₂` preserves composition (interchange / bifunctoriality):
`seq₂ (μ ≫ μ') (ν ≫ ν') = seq₂ μ ν ≫ seq₂ μ' ν'`. -/
theorem Container.seq₂_comp {G G' G'' F F' F'' : Container}
    (μ : ContainerMorphism G G') (μ' : ContainerMorphism G' G'')
    (ν : ContainerMorphism F F') (ν' : ContainerMorphism F' F'') :
    Container.seq₂ (μ.comp μ') (ν.comp ν')
      = (Container.seq₂ μ ν).comp (Container.seq₂ μ' ν') := rfl

/-! ## Naturality of the structural isomorphisms

The associator and the two unitors are *natural* in their arguments. Each square
holds by `rfl`: the maps in play are currying/Σ-reassociation on one side and
the same on the other, with the morphism data threaded identically. -/

/-- **Naturality of the associator**: `α` is natural in all three arguments. -/
theorem Container.associator_naturality {X₁ Y₁ X₂ Y₂ X₃ Y₃ : Container}
    (f₁ : ContainerMorphism X₁ Y₁) (f₂ : ContainerMorphism X₂ Y₂)
    (f₃ : ContainerMorphism X₃ Y₃) :
    (Container.seq₂ (Container.seq₂ f₁ f₂) f₃).comp (Container.associator Y₁ Y₂ Y₃).hom
      = (Container.associator X₁ X₂ X₃).hom.comp (Container.seq₂ f₁ (Container.seq₂ f₂ f₃)) :=
  rfl

/-- **Naturality of the left unitor**: `λ` is natural. -/
theorem Container.leftUnitor_naturality {X Y : Container} (f : ContainerMorphism X Y) :
    (Container.whiskerLeft Container.I f).comp (Container.leftUnitor Y).hom
      = (Container.leftUnitor X).hom.comp f := rfl

/-- **Naturality of the right unitor**: `ρ` is natural. -/
theorem Container.rightUnitor_naturality {X Y : Container} (f : ContainerMorphism X Y) :
    (Container.whiskerRight f Container.I).comp (Container.rightUnitor Y).hom
      = (Container.rightUnitor X).hom.comp f := rfl

/-! ## The pentagon

For all `C₁, C₂, C₃, C₄`, the two associator paths around the pentagon agree.
Reading composition diagrammatically (`φ.comp ψ` is "`φ` then `ψ`"), the long leg
is `(α₁₂₃ ◁ C₄) ≫ α₁,₂₃,₄ ≫ (C₁ ◁ α₂₃₄)` and the short leg is
`α₁₂,₃,₄ ≫ α₁,₂,₃₄`. Both flatten `((C₁ ◁ C₂) ◁ C₃) ◁ C₄` to the right-nested
normal form `C₁ ◁ (C₂ ◁ (C₃ ◁ C₄))`. -/

/-- **Pentagon identity** for the sequential operator. The two ways of
re-associating `((C₁ ◁ C₂) ◁ C₃) ◁ C₄` to `C₁ ◁ (C₂ ◁ (C₃ ◁ C₄))` coincide.
Transport-free, so it closes by `rfl`. -/
theorem Container.pentagon (C₁ C₂ C₃ C₄ : Container) :
    ((Container.whiskerRight (Container.associator C₁ C₂ C₃).hom C₄).comp
        (Container.associator C₁ (C₂ ◁ C₃) C₄).hom).comp
        (Container.whiskerLeft C₁ (Container.associator C₂ C₃ C₄).hom)
      = (Container.associator (C₁ ◁ C₂) C₃ C₄).hom.comp
        (Container.associator C₁ C₂ (C₃ ◁ C₄)).hom := rfl

/-! ## The triangle

For all `C₁, C₂`, the associator through the unit composed with the inner left
unitor equals the outer right unitor whiskered by `C₂`. -/

/-- **Triangle identity** for the sequential operator:
`α_{C₁, I, C₂} ≫ (C₁ ◁ λ_{C₂}) = ρ_{C₁} ◁ C₂`, as morphisms
`(C₁ ◁ I) ◁ C₂ ⟶ C₁ ◁ C₂`. Transport-free, so it closes by `rfl`. -/
theorem Container.triangle (C₁ C₂ : Container) :
    (Container.associator C₁ Container.I C₂).hom.comp
        (Container.whiskerLeft C₁ (Container.leftUnitor C₂).hom)
      = Container.whiskerRight (Container.rightUnitor C₁).hom C₂ := rfl

/-! ## Packaging: a monoidal category

A minimal, self-contained `MonoidalCategory` typeclass mirroring the style of
`Containers.Category` (no Mathlib). It extends `Category` with a tensor functor
(an object map `tensorObj` and a morphism map `tensorHom` satisfying the two
functor laws), a unit object, the associator and unitors as isomorphisms,
their naturality squares, and the pentagon and triangle coherences. The instance
`ContMonoidal` witnesses `(Cont, ◁, I)` as a monoidal category, every field
discharged by the results above. -/

/-- An **isomorphism** in a hand-rolled `Category`: a morphism with a two-sided
inverse. (The bundled-isomorphism counterpart of `ContainerIso`, generic over
any `Category`.) -/
structure CatIso {Obj : Type u} [Category Obj] (X Y : Obj) where
  /-- The forward morphism. -/
  hom : Category.Hom X Y
  /-- The backward morphism. -/
  inv : Category.Hom Y X
  /-- `hom` then `inv` is the identity. -/
  hom_inv_id : Category.comp hom inv = Category.id X
  /-- `inv` then `hom` is the identity. -/
  inv_hom_id : Category.comp inv hom = Category.id Y

/-- A minimal, self-contained **monoidal category** typeclass (Mathlib-free),
extending `Containers.Category`. The tensor is given by an object map `tensorObj`
and a bifunctorial morphism map `tensorHom`; the associator and unitors are
`CatIso`s; the coherence data are the naturality squares together with the
pentagon and triangle. -/
class MonoidalCategory (Obj : Type u) extends Category.{u, v} Obj where
  /-- The tensor product on objects. -/
  tensorObj : Obj → Obj → Obj
  /-- The tensor product on morphisms (the bifunctor's action on a pair). -/
  tensorHom : {X₁ Y₁ X₂ Y₂ : Obj} →
    Hom X₁ Y₁ → Hom X₂ Y₂ → Hom (tensorObj X₁ X₂) (tensorObj Y₁ Y₂)
  /-- The tensor preserves identities. -/
  tensorHom_id : ∀ (X Y : Obj), tensorHom (id X) (id Y) = id (tensorObj X Y)
  /-- The tensor preserves composition (interchange). -/
  tensorHom_comp : ∀ {X₁ Y₁ Z₁ X₂ Y₂ Z₂ : Obj}
    (f₁ : Hom X₁ Y₁) (g₁ : Hom Y₁ Z₁) (f₂ : Hom X₂ Y₂) (g₂ : Hom Y₂ Z₂),
    tensorHom (comp f₁ g₁) (comp f₂ g₂) = comp (tensorHom f₁ f₂) (tensorHom g₁ g₂)
  /-- The unit object. -/
  tensorUnit : Obj
  /-- The associator isomorphism. -/
  associator : (X Y Z : Obj) →
    CatIso (tensorObj (tensorObj X Y) Z) (tensorObj X (tensorObj Y Z))
  /-- The left unitor isomorphism. -/
  leftUnitor : (X : Obj) → CatIso (tensorObj tensorUnit X) X
  /-- The right unitor isomorphism. -/
  rightUnitor : (X : Obj) → CatIso (tensorObj X tensorUnit) X
  /-- Naturality of the associator. -/
  associator_naturality : ∀ {X₁ Y₁ X₂ Y₂ X₃ Y₃ : Obj}
    (f₁ : Hom X₁ Y₁) (f₂ : Hom X₂ Y₂) (f₃ : Hom X₃ Y₃),
    comp (tensorHom (tensorHom f₁ f₂) f₃) (associator Y₁ Y₂ Y₃).hom
      = comp (associator X₁ X₂ X₃).hom (tensorHom f₁ (tensorHom f₂ f₃))
  /-- Naturality of the left unitor. -/
  leftUnitor_naturality : ∀ {X Y : Obj} (f : Hom X Y),
    comp (tensorHom (id tensorUnit) f) (leftUnitor Y).hom = comp (leftUnitor X).hom f
  /-- Naturality of the right unitor. -/
  rightUnitor_naturality : ∀ {X Y : Obj} (f : Hom X Y),
    comp (tensorHom f (id tensorUnit)) (rightUnitor Y).hom = comp (rightUnitor X).hom f
  /-- The **pentagon** coherence law. -/
  pentagon : ∀ (W X Y Z : Obj),
    comp (comp (tensorHom (associator W X Y).hom (id Z))
               (associator W (tensorObj X Y) Z).hom)
         (tensorHom (id W) (associator X Y Z).hom)
      = comp (associator (tensorObj W X) Y Z).hom (associator W X (tensorObj Y Z)).hom
  /-- The **triangle** coherence law. -/
  triangle : ∀ (X Y : Obj),
    comp (associator X tensorUnit Y).hom (tensorHom (id X) (leftUnitor Y).hom)
      = tensorHom (rightUnitor X).hom (id Y)

/-- Reinterpret a `ContainerIso` as a generic `CatIso` for the category `Cont`.
The fields coincide definitionally (`Cont`'s `comp`/`id` *are*
`ContainerMorphism.comp`/`id`). -/
def ContainerIso.toCatIso {C D : Container} (i : ContainerIso C D) : CatIso C D :=
  ⟨i.hom, i.inv, i.hom_inv, i.inv_hom⟩

/-- **`(Cont, ◁, I)` is a monoidal category.** The tensor is the sequential
operator `◁` with morphism action `seq₂`; the unit is the identity container
`I`; the associator and unitors are the isomorphisms from `Sequential.lean`.
Every law — the two functor laws, the three naturality squares, the pentagon and
the triangle — holds by `rfl`, so the instance is transport-free and
axiom-clean. -/
instance ContMonoidal : MonoidalCategory Container where
  tensorObj := Container.seq
  tensorHom := Container.seq₂
  tensorHom_id := Container.seq₂_id
  tensorHom_comp := fun f₁ g₁ f₂ g₂ => Container.seq₂_comp f₁ g₁ f₂ g₂
  tensorUnit := Container.I
  associator := fun X Y Z => (Container.associator X Y Z).toCatIso
  leftUnitor := fun X => (Container.leftUnitor X).toCatIso
  rightUnitor := fun X => (Container.rightUnitor X).toCatIso
  associator_naturality := fun f₁ f₂ f₃ => Container.associator_naturality f₁ f₂ f₃
  leftUnitor_naturality := fun f => Container.leftUnitor_naturality f
  rightUnitor_naturality := fun f => Container.rightUnitor_naturality f
  pentagon := Container.pentagon
  triangle := Container.triangle

end Containers
