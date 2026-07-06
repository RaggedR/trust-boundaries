#!/usr/bin/env python3
"""Validate the loop-experiment proof registry (see REGISTRY-README.md).

Advisory trust-boundary checker. Stdlib only.

Usage (from loop-experiment/):
    python3 code/registry_validate.py registry/warnaar.json
    python3 code/registry_validate.py registry/warnaar.json --report successful-path|dead-ends|frontier

Exit 0 if the registry is valid, 1 otherwise.
"""

import argparse
import json
import os
import sys

# 'verified' = an INDEPENDENT verifier agent (or Robin) reviewed the proof
# and endorsed it; requires a 'review' field pointing at the verifier report
# (e.g. 2026-07-04/scratch/verify-seed1-layer4.md).
TRUST_ORDER = {"speculative": 0, "computed": 1, "proved": 2,
               "verified": 3, "lean-verified": 4}
SPECIAL_TRUST = {"dead-end", "in-progress", "unclassified"}
VALID_TRUST = set(TRUST_ORDER) | SPECIAL_TRUST

# How firmly a dead-end is known to be dead.
# "judgment" = abandoned on taste/cost, no counterexample; revisitable.
REFUTATION_ORDER = {"judgment": 0, "computed": 1, "proved": 2,
                    "lean-verified": 3}

NODE_REQUIRED = ("id", "approach", "trust", "children")

# Citation extraction levels (must match code/citation_check.py)
EXTRACTION_LEVELS = ["recalled", "rag-summary", "chunk-read",
                     "context-read", "paper-read"]
LOAD_BEARING_MIN = "context-read"

DEFAULT_SOURCES = "sources.json"


def load_sources(path):
    """Load a loop-sources-v1 index. Returns (index_or_None, warning_or_None)."""
    if path == "skip":
        return None, None
    explicit = path is not None
    path = path or DEFAULT_SOURCES
    try:
        with open(path) as fh:
            data = json.load(fh)
    except OSError:
        if explicit:
            return None, f"sources index '{path}' not found; skipping source checks"
        return None, None  # default path absent: quietly skip
    except json.JSONDecodeError as exc:
        return None, f"sources index '{path}' is not valid JSON ({exc}); skipping source checks"
    return data.get("sources", {}), None


def walk(node, path=()):
    """Yield (node, path) for every node in the tree. path is a tuple of ids."""
    p = path + (node.get("id", "?"),)
    yield node, p
    for child in node.get("children") or []:
        if isinstance(child, dict):
            yield from walk(child, p)


def below_load_bearing(entry):
    level = entry.get("extraction", "recalled")
    if level not in EXTRACTION_LEVELS:
        return True
    return EXTRACTION_LEVELS.index(level) < EXTRACTION_LEVELS.index(LOAD_BEARING_MIN)


def validate(registry, files_dir, source_index=None, warnings=None):
    errors = []
    if warnings is None:
        warnings = []

    for key in ("conjecture", "status", "tree"):
        if key not in registry:
            errors.append(f"top level: missing key '{key}'")
    tree = registry.get("tree")
    if not isinstance(tree, dict):
        errors.append("top level: 'tree' must be an object")
        return errors

    seen_ids = {}
    for node, path in walk(tree):
        loc = "/".join(path)

        # well-formedness
        for key in NODE_REQUIRED:
            if key not in node:
                errors.append(f"{loc}: missing key '{key}'")
        if not isinstance(node.get("children", []), list):
            errors.append(f"{loc}: 'children' must be a list")

        # unique ids
        nid = node.get("id")
        if nid in seen_ids:
            errors.append(f"{loc}: duplicate id '{nid}' (also at {seen_ids[nid]})")
        elif nid is not None:
            seen_ids[nid] = loc

        # trust values
        trust = node.get("trust")
        if trust is not None and trust not in VALID_TRUST:
            errors.append(f"{loc}: invalid trust '{trust}' "
                          f"(valid: {', '.join(sorted(VALID_TRUST))})")

        # dead ends need reasons, and their refutation level (if given)
        # must be valid; strong refutations should point at evidence
        if trust == "dead-end":
            if not node.get("reason"):
                errors.append(f"{loc}: dead-end without a 'reason'")
            ref = node.get("refutation")
            if ref is not None and ref not in REFUTATION_ORDER:
                errors.append(
                    f"{loc}: invalid refutation '{ref}' "
                    f"(valid: {', '.join(sorted(REFUTATION_ORDER, key=REFUTATION_ORDER.get))})")
            elif (ref is not None
                    and REFUTATION_ORDER[ref] >= REFUTATION_ORDER["computed"]
                    and not node.get("file")):
                warnings.append(
                    f"{loc}: refutation '{ref}' but no 'file' — evidence "
                    f"that strong should live somewhere on disk")
        elif node.get("refutation") is not None:
            errors.append(f"{loc}: 'refutation' only belongs on dead-end "
                          f"nodes (trust is '{trust}')")

        # verified needs a pointer to the review artifact: which verifier
        # agent/human and where the report lives. A self-assigned label
        # with no artifact is trust inflation.
        if trust == "verified" and not node.get("review"):
            errors.append(f"{loc}: verified without a 'review' field "
                          f"(verifier + path to the verify report)")

        # lean-verified should name its declaration
        if trust == "lean-verified" and not node.get("lean"):
            warnings.append(f"{loc}: lean-verified without a 'lean' field "
                            f"naming the sorry-free declaration")

        # boundary rule: proved or above requires every
        # non-dead-end child to be at least proved
        if TRUST_ORDER.get(trust, -1) >= TRUST_ORDER["proved"]:
            for child in node.get("children") or []:
                ct = child.get("trust")
                if ct == "dead-end":
                    continue
                if TRUST_ORDER.get(ct, -1) < TRUST_ORDER["proved"]:
                    errors.append(
                        f"{loc}: claims '{trust}' but child "
                        f"'{child.get('id')}' is '{ct}' (boundary rule: "
                        f"non-dead-end children must be at least 'proved')")

        # citation provenance: optional 'sources' field (paper slugs)
        srcs = node.get("sources")
        if srcs is not None:
            if not (isinstance(srcs, list)
                    and all(isinstance(s, str) for s in srcs)):
                errors.append(f"{loc}: 'sources' must be a list of paper-slug "
                              f"strings")
            elif source_index is not None:
                known = []
                for sid in srcs:
                    entry = source_index.get(sid)
                    if entry is None:
                        warnings.append(
                            f"{loc}: source '{sid}' not in sources.json "
                            f"(add it, or check the slug)")
                    else:
                        known.append(entry)
                # a proved claim resting only on shallow extractions is
                # trusting a summary line (or the agent's memory), not the
                # paper — the hypotheses may live in an unretrieved chunk
                if (known
                        and TRUST_ORDER.get(trust, -1) >= TRUST_ORDER["proved"]
                        and all(below_load_bearing(e) for e in known)):
                    errors.append(
                        f"{loc}: claims '{trust}' but every cited source is "
                        f"below '{LOAD_BEARING_MIN}' — context-read at least "
                        f"one (check the hypotheses) before it is load-bearing")

        # file references (relative to loop-experiment root)
        f = node.get("file")
        if f is not None and files_dir is not None:
            if not os.path.isfile(os.path.join(files_dir, f)):
                errors.append(f"{loc}: file '{f}' not found under {files_dir}")

    # status should mirror the root's trust
    if registry.get("status") != tree.get("trust"):
        errors.append(f"top level: status '{registry.get('status')}' does not "
                      f"match root trust '{tree.get('trust')}'")

    return errors


# ---- reports: coKleisli morphisms W(Registry) -> Report -------------------

def report_successful_path(tree):
    """The proved/verified/lean-verified skeleton (prune dead ends and open work)."""
    lines = []

    def rec(node, depth):
        trust = node.get("trust")
        if TRUST_ORDER.get(trust, -1) >= TRUST_ORDER["proved"]:
            lean = f"  [lean: {node['lean']}]" if node.get("lean") else ""
            f = f"  ({node['file']})" if node.get("file") else ""
            lines.append(f"{'  ' * depth}{node['id']}: {node['approach']} "
                         f"[{trust}]{lean}{f}")
            for child in node.get("children") or []:
                rec(child, depth + 1)

    root = tree
    if TRUST_ORDER.get(root.get("trust"), -1) < TRUST_ORDER["proved"]:
        # root still open: show proved subtrees under it
        lines.append(f"{root['id']}: {root['approach']} [{root.get('trust')}] "
                     f"(open; proved subtrees below)")
        for child in root.get("children") or []:
            rec(child, 1)
    else:
        rec(root, 0)
    return lines or ["(nothing at 'proved' or above yet)"]


def report_dead_ends(tree):
    """Every dead end, with its path, reason, and refutation status."""
    lines = []
    for node, path in walk(tree):
        if node.get("trust") == "dead-end":
            lines.append("/".join(path))
            lines.append(f"    reason: {node.get('reason', '(MISSING)')}")
            if node.get("file"):
                lines.append(f"    file:   {node['file']}")
            ref = node.get("refutation")
            if ref is not None:
                lines.append(f"    refutation: {ref}")
            else:
                # legacy nodes: infer from best trust among children
                best = max((TRUST_ORDER.get(c.get("trust"), -1)
                            for c in node.get("children") or []), default=-1)
                if best >= 0:
                    level = [k for k, v in TRUST_ORDER.items() if v == best][0]
                    lines.append(f"    refutation: {level} (inferred from children)")
                else:
                    lines.append("    refutation: judgment (default; no counterexample recorded)")
    return lines or ["(no dead ends recorded)"]


def report_frontier(tree):
    """Open nodes: below 'proved', not dead. Where work remains."""
    lines = []
    for node, path in walk(tree):
        trust = node.get("trust")
        if trust == "dead-end":
            continue
        if TRUST_ORDER.get(trust, -1) < TRUST_ORDER["proved"]:
            lines.append(f"{'/'.join(path)} [{trust}]: {node.get('approach')}")
    return lines or ["(no open nodes: the conjecture is closed)"]


REPORTS = {
    "successful-path": report_successful_path,
    "dead-ends": report_dead_ends,
    "frontier": report_frontier,
}


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("registry", help="path to the registry .json file")
    ap.add_argument("--files-dir", default=None,
                    help="directory node 'file' paths are relative to "
                         "(default: parent of the registry's directory, i.e. "
                         "loop-experiment/); pass 'skip' to skip "
                         "file-existence checks")
    ap.add_argument("--report", choices=sorted(REPORTS),
                    help="print a report instead of just validating")
    ap.add_argument("--sources", default=None,
                    help=f"path to the citation sources index (default: "
                         f"{DEFAULT_SOURCES} if it exists); pass 'skip' to "
                         f"disable source checks")
    args = ap.parse_args()

    try:
        with open(args.registry) as fh:
            registry = json.load(fh)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"ERROR: cannot read registry: {exc}")
        return 1

    if args.files_dir == "skip":
        files_dir = None
    elif args.files_dir:
        files_dir = args.files_dir
    else:
        files_dir = os.path.dirname(os.path.dirname(os.path.abspath(args.registry)))

    source_index, src_warning = load_sources(args.sources)
    warnings = [src_warning] if src_warning else []

    errors = validate(registry, files_dir, source_index, warnings)

    if args.report:
        tree = registry.get("tree")
        if isinstance(tree, dict):
            print(f"# {args.report}: {registry.get('conjecture', '?')}")
            for line in REPORTS[args.report](tree):
                print(line)
        else:
            print("ERROR: no tree to report on")

    if warnings:
        print(f"\n{len(warnings)} warning(s) in {args.registry}:")
        for w in warnings:
            print(f"  ~ {w}")

    if errors:
        print(f"\n{len(errors)} problem(s) in {args.registry}:")
        for e in errors:
            print(f"  - {e}")
        return 1
    if not args.report:
        print(f"OK: {args.registry} is valid "
              f"(status: {registry.get('status')})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
