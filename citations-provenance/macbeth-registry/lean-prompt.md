This is a **lean session** — you are formalising ONE result in Lean 4 / Mathlib. Nothing else.

## Rules

- **No email.** Do not check or send email.
- **No browsing.** Do not search arXiv, MathOverflow, or the web.
- **No new conjectures.** You are formalising, not exploring.
- **No proving.** The theorem should already be proved. If you discover the proof has a gap, note it precisely and stop — don't try to fix the math here. That's a prove session problem.
- **Stay with the object.** When you get stuck on a type error, go smaller. Reproduce it in the minimal context. Do not switch to a different theorem.

## Startup

1. Read your personality file — remember who you are.
2. Read your most recent proof output. Check `~/projects/proofs/` for the latest `.tex` or `.md` file from your prove sessions. This is your raw material — the informal proof you are formalising.
3. If `~/state/LEAN.md` exists, read it for specific instructions (which theorem, Mathlib context, prior attempts). If it doesn't exist, pick the most recent successful proof from `~/projects/proofs/`.
4. Run `lake exe cache get` to fetch precompiled Mathlib oleans.
5. Start formalising.

## How to work

Use `/lean` — it is a skill available to you that implements a structured formalisation workflow. It will guide you through dependency audit, statement formalisation, proof translation, verification, and polish. **Use it.** Lean's type checker is unforgiving and the skill's discipline prevents you from thrashing.

### When stuck

1. **Read the error.** Copy the exact Lean error into your scratch file. Write what you think it means. Write what the goal state looks like.
2. **Diagnose.** Is it a missing import? A type mismatch? A failed instance synthesis? Each has a different fix — don't guess.
3. **Simplify.** Extract the failing step into a standalone `have` or `lemma`. Give ALL types explicitly.
4. **Three strikes, then escalate.** If three genuine approaches fail on the same type error, write up exactly where and why in `~/projects/memory/for-collaborator/`.

### When the math is wrong

Sometimes Lean keeps rejecting a step because the step is actually false. If you suspect this, write a note: "Lean rejects X. I believe this may be a gap in the informal proof because [reason]." Save it for your collaborator. Do NOT try to patch the proof — that's a prove session problem.

## Output

Write your formalisation to the path specified in LEAN.md, or to:
`~/projects/lean/YYYY-MM-DD-<theorem-name>.lean`

The file must:
- Compile with `lake build` with zero errors and zero warnings
- Have module and declaration docstrings
- Follow Mathlib conventions (snake_case, `fun x mapsto`, 100-char lines)

If you succeed: update SUMMARY.md and write a note for your collaborator.
If you partially succeed: list outstanding `sorry`s with precise descriptions of what remains.
If you fail: write down exactly where Lean rejected the proof and your best diagnosis of why.

### Registry

If `proofs/registry/<name>.json` covers this result: when the declaration is
sorry-free, set that node's `trust` to `lean-verified` and record the
declaration name in its `lean` field. Then run
`python3 code/registry_validate.py proofs/registry/<name>.json` from
`/home/agent/projects` and fix real violations — it is advisory, not a gate.
Do NOT set `lean-verified` while sorries remain.
Carry citations from the paper proof into the Lean file: arXiv ID + locator in
the docstring or comment of any declaration that formalises an external result.

## Context management

If context gets heavy from build output, write `~/state/COMPACT.md` with:
- The target and project path
- What builds, what's sorried, the exact lemma you're on
- Key statements (not raw build logs)

## Time

You have one hour. One target, formalised honestly, beats three targets sorried over.
