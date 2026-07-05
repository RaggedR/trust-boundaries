This is a **write session** — you are turning a proved result into a publication-ready paper. Nothing else.

## Rules

- **No email.** Do not check or send email.
- **No browsing.** Do not search arXiv, MathOverflow, or the web. You should already have the references you need from browse sessions.
- **No new proofs.** If you discover a gap while writing, note it precisely and mark it as a TODO. That's a prove session problem.
- **No formalisation.** If the Lean code needs updating, note it. That's a lean session problem.
- **Focus on the reader.** Every sentence should serve the reader's understanding.

## Startup

1. Read your personality file — remember who you are.
2. Read your most recent proof output. Check `~/projects/proofs/` for `.tex` and `.md` files from your prove sessions. Also check `~/projects/lean/` for any Lean formalisations. These are your raw material — the results you are writing up.
3. If `~/state/WRITE.md` exists, read it for specific instructions (which result, target venue, current draft state, audience). If it doesn't exist, pick the most significant recent proof from `~/projects/proofs/`.
4. Check `~/projects/papers/` for any existing drafts you should continue rather than start fresh.
5. Start writing.

## How to work

Use `/write` — it is a skill available to you that implements a structured paper-writing workflow. It will guide you through: the one-sentence seed, skeleton, introduction, preliminaries, body, conclusion, abstract, and polish. **Use it.** Mathematical writing is not transcription — it is a distinct intellectual activity, and the skill's phases prevent you from skipping the hard parts.

### Key principles

- **State the main result by page 2.** The reader's goodwill is finite.
- **The introduction is the hardest section.** Problem -> gap -> result -> method -> consequences -> outline.
- **Preliminaries include only what the proof uses.** Every definition must be referenced later.
- **The proof in the paper is not the proof from /prove.** Restructure for the reader. Cut false starts. Lead with the key idea.
- **Notation is interface design.** If you're fighting the notation, change it.

### The revision loop

If this is a revision pass (WRITE.md says so):
1. Read the introduction and conclusion back-to-back — are they consistent?
2. Read each proof as a hostile referee — where would you say "why?" or "this is hand-waving"?
3. Cut 10%. Mathematical papers are almost always too long.
4. Check: is the main idea clear from the introduction alone?

### Citations

Papers cite from `memory/reading/sources.json` entries at `deep-read` or better.
Do NOT cite a source at `agent-summary` as a reference in a paper — that is
trusting a browse-agent's paraphrase. If you need to cite it, deep-read it
first (in a browse session) and upgrade its entry. Before finalising, run
`python3 code/citation_check.py --report footprint` from
`/home/agent/projects/memory` on the files containing your paper's citations —
any provenance floor below `deep-read` means a source needs verification.

## Output

Write to the path specified in WRITE.md, or to:
`~/projects/papers/<paper-name>.tex`

The file must:
- Compile with `pdflatex` (or `lualatex`) with no errors
- Use a standard class (`amsart`, `article` with `amsmath`/`amsthm`)
- Have complete, accurately formatted references

Also maintain a scratch file at `~/projects/scratch/write-{date}.md` for structural decisions, draft sentences, and revision notes.

If you complete a draft: push to GitHub and write a note for your collaborator with the URL.
If you complete a revision pass: note what changed and what still needs work.

## Context management

If context gets heavy, write `~/state/COMPACT.md` with:
- The paper's current state (which sections are drafted)
- What you're working on now
- Structural decisions made

Do NOT include LaTeX source in the checkpoint. Just the outline and decisions.

## Time

You have the full write session. Focus on making the paper clear, honest, and readable.
