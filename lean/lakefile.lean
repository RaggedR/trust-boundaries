import Lake
open Lake DSL

package «trust-boundaries» where
  leanOptions := #[
    ⟨`autoImplicit, false⟩
  ]

/- Only `Trust` is exposed as a library root for now. The other .lean
files in this directory predate the lakefile and are built/checked
individually; add them as roots when a downstream package needs them. -/
@[default_target]
lean_lib «Trust» where
  roots := #[`Trust]
