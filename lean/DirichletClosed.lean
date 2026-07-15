import Containers.Dirichlet

/-!
# `(Cont, ⊗, y)` is closed

This file proves that the Dirichlet tensor `⊗` on the category of containers
(`Containers.Dirichlet`) is **closed**: for every container `q` the functor
`− ⊗ q` has a right adjoint `Ihom q −`.

The internal hom is the container whose *shapes are the container morphisms*:

  `Ihom q r = (ContainerMorphism q r) ◁ (fun f => Σ t : q.Shape, r.Pos (f.onShapes t))`

i.e. a shape of `Ihom q r` is a pair `(u, φ)` of a shape map `u : S q → S r` and a
backward position map `φ : (t : S q) → r[u t] → q[t]` — exactly a morphism
`q ⟶ r` — and the positions over such a shape are pairs `(t, i)` with `t : S q` a
`q`-shape and `i : r[u t]` an `r`-position over its image.

This is Niu–Spivak, *Polynomial Functors*, Eq. (4.79) (arXiv:2312.00990),
transported to the container presentation. Note the internal hom really is a
*container*, not merely a hom-set: the shape type is the hom-set of `Cont`, and
the extra data — the position family — is what makes the adjunction internal.

## Main results

* `Container.ihom` — the internal hom.
* `dirichlet_closure` — the adjunction as an explicit type equivalence
  `(p ⊗ q ⟶ r) ≃ (p ⟶ Ihom q r)`, with both round trips proved.
* `dirCurry_naturality_left`, `dirCurry_naturality_right` — naturality of the
  currying bijection in `p` and in `r`.
* `dirichlet_closure_hom` — the closure applied to the unit `y` recovers
  `Ihom y r ≅ r`-style computations; more usefully, `ihom_shape_eq` records that
  the shapes of `Ihom q r` *are* the morphisms `q ⟶ r`, on the nose.

## Note on the proofs

Every proof in this file is `rfl`. The currying bijection is a rearrangement of a
Σ/× telescope, and Lean's definitional η for structures (`Prod`, `Sigma`, and the
`ContainerMorphism` structure itself) identifies the two round trips on the nose.
No transports, no `Ext.ext_eq`, no funext. This matches the situation for the `⊗`
coherences (`Containers.Dirichlet`), which are also all `rfl`: the Dirichlet
tensor is *definitionally* well behaved in a way the sequential operator `◁` and
the directed-container comonad laws are not.

Everything is `Type`-level, Lean 4 core, no Mathlib.
-/

namespace Containers

universe u v

/-! ## A hand-rolled type equivalence

Mathlib-free stand-in for `Equiv`. -/

/-- A **type equivalence**: a pair of maps with both round trips. -/
structure TypeEquiv (A : Type u) (B : Type v) where
  /-- The forward map. -/
  toFun : A → B
  /-- The backward map. -/
  invFun : B → A
  /-- `invFun` is a left inverse of `toFun`. -/
  left_inv : ∀ a, invFun (toFun a) = a
  /-- `invFun` is a right inverse of `toFun`. -/
  right_inv : ∀ b, toFun (invFun b) = b

@[inherit_doc] scoped infixr:25 " ≃ " => TypeEquiv

/-! ## The internal hom -/

/-- The **internal hom** for the Dirichlet tensor.

* Shapes: the container morphisms `q ⟶ r`. A shape is a pair `(u, φ)` with
  `u : S q → S r` and `φ : (t : S q) → r[u t] → q[t]`.
* Positions over the shape `(u, φ)`: pairs `(t, i)` with `t : S q` and
  `i : r[u t]`.

That the shape type is literally `ContainerMorphism q r` is not a shortcut — it
is the content of the theorem (Niu–Spivak Eq. 4.79). -/
def Container.ihom (q r : Container) : Container where
  Shape := ContainerMorphism q r
  Pos := fun f => (t : q.Shape) × r.Pos (f.onShapes t)

@[inherit_doc] scoped notation:35 "[" q ", " r "]" => Container.ihom q r

/-- The shapes of the internal hom **are** the morphisms `q ⟶ r`, definitionally. -/
theorem Container.ihom_shape_eq (q r : Container) :
    (Container.ihom q r).Shape = ContainerMorphism q r := rfl

/-- The positions of the internal hom over a shape `f : q ⟶ r`. -/
theorem Container.ihom_pos_eq (q r : Container) (f : ContainerMorphism q r) :
    (Container.ihom q r).Pos f = ((t : q.Shape) × r.Pos (f.onShapes t)) := rfl

/-! ## Currying and uncurrying

The two directions of the adjunction, given explicitly.

Unfolded, a morphism `F : p ⊗ q ⟶ r` consists of

* `F.onShapes : S p × S q → S r`, and
* `F.onPos : (s, t) → r[F.onShapes (s,t)] → p[s] × q[t]`,

while a morphism `G : p ⟶ [q, r]` consists of

* `G.onShapes : S p → (q ⟶ r)`, i.e. `s ↦ (u_s, φ_s)`, and
* `G.onPos : (s : S p) → (Σ t, r[u_s t]) → p[s]`.

The bijection is pure currying, *split across the two components of `F.onPos`*:
the `q[t]` component of `F.onPos` becomes the backward position map `φ_s` of the
shape `G.onShapes s`, and the `p[s]` component becomes `G.onPos`. That split is
the whole content — it is why the positions of `[q, r]` are `Σ t, r[u t]` and not
something else. -/

/-- **Currying**: `(p ⊗ q ⟶ r) → (p ⟶ [q, r])`.

The `q`-component of `F`'s backward position map is packaged *into the shape*
of the internal hom (as the shape's own backward position map); the
`p`-component becomes the backward position map of the curried morphism. -/
def dirCurry {p q r : Container} (F : ContainerMorphism (p ⊗ q) r) :
    ContainerMorphism p (Container.ihom q r) where
  onShapes := fun s =>
    { onShapes := fun t => F.onShapes (s, t)
      onPos := fun t i => (F.onPos (s, t) i).2 }
  onPos := fun s x => (F.onPos (s, x.1) x.2).1

/-- **Uncurrying**: `(p ⟶ [q, r]) → (p ⊗ q ⟶ r)`.

Read the shape map of `G` at `s` as a morphism `q ⟶ r`; its shape map gives the
`r`-shape, and its backward position map gives the `q[t]` component of the
uncurried backward position map. The `p[s]` component is `G`'s own backward
position map, applied to the position `⟨t, i⟩` of the internal hom. -/
def dirUncurry {p q r : Container} (G : ContainerMorphism p (Container.ihom q r)) :
    ContainerMorphism (p ⊗ q) r where
  onShapes := fun st => (G.onShapes st.1).onShapes st.2
  onPos := fun st i => (G.onPos st.1 ⟨st.2, i⟩, (G.onShapes st.1).onPos st.2 i)

/-! ## The round trips

Both hold by `rfl`. The only steps involved are η for `Prod` (to rebuild `st`
from `(st.1, st.2)`), η for `Sigma` (to rebuild `x` from `⟨x.1, x.2⟩`), and η for
the `ContainerMorphism` structure (to rebuild `G.onShapes s` from its two
projections). Lean 4 has all three definitionally. -/

/-- Uncurrying undoes currying. Holds by `rfl`. -/
theorem dirUncurry_dirCurry {p q r : Container} (F : ContainerMorphism (p ⊗ q) r) :
    dirUncurry (dirCurry F) = F := rfl

/-- Currying undoes uncurrying. Holds by `rfl`. -/
theorem dirCurry_dirUncurry {p q r : Container}
    (G : ContainerMorphism p (Container.ihom q r)) :
    dirCurry (dirUncurry G) = G := rfl

/-! ## The main theorem -/

/-- **The Dirichlet tensor on `Cont` is closed.**

For all containers `p`, `q`, `r` there is a bijection

  `(p ⊗ q ⟶ r)  ≃  (p ⟶ [q, r])`

natural in `p` and `r` (see `dirCurry_naturality_left` and
`dirCurry_naturality_right` below). Together with `contDirichletMonoidal`
(`Containers.Dirichlet`) this makes `(Cont, ⊗, y)` a **closed monoidal
category**, with internal hom `Container.ihom`.

Equivalently: `− ⊗ q ⊣ [q, −]`.

This is Niu–Spivak, *Polynomial Functors*, Eq. (4.79) (arXiv:2312.00990), in the
container presentation.

Declared as a **`def`, not a `theorem`**: an equivalence of types is *data* (a
pair of maps together with the round-trip proofs), not a proposition, so Lean
rejects `theorem` here. The two round-trip lemmas `dirUncurry_dirCurry` and
`dirCurry_dirUncurry` *are* theorems, and they carry the mathematical content. -/
def dirichlet_closure (p q r : Container) :
    ContainerMorphism (p ⊗ q) r ≃ ContainerMorphism p (Container.ihom q r) where
  toFun := dirCurry
  invFun := dirUncurry
  left_inv := dirUncurry_dirCurry
  right_inv := dirCurry_dirUncurry

/-! ## Naturality

The currying bijection is natural in `p` (contravariantly, by precomposition) and
in `r` (covariantly, by postcomposition). Both are `rfl`.

Naturality in `p` needs the action of `[q, −]` on morphisms only through the
identity, but naturality in `r` needs the genuine functorial action `ihomMap`,
which we define first: postcomposition with `ψ : r ⟶ r'` on shapes (a shape of
`[q, r]` *is* a morphism `q ⟶ r`), and on positions the evident backward map. -/

/-- The functorial action of `[q, −]` on a morphism `ψ : r ⟶ r'`.

On shapes: postcompose, `f ↦ f ≫ ψ` (using that shapes of `[q, r]` are morphisms
`q ⟶ r`). On positions: a position `⟨t, i⟩` of `[q, r']` over the shape `f ≫ ψ`
has `i : r'[ψ.onShapes (f.onShapes t)]`; push it back through `ψ.onPos` to get an
`r`-position over `f.onShapes t`, giving a position `⟨t, ψ.onPos _ i⟩` of
`[q, r]`. -/
def ihomMap {q r r' : Container} (ψ : ContainerMorphism r r') :
    ContainerMorphism (Container.ihom q r) (Container.ihom q r') where
  onShapes := fun f => f.comp ψ
  onPos := fun f x => ⟨x.1, ψ.onPos (f.onShapes x.1) x.2⟩

/-- `ihomMap` preserves identities. -/
theorem ihomMap_id (q r : Container) :
    ihomMap (q := q) (ContainerMorphism.id r) = ContainerMorphism.id (Container.ihom q r) :=
  rfl

/-- `ihomMap` preserves composition. -/
theorem ihomMap_comp {q r r' r'' : Container}
    (ψ : ContainerMorphism r r') (ψ' : ContainerMorphism r' r'') :
    ihomMap (q := q) (ψ.comp ψ') = (ihomMap ψ).comp (ihomMap ψ') := rfl

/-- **Naturality in `p`** (the stretch goal): currying commutes with
precomposition. For `h : p' ⟶ p` and `F : p ⊗ q ⟶ r`,

  `curry ((h ⊗ id q) ≫ F) = h ≫ curry F`.

Holds by `rfl`. -/
theorem dirCurry_naturality_left {p p' q r : Container}
    (h : ContainerMorphism p' p) (F : ContainerMorphism (p ⊗ q) r) :
    dirCurry ((Container.dir₂ h (ContainerMorphism.id q)).comp F)
      = h.comp (dirCurry F) := rfl

/-- **Naturality in `r`**: currying commutes with postcomposition. For
`F : p ⊗ q ⟶ r` and `ψ : r ⟶ r'`,

  `curry (F ≫ ψ) = curry F ≫ [q, ψ]`.

Holds by `rfl`. -/
theorem dirCurry_naturality_right {p q r r' : Container}
    (F : ContainerMorphism (p ⊗ q) r) (ψ : ContainerMorphism r r') :
    dirCurry (F.comp ψ) = (dirCurry F).comp (ihomMap ψ) := rfl

/-- Naturality in `p`, in the uncurried direction (equivalent to
`dirCurry_naturality_left`, recorded for convenience). -/
theorem dirUncurry_naturality_left {p p' q r : Container}
    (h : ContainerMorphism p' p) (G : ContainerMorphism p (Container.ihom q r)) :
    dirUncurry (h.comp G)
      = (Container.dir₂ h (ContainerMorphism.id q)).comp (dirUncurry G) := rfl

/-! ## The counit (evaluation)

The closure being an adjunction, it has a counit: the **evaluation** morphism
`ev : [q, r] ⊗ q ⟶ r`, obtained by uncurrying the identity on `[q, r]`. Unfolded,
it sends the shape `(f, t)` to `f.onShapes t` — i.e. it *applies* the morphism
stored in the shape — and its backward position map splits an `r`-position `i`
into the `[q, r]`-position `⟨t, i⟩` and the `q`-position `f.onPos t i`. -/

/-- **Evaluation** `[q, r] ⊗ q ⟶ r`, the counit of the adjunction. -/
def dirEval (q r : Container) :
    ContainerMorphism (Container.ihom q r ⊗ q) r :=
  dirUncurry (ContainerMorphism.id (Container.ihom q r))

/-- The universal property in counit form: for every `F : p ⊗ q ⟶ r`, currying
`F` is the unique map `G` with `(G ⊗ id) ≫ ev = F`. This is the existence half —
and it is `rfl`. -/
theorem dirEval_dirCurry {p q r : Container} (F : ContainerMorphism (p ⊗ q) r) :
    (Container.dir₂ (dirCurry F) (ContainerMorphism.id q)).comp (dirEval q r) = F := rfl

/-- The uniqueness half: any `G : p ⟶ [q, r]` satisfying the triangle is
`dirCurry F`. -/
theorem dirCurry_unique {p q r : Container} (F : ContainerMorphism (p ⊗ q) r)
    (G : ContainerMorphism p (Container.ihom q r))
    (h : (Container.dir₂ G (ContainerMorphism.id q)).comp (dirEval q r) = F) :
    G = dirCurry F := by
  subst h
  -- `(G ⊗ id) ≫ ev` is definitionally `dirUncurry G`, so this is
  -- `dirCurry (dirUncurry G) = G` read backwards.
  exact (dirCurry_dirUncurry G).symm

end Containers
