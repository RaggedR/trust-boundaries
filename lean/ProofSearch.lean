import Containers.Directed

/-!
# Proof search trees as a directed container

Binary search trees form a directed container where leaves are dead ends
(positions with no further moves) and nodes are branching points (choices of
tactic). The directed container structure comes from path concatenation:

* `root` = the empty path (`here`)
* `sub` = the sub-tree at a path
* `shift` = concatenation of paths

All five directed container laws (D1–D5) are verified by structural recursion
on paths. The induced comonad has:

* `extract ⟨t, v⟩ = v here` — read the label at the root
* `duplicate ⟨t, v⟩ = ⟨t, fun p => ⟨t.sub p, fun q => v (t.shift p q)⟩⟩`
  — at every node, replace the label with the full sub-search from that point,
  including all dead ends below it

A dead end is a leaf: a position `p` where `SPos (t.sub p) ≃ Unit` (only `here`
is available). The comonad laws guarantee that dead ends compose coherently at
arbitrary depth — the search history is self-consistent no matter where you
zoom in.

A coKleisli morphism `W(X) → Y` is a **proof strategy**: a function that can
inspect the entire search tree (including dead ends) to decide what to produce.
-/

namespace Containers

/-- A binary search tree shape. `leaf` is a terminal node (dead end or success);
`node l r` branches into two sub-searches. The distinction between dead end
and success lives in the labelling `X`, not in the shape. -/
inductive STree where
  | leaf : STree
  | node : STree → STree → STree

/-- A position (path) in a search tree. `here` is the root; `left`/`right`
descend into the corresponding sub-tree. For a `leaf`, the only position is
`here` — this is what makes it a dead end. -/
inductive SPos : STree → Type where
  | here : SPos t
  | left : SPos l → SPos (.node l r)
  | right : SPos r → SPos (.node l r)

/-- The sub-tree at a given position. At `here`, the sub-tree is the whole tree.
At `left p` or `right p`, we descend into the corresponding child. -/
def STree.sub : (t : STree) → SPos t → STree
  | t, .here => t
  | .node l _, .left p => l.sub p
  | .node _ r, .right p => r.sub p

/-- Shift: embed a position in a sub-tree back into the original tree. This is
path concatenation — position `q` in the sub-tree at `p`, viewed as a
position in the whole tree. -/
def STree.shift : (t : STree) → (p : SPos t) → SPos (t.sub p) → SPos t
  | _, .here, q => q
  | .node l _, .left p, q => .left (l.shift p q)
  | .node _ r, .right p, q => .right (r.shift p q)

/-- **D3**: shifting by the root of the sub-tree recovers the original position.
This is the right identity law: `p ⊕ o(s ↓ p) = p`, i.e. concatenating the
empty path on the right is the identity. -/
def STree.shift_root : (t : STree) → (p : SPos t) →
    t.shift p .here = p
  | _, .here => rfl
  | .node l _, .left p => congrArg SPos.left (l.shift_root p)
  | .node _ r, .right p => congrArg SPos.right (r.shift_root p)

/-- **D4**: sub-trees nest along the shift. `(s ↓ (p ⊕ q)) = (s ↓ p) ↓ q`,
i.e. the sub-tree at a concatenated path equals descending twice. -/
def STree.sub_shift : (t : STree) → (p : SPos t) → (q : SPos (t.sub p)) →
    t.sub (t.shift p q) = (t.sub p).sub q
  | _, .here, _ => rfl
  | .node l _, .left p, q => l.sub_shift p q
  | .node _ r, .right p, q => r.sub_shift p q

/-- **D5**: the shift is associative (with transport along D4).
`(p ⊕ q) ⊕ r = p ⊕ (q ⊕ r)`, i.e. path concatenation is associative.

The transport `(sub_shift ..).symm ▸ r` is needed because `r` lives in the
fibre over `(t.sub p).sub q`, while the LHS needs it in the fibre over
`t.sub (t.shift p q)` — D4 witnesses that these are equal. -/
def STree.shift_assoc : (t : STree) → (p : SPos t) → (q : SPos (t.sub p)) →
    (r : SPos ((t.sub p).sub q)) →
    t.shift (t.shift p q) ((t.sub_shift p q).symm ▸ r) =
      t.shift p ((t.sub p).shift q r)
  | _, .here, _, _ => rfl
  | .node l _, .left p, q, r => congrArg SPos.left (l.shift_assoc p q r)
  | .node _ r', .right p, q, r => congrArg SPos.right (r'.shift_assoc p q r)

/-- The directed container of binary proof search trees. Shapes are tree
structures; positions are paths; the comonad navigates the search space
while preserving dead ends at every depth.

D1 and D2 are `rfl` because `sub t here = t` and `shift t here q = q`
hold definitionally (they are the first cases of the structural recursion).
D3–D5 are proved by structural recursion on paths. -/
def proofSearch : DirectedContainer where
  Shape := STree
  Pos := SPos
  root := fun _ => .here
  sub := STree.sub
  shift := STree.shift
  d1 := fun _ => rfl
  d4 := STree.sub_shift
  d2 := fun _ _ => rfl
  d3 := STree.shift_root
  d5 := STree.shift_assoc

end Containers
