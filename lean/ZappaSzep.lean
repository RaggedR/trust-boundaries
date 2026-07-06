/-!
# The Zappa–Szép product of monoids: cocycle axioms ⟺ associativity

This file formalises the algebraic core behind the *pairwise Zappa–Szép
criterion* (MacBeth, `proofs/2026-06-10-zs-criterion-cocycle.tex`): given two
monoids `L`, `G` together with a left action `▷ : G → L → L` and a *restriction*
`◁ : G → L → G`, the binary operation
`(a, g) * (b, h) = (a · (g ▷ b), (g ◁ b) · h)`
on `L × G` is **associative if and only if** the four Brin/Zappa–Szép cocycle
axioms `ZS1`–`ZS4` hold (assuming the four unit-compatibility conditions, which
are exactly what make `(1, 1)` a two-sided unit).

The proof is purely equational. The forward direction (`ZS1`–`ZS4` ⟹ assoc)
uses no unit laws; the converse extracts each axiom by specialising the
associativity instance at units, exactly as in the informal proof — the
`L`-coordinate of one associativity instance splits into `ZS1 + ZS2`, the
`G`-coordinate into `ZS3 + ZS4`.

Everything is `Type`-level core Lean (no Mathlib), matching the style of
`Containers/Basic.lean`.
-/

namespace Containers

namespace ZappaSzep

/-- A **matched pair** of monoids: two monoids `L` (written multiplicatively
`mulL`, unit `oneL`) and `G` (`mulG`, `oneG`), a left action `lact : G → L → L`
(notation `▷`) and a restriction `ract : G → L → G` (notation `◁`), together with
the four unit-compatibility conditions that make `(oneL, oneG)` a unit for the
Zappa–Szép product.

No cocycle axiom is assumed here: `ZS1`–`ZS4` are the *content* of the main
theorem, so they are stated separately as predicates on a `MatchedPair`. -/
structure MatchedPair where
  /-- Carrier of the first monoid. -/
  L : Type
  /-- Carrier of the second monoid. -/
  G : Type
  /-- Multiplication of `L`. -/
  mulL : L → L → L
  /-- Unit of `L`. -/
  oneL : L
  /-- Multiplication of `G`. -/
  mulG : G → G → G
  /-- Unit of `G`. -/
  oneG : G
  /-- Associativity of `L`. -/
  mulL_assoc : ∀ a b c, mulL (mulL a b) c = mulL a (mulL b c)
  /-- Left unit law of `L`. -/
  oneL_mul : ∀ a, mulL oneL a = a
  /-- Right unit law of `L`. -/
  mul_oneL : ∀ a, mulL a oneL = a
  /-- Associativity of `G`. -/
  mulG_assoc : ∀ g h k, mulG (mulG g h) k = mulG g (mulG h k)
  /-- Left unit law of `G`. -/
  oneG_mul : ∀ g, mulG oneG g = g
  /-- Right unit law of `G`. -/
  mul_oneG : ∀ g, mulG g oneG = g
  /-- The left action `▷ : G → L → L`. -/
  lact : G → L → L
  /-- The restriction `◁ : G → L → G`. -/
  ract : G → L → G
  /-- `oneG` acts trivially on the left (`U1a`). -/
  lact_oneG : ∀ a, lact oneG a = a
  /-- `oneG` restricts trivially (`U1b`). -/
  ract_oneG : ∀ a, ract oneG a = oneG
  /-- Acting on `oneL` is `oneL` (`U2a`). -/
  lact_oneL : ∀ g, lact g oneL = oneL
  /-- Restricting along `oneL` is the identity (`U2b`). -/
  ract_oneL : ∀ g, ract g oneL = g

namespace MatchedPair

variable (P : MatchedPair)

/-- The Zappa–Szép product operation on `L × G`:
`(a, g) * (b, h) = (a · (g ▷ b), (g ◁ b) · h)`. -/
def mul (x y : P.L × P.G) : P.L × P.G :=
  (P.mulL x.1 (P.lact x.2 y.1), P.mulG (P.ract x.2 y.1) y.2)

/-- `ZS1`: the left action is a crossed homomorphism in its `L`-argument,
`g ▷ (a · b) = (g ▷ a) · ((g ◁ a) ▷ b)`. -/
def ZS1 : Prop :=
  ∀ (g : P.G) (a b : P.L),
    P.lact g (P.mulL a b) = P.mulL (P.lact g a) (P.lact (P.ract g a) b)

/-- `ZS2`: the left action is an action of `G`, `(g · h) ▷ a = g ▷ (h ▷ a)`. -/
def ZS2 : Prop :=
  ∀ (g h : P.G) (a : P.L),
    P.lact (P.mulG g h) a = P.lact g (P.lact h a)

/-- `ZS3`: the restriction is a crossed homomorphism in its `G`-argument,
`(g · h) ◁ a = (g ◁ (h ▷ a)) · (h ◁ a)`. -/
def ZS3 : Prop :=
  ∀ (g h : P.G) (a : P.L),
    P.ract (P.mulG g h) a = P.mulG (P.ract g (P.lact h a)) (P.ract h a)

/-- `ZS4`: the restriction is a right action of `L`, `g ◁ (a · b) = (g ◁ a) ◁ b`. -/
def ZS4 : Prop :=
  ∀ (g : P.G) (a b : P.L),
    P.ract g (P.mulL a b) = P.ract (P.ract g a) b

/-- Associativity of the Zappa–Szép product. -/
def Assoc : Prop :=
  ∀ x y z : P.L × P.G, P.mul (P.mul x y) z = P.mul x (P.mul y z)

/-- **Forward direction.** The four cocycle axioms imply associativity of the
Zappa–Szép product. The `L`-coordinate of the associativity instance follows from
`ZS1` (re-associating the action over a product) together with `ZS2` (the action
law); the `G`-coordinate from `ZS3` and `ZS4`. No unit law is used here. -/
theorem assoc_of_zs (h1 : P.ZS1) (h2 : P.ZS2) (h3 : P.ZS3) (h4 : P.ZS4) :
    P.Assoc := by
  rintro ⟨a, g⟩ ⟨b, h⟩ ⟨c, k⟩
  simp only [mul, Prod.mk.injEq]
  refine ⟨?_, ?_⟩
  · rw [P.mulL_assoc, h1 g b (P.lact h c), h2 (P.ract g b) h c]
  · rw [h3 (P.ract g b) h c, P.mulG_assoc, h4 g b (P.lact h c)]

/-- **Converse direction.** Associativity of the Zappa–Szép product implies each
cocycle axiom. Each axiom is recovered by specialising the associativity instance
at units and reading off one coordinate: `ZS1`, `ZS2` from the `L`-coordinate and
`ZS3`, `ZS4` from the `G`-coordinate. The unit-compatibility fields of
`MatchedPair` are exactly what collapse the specialised instances. -/
theorem zs_of_assoc (H : P.Assoc) :
    P.ZS1 ∧ P.ZS2 ∧ P.ZS3 ∧ P.ZS4 := by
  refine ⟨?_, ?_, ?_, ?_⟩
  · -- ZS1: L-coordinate at `x = (1, g)`, `y = (a, 1)`, `z = (b, 1)`.
    intro g a b
    have e := H (P.oneL, g) (a, P.oneG) (b, P.oneG)
    simp only [mul, P.oneL_mul, P.mul_oneG, P.lact_oneG, Prod.mk.injEq] at e
    exact e.1.symm
  · -- ZS2: L-coordinate at `x = (1, g)`, `y = (1, h)`, `z = (a, 1)`.
    intro g h a
    have e := H (P.oneL, g) (P.oneL, h) (a, P.oneG)
    simp only [mul, P.lact_oneL, P.ract_oneL, P.oneL_mul, Prod.mk.injEq] at e
    exact e.1
  · -- ZS3: G-coordinate at `x = (1, g)`, `y = (1, h)`, `z = (a, 1)`.
    intro g h a
    have e := H (P.oneL, g) (P.oneL, h) (a, P.oneG)
    simp only [mul, P.ract_oneL, P.oneL_mul, P.mul_oneG, Prod.mk.injEq] at e
    exact e.2
  · -- ZS4: G-coordinate at `x = (1, g)`, `y = (a, 1)`, `z = (b, 1)`.
    intro g a b
    have e := H (P.oneL, g) (a, P.oneG) (b, P.oneG)
    simp only [mul, P.mul_oneG, P.lact_oneG, P.ract_oneG, Prod.mk.injEq] at e
    exact e.2.symm

/-- **Main theorem.** For a matched pair of monoids, the Zappa–Szép product is
associative if and only if the four Brin/Zappa–Szép cocycle axioms hold. -/
theorem zs_iff_assoc :
    (P.ZS1 ∧ P.ZS2 ∧ P.ZS3 ∧ P.ZS4) ↔ P.Assoc :=
  ⟨fun ⟨h1, h2, h3, h4⟩ => P.assoc_of_zs h1 h2 h3 h4, P.zs_of_assoc⟩

end MatchedPair

/-- The **direct product** of `(Nat, +, 0)` with itself, with trivial actions
(`g ▷ a = a`, `g ◁ a = g`). This is a matched pair, and a sanity check that
`MatchedPair` is inhabited and the cocycle axioms `ZS1`–`ZS4` are genuinely
satisfiable. -/
def natDirect : MatchedPair where
  L := Nat
  G := Nat
  mulL := Nat.add
  oneL := 0
  mulG := Nat.add
  oneG := 0
  mulL_assoc := fun a b c => Nat.add_assoc a b c
  oneL_mul := fun a => Nat.zero_add a
  mul_oneL := fun a => Nat.add_zero a
  mulG_assoc := fun a b c => Nat.add_assoc a b c
  oneG_mul := fun a => Nat.zero_add a
  mul_oneG := fun a => Nat.add_zero a
  lact := fun _ a => a
  ract := fun g _ => g
  lact_oneG := fun _ => rfl
  ract_oneG := fun _ => rfl
  lact_oneL := fun _ => rfl
  ract_oneL := fun _ => rfl

/-- The trivial actions satisfy all four cocycle axioms, so `zs_iff_assoc` yields
associativity of the underlying product monoid. -/
example : natDirect.Assoc :=
  natDirect.zs_iff_assoc.mp
    ⟨fun _ _ _ => rfl, fun _ _ _ => rfl, fun _ _ _ => rfl, fun _ _ _ => rfl⟩

end ZappaSzep

end Containers
