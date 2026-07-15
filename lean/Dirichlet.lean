import Containers.Monoidal

/-!
# The Dirichlet tensor `(Cont, ⊗, y)`

This file adds the third of the four monoidal structures on `Cont` (the fourth,
the sequential operator `◁`, is in `Containers.Monoidal`; the product and
coproduct ones are in `Containers.FourMonoidal`).

For `C = S ◁ P` and `D = T ◁ Q` the **Dirichlet tensor** is

  `C ⊗ D = (S × T) ◁ (fun (s, t) => P s × Q t)`.

Contrast the *categorical product* of containers (`Container.prod`, `Cont.lean`):

  `C × D = (S × T) ◁ (fun (s, t) => P s ⊕ Q t)`.

The shapes agree; the **positions** are the coproduct `P s ⊕ Q t` for the product
and the product `P s × Q t` for the Dirichlet tensor. That single swap is the
heart of the chapter: on extensions it is the difference between

  `⟦C × D⟧ X = Σ (s,t), X^(P s + Q t) = ⟦C⟧ X × ⟦D⟧ X`   (a pointwise product), and
  `⟦C ⊗ D⟧ X = Σ (s,t), X^(P s × Q t) = Σ (s,t), (X^(P s))^(Q t)`,

the first pointwise because the exponential law `y^(A+B) ≅ y^A × y^B` splits the
positions, the second *not* pointwise because `y^(A×B)` admits no such splitting
(witness: `y³ ⊗ y³ = y⁹`, while anything pointwise would give `y⁶`). See the
taxonomy at the end of this file.

The unit is `y = Unit ◁ (fun _ => Unit)`, i.e. **the same container `I`** that is
the unit for `◁`. (`y ⊗ C` has shapes `Unit × S` and positions `Unit × P s`: two
`Unit`-collapses.) Two of the four monoidal structures on `Cont` share a unit;
this is not an accident — both `◁` and `⊗` restrict to the *identity* on the
one-shape/one-position container.

Everything is `Type`-level, Lean 4 core, no Mathlib.
-/

namespace Containers

universe u v

/-! ## The tensor and its unit -/

/-- The **Dirichlet tensor** `C ⊗ D`: shapes `S × T`, positions `P s × Q t`.
Note the positions are a *product* — this is exactly what distinguishes `⊗` from
the categorical product `Container.prod`, whose positions are the *coproduct*
`P s ⊕ Q t`. -/
def Container.dirichlet (C D : Container) : Container where
  Shape := C.Shape × D.Shape
  Pos := fun st => C.Pos st.1 × D.Pos st.2

@[inherit_doc] scoped infixr:70 " ⊗ " => Container.dirichlet

/-- The unit for the Dirichlet tensor, `y = Unit ◁ (fun _ => Unit)`. It is *the
same container* as the unit `I` for the sequential operator `◁`; we give it the
`Poly`-style name `y` because in the Dirichlet setting it is read as the
representable `y¹`. -/
abbrev Container.y : Container := Container.I

/-! ## Bifunctoriality

`⊗` is a functor `Cont × Cont ⟶ Cont`. Unlike `◁`, whose morphism action has to
thread the outer backward position map through the inner shape assignment, the
Dirichlet action is *componentwise*: shapes forward in each coordinate, positions
backward in each coordinate. Hence the functor laws are `rfl`. -/

/-- The **action of `⊗` on a pair of morphisms**: `dir₂ μ ν : C ⊗ D ⟶ C' ⊗ D'`.
Componentwise in both coordinates. -/
def Container.dir₂ {C C' D D' : Container}
    (μ : ContainerMorphism C C') (ν : ContainerMorphism D D') :
    ContainerMorphism (C ⊗ D) (C' ⊗ D') where
  onShapes := fun st => (μ.onShapes st.1, ν.onShapes st.2)
  onPos := fun st pq => (μ.onPos st.1 pq.1, ν.onPos st.2 pq.2)

/-- `dir₂` preserves identities. -/
theorem Container.dir₂_id (C D : Container) :
    Container.dir₂ (ContainerMorphism.id C) (ContainerMorphism.id D)
      = ContainerMorphism.id (C ⊗ D) := rfl

/-- `dir₂` preserves composition (interchange / bifunctoriality). -/
theorem Container.dir₂_comp {C C' C'' D D' D'' : Container}
    (μ : ContainerMorphism C C') (μ' : ContainerMorphism C' C'')
    (ν : ContainerMorphism D D') (ν' : ContainerMorphism D' D'') :
    Container.dir₂ (μ.comp μ') (ν.comp ν')
      = (Container.dir₂ μ ν).comp (Container.dir₂ μ' ν') := rfl

/-! ## Structural isomorphisms

The associator is `Prod`-reassociation on shapes *and* on positions (the latter
run backwards, but `Prod` reassociation is its own mirror image). The unitors are
`Unit`-collapses in both components. Every round trip holds by `rfl`, thanks to
definitional η for `Prod` and `Unit`. -/

/-- The **associator** `(C ⊗ D) ⊗ E ≅ C ⊗ (D ⊗ E)`: `Prod`-reassociation on
shapes and (backwards) on positions. Transport-free. -/
def Container.dirAssociator (C D E : Container) :
    ContainerIso ((C ⊗ D) ⊗ E) (C ⊗ (D ⊗ E)) where
  hom :=
    { onShapes := fun x => (x.1.1, (x.1.2, x.2))
      onPos := fun _ p => ((p.1, p.2.1), p.2.2) }
  inv :=
    { onShapes := fun x => ((x.1, x.2.1), x.2.2)
      onPos := fun _ p => (p.1.1, (p.1.2, p.2)) }
  hom_inv := rfl
  inv_hom := rfl

/-- The **left unitor** `y ⊗ C ≅ C`. -/
def Container.dirLeftUnitor (C : Container) : ContainerIso (Container.y ⊗ C) C where
  hom :=
    { onShapes := fun x => x.2
      onPos := fun _ p => ((), p) }
  inv :=
    { onShapes := fun s => ((), s)
      onPos := fun _ p => p.2 }
  hom_inv := rfl
  inv_hom := rfl

/-- The **right unitor** `C ⊗ y ≅ C`. -/
def Container.dirRightUnitor (C : Container) : ContainerIso (C ⊗ Container.y) C where
  hom :=
    { onShapes := fun x => x.1
      onPos := fun _ p => (p, ()) }
  inv :=
    { onShapes := fun s => (s, ())
      onPos := fun _ p => p.1 }
  hom_inv := rfl
  inv_hom := rfl

/-! ## Naturality and coherence

All three naturality squares, the pentagon and the triangle hold by `rfl`: every
map in sight is a `Prod`/`Unit` shuffle, and Lean's definitional η for structures
identifies the two legs on the nose. -/

/-- **Naturality of the Dirichlet associator.** -/
theorem Container.dirAssociator_naturality {X₁ Y₁ X₂ Y₂ X₃ Y₃ : Container}
    (f₁ : ContainerMorphism X₁ Y₁) (f₂ : ContainerMorphism X₂ Y₂)
    (f₃ : ContainerMorphism X₃ Y₃) :
    (Container.dir₂ (Container.dir₂ f₁ f₂) f₃).comp (Container.dirAssociator Y₁ Y₂ Y₃).hom
      = (Container.dirAssociator X₁ X₂ X₃).hom.comp
          (Container.dir₂ f₁ (Container.dir₂ f₂ f₃)) := rfl

/-- **Naturality of the Dirichlet left unitor.** -/
theorem Container.dirLeftUnitor_naturality {X Y : Container} (f : ContainerMorphism X Y) :
    (Container.dir₂ (ContainerMorphism.id Container.y) f).comp
        (Container.dirLeftUnitor Y).hom
      = (Container.dirLeftUnitor X).hom.comp f := rfl

/-- **Naturality of the Dirichlet right unitor.** -/
theorem Container.dirRightUnitor_naturality {X Y : Container} (f : ContainerMorphism X Y) :
    (Container.dir₂ f (ContainerMorphism.id Container.y)).comp
        (Container.dirRightUnitor Y).hom
      = (Container.dirRightUnitor X).hom.comp f := rfl

/-- **Pentagon** for the Dirichlet tensor. -/
theorem Container.dirPentagon (C₁ C₂ C₃ C₄ : Container) :
    ((Container.dir₂ (Container.dirAssociator C₁ C₂ C₃).hom (ContainerMorphism.id C₄)).comp
        (Container.dirAssociator C₁ (C₂ ⊗ C₃) C₄).hom).comp
        (Container.dir₂ (ContainerMorphism.id C₁) (Container.dirAssociator C₂ C₃ C₄).hom)
      = (Container.dirAssociator (C₁ ⊗ C₂) C₃ C₄).hom.comp
          (Container.dirAssociator C₁ C₂ (C₃ ⊗ C₄)).hom := rfl

/-- **Triangle** for the Dirichlet tensor. -/
theorem Container.dirTriangle (C₁ C₂ : Container) :
    (Container.dirAssociator C₁ Container.y C₂).hom.comp
        (Container.dir₂ (ContainerMorphism.id C₁) (Container.dirLeftUnitor C₂).hom)
      = Container.dir₂ (Container.dirRightUnitor C₁).hom (ContainerMorphism.id C₂) := rfl

/-! ## `(Cont, ⊗, y)` is a monoidal category

Declared as a **`def`, not an `instance`**: `Cont` carries (at least) *four*
monoidal structures — `◁`, `⊗`, `×`, `+` — so at most one of them can be the
canonical `MonoidalCategory Container` instance without wrecking instance
resolution. The canonical instance is `ContMonoidal` (the sequential operator
`◁`, the spine of the development); the other three are named `def`s, to be used
explicitly. That four structures live on one category is the mathematical point,
and this is how the code says it. -/

/-- **`(Cont, ⊗, y)` is a monoidal category.** Every law holds by `rfl`. -/
@[reducible] def contDirichletMonoidal : MonoidalCategory Container where
  tensorObj := Container.dirichlet
  tensorHom := Container.dir₂
  tensorHom_id := Container.dir₂_id
  tensorHom_comp := fun f₁ g₁ f₂ g₂ => Container.dir₂_comp f₁ g₁ f₂ g₂
  tensorUnit := Container.y
  associator := fun X Y Z => (Container.dirAssociator X Y Z).toCatIso
  leftUnitor := fun X => (Container.dirLeftUnitor X).toCatIso
  rightUnitor := fun X => (Container.dirRightUnitor X).toCatIso
  associator_naturality := fun f₁ f₂ f₃ => Container.dirAssociator_naturality f₁ f₂ f₃
  leftUnitor_naturality := fun f => Container.dirLeftUnitor_naturality f
  rightUnitor_naturality := fun f => Container.dirRightUnitor_naturality f
  pentagon := Container.dirPentagon
  triangle := Container.dirTriangle

/-! ## The extension of a Dirichlet tensor: a normal form, *not* a strictness theorem

By definition,

  `⟦C ⊗ D⟧ X = Σ (st : S × T), (P st.1 × Q st.2 → X)`,

and `dirichletExt_normalForm` below records this as a **definitional equality of
types** (`rfl`). It is a useful computation/normal-form rule, and nothing more.

**It is not a monoidal-functor statement, and in particular it does not say that
`⟦−⟧` is *strict* monoidal for `⊗`.** A comparison map must relate `⟦C ⊗ D⟧` to
`⟦C⟧` and `⟦D⟧` through a tensor *on the target category*. The right-hand side
above is not built from the functors `⟦C⟧`, `⟦D⟧` at all: it re-reads the
container's *presentation* (`S`, `T`, `P`, `Q`). Observing that `⟦−⟧` "preserves"
a tensor that was itself defined by reading the presentation is circular; the
`rfl` is an unfolding of a definition. Compare the three comparisons with real
content:

* `◁`: `⟦G ◁ F⟧ X ≅ ⟦G⟧ (⟦F⟧ X)` — target tensor = composition of functors
  (`Container.seqExt`, `Sequential.lean`; a genuine iso, not an identity);
* `+`: `⟦C + D⟧ X ≅ ⟦C⟧ X ⊕ ⟦D⟧ X` — target tensor = pointwise coproduct
  (`FourMonoidal.lean`; genuine iso);
* `×`: `⟦C × D⟧ X ≅ ⟦C⟧ X × ⟦D⟧ X` — target tensor = pointwise product
  (`FourMonoidal.lean`; genuine iso).

The correct intrinsic account of `⊗` is due to **Niu–Spivak, *Polynomial
Functors*, Prop. 3.79** (arXiv:2312.00990): `⊗` is the **Day convolution** on
`[Set, Set]` of the cartesian monoidal structure `(Set, ×, 1)`. The comparison
map `⟦C⟧ ⊙ ⟦D⟧ → ⟦C ⊗ D⟧` is then the co-Yoneda/density isomorphism out of a
coend — an iso, but emphatically not an identity. So `⟦−⟧` is **strong**, not
strict, monoidal for `⊗`. (The coend is not constructible in Lean core without
quotients, so we do not formalise it here.)

A second warning, worth stating because it is easy to get backwards: being a Day
convolution is *not* what makes `⊗` non-pointwise. The categorical product `×` on
`Cont` is **also** a Day convolution — of `(Set, +, 0)` — and it *is* pointwise.
The real criterion is whether the corepresentable splits the domain tensor:

* `y^(A+B) ≅ y^A × y^B` — so Day-of-`+` (the product `×`) *is* pointwise;
* `y^(A×B)` admits **no** such splitting — so Day-of-`×` (the Dirichlet `⊗`) is
  not. Witness: `y³ ⊗ y³ = y⁹`, whereas anything pointwise would give `y⁶`.

The honest taxonomy of the four monoidal structures on `Cont`:

| structure | Day convolution of | unit | `⟦−⟧` pointwise? |
|---|---|---|---|
| product `×`     | `(Set, +, 0)` | `1 = y⁰` | yes |
| Dirichlet `⊗`   | `(Set, ×, 1)` | `y = y¹` | no |
| coproduct `+`   | not a Day convolution (fails to preserve the initial object in each variable) | `0` | yes |
| sequential `◁`  | not a Day convolution (not cocontinuous in the right variable) | `I = y` | no |

What *is* non-vacuous, and ours, is the relation to the sequential operator
recorded below: `⊗` is the *uniform* (non-dependent) fragment of `◁`. -/

/-- **Normal form for the extension of a Dirichlet tensor.** Holds by `rfl`: it is
literally the unfolding of `Container.dirichlet` and `Ext`. Useful as a
computation rule. It is *not* a strict-monoidality statement for `⟦−⟧` — the
right-hand side mentions the presentation `S, T, P, Q`, not the functors `⟦C⟧`,
`⟦D⟧`. See the discussion above (and Niu–Spivak Prop. 3.79: the honest statement
is that `⟦−⟧` is *strong* monoidal for `⊗`, the target tensor being Day
convolution of `(Set, ×, 1)`, with a coend comparison iso). -/
theorem Container.dirichletExt_normalForm (C D : Container) (X : Type) :
    Ext (C ⊗ D) X = ((st : C.Shape × D.Shape) × (C.Pos st.1 × D.Pos st.2 → X)) := rfl

/-! ## `⊗` is the uniform fragment of `◁`

The non-vacuous statement in the neighbourhood of the strictness claim. Both
`C ⊗ D` and `C ◁ D` "put a `D` at every `C`-position", but

* `C ◁ D` lets the inner `D`-shape *depend* on the outer `C`-position: its shapes
  are `Σ s : S, (P s → T)`;
* `C ⊗ D` forces one inner shape *uniformly*: its shapes are `S × T`.

Choosing the constant assignment `fun _ => t` therefore embeds `⊗` into `◁`.
On positions the two agree on the nose: `Σ p : P s, Q ((fun _ => t) p) = P s × Q t`
definitionally, so the morphism is transport-free.

This is the precise sense in which the Dirichlet tensor "reads the polynomial
presentation": it is `◁` with the dependency switched off. -/

/-- The canonical **uniformity morphism** `C ⊗ D ⟶ C ◁ D`: send the shape `(s, t)`
to `(s, fun _ => t)` (the constant inner-shape assignment); positions are the
identity, the fibres agreeing definitionally. -/
def Container.dirToSeq (C D : Container) : ContainerMorphism (C ⊗ D) (C ◁ D) where
  onShapes := fun st => ⟨st.1, fun _ => st.2⟩
  onPos := fun _ pq => (pq.1, pq.2)

/-- The container `y² = Unit ◁ Bool`: one shape, two positions. -/
def Container.ySq : Container where
  Shape := Unit
  Pos := fun _ => Bool

/-- The constant container `2 = Bool ◁ (fun _ => Empty)`: two shapes, no
positions. -/
def Container.two : Container where
  Shape := Bool
  Pos := fun _ => Empty

/-- The inner-shape-assignment component of a `y² ◁ 2` shape, as a plain
(non-dependent) function `Bool → Bool`. A helper for the counterexample below:
it lets us apply `congrArg` to an equation between `Sigma`-shapes. -/
def Container.seqShapeSnd (z : (Container.ySq ◁ Container.two).Shape) : Bool → Bool := z.2

/-- The uniformity morphism is **not** an isomorphism in general: for `C = y²` and
`D = 2` its shape map `Bool → (Bool → Bool)`, `t ↦ fun _ => t`, misses the
identity function, hence is not surjective on shapes. (Concretely `y² ⊗ 2` has 2
shapes while `y² ◁ 2` has 4 — and both have no positions, so `⟦y² ⊗ 2⟧ X` has 2
elements and `⟦y² ◁ 2⟧ X` has 4, for every `X`.) So `⊗ ≠ ◁`: the uniformity
morphism is a genuine comparison, not an equivalence. -/
theorem Container.dirToSeq_not_surjective :
    ¬ ∃ st : (Container.ySq ⊗ Container.two).Shape,
        (Container.dirToSeq Container.ySq Container.two).onShapes st
          = (⟨(), fun b => b⟩ : (Container.ySq ◁ Container.two).Shape) := by
  intro ⟨st, hst⟩
  -- `hst : ⟨(), fun _ => st.2⟩ = ⟨(), fun b => b⟩`, so the constant function
  -- `fun _ => st.2` equals the identity on `Bool` — impossible.
  have hf := congrArg Container.seqShapeSnd hst
  have h1 : st.2 = true := congrFun hf true
  have h2 : st.2 = false := congrFun hf false
  rw [h1] at h2
  exact Bool.noConfusion h2

end Containers
