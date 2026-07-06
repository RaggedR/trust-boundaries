#!/usr/bin/env python3
"""Citation provenance checker for the loop experiment.

Citations come out of the RAG: a citation is a chunk reference
`paper_slug/chunk_NNN` plus a locator (Thm/Eq/Sec number) at the point of
use. This tool validates sources.json and checks that chunk references
cited in markdown/TeX files resolve in the index AND on disk (the corpus
lives at ../literature/chunks/). Advisory: readable messages, exit 0 = clean.
Stdlib only. See CITATIONS-README.md.

Usage (from loop-experiment/, or pass --root):
  python3 code/citation_check.py                                # validate index
  python3 code/citation_check.py 2026-07-04/scratch/foo.md ...  # + resolve refs
  python3 code/citation_check.py --report footprint <files>
  python3 code/citation_check.py --report shallow <files>
"""

import argparse
import json
import re
import sys
from pathlib import Path

# How the knowledge arrived, weakest first:
#   recalled     — from the agent's own training memory; no chunk behind it
#   rag-summary  — only the chunk's one-line summary was seen (--summaries-only)
#   chunk-read   — the retrieved chunk was read verbatim
#   context-read — surrounding chunks read; hypotheses/notation of the cited
#                  statement checked (the RAG hazard: hypotheses live in a
#                  chunk that wasn't retrieved)
#   paper-read   — the relevant section/paper worked through
LEVELS = ["recalled", "rag-summary", "chunk-read", "context-read", "paper-read"]
LOAD_BEARING_MIN = "context-read"

# Chunk references: paper_slug/chunk_NNN (slug as in literature/chunks/)
CHUNK_RE = re.compile(r"\b([a-z0-9][a-z0-9_\-]*/chunk_\d{3})\b")

DEFAULT_CHUNKS_DIR = Path("../literature/chunks")


def slug_of(ref):
    return ref.split("/", 1)[0]


def load_index(path):
    try:
        data = json.loads(path.read_text())
    except FileNotFoundError:
        return None, [f"{path}: not found"]
    except json.JSONDecodeError as e:
        return None, [f"{path}: invalid JSON: {e}"]
    problems = []
    if data.get("format") != "loop-sources-v1":
        problems.append(f"{path}: missing or unknown 'format' (want loop-sources-v1)")
    sources = data.get("sources")
    if not isinstance(sources, dict):
        return None, problems + [f"{path}: 'sources' must be an object"]
    return sources, problems


def validate_index(sources, root, chunks_dir):
    problems = []
    for slug, entry in sources.items():
        where = f"sources[{slug}]"
        if not isinstance(entry, dict):
            problems.append(f"{where}: entry must be an object")
            continue
        for field in ("title", "extraction", "read"):
            if field not in entry:
                problems.append(f"{where}: missing '{field}'")
        level = entry.get("extraction")
        if level is not None and level not in LEVELS:
            problems.append(
                f"{where}: extraction '{level}' invalid (one of: {', '.join(LEVELS)})"
            )
        # recalled sources have no corpus directory; everything else must
        if level != "recalled" and chunks_dir is not None:
            if not (chunks_dir / slug).is_dir():
                problems.append(
                    f"{where}: no corpus directory {chunks_dir / slug} "
                    f"(if this paper is not in the corpus, mark it 'recalled')"
                )
        for rel in entry.get("read", []) or []:
            if root and not (root / rel).exists():
                problems.append(f"{where}: read file missing: {rel}")
        for i, corr in enumerate(entry.get("corrections", []) or []):
            if not isinstance(corr, dict) or "date" not in corr or "note" not in corr:
                problems.append(f"{where}: corrections[{i}] needs 'date' and 'note'")
    return problems


def cited_refs(path):
    return sorted(set(CHUNK_RE.findall(path.read_text(errors="replace"))))


def check_files(files, sources, chunks_dir):
    problems = []
    for f in files:
        for ref in cited_refs(f):
            slug = slug_of(ref)
            if slug not in sources:
                problems.append(
                    f"{f}: cites {ref} — unregistered source; add '{slug}' to "
                    f"sources.json at its honest extraction level"
                )
            if chunks_dir is not None and not (chunks_dir / (ref + ".tex")).is_file():
                problems.append(
                    f"{f}: cites {ref} — no such chunk on disk "
                    f"(hallucinated reference? check {chunks_dir / slug})"
                )
    return problems


def floor_level(levels):
    return min(levels, key=LEVELS.index) if levels else None


def report_footprint(files, sources):
    for f in files:
        refs = cited_refs(f)
        print(f"\n{f}")
        if not refs:
            print("  no chunk citations found")
            continue
        levels = []
        for slug in sorted({slug_of(r) for r in refs}):
            entry = sources.get(slug)
            used = [r for r in refs if slug_of(r) == slug]
            if entry is None:
                print(f"  {slug}  UNREGISTERED  ({len(used)} chunk(s) cited)")
                continue
            level = entry.get("extraction", "?")
            levels.append(level)
            flags = ""
            if entry.get("corrections"):
                flags = f"  [{len(entry['corrections'])} correction(s) — check them]"
            print(f"  {slug}  {level:<13} {len(used)} chunk(s){flags}")
        fl = floor_level([l for l in levels if l in LEVELS])
        print(f"  provenance floor: {fl or 'n/a (unregistered citations only)'}")


def report_shallow(files, sources):
    leaning = {}  # slug -> [files]
    for f in files:
        for ref in cited_refs(f):
            slug = slug_of(ref)
            entry = sources.get(slug)
            if entry and LEVELS.index(entry.get("extraction", "recalled")) \
                    < LEVELS.index(LOAD_BEARING_MIN):
                leaning.setdefault(slug, []).append(f)
    if not leaning:
        print(f"no sources below '{LOAD_BEARING_MIN}' are cited by the scanned files")
        return
    print(f"context-read worklist (sources below '{LOAD_BEARING_MIN}', "
          f"most-leaned-on first):")
    for slug, fs in sorted(leaning.items(), key=lambda kv: -len(kv[1])):
        entry = sources[slug]
        print(f"  {slug}  [{entry.get('extraction')}] — cited by {len(fs)} file(s)")
        for f in sorted(set(fs)):
            print(f"      {f}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("files", nargs="*", type=Path, help="md/tex files to check")
    ap.add_argument("--root", type=Path, default=Path("."),
                    help="loop-experiment root (default: cwd)")
    ap.add_argument("--sources", type=Path, default=None,
                    help="sources.json (default: <root>/sources.json)")
    ap.add_argument("--chunks-dir", default=None,
                    help=f"corpus chunks dir (default: <root>/{DEFAULT_CHUNKS_DIR}); "
                         f"pass 'skip' to disable on-disk chunk checks")
    ap.add_argument("--report", choices=["footprint", "shallow"], default=None)
    args = ap.parse_args()

    if args.chunks_dir == "skip":
        chunks_dir = None
    elif args.chunks_dir:
        chunks_dir = Path(args.chunks_dir)
    else:
        chunks_dir = args.root / DEFAULT_CHUNKS_DIR
        if not chunks_dir.is_dir():
            print(f"note: {chunks_dir} not found; skipping on-disk chunk checks")
            chunks_dir = None

    sources_path = args.sources or args.root / "sources.json"
    sources, problems = load_index(sources_path)
    if sources is None:
        for p in problems:
            print(p)
        return 1
    problems += validate_index(sources, args.root, chunks_dir)

    if args.report == "footprint":
        report_footprint(args.files, sources)
        return 0
    if args.report == "shallow":
        report_shallow(args.files, sources)
        return 0

    problems += check_files(args.files, sources, chunks_dir)
    if problems:
        for p in problems:
            print(p)
        print(f"\n{len(problems)} problem(s). Advisory: fix what's real.")
        return 1
    n = len(args.files)
    print(f"sources.json OK ({len(sources)} sources)"
          + (f"; {n} file(s) resolve cleanly" if n else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
