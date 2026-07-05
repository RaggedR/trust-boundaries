#!/usr/bin/env python3
"""Validate a proof registry (see proofs/registry/README.md).

Advisory trust-boundary checker. Stdlib only.

Usage:
    python3 registry_validate.py <registry.json> [--proofs-dir DIR] [--registry-dir DIR]
    python3 registry_validate.py <registry.json> --report successful-path|dead-ends|frontier|cross-refs

Exit 0 if the registry is valid, 1 otherwise.
"""

import argparse
import json
import os
import sys

TRUST_ORDER = {"speculative": 0, "computed": 1, "proved": 2,
               "peer-reviewed": 3, "published": 4, "lean-verified": 5}
SPECIAL_TRUST = {"dead-end", "in-progress", "unclassified"}
VALID_TRUST = set(TRUST_ORDER) | SPECIAL_TRUST

# How firmly a dead-end is known to be dead (see README: "Dead-end levels").
# "judgment" = abandoned on taste/cost, no counterexample; revisitable.
REFUTATION_ORDER = {"judgment": 0, "computed": 1, "proved": 2,
                    "lean-verified": 3}

NODE_REQUIRED = ("id", "approach", "trust", "children")

DEFAULT_SOURCES = "memory/reading/sources.json"

# Trust ranks used for the cross-registry cap. in-progress and unclassified
# rank below speculative: an open or unchecked local claim can always cite
# a canonical node, whatever its level.
CAP_RANK = dict(TRUST_ORDER, **{"in-progress": -1, "unclassified": -1})


def parse_shared(value):
    """Parse '<registry>#<node-id>'. Returns (registry, node_id) or None."""
    if not isinstance(value, str) or value.count("#") != 1:
        return None
    reg, nid = value.split("#")
    if not reg or not nid:
        return None
    return reg, nid


def load_sibling(registry_dir, name, cache):
    """Load <registry_dir>/<name>.json, memoized. Returns (tree, error)."""
    if name in cache:
        return cache[name]
    path = os.path.join(registry_dir, name + ".json")
    try:
        with open(path) as fh:
            data = json.load(fh)
        tree = data.get("tree")
        if not isinstance(tree, dict):
            result = (None, f"registry '{name}' has no tree")
        else:
            result = (tree, None)
    except OSError:
        result = (None, f"registry '{name}.json' not found under {registry_dir}")
    except json.JSONDecodeError as exc:
        result = (None, f"registry '{name}.json' is not valid JSON ({exc})")
    cache[name] = result
    return result


def find_node(tree, nid):
    """Find the node with id nid anywhere in tree, or None."""
    for node, _ in walk(tree):
        if node.get("id") == nid:
            return node
    return None


def resolve_shared(node, registry_dir, cache):
    """Resolve a node's 'shared' ref to its canonical node.

    Returns (canonical_node, error). The one-hop rule lives here: the
    canonical node must not itself be shared, so resolution is a single
    lookup and cycles are impossible by construction.
    """
    parsed = parse_shared(node.get("shared"))
    if parsed is None:
        return None, ("'shared' must be '<registry>#<node-id>' "
                      f"(got {node.get('shared')!r})")
    reg, nid = parsed
    tree, err = load_sibling(registry_dir, reg, cache)
    if err:
        return None, err
    target = find_node(tree, nid)
    if target is None:
        return None, f"shared target '{reg}#{nid}' not found"
    if target.get("shared") is not None:
        return None, (f"shared target '{reg}#{nid}' is itself shared "
                      f"(one-hop rule: point at the canonical node)")
    return target, None


def load_sources(path):
    """Load a clio-sources-v1 index. Returns (index_or_None, warning_or_None)."""
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


def validate(registry, proofs_dir, source_index=None, warnings=None,
             registry_dir=None):
    errors = []
    if warnings is None:
        warnings = []
    reg_cache = {}

    def effective_trust(n):
        """A node's trust for boundary purposes: canonical if shared.

        Falls back to the local trust when resolution fails — the failure
        itself is reported once, at the node's own visit.
        """
        if n.get("shared") is None or registry_dir is None:
            return n.get("trust")
        canon, err = resolve_shared(n, registry_dir, reg_cache)
        return canon.get("trust") if canon is not None else n.get("trust")

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

        # shared nodes are stubs: the canonical node (in a sibling
        # registry) owns the subtree, reason, file, and sources. The
        # stub's local trust is a cache that must not exceed the
        # canonical trust — trust inflation across a link is the
        # cross-registry boundary violation.
        shared = node.get("shared")
        if shared is not None:
            if node.get("children"):
                errors.append(f"{loc}: shared node must be a stub "
                              f"(children live at the canonical node)")
            if registry_dir is not None:
                canon, err = resolve_shared(node, registry_dir, reg_cache)
                if err:
                    errors.append(f"{loc}: {err}")
                else:
                    ct = canon.get("trust")
                    if ct == "dead-end":
                        if trust != "dead-end":
                            errors.append(
                                f"{loc}: canonical '{shared}' is dead-end "
                                f"but stub claims '{trust}'")
                    elif ct in TRUST_ORDER:
                        if (CAP_RANK.get(trust, len(TRUST_ORDER))
                                > TRUST_ORDER[ct]):
                            errors.append(
                                f"{loc}: stub trust '{trust}' exceeds "
                                f"canonical '{shared}' trust '{ct}' "
                                f"(trust lives at the canonical node)")
                    else:  # canonical is in-progress or unclassified
                        if CAP_RANK.get(trust, len(TRUST_ORDER)) > -1:
                            errors.append(
                                f"{loc}: stub trust '{trust}' exceeds "
                                f"canonical '{shared}' trust '{ct}' "
                                f"(trust lives at the canonical node)")

        # dead ends need reasons, and their refutation level (if given)
        # must be valid; strong refutations should point at evidence
        if trust == "dead-end":
            if not node.get("reason") and shared is None:
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

        # peer-reviewed needs a pointer to the review artifact:
        # who reviewed it and where the review lives. A self-assigned
        # label with no artifact is trust inflation.
        if trust == "peer-reviewed" and not node.get("review"):
            errors.append(f"{loc}: peer-reviewed without a 'review' field "
                          f"(reviewer + where the review lives)")

        # published needs a pointer to the publication:
        # venue + reference (DOI / arXiv id / issue). These upgrades
        # arrive as email events (see README: "Email events").
        if trust == "published" and not node.get("publication"):
            errors.append(f"{loc}: published without a 'publication' field "
                          f"(venue + DOI/arXiv reference)")

        # boundary rule: proved or above requires every
        # non-dead-end child to be at least proved. Shared children
        # count at their canonical (resolved) trust.
        if TRUST_ORDER.get(trust, -1) >= TRUST_ORDER["proved"]:
            for child in node.get("children") or []:
                ct = effective_trust(child)
                if ct == "dead-end":
                    continue
                if TRUST_ORDER.get(ct, -1) < TRUST_ORDER["proved"]:
                    errors.append(
                        f"{loc}: claims '{trust}' but child "
                        f"'{child.get('id')}' is '{ct}' (boundary rule: "
                        f"non-dead-end children must be at least 'proved')")

        # citation provenance: optional 'sources' field (arXiv ids)
        srcs = node.get("sources")
        if srcs is not None:
            if not (isinstance(srcs, list)
                    and all(isinstance(s, str) for s in srcs)):
                errors.append(f"{loc}: 'sources' must be a list of arXiv id "
                              f"strings")
            elif source_index is not None:
                known = []
                for sid in srcs:
                    entry = source_index.get(sid)
                    if entry is None:
                        warnings.append(
                            f"{loc}: source '{sid}' not in the sources index "
                            f"(add it to sources.json, or check the id)")
                    else:
                        known.append(entry)
                # a proved claim resting only on agent-summary extractions
                # is trusting a browse-agent's paraphrase, not the paper
                if (known
                        and TRUST_ORDER.get(trust, -1) >= TRUST_ORDER["proved"]
                        and all(e.get("extraction") == "agent-summary"
                                for e in known)):
                    errors.append(
                        f"{loc}: claims '{trust}' but every cited source is "
                        f"'agent-summary' — deep-read at least one before it "
                        f"is load-bearing")

        # file references
        f = node.get("file")
        if f is not None and proofs_dir is not None:
            if not os.path.isfile(os.path.join(proofs_dir, f)):
                errors.append(f"{loc}: file '{f}' not found under {proofs_dir}")

    # status should mirror the root's trust
    if registry.get("status") != tree.get("trust"):
        errors.append(f"top level: status '{registry.get('status')}' does not "
                      f"match root trust '{tree.get('trust')}'")

    return errors


# ---- reports: coKleisli morphisms W(Registry) -> Report -------------------

def report_successful_path(tree):
    """The proved/lean-verified skeleton (prune dead ends and open work)."""
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


def report_cross_refs(tree, own_name, registry_dir):
    """Every shared link touching this registry, both directions.

    The fourth coKleisli morphism: it needs the whole tree AND its
    siblings — a shared node is a container morphism between
    registries, and this report is its trace.
    """
    cache = {}
    lines = ["outgoing:"]
    found = False
    for node, path in walk(tree):
        if node.get("shared") is None:
            continue
        found = True
        canon, err = resolve_shared(node, registry_dir, cache)
        detail = f"[{canon.get('trust')}]" if canon else f"[UNRESOLVED: {err}]"
        lines.append(f"  {'/'.join(path)} -> {node['shared']} {detail}")
    if not found:
        lines.append("  (none)")

    lines.append("incoming:")
    found = False
    try:
        siblings = sorted(f for f in os.listdir(registry_dir)
                          if f.endswith(".json"))
    except OSError:
        siblings = []
    for fname in siblings:
        name = fname[:-len(".json")]
        if name == own_name:
            continue
        sib_tree, err = load_sibling(registry_dir, name, cache)
        if sib_tree is None:
            continue
        for node, path in walk(sib_tree):
            parsed = parse_shared(node.get("shared")) \
                if node.get("shared") is not None else None
            if parsed and parsed[0] == own_name:
                found = True
                lines.append(f"  {name}: {'/'.join(path)} -> #{parsed[1]}")
    if not found:
        lines.append("  (none)")
    return lines


REPORTS = {
    "successful-path": report_successful_path,
    "dead-ends": report_dead_ends,
    "frontier": report_frontier,
}


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("registry", help="path to the registry .json file")
    ap.add_argument("--proofs-dir", default=None,
                    help="directory containing proof files (default: parent "
                         "of the registry's directory); pass 'skip' to skip "
                         "file-existence checks")
    ap.add_argument("--report", choices=sorted(REPORTS) + ["cross-refs"],
                    help="print a report instead of just validating")
    ap.add_argument("--registry-dir", default=None,
                    help="directory holding sibling registries for "
                         "resolving 'shared' refs (default: the registry's "
                         "own directory); pass 'skip' to skip shared checks")
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

    if args.proofs_dir == "skip":
        proofs_dir = None
    elif args.proofs_dir:
        proofs_dir = args.proofs_dir
    else:
        proofs_dir = os.path.dirname(os.path.dirname(os.path.abspath(args.registry)))

    if args.registry_dir == "skip":
        registry_dir = None
    elif args.registry_dir:
        registry_dir = args.registry_dir
    else:
        registry_dir = os.path.dirname(os.path.abspath(args.registry))

    source_index, src_warning = load_sources(args.sources)
    warnings = [src_warning] if src_warning else []

    errors = validate(registry, proofs_dir, source_index, warnings,
                      registry_dir)

    if args.report:
        tree = registry.get("tree")
        if isinstance(tree, dict):
            print(f"# {args.report}: {registry.get('conjecture', '?')}")
            if args.report == "cross-refs":
                own = os.path.basename(args.registry)
                own = own[:-len(".json")] if own.endswith(".json") else own
                lines = report_cross_refs(
                    tree, own, registry_dir
                    or os.path.dirname(os.path.abspath(args.registry)))
            else:
                lines = REPORTS[args.report](tree)
            for line in lines:
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
