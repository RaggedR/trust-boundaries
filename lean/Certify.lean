import Trust

/-!
# Certification

`#print axioms` on the trust-level algebra. CI runs this file and fails if the
output mentions `sorryAx` (a `sorry` reached the result) or if any report is missing
(a name that failed to resolve — a vacuous "proof"). A clean report lists only
Lean's foundational axioms, or none.

Scope. `Trust` is the self-contained (no-Mathlib) trust-level lattice that the rest
of the development is built on: a conservative meet (`cmin`) and join (`cmax`), and
list aggregation by `cmax`. These laws — meet is a greatest lower bound, join is one
of its arguments, and an aggregate never exceeds the running maximum and is attained
— are what make "take the least-trusted input" and "propagate the boundary"
well-defined. They are certified here; the rest of the repository is `sorry`-free by
static scan but built module-by-module rather than as one default target.
-/

-- Conservative meet is the greatest lower bound of the two trust levels.
#print axioms Containers.Trust.le_cmin
-- Conservative join returns one of its two arguments.
#print axioms Containers.Trust.cmax_cases
-- List aggregation by cmax: every element is ≤ the fold, and the fold is attained.
#print axioms Containers.Trust.le_foldr_max
#print axioms Containers.Trust.foldr_max_cases
