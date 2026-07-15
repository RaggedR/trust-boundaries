import Containers.Directed

/-!
# Morphisms of directed containers are cofunctors: `DCont ≅ Cof`

This file builds on `Containers.Directed`. It formalises the *morphism level* of
the directed-container/small-category dictionary (Ahman–Chapman–Uustalu;
Shapiro–Spivak): the morphisms native to directed containers are **cofunctors**
(retrofunctors), *not* functors.

## The dictionary

A directed container `C` presents a small category `cat C`:

* objects are shapes `C.Shape`;
* a morphism out of `s` is a position `p : C.Pos s`, with codomain `s ↓ p`
  (`DirectedContainer.cod`);
* the identity at `s` is the root `o(s)` (`DirectedContainer.idHom`);
* composition `q ∘ p` is the shift `p ⊕ q` (`DirectedContainer.after`).

## The variance point

A container morphism `(f, f♯)` carries a shape map `f : C.Shape → D.Shape`
*forward* but a position map `f♯ : D.Pos (f s) → C.Pos s` *backward*. A functor
acts on hom-sets covariantly (`P s → P' (f s)`), so the two variances are
opposite and a directed-container morphism cannot be a functor. With the
directed-structure compatibility laws spelled out (M0/M1/M2), `(f, f♯)` is
exactly a **cofunctor** of the presented categories (C0/C1/C2).

## Main results

* `DContMorphism C D` — morphism of directed containers (laws M0/M1/M2). The
  shift law M2 transports the position `k` along the codomain law M0, mirroring
  how D5 transports along D4 in `Containers.Directed`.
* `Cofunctor C D` — cofunctor of the presented categories (laws C0/C1/C2),
  phrased with the dictionary vocabulary `cod`/`idHom`/`after`.
* `DContMorphism.toCofunctor` / `Cofunctor.toDContMorphism` with
  `toCofunctor_toDContMorphism` and `toDContMorphism_toCofunctor`: the two
  structures carry **identical data** — the hom-set bijection `DCont ≅ Cof`,
  both directions, no `sorry`. (M0/M1/M2 and C0/C1/C2 are definitionally equal
  under the dictionary, so the round-trips are `rfl`.)
* `Cofunctor.id` and `Cofunctor.comp` with `Cofunctor.id_comp`,
  `Cofunctor.comp_id`, `Cofunctor.comp_assoc`: cofunctors form a **strict**
  category `Cof` (the laws hold definitionally).
* `DContMorphism.toCofunctor_id` and `DContMorphism.toCofunctor_comp`: the
  assignment `Φ = (·).toCofunctor` preserves identities and composition. Being
  identity-on-objects, bijective on every hom-set, and functorial, `Φ` is an
  isomorphism of categories `DCont ≅ Cof`.

The genuinely dependent content is `Cofunctor.comp_transport`, isolating the
transport that makes the composite shift law `c2` typecheck.

Everything is `Type`-level, Lean 4 core, no Mathlib.
-/

namespace Containers

namespace DirectedContainer

/-- The identity morphism at `s` in the presented category: the root `o(s)`. -/
def idHom (C : DirectedContainer) (s : C.Shape) : C.Pos s := C.root s

/-- The codomain of a morphism `p` out of `s`: the sub-shape `s ↓ p`. -/
def cod (C : DirectedContainer) (s : C.Shape) (p : C.Pos s) : C.Shape := C.sub s p

/-- Composition `q ∘ p` in the presented category, with `p` out of `s` and `q`
out of `cod p`: the shift `p ⊕ q`. -/
def after (C : DirectedContainer) (s : C.Shape) (p : C.Pos s)
    (q : C.Pos (C.sub s p)) : C.Pos s := C.shift s p q

end DirectedContainer

open DirectedContainer

/-- A **morphism of directed containers** `C → D`: a container morphism
`(f, f♯)` — a shape map `f` and a *contravariant* position map `f♯` — satisfying
the directed-structure laws M0/M1/M2. The shift law `m2` transports the position
`k` along `m0`, exactly as D5 transports along D4. -/
structure DContMorphism (C D : DirectedContainer) where
  /-- The forward map on shapes. -/
  f : C.Shape → D.Shape
  /-- The contravariant map on positions, `D.Pos (f s) → C.Pos s`. -/
  fSharp : (s : C.Shape) → D.Pos (f s) → C.Pos s
  /-- M0: `f` sends the sub-shape under `f♯ h` to the sub-shape under `h`. -/
  m0 : ∀ (s : C.Shape) (h : D.Pos (f s)),
    f (C.sub s (fSharp s h)) = D.sub (f s) h
  /-- M1: `f♯` sends the root to the root. -/
  m1 : ∀ (s : C.Shape), fSharp s (D.root (f s)) = C.root s
  /-- M2: `f♯` is a homomorphism for the shift (the right factor transported
  along M0). -/
  m2 : ∀ (s : C.Shape) (h : D.Pos (f s)) (k : D.Pos (D.sub (f s) h)),
    fSharp s (D.shift (f s) h k)
      = C.shift s (fSharp s h) (fSharp (C.sub s (fSharp s h)) ((m0 s h).symm ▸ k))

/-- A **cofunctor** `cat C → cat D` of the presented categories: an object map
`obj` together with a *lift* sending a morphism `h` out of `obj s` to a morphism
out of `s`, subject to the cofunctor laws C0/C1/C2 (codomain, unit, composition).
Read through the dictionary `cod`/`idHom`/`after`, this is definitionally a
`DContMorphism`. -/
structure Cofunctor (C D : DirectedContainer) where
  /-- The object map. -/
  obj : C.Shape → D.Shape
  /-- The lift: a morphism out of `obj s` becomes a morphism out of `s`. -/
  lift : (s : C.Shape) → D.Pos (obj s) → C.Pos s
  /-- C0 (codomain): the lift preserves codomains over `obj`. -/
  c0 : ∀ (s : C.Shape) (h : D.Pos (obj s)),
    obj (C.cod s (lift s h)) = D.cod (obj s) h
  /-- C1 (unit): the lift sends the identity to the identity. -/
  c1 : ∀ (s : C.Shape), lift s (D.idHom (obj s)) = C.idHom s
  /-- C2 (composition): the lift is functorial for composition (the right factor
  transported along C0). -/
  c2 : ∀ (s : C.Shape) (h : D.Pos (obj s)) (k : D.Pos (D.cod (obj s) h)),
    lift s (D.after (obj s) h k)
      = C.after s (lift s h) (lift (C.cod s (lift s h)) ((c0 s h).symm ▸ k))

/-- A directed-container morphism *is* a cofunctor: the same data, with M0/M1/M2
read as C0/C1/C2 under the dictionary. -/
def DContMorphism.toCofunctor {C D : DirectedContainer} (m : DContMorphism C D) :
    Cofunctor C D :=
  ⟨m.f, m.fSharp, m.m0, m.m1, m.m2⟩

/-- A cofunctor *is* a directed-container morphism: the inverse assignment. -/
def Cofunctor.toDContMorphism {C D : DirectedContainer} (φ : Cofunctor C D) :
    DContMorphism C D :=
  ⟨φ.obj, φ.lift, φ.c0, φ.c1, φ.c2⟩

/-- Round-trip, one direction: `toCofunctor` then `toDContMorphism` is the
identity. Half of the hom-set bijection `DCont ≅ Cof`. -/
theorem toCofunctor_toDContMorphism {C D : DirectedContainer} (m : DContMorphism C D) :
    m.toCofunctor.toDContMorphism = m := rfl

/-- Round-trip, other direction: `toDContMorphism` then `toCofunctor` is the
identity. Together with `toCofunctor_toDContMorphism` this is the hom-set
bijection `DCont ≅ Cof`. -/
theorem toDContMorphism_toCofunctor {C D : DirectedContainer} (φ : Cofunctor C D) :
    φ.toDContMorphism.toCofunctor = φ := rfl

/-- The transport identity underlying composition of cofunctor lifts.
Transporting `ψ.lift x (e₂.symm ▸ k)` backward along `e : y = x` equals lifting
at the new index `y` with the input transported along the composite equality.
This is the dependent bookkeeping that makes the composite shift law `c2`
typecheck; proved by clearing both shape equalities. -/
theorem Cofunctor.comp_transport {D E : DirectedContainer} (ψ : Cofunctor D E)
    {x y : D.Shape} (e : y = x) {z : E.Shape} (e₂ : ψ.obj x = z) (k : E.Pos z) :
    e.symm ▸ (ψ.lift x (e₂.symm ▸ k))
      = ψ.lift y (((congrArg ψ.obj e).trans e₂).symm ▸ k) := by
  subst e; subst e₂; rfl

/-- The **identity cofunctor** on `cat C`. -/
def Cofunctor.id (C : DirectedContainer) : Cofunctor C C where
  obj := fun s => s
  lift := fun _ p => p
  c0 := fun _ _ => rfl
  c1 := fun _ => rfl
  c2 := fun _ _ _ => rfl

/-- **Composition of cofunctors**: `φ : cat C → cat D` then `ψ : cat D → cat E`,
giving `cat C → cat E`. Object maps compose forward; lifts compose backward. The
composite codomain and unit laws chain the factors' laws; the composite shift law
needs `Cofunctor.comp_transport`. -/
def Cofunctor.comp {C D E : DirectedContainer} (φ : Cofunctor C D) (ψ : Cofunctor D E) :
    Cofunctor C E where
  obj := fun s => ψ.obj (φ.obj s)
  lift := fun s m => φ.lift s (ψ.lift (φ.obj s) m)
  c0 := fun s h => (congrArg ψ.obj (φ.c0 s (ψ.lift (φ.obj s) h))).trans (ψ.c0 (φ.obj s) h)
  c1 := fun s => (congrArg (φ.lift s) (ψ.c1 (φ.obj s))).trans (φ.c1 s)
  c2 := by
    intro s h k
    rw [ψ.c2 (φ.obj s) h k, φ.c2 s (ψ.lift (φ.obj s) h) _,
      Cofunctor.comp_transport ψ (φ.c0 s (ψ.lift (φ.obj s) h)) (ψ.c0 (φ.obj s) h) k]

/-- Left unit law for `Cof`: the identity cofunctor is a left unit. Holds
definitionally. -/
theorem Cofunctor.id_comp {C D : DirectedContainer} (φ : Cofunctor C D) :
    (Cofunctor.id C).comp φ = φ := rfl

/-- Right unit law for `Cof`: the identity cofunctor is a right unit. Holds
definitionally. -/
theorem Cofunctor.comp_id {C D : DirectedContainer} (φ : Cofunctor C D) :
    φ.comp (Cofunctor.id D) = φ := rfl

/-- Associativity of cofunctor composition. Holds definitionally: `Cof` is a
*strict* category. -/
theorem Cofunctor.comp_assoc {C D E F : DirectedContainer}
    (φ : Cofunctor C D) (ψ : Cofunctor D E) (χ : Cofunctor E F) :
    (φ.comp ψ).comp χ = φ.comp (ψ.comp χ) := rfl

/-- The identity morphism of directed containers, transported from `Cofunctor.id`. -/
def DContMorphism.id (C : DirectedContainer) : DContMorphism C C :=
  (Cofunctor.id C).toDContMorphism

/-- Composition of directed-container morphisms, transported from `Cofunctor.comp`. -/
def DContMorphism.comp {C D E : DirectedContainer}
    (m : DContMorphism C D) (n : DContMorphism D E) : DContMorphism C E :=
  (m.toCofunctor.comp n.toCofunctor).toDContMorphism

/-- `Φ = (·).toCofunctor` preserves identities. -/
theorem DContMorphism.toCofunctor_id (C : DirectedContainer) :
    (DContMorphism.id C).toCofunctor = Cofunctor.id C := rfl

/-- `Φ = (·).toCofunctor` preserves composition. With the hom-set bijection
(`toCofunctor_toDContMorphism`, `toDContMorphism_toCofunctor`) and being the
identity on objects, `Φ` is an isomorphism of categories `DCont ≅ Cof`. -/
theorem DContMorphism.toCofunctor_comp {C D E : DirectedContainer}
    (m : DContMorphism C D) (n : DContMorphism D E) :
    (m.comp n).toCofunctor = m.toCofunctor.comp n.toCofunctor := rfl

end Containers
