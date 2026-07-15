import Containers.Cont

/-!
# Container composition `◁` and its monoidal structure

This file builds on `Containers.Cont`. It equips the category `Cont` of
containers (objects `S ◁ P`, morphisms the contravariant
`Containers.ContainerMorphism`) with the **composition product** `◁`, the
operation whose extension is *composition of the induced functors*:
`⟦G ◁ F⟧ = ⟦G⟧ ∘ ⟦F⟧`. This is the spine of the whole development — a
`◁`-comonoid in `Cont` is exactly a directed container.

For `F = S ◁ P` and `G = T ◁ Q`, the composite `G ◁ F` (read "`G` outside,
`F` inside") has

* shapes `Σ t : T, (Q t → S)` — an outer `G`-shape together with a choice of
  inner `F`-shape for each `G`-position, and
* positions at `(t, f)` given by `Σ q : Q t, P (f q)` — pick an outer position
  `q`, then a position inside the inner shape `f q` sitting there.

The unit is the **identity container** `I = Unit ◁ (fun _ => Unit)`, whose
extension is `Id`.

We then prove the monoidal coherences as *isomorphisms of containers*
(`ContainerIso`), reusing the `ext'` machinery of `Cont.lean`:

* the **left** and **right unitors** `I ◁ F ≅ F` and `F ◁ I ≅ F`, and
* the **associator** `(H ◁ G) ◁ F ≅ H ◁ (G ◁ F)`.

The pleasant surprise — and the reason this is the *composition* product and
not a transport-laden mess — is that every dependent type involved lines up
**definitionally**. The associator, in particular, is nothing but the
re-association of an iterated dependent sum: `((u, v), p) ↔ (u, (v, p))`, and
the fibre over which `p` lives, `F.Pos ((m u).2 v)`, is *definitionally* the
fibre `F.Pos (k (u, v))` on the other side. No `Sigma` transports appear; the
round-trip laws hold after a `cases` on the nested pairs.

Everything is `Type`-level, Lean 4 core, no Mathlib — matching `Cont.lean`.
-/

namespace Containers

/-! ## The composition product `◁` -/

/-- **Container composition** `G ◁ F` ("`G` outside, `F` inside"). A shape is an
outer `G`-shape `t` together with a function assigning to each `G`-position an
inner `F`-shape; a position is an outer `G`-position `q` together with an inner
`F`-position in the shape sitting at `q`. Its extension is `⟦G⟧ ∘ ⟦F⟧`. -/
def Container.comp (G F : Container) : Container where
  Shape := (t : G.Shape) × (G.Pos t → F.Shape)
  Pos := fun tf => (q : G.Pos tf.1) × F.Pos (tf.2 q)

@[inherit_doc] scoped infixr:70 " ◁ " => Container.comp

/-- The **identity container** `I = Unit ◁ (fun _ => Unit)`: one shape, one
position. Its extension is the identity functor, and it is the unit for `◁`. -/
def Container.I : Container where
  Shape := Unit
  Pos := fun _ => Unit

/-! ## The defining property: extension is functor composition

The whole point of `◁` is that `⟦G ◁ F⟧ = ⟦G⟧ ∘ ⟦F⟧` as functors on `Type`.
We make this precise and machine-checked: at every type `X`, the extension
`Ext (G ◁ F) X` is in natural bijection with `Ext G (Ext F X)`. The bijection
*uncurries* the position labelling, and — as with the associator — both fibres
agree definitionally, so the round trips are `rfl` after a `cases`. This is the
lemma that pins down the composition convention. -/

/-- Forward half of `⟦G ◁ F⟧ X ≅ ⟦G⟧ (⟦F⟧ X)`: regroup a labelling of the
nested position sum as an outer structure of inner structures. -/
def Container.compExt {G F : Container} {X : Type} :
    Ext (G ◁ F) X → Ext G (Ext F X) :=
  fun p => ⟨p.1.1, fun q => ⟨p.1.2 q, fun r => p.2 ⟨q, r⟩⟩⟩

/-- Backward half of `⟦G ◁ F⟧ X ≅ ⟦G⟧ (⟦F⟧ X)`. -/
def Container.compExtInv {G F : Container} {X : Type} :
    Ext G (Ext F X) → Ext (G ◁ F) X :=
  fun p => ⟨⟨p.1, fun q => (p.2 q).1⟩, fun qr => (p.2 qr.1).2 qr.2⟩

/-- The two halves are mutually inverse: `compExtInv ∘ compExt = id`. -/
theorem Container.compExtInv_compExt {G F : Container} {X : Type}
    (p : Ext (G ◁ F) X) : Container.compExtInv (Container.compExt p) = p := by
  rcases p with ⟨⟨t, f⟩, lab⟩
  rfl

/-- The two halves are mutually inverse: `compExt ∘ compExtInv = id`. This,
together with `compExtInv_compExt`, is the equation `⟦G ◁ F⟧ = ⟦G⟧ ∘ ⟦F⟧`. -/
theorem Container.compExt_compExtInv {G F : Container} {X : Type}
    (p : Ext G (Ext F X)) : Container.compExt (Container.compExtInv p) = p := by
  rcases p with ⟨t, m⟩
  rfl

/-! ## Isomorphisms of containers

An isomorphism in `Cont`: a morphism with a two-sided inverse. We package it
explicitly because the unitors and associator are isomorphisms, not equalities
(the underlying shape sets are only *bijective*, e.g. `Unit → S ≅ S`). -/

/-- An **isomorphism of containers**: a pair of mutually inverse container
morphisms. -/
structure ContainerIso (C D : Container) where
  /-- The forward morphism. -/
  hom : ContainerMorphism C D
  /-- The backward morphism. -/
  inv : ContainerMorphism D C
  /-- `hom` then `inv` is the identity on `C`. -/
  hom_inv : hom.comp inv = ContainerMorphism.id C
  /-- `inv` then `hom` is the identity on `D`. -/
  inv_hom : inv.comp hom = ContainerMorphism.id D

/-! ## The left unitor `I ◁ F ≅ F`

A shape of `I ◁ F` is `(⟨⟩, f)` with `f : Unit → F.Shape`; the bijection with
`F.Shape` is `f ↦ f ⟨⟩` / `s ↦ fun _ => s`. Positions transport along the same
`Unit`-collapse. -/

/-- The **left unitor** `I ◁ F ≅ F`. Forward: read off the single inner shape.
Backward: the constant assignment. All four data are `Unit`-collapses; the
round trips hold by `rfl` (`Unit`- and `Sigma`-η). -/
def Container.leftUnitor (F : Container) : ContainerIso (Container.I ◁ F) F where
  hom :=
    { onShapes := fun tf => tf.2 ()
      onPos := fun _ p => ⟨(), p⟩ }
  inv :=
    { onShapes := fun s => ⟨(), fun _ => s⟩
      onPos := fun _ qp => qp.2 }
  hom_inv := rfl
  inv_hom := rfl

/-! ## The right unitor `F ◁ I ≅ F`

A shape of `F ◁ I` is `(s, g)` with `g : F.Pos s → Unit`; the bijection with
`F.Shape` is the first projection, since `F.Pos s → Unit ≅ Unit`. Positions
`Σ p : F.Pos s, Unit` collapse to `F.Pos s`. -/

/-- The **right unitor** `F ◁ I ≅ F`. Forward: drop the trivial inner data.
Backward: pad with the unique map to `Unit`. Round trips by `rfl`. -/
def Container.rightUnitor (F : Container) : ContainerIso (F ◁ Container.I) F where
  hom :=
    { onShapes := fun sg => sg.1
      onPos := fun _ p => ⟨p, ()⟩ }
  inv :=
    { onShapes := fun s => ⟨s, fun _ => ()⟩
      onPos := fun _ pu => pu.1 }
  hom_inv := rfl
  inv_hom := rfl

/-! ## The associator `(H ◁ G) ◁ F ≅ H ◁ (G ◁ F)`

The heart of the monoidal structure. A shape of the left side is
`((a, g), k)` with `g : H.Pos a → G.Shape` and
`k : (Σ u : H.Pos a, G.Pos (g u)) → F.Shape`; a shape of the right side is
`(a, m)` with `m : H.Pos a → Σ b : G.Shape, (G.Pos b → F.Shape)`. The
bijection *curries* the inner data:
`m u = ⟨g u, fun v => k ⟨u, v⟩⟩`, inverted by `g u = (m u).1`,
`k ⟨u, v⟩ = (m u).2 v`.

On positions it is the re-association of a nested dependent sum,
`(⟨u, v⟩, p) ↔ (u, ⟨v, p⟩)`. Crucially `F.Pos ((m u).2 v)` is *definitionally*
`F.Pos (k ⟨u, v⟩)`, so no transport is needed and the round trips close by
`cases` + `rfl`. -/

/-- The **associator** `(H ◁ G) ◁ F ≅ H ◁ (G ◁ F)`. Both directions curry /
uncurry the inner shape assignment and re-associate the nested position sum.
Because the position fibres agree definitionally, the construction is
transport-free. -/
def Container.associator (H G F : Container) :
    ContainerIso ((H ◁ G) ◁ F) (H ◁ (G ◁ F)) where
  hom :=
    { onShapes := fun xk => ⟨xk.1.1, fun u => ⟨xk.1.2 u, fun v => xk.2 ⟨u, v⟩⟩⟩
      onPos := fun _ uvp => ⟨⟨uvp.1, uvp.2.1⟩, uvp.2.2⟩ }
  inv :=
    { onShapes := fun am => ⟨⟨am.1, fun u => (am.2 u).1⟩, fun y => (am.2 y.1).2 y.2⟩
      onPos := fun _ yp => ⟨yp.1.1, yp.1.2, yp.2⟩ }
  hom_inv := by
    refine ContainerMorphism.ext' rfl ?_
    intro s p
    rcases s with ⟨⟨a, g⟩, k⟩
    rcases p with ⟨⟨u, v⟩, q⟩
    rfl
  inv_hom := by
    refine ContainerMorphism.ext' rfl ?_
    intro s p
    rcases s with ⟨a, m⟩
    rcases p with ⟨u, v, q⟩
    rfl

/-! ## The compositional payoff

A **`◁`-comonoid** in `Cont` — a container `C` with a counit `C ⟶ I` and a
comultiplication `C ⟶ C ◁ C` satisfying the comonoid laws — is *exactly* a
**directed container** (equivalently, a comonad on `Set` whose underlying
functor is a container). This identifies `(Cont, ◁, I)` as the home of the
spine of the programme: directed containers, the carriers of compositional
state, are the comonoids of container composition. The comonoid laws unfold to
the directed-container axioms already formalised in `Containers.Directed`; we
record the correspondence here as the organising remark and leave the
equivalence to that file. -/

end Containers
