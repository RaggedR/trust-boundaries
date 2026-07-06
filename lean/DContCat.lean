import Containers.Directed

/-!
# Directed containers as categories, and their morphisms as cofunctors

This file formalizes the object-level dictionary of Ahman–Uustalu,
*Directed containers as categories* (2016), together with the morphism-level
result of `papers/dcont-cof.tex`: directed-container morphisms are
**cofunctors** between the induced categories.

## The dictionary

A directed container `D` presents a small category `𝒞(D)`:

* objects are shapes `s : S`;
* a morphism `s → s'` is a position `p : P s` with `s ↓ p = s'`
  (packaged as a `Subtype`);
* the identity at `s` is the root `o s` (D1 says its codomain is `s`);
* composition is the shift `⊕` (D4 says codomains match up).

The category laws are exactly D2/D3 (identities) and D5 (associativity),
transported along the shape equalities D1 and D4.

Conversely, a small category `𝒞` yields a directed container: shapes are
objects, `P s = Σ s', 𝒞(s, s')` is the type of *outgoing* morphisms,
`sub` is the codomain projection, `root` is the identity, `shift` is
composition. Here D1 and D4 hold by `rfl`, and D2/D3/D5 are the category
laws.

## The round-trip gap

The two constructions are mutually inverse only up to isomorphism, not
definitional equality: starting from `D`, the round trip replaces `P s` by
`Σ s', {p : P s // s ↓ p = s'}` — the total space of the fibration of
positions over their codomains. We exhibit the pointwise position
bijection (`toRoundtripPos` / `ofRoundtripPos`, both round trips proved),
but do not force a `rfl`-equality that does not hold. The other direction
(category → container → category) has the same flavour: hom-sets get
wrapped in a `Subtype` over a `Sigma`, equal only up to the evident
bijection.

## Morphisms

A `DContMorphism C D` is a container morphism (shape map covariant,
position map **contravariant**) satisfying M0–M2. A `Cofunctor C D` is a
cofunctor of the presented categories, laws C0–C2. These are *literally
the same data* under the dictionary — the hom-set bijection
`DContMorphism.toCofunctor` / `Cofunctor.toDContMorphism` has both round
trips `rfl`. Composition of cofunctors needs one genuinely dependent step,
isolated in `Cofunctor.comp_transport` (proved by `subst; subst; rfl`);
the category laws for `Cofunctor` and the functoriality of `toCofunctor`
are then all `rfl`.

Everything is `Type`-level, Lean 4 core, no Mathlib.
-/

namespace Containers

/-- A **small category**, hand-rolled (no Mathlib): a type of objects, a
type of morphisms between any two objects, identities, and *diagrammatic*
composition `comp : Hom a b → Hom b c → Hom a c`, subject to the usual
unit and associativity laws. Diagrammatic order matches the shift of a
directed container: `p ⊕ q` first travels along `p`, then along `q`. -/
structure SmallCat where
  Obj : Type
  Hom : Obj → Obj → Type
  id : (a : Obj) → Hom a a
  comp : {a b c : Obj} → Hom a b → Hom b c → Hom a c
  id_comp : ∀ {a b : Obj} (f : Hom a b), comp (id a) f = f
  comp_id : ∀ {a b : Obj} (f : Hom a b), comp f (id b) = f
  assoc : ∀ {a b c d : Obj} (f : Hom a b) (g : Hom b c) (h : Hom c d),
    comp (comp f g) h = comp f (comp g h)

namespace DirectedContainer

variable (D : DirectedContainer)

/-- Transporting forth and back along a shape equality is the identity.
Used to cancel the D1-transport in the left unit law. -/
theorem transport_cancel {α : Type} {P : α → Type} {x y : α}
    (h : x = y) (p : P y) : h ▸ h.symm ▸ p = p := by
  subst h; rfl

/-- The codomain of a composite: if `p : P a` lands on `b` and `q : P b`
lands on `c`, then the shift `p ⊕ q` lands on `c`. This is D4 with both
shape equalities made into bound variables so that `subst` fires; it
supplies the `Subtype` property of composition in the induced category. -/
theorem sub_shift_eq {a b c : D.Shape} (p : D.Pos a) (hp : D.sub a p = b)
    (q : D.Pos b) (hq : D.sub b q = c) :
    D.sub a (D.shift a p (hp.symm ▸ q)) = c := by
  subst hp; subst hq
  exact D.d4 a p q

/-- The small category presented by a directed container: objects are
shapes, a morphism `a → b` is a position over `a` whose sub-shape is `b`,
the identity is the root (D1), and composition is the shift (D4). The
unit laws are D2 and D3; associativity is D5. Each law is proved by
`subst`-ing the codomain equalities, after which the transports reduce
definitionally (proofs of shape equalities are definitionally irrelevant),
leaving exactly the directed-container law. -/
def toSmallCat : SmallCat where
  Obj := D.Shape
  Hom a b := { p : D.Pos a // D.sub a p = b }
  id a := ⟨D.root a, D.d1 a⟩
  comp f g :=
    ⟨D.shift _ f.val (f.property.symm ▸ g.val),
     D.sub_shift_eq f.val f.property g.val g.property⟩
  id_comp := by
    intro a b f
    obtain ⟨p, hp⟩ := f
    subst hp
    apply Subtype.ext
    show D.shift a (D.root a) ((D.d1 a).symm ▸ p) = p
    rw [D.d2]
    exact transport_cancel (D.d1 a) p
  comp_id := by
    intro a b f
    obtain ⟨p, hp⟩ := f
    subst hp
    exact Subtype.ext (D.d3 a p)
  assoc := by
    intro a b c d f g h
    obtain ⟨p, hp⟩ := f
    obtain ⟨q, hq⟩ := g
    obtain ⟨r, hr⟩ := h
    subst hp; subst hq; subst hr
    exact Subtype.ext (D.d5 a p q r)

end DirectedContainer

namespace SmallCat

/-- The directed container presented by a small category: shapes are
objects, positions over `s` are *outgoing* morphisms `Σ s', Hom s s'`,
the sub-shape is the codomain, the root is the identity, and the shift is
composition. D1 and D4 hold by `rfl` (the codomain of a composite is the
codomain of the second factor, definitionally), so the transports in D2
and D5 vanish and the laws are exactly the category laws. -/
def toDirectedContainer (C : SmallCat) : DirectedContainer where
  Shape := C.Obj
  Pos s := (s' : C.Obj) × C.Hom s s'
  root s := ⟨s, C.id s⟩
  sub _ p := p.1
  shift _ p q := ⟨q.1, C.comp p.2 q.2⟩
  d1 _ := rfl
  d4 _ _ _ := rfl
  d2 _ q := congrArg (Sigma.mk q.1) (C.id_comp q.2)
  d3 _ p := congrArg (Sigma.mk p.1) (C.comp_id p.2)
  d5 _ p q r := congrArg (Sigma.mk r.1) (C.assoc p.2 q.2 r.2)

end SmallCat

/-! ## The round trip, honestly

`D.toSmallCat.toDirectedContainer` is not definitionally `D`: its
positions over `s` are `Σ s', {p : D.Pos s // D.sub s p = s'}` — each
position tagged with its codomain and the proof that it lands there. The
total space of this fibration is in bijection with `D.Pos s` (a position
determines its codomain), which we prove pointwise below. Upgrading this
to an isomorphism (or equivalence) of directed containers would require a
notion of directed-container isomorphism transporting root/sub/shift
along the bijection; that is deferred, and the equivalence of categories
`DCont ≃ Cat` remains at the paper level (Ahman–Uustalu 2016, Thm 3.6). -/

namespace DirectedContainer

/-- Tag a position with its codomain: the forward half of the pointwise
round-trip bijection `D.Pos s ≃ D.toSmallCat.toDirectedContainer.Pos s`. -/
def toRoundtripPos (D : DirectedContainer) (s : D.Shape) (p : D.Pos s) :
    D.toSmallCat.toDirectedContainer.Pos s :=
  ⟨D.sub s p, p, rfl⟩

/-- Forget the codomain tag: the backward half of the bijection. -/
def ofRoundtripPos (D : DirectedContainer) (s : D.Shape)
    (p : D.toSmallCat.toDirectedContainer.Pos s) : D.Pos s :=
  p.2.val

theorem ofRoundtripPos_toRoundtripPos (D : DirectedContainer)
    (s : D.Shape) (p : D.Pos s) :
    D.ofRoundtripPos s (D.toRoundtripPos s p) = p := rfl

theorem toRoundtripPos_ofRoundtripPos (D : DirectedContainer)
    (s : D.Shape) (p : D.toSmallCat.toDirectedContainer.Pos s) :
    D.toRoundtripPos s (D.ofRoundtripPos s p) = p := by
  obtain ⟨s', q, hq⟩ := p
  subst hq
  rfl

end DirectedContainer

/-! ## Morphisms: directed-container morphisms and cofunctors

A directed-container morphism `(f, f♯)` has a covariant shape map and a
**contravariant** position map — it pulls positions over the image shape
back. It is NOT a functor of the induced categories (the position map
runs the wrong way); it is a *cofunctor*. M2 transports the inner
position along M0 exactly as D5 transports along D4. -/

/-- A **morphism of directed containers** `C ⇒ D`: a container morphism
whose position map respects root, sub, and shift.

* M0: the codomain of a pulled-back position maps to the original codomain;
* M1: the root pulls back to the root;
* M2: the shift pulls back to the shift (inner position transported
  along M0). -/
structure DContMorphism (C D : DirectedContainer) where
  onShapes : C.Shape → D.Shape
  onPos : (s : C.Shape) → D.Pos (onShapes s) → C.Pos s
  m0 : ∀ (s : C.Shape) (h : D.Pos (onShapes s)),
    onShapes (C.sub s (onPos s h)) = D.sub (onShapes s) h
  m1 : ∀ s : C.Shape, onPos s (D.root (onShapes s)) = C.root s
  m2 : ∀ (s : C.Shape) (h : D.Pos (onShapes s))
    (k : D.Pos (D.sub (onShapes s) h)),
    onPos s (D.shift (onShapes s) h k)
      = C.shift s (onPos s h)
          (onPos (C.sub s (onPos s h)) ((m0 s h).symm ▸ k))

/-- A **cofunctor** between the categories presented by two directed
containers: an object map `obj` and a backward lift of morphisms out of
`obj s` to morphisms out of `s`.

* C0: the lift preserves codomains (`cod`, i.e. `sub`);
* C1: the lift preserves identities (`idHom`, i.e. `root`);
* C2: the lift preserves composition (`after`, i.e. `shift`).

This is *literally the same data* as `DContMorphism C D`: C0/C1/C2 are
M0/M1/M2 read through the dictionary of `toSmallCat`. -/
structure Cofunctor (C D : DirectedContainer) where
  obj : C.Shape → D.Shape
  lift : (s : C.Shape) → D.Pos (obj s) → C.Pos s
  c0 : ∀ (s : C.Shape) (h : D.Pos (obj s)),
    obj (C.sub s (lift s h)) = D.sub (obj s) h
  c1 : ∀ s : C.Shape, lift s (D.root (obj s)) = C.root s
  c2 : ∀ (s : C.Shape) (h : D.Pos (obj s))
    (k : D.Pos (D.sub (obj s) h)),
    lift s (D.shift (obj s) h k)
      = C.shift s (lift s h)
          (lift (C.sub s (lift s h)) ((c0 s h).symm ▸ k))

/-- Read a directed-container morphism as a cofunctor: the identity on
data, M0/M1/M2 becoming C0/C1/C2. -/
def DContMorphism.toCofunctor {C D : DirectedContainer}
    (φ : DContMorphism C D) : Cofunctor C D where
  obj := φ.onShapes
  lift := φ.onPos
  c0 := φ.m0
  c1 := φ.m1
  c2 := φ.m2

/-- Read a cofunctor as a directed-container morphism: the identity on
data, C0/C1/C2 becoming M0/M1/M2. -/
def Cofunctor.toDContMorphism {C D : DirectedContainer}
    (φ : Cofunctor C D) : DContMorphism C D where
  onShapes := φ.obj
  onPos := φ.lift
  m0 := φ.c0
  m1 := φ.c1
  m2 := φ.c2

/-- The hom-set bijection, one way: `rfl`, because the two structures
carry identical data. -/
theorem DContMorphism.toDContMorphism_toCofunctor {C D : DirectedContainer}
    (φ : DContMorphism C D) : φ.toCofunctor.toDContMorphism = φ := rfl

/-- The hom-set bijection, the other way: also `rfl`. -/
theorem Cofunctor.toCofunctor_toDContMorphism {C D : DirectedContainer}
    (φ : Cofunctor C D) : φ.toDContMorphism.toCofunctor = φ := rfl

namespace Cofunctor

/-- The identity cofunctor. All three laws hold by `rfl`: the transport
in C2 is along `rfl` and vanishes definitionally. -/
def id (C : DirectedContainer) : Cofunctor C C where
  obj s := s
  lift _ p := p
  c0 _ _ := rfl
  c1 _ := rfl
  c2 _ _ _ := rfl

/-- The one genuinely dependent step in composing cofunctors: the inner
position `k`, transported across both factors' C0 equalities in one hop,
equals the two-hop transport. Making the shape equalities bound variables
lets `subst` fire, and the statement collapses to `rfl`. -/
theorem comp_transport {D E : DirectedContainer} (ψ : Cofunctor D E)
    {x y : D.Shape} {z : E.Shape} (e : y = x) (e₂ : ψ.obj x = z)
    (k : E.Pos z) :
    e.symm ▸ ψ.lift x (e₂.symm ▸ k)
      = ψ.lift y (((congrArg ψ.obj e).trans e₂).symm ▸ k) := by
  subst e; subst e₂; rfl

/-- Composition of cofunctors: objects compose forwards, lifts compose
backwards (`m ↦ φ.lift s (ψ.lift (φ.obj s) m)`). C0 is the two factors'
C0s glued by `congrArg`/`trans`; C1 is two rewrites; C2 is the factors'
C2s followed by `comp_transport`. -/
def comp {C D E : DirectedContainer}
    (φ : Cofunctor C D) (ψ : Cofunctor D E) : Cofunctor C E where
  obj s := ψ.obj (φ.obj s)
  lift s m := φ.lift s (ψ.lift (φ.obj s) m)
  c0 s m := (congrArg ψ.obj (φ.c0 s (ψ.lift (φ.obj s) m))).trans
    (ψ.c0 (φ.obj s) m)
  c1 s := by rw [ψ.c1, φ.c1]
  c2 s h k := by
    rw [ψ.c2, φ.c2,
      ψ.comp_transport (φ.c0 s (ψ.lift (φ.obj s) h)) (ψ.c0 (φ.obj s) h)]

/-- Left unit law: `id ∘ φ = φ`, by `rfl` (function eta plus proof
irrelevance for the law fields). -/
theorem id_comp {C D : DirectedContainer} (φ : Cofunctor C D) :
    comp (id C) φ = φ := rfl

/-- Right unit law: `φ ∘ id = φ`, by `rfl`. -/
theorem comp_id {C D : DirectedContainer} (φ : Cofunctor C D) :
    comp φ (id D) = φ := rfl

/-- Associativity of cofunctor composition, by `rfl`: the data composes
strictly and the transported laws are proof-irrelevant. -/
theorem comp_assoc {B C D E : DirectedContainer}
    (φ : Cofunctor B C) (ψ : Cofunctor C D) (χ : Cofunctor D E) :
    comp (comp φ ψ) χ = comp φ (comp ψ χ) := rfl

end Cofunctor

namespace DContMorphism

/-- The identity directed-container morphism, defined by transporting the
identity cofunctor across the (`rfl`) hom-set bijection — the two
structures carry the same data, so this *is* the identity on data. -/
def id (C : DirectedContainer) : DContMorphism C C :=
  (Cofunctor.id C).toDContMorphism

/-- Composition of directed-container morphisms, via the bijection: the
composite pulls positions back through `ψ` and then through `φ`. -/
def comp {C D E : DirectedContainer}
    (φ : DContMorphism C D) (ψ : DContMorphism D E) : DContMorphism C E :=
  (φ.toCofunctor.comp ψ.toCofunctor).toDContMorphism

/-- Φ = `toCofunctor` preserves identities, by `rfl`. -/
theorem toCofunctor_id (C : DirectedContainer) :
    (id C).toCofunctor = Cofunctor.id C := rfl

/-- Φ = `toCofunctor` preserves composition, by `rfl`. Together with the
`rfl` hom-set bijection and identity-on-objects, this makes Φ an
isomorphism between the category of directed containers and the category
of their presented categories and cofunctors. -/
theorem toCofunctor_comp {C D E : DirectedContainer}
    (φ : DContMorphism C D) (ψ : DContMorphism D E) :
    (φ.comp ψ).toCofunctor = φ.toCofunctor.comp ψ.toCofunctor := rfl

end DContMorphism

end Containers
