import Containers.Monoidal
import Containers.Directed

/-!
# A directed container is a comonoid in `(Cont, ◁, I)`

`Containers.Sequential` equips the category `Cont` with the **sequential operator** `◁`
(the operation whose extension is composition of the induced functors) and `Containers.
Monoidal` proves that `(Cont, ◁, I)` is a monoidal category. This file cashes that
structure in: it defines a **comonoid** in `(Cont, ◁, I)` — a container `C` with a counit
`ε : C ⟶ I` and a comultiplication `δ : C ⟶ C ◁ C` satisfying the two counit laws and
coassociativity, *all stated internally to `Cont`* — and shows that every **directed
container** (Ahman–Chapman–Uustalu, *When is a container a comonad?*, LMCS 10(3):2014) is
one, via `DirectedContainer.toComonoid`.

The point of stating the laws internally is that they never mention `Ext`, functors, or
`[Set, Set]`. The comonoid laws are equations between *container morphisms*, built from
`Container.seq₂` (the action of `◁` on morphisms) and the unitors and associator of
`Containers.Monoidal`. Unfolding them recovers the directed-container axioms on the nose:

* **right counit** `δ ; (C ◁ ε) = ρ⁻¹` is **D3** — and it needs no transport at all: both
  sides have definitionally equal shape maps, so the law *is* `d3` (see `right_counit`);
* **left counit** `δ ; (ε ◁ C) = λ⁻¹` is **D1** (shapes) and **D2** (positions);
* **coassociativity** `δ ; (δ ◁ C) ; α = δ ; (C ◁ δ)` is **D4** (shapes) and **D5**
  (positions).

This is the same partition of the axioms that `Containers.Directed` finds at the *comonad*
level — which is the content of the result: the correspondence is an artifact of the
monoidal structure on `Cont`, not of passing through `[Set, Set]`.

## The dependent content

D1 and D4 are only *propositional* shape equalities, so the two sides of the left-counit and
coassociativity laws have shape maps that agree only propositionally, and their position
maps live over different fibres. Every such cast is routed through two helpers:

* `ContainerMorphism.ext_eq` — pointwise extensionality for morphisms. It is deliberately
  stated with a *pointwise* shape equality `hs : ∀ s, f s = g s`, unlike the ambient
  `ContainerMorphism.ext'`, so that the proof term `hs s` appears literally in the position
  obligation and the transport can be rewritten; and
* `Container.seq_pos_transport` — which computes the induced transport on positions of
  `E ◁ C` componentwise (outer position fixed, inner position transported).

Both are proved by `funext` + `cases`, and definitional proof irrelevance then collapses the
residual casts. `DirectedContainer.toComonoid` depends only on `Quot.sound` (via `funext`).

The **converse** — that every comonoid arises this way, so that comonoids in `(Cont, ◁, I)`
are *exactly* directed containers — is not yet formalised here; see the note below.

Everything is `Type`-level, Lean 4 core, no Mathlib.
-/

namespace Containers

open Container

/-- **Pointwise extensionality for container morphisms.** Two morphisms agree as soon
as their shape maps agree *pointwise* and their position maps agree after transporting
along that pointwise equality. This is the morphism-level analogue of
`Containers.Ext.ext_eq`, and it is stated pointwise on purpose: the proof term `hs s`
then appears literally in the position obligation, so the transport can be computed by
`Container.seq_pos_transport`. (`ContainerMorphism.ext'` transports along
`congrFun (funext hs) s`, which is only *propositionally* `hs s`.) -/
theorem ContainerMorphism.ext_eq {C D : Container} {f g : C.Shape → D.Shape}
    {fp : (s : C.Shape) → D.Pos (f s) → C.Pos s}
    {gp : (s : C.Shape) → D.Pos (g s) → C.Pos s}
    (hs : ∀ s, f s = g s) (hp : ∀ s p, fp s p = gp s (hs s ▸ p)) :
    (⟨f, fp⟩ : ContainerMorphism C D) = ⟨g, gp⟩ := by
  have hfg : f = g := funext hs
  cases hfg
  have hpp : fp = gp := funext fun s => funext fun p => hp s p
  cases hpp
  rfl

/-- Transporting forwards along `h` and back again is the identity. Used to cancel the
`D4` round-trip that appears when D5 is matched against the coassociativity obligation. -/
theorem Container.cast_symm_cast {α : Type} {P : α → Type} {a b : α} (h : a = b) (x : P a) :
    (h.symm ▸ (h ▸ x : P b) : P a) = x := by
  cases h
  rfl

/-- **The transport lemma.** Positions of `E ◁ C` over the shape `⟨t, f⟩` are pairs
`⟨u, q⟩` with `q : C.Pos (f u)`, so a *pointwise* equality `h : ∀ u, f u = g u` of
inner-shape assignments induces a transport on positions — and that transport is
computed componentwise: it leaves the outer position `u` alone and transports the inner
position `q` along `h u`. Every dependent cast in this file is an instance of this
lemma. -/
theorem Container.seq_pos_transport {C E : Container} {t : E.Shape}
    {f g : E.Pos t → C.Shape} (h : ∀ u, f u = g u) (u : E.Pos t) (q : C.Pos (f u)) :
    (congrArg (Sigma.mk (β := fun k => E.Pos k → C.Shape) t) (funext h) ▸
        (⟨u, q⟩ : (E ◁ C).Pos ⟨t, f⟩) : (E ◁ C).Pos ⟨t, g⟩)
      = (⟨u, (h u ▸ q : C.Pos (g u))⟩ : (E ◁ C).Pos ⟨t, g⟩) := by
  have hfg : f = g := funext h
  cases hfg
  rfl

/-- A **comonoid in the monoidal category `(Cont, ◁, I)`**. -/
structure Container.Comonoid (C : Container) where
  /-- The counit `ε : C ⟶ I`. -/
  counit : ContainerMorphism C Container.I
  /-- The comultiplication `δ : C ⟶ C ◁ C`. -/
  comult : ContainerMorphism C (C ◁ C)
  /-- Left counit law. -/
  left_counit :
    comult.comp (Container.seq₂ counit (ContainerMorphism.id C))
      = (Container.leftUnitor C).inv
  /-- Right counit law. -/
  right_counit :
    comult.comp (Container.seq₂ (ContainerMorphism.id C) counit)
      = (Container.rightUnitor C).inv
  /-- Coassociativity. -/
  coassoc :
    (comult.comp (Container.seq₂ comult (ContainerMorphism.id C))).comp
        (Container.associator C C C).hom
      = comult.comp (Container.seq₂ (ContainerMorphism.id C) comult)

/-! ## Forward direction -/

namespace DirectedContainer

/-- The counit `ε : C ⟶ I` of a directed container: pick the root. -/
def coCounit (D : DirectedContainer) : ContainerMorphism D.toContainer Container.I where
  onShapes := fun _ => ()
  onPos := fun s _ => D.root s

/-- The comultiplication `δ : C ⟶ C ◁ C` of a directed container. -/
def coComult (D : DirectedContainer) :
    ContainerMorphism D.toContainer (D.toContainer ◁ D.toContainer) where
  onShapes := fun s => ⟨s, D.sub s⟩
  onPos := fun s pq => D.shift s pq.1 pq.2

/-- A directed container is a `◁`-comonoid. -/
def toComonoid (D : DirectedContainer) : Container.Comonoid D.toContainer where
  counit := D.coCounit
  comult := D.coComult
  left_counit := by
    refine ContainerMorphism.ext_eq (fun s => congrArg (Sigma.mk ())
      (funext fun _ => D.d1 s)) ?_
    intro s p
    obtain ⟨u, q⟩ := p
    have ht := Container.seq_pos_transport (C := D.toContainer) (E := Container.I) (t := ())
      (f := fun _ => D.sub s (D.root s)) (g := fun _ => s) (fun _ => D.d1 s) u q
    exact (D.d2 s q).trans
      (congrArg (fun z : (_u : Container.I.Pos ()) × D.Pos s => z.2) ht).symm
  right_counit := ContainerMorphism.ext' rfl (fun s pu => D.d3 s pu.1)
  coassoc := by
    refine ContainerMorphism.ext_eq (fun s => congrArg (Sigma.mk s)
      (funext fun u => congrArg (Sigma.mk (D.sub s u)) (funext fun v => D.d4 s u v))) ?_
    intro s p
    obtain ⟨u, v, w⟩ := p
    -- The inner shape equality, pointwise in the outer position `u`: this is D4.
    have hin : ∀ u' : D.Pos s, ∀ v' : D.Pos (D.sub s u'),
        D.sub s (D.shift s u' v') = D.sub (D.sub s u') v' := fun u' v' => D.d4 s u' v'
    -- Compute the transport of `⟨u, v, w⟩` componentwise: outer, then inner.
    have ht2 := Container.seq_pos_transport (C := D.toContainer) (E := D.toContainer)
      (t := D.sub s u) (f := fun v' => D.sub s (D.shift s u v'))
      (g := fun v' => D.sub (D.sub s u) v') (hin u) v w
    have ht1 := Container.seq_pos_transport (C := D.toContainer ◁ D.toContainer)
      (E := D.toContainer) (t := s)
      (f := fun u' => ⟨D.sub s u', fun v' => D.sub s (D.shift s u' v')⟩)
      (g := fun u' => ⟨D.sub s u', fun v' => D.sub (D.sub s u') v'⟩)
      (fun u' => congrArg (Sigma.mk (D.sub s u')) (funext (hin u'))) u ⟨v, w⟩
    have hT := ht1.trans (congrArg (fun z : (D.toContainer ◁ D.toContainer).Pos
      ⟨D.sub s u, fun v' => D.sub (D.sub s u) v'⟩ => (⟨u, z⟩ :
        (v' : D.Pos s) × (D.toContainer ◁ D.toContainer).Pos
          ⟨D.sub s v', fun v'' => D.sub (D.sub s v') v''⟩)) ht2)
    -- D5, with the cast round-trip `(d4).symm ▸ (d4 ▸ w)` cancelled.
    have h5 := D.d5 s u v (D.d4 s u v ▸ w)
    rw [Container.cast_symm_cast (P := D.Pos) (D.d4 s u v) w] at h5
    exact h5.trans (congrArg (fun z => D.coComult.onPos s
      ((Container.seq₂ (ContainerMorphism.id D.toContainer) D.coComult).onPos
        (D.coComult.onShapes s) z)) hT).symm

end DirectedContainer

end Containers
