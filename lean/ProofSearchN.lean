import Containers.Directed

/-!
# N-ary proof search trees as a directed container

This generalizes `ProofSearch.lean` from binary trees to **finitely-branching
rose trees** (arbitrary arity at each node). The directed container structure is
identical in spirit: shapes are tree structures, positions are paths from root to
a node, and the comonad operations come from path concatenation.

## Encoding choice

We use `RTree := node (n : Nat) (children : Fin n → RTree)` rather than the
more natural `node (children : List RTree)`. The `Fin n` encoding avoids
nested-inductive complications (List wraps the recursive occurrence) and lets
structural recursion work directly on `RTree` and `RPos` without well-founded
recursion or fuel arguments.

A leaf (dead end or success) is `node 0 f` where `f : Fin 0 → RTree` is vacuous.
The only position in a leaf is `here`.

## Comonad reading

The induced comonad on `Ext ⟨RTree, RPos⟩` has:

* `extract ⟨t, v⟩ = v here` — read the label at the root
* `duplicate ⟨t, v⟩ = ⟨t, fun p => ⟨t.sub p, fun q => v (t.shift p q)⟩⟩`
  — at every node, replace the label with the full sub-search from that point

A coKleisli morphism `W(X) → Y` is a proof strategy that can inspect the
entire (arbitrarily-branching) search tree to decide what to produce.

## Relationship to STree

`STree` embeds into `RTree`: a leaf maps to `node 0 !` and `node l r` maps to
`node 2 ![l', r']` (where `l'`, `r'` are the recursive images and `![]` is
`Fin`-vector notation). This is not a strict sub-case since `STree` forces
exactly 0 or 2 children at every node, while `RTree` allows any natural number.
-/

namespace Containers

/-- A finitely-branching rose tree. Each node carries its branching factor `n`
and a function assigning a child tree to each index `i : Fin n`. A leaf is
`node 0 f` (vacuous `f`). -/
inductive RTree where
  | node : (n : Nat) → (Fin n → RTree) → RTree

/-- A position (path) in a rose tree. `here` is the root; `child i p` descends
into the `i`-th child and continues along path `p`. For a leaf (`n = 0`), the
only position is `here` since there are no valid `i : Fin 0`. -/
inductive RPos : RTree → Type where
  | here : RPos t
  | child : (i : Fin n) → RPos (children i) → RPos (.node n children)

/-- The sub-tree at a given position. At `here`, the sub-tree is the whole tree.
At `child i p`, we descend into child `i` and recurse. -/
def RTree.sub : (t : RTree) → RPos t → RTree
  | t, .here => t
  | .node _ children, .child i p => (children i).sub p

/-- Shift: embed a position in a sub-tree back into the original tree. This is
path concatenation — position `q` in the sub-tree at `p`, viewed as a position
in the whole tree. -/
def RTree.shift : (t : RTree) → (p : RPos t) → RPos (t.sub p) → RPos t
  | _, .here, q => q
  | .node _ children, .child i p, q => .child i ((children i).shift p q)

/-- **D3**: shifting by the root of the sub-tree recovers the original position.
Right identity: `p ++ here = p`. -/
def RTree.shift_root : (t : RTree) → (p : RPos t) →
    t.shift p .here = p
  | _, .here => rfl
  | .node _ children, .child i p => congrArg (RPos.child i) ((children i).shift_root p)

/-- **D4**: sub-trees nest along the shift. `sub t (shift t p q) = sub (sub t p) q`. -/
def RTree.sub_shift : (t : RTree) → (p : RPos t) → (q : RPos (t.sub p)) →
    t.sub (t.shift p q) = (t.sub p).sub q
  | _, .here, _ => rfl
  | .node _ children, .child i p, q => (children i).sub_shift p q

/-- **D5**: shift is associative (with transport along D4).
`shift t (shift t p q) (transport r) = shift t p (shift (sub t p) q r)`. -/
def RTree.shift_assoc : (t : RTree) → (p : RPos t) → (q : RPos (t.sub p)) →
    (r : RPos ((t.sub p).sub q)) →
    t.shift (t.shift p q) ((t.sub_shift p q).symm ▸ r) =
      t.shift p ((t.sub p).shift q r)
  | _, .here, _, _ => rfl
  | .node _ children, .child i p, q, r =>
      congrArg (RPos.child i) ((children i).shift_assoc p q r)

/-- The directed container of N-ary proof search trees. Shapes are rose trees;
positions are paths; the comonad navigates the search space while preserving
dead ends at every depth.

D1 and D2 are `rfl` because `sub t here = t` and `shift t here q = q` hold
definitionally. D3-D5 are proved by structural recursion on paths. -/
def proofSearchN : DirectedContainer where
  Shape := RTree
  Pos := RPos
  root := fun _ => .here
  sub := RTree.sub
  shift := RTree.shift
  d1 := fun _ => rfl
  d4 := RTree.sub_shift
  d2 := fun _ _ => rfl
  d3 := RTree.shift_root
  d5 := RTree.shift_assoc

end Containers
