#!/usr/bin/env python3
"""Citation provenance checker for Clio's memory files.

Validates sources.json and checks that arXiv IDs cited in markdown files
resolve in the index. Advisory: readable messages, exit 0 = clean.
Stdlib only. See the citations README (memory/reading/CITATIONS-README.md).

Usage (from /home/clio/projects/memory, or pass --memory-dir):
  python3 code/citation_check.py                              # validate index
  python3 code/citation_check.py connections/foo.md ...       # + resolve IDs
  python3 code/citation_check.py --report footprint connections/foo.md
  python3 code/citation_check.py --report shallow
"""

import argparse
import json
import re
import sys
from pathlib import Path

LEVELS = ["agent-summary", "abstract", "deep-read", "verified-quote"]

# arXiv new-style IDs: YYMM.NNNNN with a plausible month, word-bounded.
# The month check (01-12) keeps ordinary decimals like 3.14159 out.
ARXIV_RE = re.compile(r"\b(\d{2}(?:0[1-9]|1[0-2])\.\d{4,5})\b")


def load_index(path):
    try:
        data = json.loads(path.read_text())
    except FileNotFoundError:
        return None, [f"{path}: not found"]
    except json.JSONDecodeError as e:
        return None, [f"{path}: invalid JSON: {e}"]
    problems = []
    if data.get("format") != "clio-sources-v1":
        problems.append(f"{path}: missing or unknown 'format' (want clio-sources-v1)")
    sources = data.get("sources")
    if not isinstance(sources, dict):
        return None, problems + [f"{path}: 'sources' must be an object"]
    return sources, problems


def validate_index(sources, memory_dir):
    problems = []
    for sid, entry in sources.items():
        where = f"sources[{sid}]"
        if not ARXIV_RE.fullmatch(sid):
            problems.append(f"{where}: id does not look like an arXiv ID")
        if not isinstance(entry, dict):
            problems.append(f"{where}: entry must be an object")
            continue
        for field in ("title", "authors", "extraction", "read"):
            if field not in entry:
                problems.append(f"{where}: missing '{field}'")
        level = entry.get("extraction")
        if level is not None and level not in LEVELS:
            problems.append(
                f"{where}: extraction '{level}' invalid (one of: {', '.join(LEVELS)})"
            )
        for rel in entry.get("read", []) or []:
            if memory_dir and not (memory_dir / rel).exists():
                problems.append(f"{where}: read file missing: {rel}")
        for i, corr in enumerate(entry.get("corrections", []) or []):
            if not isinstance(corr, dict) or "date" not in corr or "note" not in corr:
                problems.append(f"{where}: corrections[{i}] needs 'date' and 'note'")
    return problems


def cited_ids(path):
    return sorted(set(ARXIV_RE.findall(path.read_text())))


def check_files(files, sources):
    problems = []
    for f in files:
        for sid in cited_ids(f):
            if sid not in sources:
                problems.append(
                    f"{f}: cites {sid} — unregistered source; add it to "
                    f"sources.json at its honest extraction level"
                )
    return problems


def floor_level(levels):
    return min(levels, key=LEVELS.index) if levels else None


def report_footprint(files, sources):
    for f in files:
        ids = cited_ids(f)
        print(f"\n{f}")
        if not ids:
            print("  no arXiv citations found")
            continue
        levels = []
        for sid in ids:
            entry = sources.get(sid)
            if entry is None:
                print(f"  {sid}  UNREGISTERED")
                continue
            level = entry.get("extraction", "?")
            levels.append(level)
            flags = ""
            if entry.get("corrections"):
                flags = f"  [{len(entry['corrections'])} correction(s) — check them]"
            print(f"  {sid}  {level:<14} {entry.get('authors', '?')}{flags}")
        fl = floor_level([l for l in levels if l in LEVELS])
        print(f"  provenance floor: {fl or 'n/a (unregistered citations only)'}")


def report_shallow(files, sources, memory_dir):
    if not files and memory_dir:
        files = sorted(
            list((memory_dir / "connections").glob("*.md"))
            + list((memory_dir / "topics").glob("*.md"))
        )
    leaning = {}  # sid -> [files]
    for f in files:
        for sid in cited_ids(f):
            entry = sources.get(sid)
            if entry and entry.get("extraction") == "agent-summary":
                leaning.setdefault(sid, []).append(f)
    if not leaning:
        print("no agent-summary sources are cited by the scanned files")
        return
    print("deep-read worklist (agent-summary sources, most-leaned-on first):")
    for sid, fs in sorted(leaning.items(), key=lambda kv: -len(kv[1])):
        entry = sources[sid]
        print(f"  {sid}  {entry.get('authors', '?')} — cited by {len(fs)} file(s)")
        for f in fs:
            print(f"      {f}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("files", nargs="*", type=Path, help="markdown files to check")
    ap.add_argument("--memory-dir", type=Path, default=Path("."),
                    help="Clio's memory/ directory (default: cwd)")
    ap.add_argument("--sources", type=Path, default=None,
                    help="sources.json (default: <memory-dir>/reading/sources.json)")
    ap.add_argument("--report", choices=["footprint", "shallow"], default=None)
    args = ap.parse_args()

    sources_path = args.sources or args.memory_dir / "reading" / "sources.json"
    sources, problems = load_index(sources_path)
    if sources is None:
        for p in problems:
            print(p)
        return 1
    problems += validate_index(sources, args.memory_dir)

    if args.report == "footprint":
        report_footprint(args.files, sources)
        return 0
    if args.report == "shallow":
        report_shallow(args.files, sources, args.memory_dir)
        return 0

    problems += check_files(args.files, sources)
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
