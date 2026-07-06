#!/usr/bin/env python3
"""Generic trust-system validator, parametrized over (T, phi).

Reference implementation for notes/TRUST_SYSTEMS_THEORY.md: one validator
that replaces the per-deployment ports (loop-experiment, Clio, MacBeth).
A deployment is a JSON descriptor (see deployments/) declaring the check
chain T, the extraction chain and interface map phi, the evidence fields,
and the citation formats. A fourth deployment is a fourth descriptor.

Checks and the theory they implement (see README.md for the dictionary):
  - boundary rule            = node-local soundness (+), Definition 2.1
  - acyclicity               = well-foundedness, Remark 2.3 (Lean `cyc`)
  - source blocking          = the interface map phi, Corollary 3.4
  - shared refs + trust cap  = cross-agent citation, Corollary 3.5
  - certificate-gap report   = the two failure modes of section 4:
      mode 1 (rho absent) vs mode 2 (rho cached in prose: certified t < tau)

Advisory: readable messages, exit 0 = clean. Stdlib only.

Usage:
  trustcheck.py --deployment deployments/loop.json [--root DIR] validate REGISTRY.json
  trustcheck.py --deployment ... sources [FILES...]        # index + machine refs
  trustcheck.py --deployment ... report successful-path|dead-ends|frontier|cross-refs REGISTRY.json
  trustcheck.py --deployment ... report footprint|shallow|certificate-gap FILES...
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# Deployment descriptor = (T, phi) as data
# ---------------------------------------------------------------------------

class Deployment:
    """The parameters of one trust system, loaded from a JSON descriptor."""

    def __init__(self, data, root):
        self.name = data["name"]
        self.root = Path(root)

        t = data["trust"]
        self.trust_chain = list(t["chain"])                 # T, weakest first
        self.trust_rank = {lv: i for i, lv in enumerate(self.trust_chain)}
        self.special = set(t.get("special", []))
        self.valid_trust = set(self.trust_chain) | self.special
        self.boundary_at = t["boundary_at"]
        self.refutation_chain = list(t.get("refutation_chain", []))
        self.refutation_rank = {lv: i for i, lv in
                                enumerate(self.refutation_chain)}
        self.evidence = t.get("evidence", {})               # level -> spec

        s = data.get("sources", {})
        self.sources_format = s.get("format")
        self.sources_default = s.get("default_path", "sources.json")
        self.extraction_chain = list(s.get("extraction_chain", []))
        self.extraction_rank = {lv: i for i, lv in
                                enumerate(self.extraction_chain)}
        self.blocking = s.get("blocking", [])   # [{below_extraction, blocks_trust}]
        self.corpus_dir = s.get("corpus_dir")               # chunk deployments
        self.corpus_exempt = set(s.get("corpus_exempt", []))

        c = data.get("citation", {})
        self.machine_re = re.compile(c["machine_regex"]) if c.get(
            "machine_regex") else None
        self.machine_resolve = c.get("machine_resolve", "index")
        self.machine_suffix = c.get("machine_suffix", "")
        self.prose_roots = [self._resolve(p) for p in c.get("prose_roots", [])]

        # cross-agent interfaces (Def 3.1 / Cor 3.5): per peer, a monotone
        # phi on the trust chains and a source_phi on the extraction chains
        self.interfaces = {}
        for peer, spec in (data.get("interfaces") or {}).items():
            self.interfaces[peer] = {
                "registry_dir": self._resolve(spec["registry_dir"]),
                "artifact_root": (self._resolve(spec["artifact_root"])
                                  if spec.get("artifact_root") else None),
                "on_missing_artifact": spec.get("on_missing_artifact",
                                                "error"),
                "phi": spec.get("phi") or {},
                "source_phi": spec.get("source_phi") or {},
                "sources_path": (self._resolve(spec["sources_path"])
                                 if spec.get("sources_path") else None),
            }

    def _resolve(self, p):
        p = Path(os.path.expanduser(p))
        return p if p.is_absolute() else self.root / p

    # rank helpers: unknown values rank below everything (bottom = no check)
    def trank(self, level):
        return self.trust_rank.get(level, -1)

    def erank(self, level):
        return self.extraction_rank.get(level, -1)

    # cross-registry cap (Cor 3.5): open/unchecked local claims rank below
    # the chain, so a stub may always cite a canonical node
    def cap_rank(self, level):
        if level in self.trust_rank:
            return self.trust_rank[level]
        if level in self.special:
            return -1
        return len(self.trust_chain)    # invalid: exceeds everything


def load_deployment(path, root):
    with open(path) as fh:
        return Deployment(json.load(fh), root)


def lint_interfaces(dep, descriptor_path):
    """Check each declared phi is a morphism of trust systems (Def 3.1).

    Side conditions, checked mechanically: total on the peer's chain,
    monotone with respect to both chain orders, strict at bottom (peer's
    unchecked maps to our unchecked), specials to specials; same for
    source_phi on the extraction chains. A phi violating these is a
    DESCRIPTOR error, not a registry error — Lemma 3.2 does not hold for
    it, so nothing it transports is safe. The peer's side of the order is
    read from '<peer>.json' next to our own descriptor; when that file is
    absent the side conditions are unchecked (warning), but images are
    still verified to be levels of this deployment.

    Returns (errors, warnings).
    """
    errors, warns = [], []
    for peer, iface in dep.interfaces.items():
        phi, sphi = iface["phi"], iface["source_phi"]
        where = f"interfaces[{peer}]"
        for lv in set(phi.values()):
            if lv not in dep.valid_trust:
                errors.append(f"{where}: phi image '{lv}' is not a trust "
                              f"level of this deployment")
        for lv in set(sphi.values()):
            if lv not in dep.extraction_rank:
                errors.append(f"{where}: source_phi image '{lv}' is not an "
                              f"extraction level of this deployment")
        peer_path = Path(descriptor_path).parent / (peer + ".json")
        try:
            pdata = json.loads(peer_path.read_text())
        except (OSError, json.JSONDecodeError):
            warns.append(f"{where}: peer descriptor '{peer_path}' not "
                         f"readable — phi side conditions unchecked")
            continue
        pchain = pdata.get("trust", {}).get("chain", [])
        pspecial = pdata.get("trust", {}).get("special", [])
        missing = [lv for lv in pchain if lv not in phi]
        if missing:
            errors.append(f"{where}: phi not total on {peer}'s chain "
                          f"(missing: {', '.join(missing)})")
        images = [dep.trank(phi[lv]) for lv in pchain if lv in phi]
        if any(a > b for a, b in zip(images, images[1:])):
            errors.append(f"{where}: phi is not monotone along {peer}'s "
                          f"chain")
        if pchain and phi.get(pchain[0]) is not None \
                and phi[pchain[0]] != dep.trust_chain[0]:
            errors.append(f"{where}: phi not strict at bottom "
                          f"('{pchain[0]}' must map to "
                          f"'{dep.trust_chain[0]}', the unchecked level)")
        for lv in pspecial:
            if lv in phi and phi[lv] not in dep.special:
                errors.append(f"{where}: peer special '{lv}' maps to "
                              f"non-special '{phi[lv]}'")
        pext = pdata.get("sources", {}).get("extraction_chain", [])
        pmissing = [lv for lv in pext if lv not in sphi]
        if pmissing:
            errors.append(f"{where}: source_phi not total on {peer}'s "
                          f"extraction chain (missing: "
                          f"{', '.join(pmissing)})")
        simages = [dep.erank(sphi[lv]) for lv in pext if lv in sphi]
        if any(a > b for a, b in zip(simages, simages[1:])):
            errors.append(f"{where}: source_phi is not monotone along "
                          f"{peer}'s extraction chain")
    return errors, warns


# ---------------------------------------------------------------------------
# Registry loading and traversal
# ---------------------------------------------------------------------------

def walk(node, path=()):
    """Yield (node, path) for every node in the tree. path is a tuple of ids."""
    p = path + (node.get("id", "?"),)
    yield node, p
    for child in node.get("children") or []:
        if isinstance(child, dict):
            yield from walk(child, p)


def parse_shared(value):
    """Parse '<registry>#<node-id>'. Returns (registry, node_id) or None."""
    if not isinstance(value, str) or value.count("#") != 1:
        return None
    reg, nid = value.split("#")
    if not reg or not nid:
        return None
    return reg, nid


def _load_registry_file(path, label):
    try:
        with open(path) as fh:
            data = json.load(fh)
        tree = data.get("tree")
        if not isinstance(tree, dict):
            return None, f"registry '{label}' has no tree"
        return tree, None
    except OSError:
        return None, f"registry '{label}' not found at {path}"
    except json.JSONDecodeError as exc:
        return None, f"registry '{label}' is not valid JSON ({exc})"


def reg_key(dep, context_key, ref):
    """Canonical key for a registry name as seen from a context registry.

    Key namespace: 'name' = sibling in the local registry dir;
    '<peer>/name' = a registry in that peer's synced snapshot
    (interfaces[peer].registry_dir). Inside a peer's tree an unqualified
    name is the peer's own sibling, and a name qualified with OUR agent
    name points back at a local registry (both sides address the same
    canonical registries; snapshots are copies of them). A reference to a
    peer of a peer is unresolvable from here: returns None.
    """
    context_peer = context_key.split("/", 1)[0] if "/" in context_key else None
    if "/" not in ref:
        return f"{context_peer}/{ref}" if context_peer else ref
    head, rest = ref.split("/", 1)
    if "/" in rest:
        return None
    if head == dep.name:
        return rest
    if context_peer is None and head in dep.interfaces:
        return ref
    return None


def load_by_key(dep, registry_dir, key, cache):
    """Load the registry named by a canonical key, memoized.

    Returns (tree, error). Peer keys resolve under the interface's
    registry_dir — a synced snapshot, since agents live in separate
    containers (citing a peer's registry means carrying a copy).
    """
    if key in cache:
        return cache[key]
    if "/" in key:
        peer, name = key.split("/", 1)
        iface = dep.interfaces.get(peer)
        if iface is None:
            result = (None, f"no interface declared for peer '{peer}'")
        else:
            result = _load_registry_file(
                Path(iface["registry_dir"]) / (name + ".json"), key)
    else:
        result = _load_registry_file(
            Path(registry_dir) / (key + ".json"), key)
    cache[key] = result
    return result


def find_node(tree, nid):
    for node, _ in walk(tree):
        if node.get("id") == nid:
            return node
    return None


def resolve_shared(dep, node, registry_dir, cache):
    """Resolve a node's 'shared' ref to its canonical node.

    One-hop rule: the canonical node must not itself be shared, so
    resolution is a single lookup. Returns (target, iface, error);
    iface is the cross-agent interface when the canonical node lives in
    a peer's trust system — its trust is then only meaningful through
    phi (Lemma 3.2), never raw.
    """
    parsed = parse_shared(node.get("shared"))
    if parsed is None:
        return None, None, ("'shared' must be '<registry>#<node-id>' "
                            f"(got {node.get('shared')!r})")
    reg, nid = parsed
    key = reg_key(dep, "", reg)
    if key is None:
        return None, None, (f"registry '{reg}' is not resolvable from here "
                            f"(unknown peer, or a peer of a peer)")
    iface = dep.interfaces.get(key.split("/", 1)[0]) if "/" in key else None
    tree, err = load_by_key(dep, registry_dir, key, cache)
    if err:
        return None, iface, err
    target = find_node(tree, nid)
    if target is None:
        return None, iface, f"shared target '{reg}#{nid}' not found"
    if target.get("shared") is not None:
        return None, iface, (f"shared target '{reg}#{nid}' is itself shared "
                             f"(one-hop rule: point at the canonical node)")
    return target, iface, None


# ---------------------------------------------------------------------------
# Acyclicity (Remark 2.3): the premise digraph over (registry, node-id)
# ---------------------------------------------------------------------------

def check_acyclic(dep, own_name, tree, registry_dir, cache):
    """Explicit well-foundedness check on the cross-registry premise digraph.

    Nodes are (registry-key, node-id); edges are parent -> child within a
    tree and stub -> canonical across registries — including across AGENTS:
    peer snapshots are walked, and a peer stub qualified with our own agent
    name closes the loop back into local registries. A single JSON tree is
    acyclic by format; 'shared' links break tree-ness, and the one-hop rule
    alone does NOT exclude cycles (a stub in A can point into B whose
    descendant stub points back above the first stub in A — with or without
    a container boundary in between). Circular citation is trust inflation
    that passes every node-local check (Lean `cyc`), so the cycle check is
    load-bearing, not hygiene. Cross-agent it is also where Lemma 3.2 would
    otherwise be abused: two agents each grading the other's claim as their
    premise is tau = bottom on both sides.
    """
    errors = []
    trees = {own_name: tree}

    def get_tree(key):
        if key in trees:
            return trees[key]
        t, _ = load_by_key(dep, registry_dir, key, cache)
        trees[key] = t
        return t

    # child edges by (key, id); stub edges resolved lazily
    def edges(key, nid):
        t = get_tree(key)
        if t is None:
            return
        n = find_node(t, nid)
        if n is None:
            return
        parsed = parse_shared(n["shared"]) if n.get("shared") else None
        if parsed:
            tgt = reg_key(dep, key, parsed[0])
            if tgt is not None:
                yield (tgt, parsed[1])
        for child in n.get("children") or []:
            if isinstance(child, dict) and child.get("id"):
                yield (key, child["id"])

    WHITE, GREY, BLACK = 0, 1, 2
    colour = {}

    def dfs(start):
        stack = [(start, iter(edges(*start)))]
        colour[start] = GREY
        path = [start]
        while stack:
            node, it = stack[-1]
            advanced = False
            for succ in it:
                if colour.get(succ, WHITE) == GREY:
                    cyc = path[path.index(succ):] + [succ]
                    errors.append(
                        "cycle in the premise relation (tau = bottom on it, "
                        "every node-local check passes — Remark 2.3): "
                        + " -> ".join(f"{r}#{i}" for r, i in cyc))
                elif colour.get(succ, WHITE) == WHITE:
                    colour[succ] = GREY
                    stack.append((succ, iter(edges(*succ))))
                    path.append(succ)
                    advanced = True
                    break
            if not advanced:
                colour[node] = BLACK
                stack.pop()
                path.pop()

    for node, _ in walk(tree):
        nid = node.get("id")
        if nid and colour.get((own_name, nid), WHITE) == WHITE:
            dfs((own_name, nid))
    return errors


# ---------------------------------------------------------------------------
# Sources index
# ---------------------------------------------------------------------------

def load_sources(dep, path):
    """Load a sources index. Returns (index_or_None, warning_or_None)."""
    if path == "skip":
        return None, None
    explicit = path is not None
    path = Path(path) if path else dep.root / dep.sources_default
    try:
        data = json.loads(Path(path).read_text())
    except OSError:
        if explicit:
            return None, f"sources index '{path}' not found; skipping source checks"
        return None, None   # default path absent: quietly skip
    except json.JSONDecodeError as exc:
        return None, (f"sources index '{path}' is not valid JSON ({exc}); "
                      f"skipping source checks")
    return data if isinstance(data, dict) else {}, None


def validate_sources(dep, data, chunks_dir):
    """Validate the index itself (format, fields, extraction, files on disk)."""
    problems = []
    if dep.sources_format and data.get("format") != dep.sources_format:
        problems.append(f"sources index: missing or unknown 'format' "
                        f"(want {dep.sources_format})")
    sources = data.get("sources")
    if not isinstance(sources, dict):
        return {}, problems + ["sources index: 'sources' must be an object"]
    for slug, entry in sources.items():
        where = f"sources[{slug}]"
        if not isinstance(entry, dict):
            problems.append(f"{where}: entry must be an object")
            continue
        for field in ("title", "extraction", "read"):
            if field not in entry:
                problems.append(f"{where}: missing '{field}'")
        level = entry.get("extraction")
        if level is not None and level not in dep.extraction_rank:
            problems.append(f"{where}: extraction '{level}' invalid "
                            f"(one of: {', '.join(dep.extraction_chain)})")
        if (chunks_dir is not None and level not in dep.corpus_exempt
                and not (chunks_dir / slug).is_dir()):
            problems.append(
                f"{where}: no corpus directory {chunks_dir / slug} "
                f"(if this paper is not in the corpus, mark it "
                f"'{next(iter(dep.corpus_exempt), 'recalled')}')")
        for rel in entry.get("read", []) or []:
            if not (dep.root / rel).exists():
                problems.append(f"{where}: read file missing: {rel}")
        for i, corr in enumerate(entry.get("corrections", []) or []):
            if not isinstance(corr, dict) or "date" not in corr or "note" not in corr:
                problems.append(f"{where}: corrections[{i}] needs 'date' and 'note'")
    return sources, problems


def below_extraction(dep, entry, threshold):
    """Missing/invalid extraction ranks at the bottom: no check recorded."""
    return dep.erank(entry.get("extraction")) < dep.erank(threshold)


# ---------------------------------------------------------------------------
# Registry validation: (+) and everything node-local
# ---------------------------------------------------------------------------

NODE_REQUIRED = ("id", "approach", "trust", "children")
VALID_ROLES = ("premise", "attempt")


def validate_registry(dep, registry, own_name, files_dir, registry_dir,
                      source_index, warnings):
    errors = []
    reg_cache = {}
    peer_sources_cache = {}
    b_at = dep.boundary_at

    def transported(canon, iface):
        """Canonical trust as this system sees it: through phi if the
        canonical node lives in a peer's system (Lemma 3.2 — phi(tau) is
        the best safe grade; an unmapped peer level transports as nothing,
        i.e. unchecked)."""
        ct = canon.get("trust")
        return iface["phi"].get(ct) if iface is not None else ct

    def effective_trust(n):
        """Trust for boundary purposes: canonical if shared (Cor 3.5),
        transported along phi if the canonical node is a peer's."""
        if n.get("shared") is None or registry_dir is None:
            return n.get("trust")
        canon, iface, _ = resolve_shared(dep, n, registry_dir, reg_cache)
        return transported(canon, iface) if canon is not None \
            else n.get("trust")

    def peer_source_entry(sid, loc):
        """Resolve '<peer>:<slug>' in the peer's sources index, with its
        extraction level demoted through source_phi: extraction does not
        survive delegation at full strength (we hold the peer's record of
        the check, not the check)."""
        peer, slug = sid.split(":", 1)
        iface = dep.interfaces.get(peer)
        if iface is None:
            warnings.append(f"{loc}: source '{sid}' names unknown peer "
                            f"'{peer}' (no interface declared)")
            return None
        if peer not in peer_sources_cache:
            idx = None
            p = iface["sources_path"]
            if p is None:
                warnings.append(f"{loc}: interface '{peer}' has no "
                                f"sources_path; cannot resolve '{sid}'")
            else:
                try:
                    idx = json.loads(Path(p).read_text()).get("sources", {})
                except (OSError, json.JSONDecodeError) as exc:
                    warnings.append(f"{loc}: {peer}'s sources index at "
                                    f"'{p}' unreadable ({exc})")
            peer_sources_cache[peer] = idx
        idx = peer_sources_cache[peer]
        if idx is None:
            return None
        entry = idx.get(slug)
        if entry is None:
            warnings.append(f"{loc}: source '{sid}' not in {peer}'s "
                            f"sources index")
            return None
        level = iface["source_phi"].get(entry.get("extraction"))
        return {**entry, "extraction": level}

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

        # trust values live in T + specials
        trust = node.get("trust")
        if trust is not None and trust not in dep.valid_trust:
            errors.append(f"{loc}: invalid trust '{trust}' "
                          f"(valid: {', '.join(sorted(dep.valid_trust))})")

        # role: required on every non-root node, must be premise or attempt
        role = node.get("role")
        if len(path) > 1:  # not root
            if role is None:
                errors.append(f"{loc}: missing 'role' field "
                              f"(must be 'premise' or 'attempt')")
            elif role not in VALID_ROLES:
                errors.append(f"{loc}: invalid role '{role}' "
                              f"(must be 'premise' or 'attempt')")

        # shared nodes are stubs; local trust is a cache that must not
        # exceed the canonical trust (cross-registry boundary, Cor 3.5)
        shared = node.get("shared")
        if shared is not None:
            if node.get("children"):
                errors.append(f"{loc}: shared node must be a stub "
                              f"(children live at the canonical node)")
            if registry_dir is not None:
                canon, iface, err = resolve_shared(dep, node, registry_dir,
                                                   reg_cache)
                if err:
                    errors.append(f"{loc}: {err}")
                else:
                    ct = transported(canon, iface)
                    raw = canon.get("trust")
                    via = (f" (canonical '{raw}' via phi)"
                           if iface is not None else "")
                    if iface is not None and ct is None:
                        errors.append(
                            f"{loc}: canonical '{shared}' has trust "
                            f"'{raw}' with no phi image — transports as "
                            f"unchecked; extend the interface map or do "
                            f"not cite it")
                    elif ct == "dead-end":
                        if trust != "dead-end":
                            errors.append(
                                f"{loc}: canonical '{shared}' is "
                                f"dead-end{via} but stub claims '{trust}'")
                    elif dep.cap_rank(trust) > dep.cap_rank(ct):
                        errors.append(
                            f"{loc}: stub trust '{trust}' exceeds canonical "
                            f"'{shared}' trust '{ct}'{via} (trust lives at "
                            f"the canonical node)")
                    # trust transport requires artifact transport: an
                    # import at/above our boundary is load-bearing, so
                    # its evidence must exist on OUR side of the
                    # container boundary
                    if (iface is not None and ct is not None
                            and dep.trank(ct) >= dep.trank(b_at)):
                        f_ = canon.get("file")
                        root_ = iface["artifact_root"]
                        present = bool(f_) and root_ is not None \
                            and (root_ / f_).is_file()
                        if not present:
                            detail = (f"evidence '{f_}' not under {root_}"
                                      if f_ else "canonical node has no "
                                                 "'file'")
                            msg = (f"{loc}: imports '{shared}' at '{ct}' "
                                   f"but {detail} — trust transport "
                                   f"requires artifact transport")
                            if iface["on_missing_artifact"] == "warning":
                                warnings.append(msg)
                            else:
                                errors.append(msg)

        # dead ends: reasons + refutation sub-poset (section 5)
        if trust == "dead-end":
            if not node.get("reason") and shared is None:
                errors.append(f"{loc}: dead-end without a 'reason'")
            ref = node.get("refutation")
            if ref is not None and ref not in dep.refutation_rank:
                errors.append(
                    f"{loc}: invalid refutation '{ref}' "
                    f"(valid: {', '.join(dep.refutation_chain)})")
            elif (ref is not None
                    and dep.refutation_rank[ref] >= dep.refutation_rank.get(
                        "computed", 1)
                    and not node.get("file")):
                warnings.append(
                    f"{loc}: refutation '{ref}' but no 'file' — evidence "
                    f"that strong should live somewhere on disk")
        elif node.get("refutation") is not None:
            errors.append(f"{loc}: 'refutation' only belongs on dead-end "
                          f"nodes (trust is '{trust}')")

        # evidence fields: a self-assigned label with no artifact is
        # trust inflation. Stubs are exempt: evidence lives at the
        # canonical node.
        spec = dep.evidence.get(trust)
        if spec and shared is None and not node.get(spec["field"]):
            msg = (f"{loc}: {trust} without a '{spec['field']}' field "
                   f"({spec.get('hint', 'pointer to the evidence')})")
            if spec.get("severity", "error") == "warning":
                warnings.append(msg)
            else:
                errors.append(msg)

        # boundary rule (+): claiming >= boundary_at requires every
        # premise child at least boundary_at, at canonical trust.
        # Attempt children are exploration, not dependencies.
        if dep.trank(trust) >= dep.trank(b_at):
            for child in node.get("children") or []:
                if child.get("role") == "attempt":
                    continue
                ct = effective_trust(child)
                if ct == "dead-end":
                    continue
                if dep.trank(ct) < dep.trank(b_at):
                    errors.append(
                        f"{loc}: claims '{trust}' but premise child "
                        f"'{child.get('id')}' is '{ct}' (boundary rule: "
                        f"premise children must be at least '{b_at}')")

        # citation provenance: phi blocking (Cor 3.4)
        srcs = node.get("sources")
        if srcs is not None:
            if not (isinstance(srcs, list)
                    and all(isinstance(s, str) for s in srcs)):
                errors.append(f"{loc}: 'sources' must be a list of source-id "
                              f"strings")
            else:
                known = []
                for sid in srcs:
                    if ":" in sid:      # '<peer>:<slug>' — via an interface
                        entry = peer_source_entry(sid, loc)
                        if entry is not None:
                            known.append(entry)
                    elif source_index is not None:
                        entry = source_index.get(sid)
                        if entry is None:
                            warnings.append(
                                f"{loc}: source '{sid}' not in the sources "
                                f"index (add it, or check the id)")
                        else:
                            known.append(entry)
                for rule in dep.blocking:
                    if (known
                            and dep.trank(trust) >= dep.trank(rule["blocks_trust"])
                            and all(below_extraction(dep, e,
                                                     rule["below_extraction"])
                                    for e in known)):
                        errors.append(
                            f"{loc}: claims '{trust}' but every cited source "
                            f"is below '{rule['below_extraction']}' — extract "
                            f"at least one that far (check the hypotheses) "
                            f"before it is load-bearing")

        # file references
        f = node.get("file")
        if f is not None and files_dir is not None:
            if not os.path.isfile(os.path.join(files_dir, f)):
                errors.append(f"{loc}: file '{f}' not found under {files_dir}")

    # status should mirror the root's trust
    if registry.get("status") != tree.get("trust"):
        errors.append(f"top level: status '{registry.get('status')}' does not "
                      f"match root trust '{tree.get('trust')}'")

    # well-foundedness, explicitly (Remark 2.3)
    if registry_dir is not None:
        errors.extend(check_acyclic(dep, own_name, tree, registry_dir,
                                    reg_cache))

    return errors


# ---------------------------------------------------------------------------
# Machine citations in files
# ---------------------------------------------------------------------------

def machine_refs(dep, path):
    if dep.machine_re is None:
        return []
    return sorted(set(dep.machine_re.findall(path.read_text(errors="replace"))))


def slug_of(ref):
    return ref.split("/", 1)[0]


def resolve_machine(dep, ref, sources, chunks_dir):
    """Does a machine-format citation resolve? Returns (ok, why_not)."""
    slug = slug_of(ref)
    if sources is not None and slug not in sources:
        return False, "unregistered source"
    if dep.machine_resolve == "corpus-file":
        if chunks_dir is not None and not (
                chunks_dir / (ref + dep.machine_suffix)).is_file():
            return False, "no such chunk on disk"
    return True, None


def check_files(dep, files, sources, chunks_dir):
    problems = []
    for f in files:
        for ref in machine_refs(dep, f):
            slug = slug_of(ref)
            if sources is not None and slug not in sources:
                problems.append(
                    f"{f}: cites {ref} — unregistered source; add '{slug}' "
                    f"to the sources index at its honest extraction level")
            if (dep.machine_resolve == "corpus-file" and chunks_dir is not None
                    and not (chunks_dir / (ref + dep.machine_suffix)).is_file()):
                problems.append(
                    f"{f}: cites {ref} — no such chunk on disk "
                    f"(hallucinated reference? check {chunks_dir / slug})")
    return problems


# ---------------------------------------------------------------------------
# Reports over registries (unchanged semantics from the deployed ports)
# ---------------------------------------------------------------------------

def report_successful_path(dep, tree):
    lines = []
    b = dep.trank(dep.boundary_at)

    def rec(node, depth):
        trust = node.get("trust")
        if dep.trank(trust) >= b:
            lean = f"  [lean: {node['lean']}]" if node.get("lean") else ""
            f = f"  ({node['file']})" if node.get("file") else ""
            lines.append(f"{'  ' * depth}{node['id']}: {node['approach']} "
                         f"[{trust}]{lean}{f}")
            for child in node.get("children") or []:
                rec(child, depth + 1)

    root = tree
    if dep.trank(root.get("trust")) < b:
        lines.append(f"{root['id']}: {root['approach']} [{root.get('trust')}] "
                     f"(open; {dep.boundary_at} subtrees below)")
        for child in root.get("children") or []:
            rec(child, 1)
    else:
        rec(root, 0)
    return lines or [f"(nothing at '{dep.boundary_at}' or above yet)"]


def report_dead_ends(dep, tree):
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
                best = max((dep.trank(c.get("trust"))
                            for c in node.get("children") or []), default=-1)
                if best >= 0:
                    lines.append(f"    refutation: {dep.trust_chain[best]} "
                                 f"(inferred from children)")
                else:
                    lines.append("    refutation: judgment (default; "
                                 "no counterexample recorded)")
    return lines or ["(no dead ends recorded)"]


def report_frontier(dep, tree):
    lines = []
    for node, path in walk(tree):
        trust = node.get("trust")
        if trust == "dead-end":
            continue
        if dep.trank(trust) < dep.trank(dep.boundary_at):
            lines.append(f"{'/'.join(path)} [{trust}]: {node.get('approach')}")
    return lines or ["(no open nodes: the conjecture is closed)"]


def report_cross_refs(dep, tree, own_name, registry_dir):
    cache = {}
    lines = ["outgoing:"]
    found = False
    for node, path in walk(tree):
        if node.get("shared") is None:
            continue
        found = True
        canon, iface, err = resolve_shared(dep, node, registry_dir, cache)
        if canon is None:
            detail = f"[UNRESOLVED: {err}]"
        elif iface is not None:
            raw = canon.get("trust")
            detail = f"[{raw} -> {iface['phi'].get(raw)} via phi]"
        else:
            detail = f"[{canon.get('trust')}]"
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
        sib_tree, _ = load_by_key(dep, registry_dir, name, cache)
        if sib_tree is None:
            continue
        for node, path in walk(sib_tree):
            parsed = parse_shared(node.get("shared")) \
                if node.get("shared") is not None else None
            if parsed and parsed[0] == own_name:
                found = True
                lines.append(f"  {name}: {'/'.join(path)} -> #{parsed[1]}")
    # incoming from peer snapshots: refs qualified with OUR agent name
    for peer, iface in sorted(dep.interfaces.items()):
        try:
            fnames = sorted(f for f in os.listdir(iface["registry_dir"])
                            if f.endswith(".json"))
        except OSError:
            continue
        for fname in fnames:
            key = f"{peer}/{fname[:-len('.json')]}"
            sib_tree, _ = load_by_key(dep, registry_dir, key, cache)
            if sib_tree is None:
                continue
            for node, path in walk(sib_tree):
                parsed = parse_shared(node.get("shared")) \
                    if node.get("shared") is not None else None
                if parsed and parsed[0].startswith(dep.name + "/"):
                    found = True
                    target = parsed[0].split("/", 1)[1]
                    lines.append(f"  {key}: {'/'.join(path)} -> "
                                 f"{target}#{parsed[1]}")
    if not found:
        lines.append("  (none)")
    return lines


# ---------------------------------------------------------------------------
# Reports over files
# ---------------------------------------------------------------------------

def floor_level(dep, levels):
    return min(levels, key=dep.erank) if levels else None


def report_footprint(dep, files, sources):
    for f in files:
        refs = machine_refs(dep, f)
        print(f"\n{f}")
        if not refs:
            print("  no machine citations found")
            continue
        levels = []
        for slug in sorted({slug_of(r) for r in refs}):
            entry = sources.get(slug)
            used = [r for r in refs if slug_of(r) == slug]
            if entry is None:
                print(f"  {slug}  UNREGISTERED  ({len(used)} citation(s))")
                continue
            level = entry.get("extraction", "?")
            levels.append(level)
            flags = ""
            if entry.get("corrections"):
                flags = f"  [{len(entry['corrections'])} correction(s) — check them]"
            print(f"  {slug}  {level:<13} {len(used)} citation(s){flags}")
        fl = floor_level(dep, [l for l in levels if l in dep.extraction_rank])
        print(f"  provenance floor: {fl or 'n/a (unregistered citations only)'}")


def report_shallow(dep, files, sources):
    threshold = dep.blocking[0]["below_extraction"] if dep.blocking else None
    if threshold is None:
        print("no blocking rule in the deployment descriptor; nothing to report")
        return
    leaning = {}
    for f in files:
        for ref in machine_refs(dep, f):
            slug = slug_of(ref)
            entry = sources.get(slug)
            if entry and below_extraction(dep, entry, threshold):
                leaning.setdefault(slug, []).append(f)
    if not leaning:
        print(f"no sources below '{threshold}' are cited by the scanned files")
        return
    print(f"extraction worklist (sources below '{threshold}', "
          f"most-leaned-on first):")
    for slug, fs in sorted(leaning.items(), key=lambda kv: -len(kv[1])):
        entry = sources[slug]
        print(f"  {slug}  [{entry.get('extraction')}] — cited by {len(fs)} file(s)")
        for f in sorted(set(fs)):
            print(f"      {f}")


# --- certificate gap: modes 1 and 2 of section 4 ---------------------------

# Path-shaped prose tokens: optionally ~/ or ./ or ../, then a path with a
# recognisable text extension. Deliberately conservative — this is an
# existence-check on candidate rho caches, not a parser.
PROSE_PATH_RE = re.compile(
    r"(?<![\w/])((?:~/|\.{1,2}/)?[A-Za-z0-9_\-][\w.\-]*(?:/[\w.\-]+)*"
    r"\.(?:tex|md|json|py|lean|txt))\b")

# an optional 'lines 2672-2687' / '2672–2687' locator shortly after the path
LINE_RANGE_RE = re.compile(
    r"^[^\n]{0,40}?(?:lines?\s*)?(\d{2,6})\s*[\u2013\u2014-]\s*(\d{2,6})")


def _basename_index(roots):
    """Memoized recursive basename search over the prose roots."""
    cache = {}

    def lookup(name):
        if name not in cache:
            hits = []
            for root in roots:
                if root.is_dir():
                    hits.extend(root.rglob(name))
                if len(hits) > 20:
                    break
            cache[name] = hits
        return cache[name]

    return lookup


def resolve_prose(dep, token, lookup):
    """Resolve a prose path token against the deployment's search roots.

    Returns a list of existing paths (empty = unresolved)."""
    raw = Path(os.path.expanduser(token))
    if raw.is_absolute():
        return [raw] if raw.exists() else []
    hits = []
    for root in dep.prose_roots + [dep.root]:
        p = (root / token)
        if p.exists():
            hits.append(p)
    if hits:
        return hits
    candidates = list(lookup(raw.name))
    if "/" not in token or not candidates:
        return candidates
    # path with directories that doesn't join onto any root: prefer the
    # candidates sharing the longest trailing-component suffix with it
    parts = raw.parts
    best, best_k = [], 0
    for cand in candidates:
        cp = cand.parts
        k = 0
        while (k < len(parts) and k < len(cp)
               and parts[-1 - k].lower() == cp[-1 - k].lower()):
            k += 1
        if k > best_k:
            best, best_k = [cand], k
        elif k == best_k:
            best.append(cand)
    return best


def report_certificate_gap(dep, files, sources, chunks_dir):
    """Classify every outgoing reference of the given files.

      (a) machine format, resolves        — valid cached rho
      (b) machine format, dangling        — broken cache (hallucinated ref)
      (c) prose, resolves extensionally   — MODE 2: a consolidation exists,
          tau is preserved, but the certified t < tau (Lemma 2.2 (ii));
          backfill candidate before the next consolidation makes the
          loss canonical
      (d) prose, unresolvable             — MODE 1 candidate (rho absent)

    'Prose' = path-shaped tokens and registered source ids mentioned
    without machine format.
    """
    lookup = _basename_index(dep.prose_roots)
    tot = {"a": 0, "b": 0, "c": 0, "d": 0}
    for f in files:
        text = f.read_text(errors="replace")
        a, b, c, d = [], [], [], []

        mrefs = sorted(set(dep.machine_re.findall(text))) if dep.machine_re else []
        for ref in mrefs:
            ok, why = resolve_machine(dep, ref, sources, chunks_dir)
            (a if ok else b).append(ref if ok else f"{ref} ({why})")

        seen = set()
        for m in PROSE_PATH_RE.finditer(text):
            token = m.group(1)
            if token in seen:
                continue
            seen.add(token)
            if any(token in r for r in mrefs):
                continue
            locator = ""
            lr = LINE_RANGE_RE.match(text[m.end():m.end() + 60])
            hits = resolve_prose(dep, token, lookup)
            if hits:
                if lr:
                    lo, hi = int(lr.group(1)), int(lr.group(2))
                    n = max(len(h.read_text(errors="replace").splitlines())
                            for h in hits[:5] if h.is_file())
                    locator = (f", lines {lo}-{hi} "
                               + ("OK" if lo <= hi <= n else
                                  f"OUT OF RANGE (file has {n})"))
                where = str(hits[0]) + (f" (+{len(hits) - 1} more)"
                                        if len(hits) > 1 else "")
                c.append(f"{token} -> {where}{locator}")
            else:
                d.append(token)

        # registered source ids named in prose without a machine ref
        if sources:
            cited_slugs = {slug_of(r) for r in mrefs}
            for slug in sources:
                if slug in cited_slugs:
                    continue
                if re.search(r"(?<![\w/])" + re.escape(slug) + r"(?![\w/])",
                             text):
                    c.append(f"{slug} (registered source named in prose, "
                             f"no machine citation)")

        print(f"\n{f}")
        for key, label, items in (
                ("a", "machine, resolves (valid cached rho)", a),
                ("b", "machine, DANGLING (broken cache)", b),
                ("c", "prose, resolves extensionally (MODE 2: t < tau, "
                      "backfill candidate)", c),
                ("d", "prose, unresolvable (MODE 1 candidate: rho absent?)", d)):
            tot[key] += len(items)
            if items:
                print(f"  ({key}) {label}: {len(items)}")
                for it in items:
                    print(f"        {it}")
        if not any((a, b, c, d)):
            print("  no outgoing references found")

    print(f"\ncertificate gap: {tot['c']} reference(s) resolve extensionally "
          f"but not in machine format (mode 2 — the certified t is below "
          f"canonical tau; backfill these), {tot['b']} dangling machine "
          f"ref(s), {tot['d']} unresolved prose token(s) (mode 1 candidates), "
          f"{tot['a']} valid machine ref(s).")
    return 0


REGISTRY_REPORTS = {"successful-path", "dead-ends", "frontier", "cross-refs"}
FILE_REPORTS = {"footprint", "shallow", "certificate-gap"}


# ---------------------------------------------------------------------------
# Directed container operations (Lean: Directed.lean, CoKleisli.lean)
#
# The registry tree is a directed container (Ahman-Chapman-Uustalu):
#   Shape  = rose tree structure
#   Pos    = index-tuple paths: () = root, (i,) = i-th child, ...
#   root   = ()
#   sub    = follow the path
#   shift  = path concatenation (the free monoid on child indices)
#
# The comonad on Ext(Shape, Pos):
#   extract <s,v> = v(root(s))           — read the label at the root
#   comult  <s,v> = <s, p -> <sub(s,p), q -> v(shift(s,p,q))>>
#                                         — at each position, the full subtree
#
# CoKleisli:
#   extend f <s,v> = <s, p -> f(sub(s,p))>
#   g .* f = g o extend(f)
#
# Strength:
#   sigma <s,v> = (fst(v(root(s))), <s, snd o v>)
# ---------------------------------------------------------------------------

def dc_extract(tree):
    """Counit: read the label at the root. (Lean: counit)

    extract <s, v> = v(root(s)) = v(()).
    Returns the root node dict without children."""
    return {k: v for k, v in tree.items() if k != "children"}


def dc_sub(tree, path):
    """Sub-shape at a position. (Lean: RTree.sub)

    sub(t, ()) = t;  sub(t, (i,)+rest) = sub(children[i], rest)."""
    node = tree
    for i in path:
        children = node.get("children") or []
        if i < 0 or i >= len(children):
            raise IndexError(f"child index {i} out of range "
                             f"(node '{node.get('id')}' has {len(children)} "
                             f"children)")
        node = children[i]
    return node


def dc_shift(path_p, path_q):
    """Shift: path concatenation. (Lean: RTree.shift)

    shift(s, p, q) = p ++ q.  No tree argument needed — positions are
    the free monoid on child indices."""
    return path_p + path_q


def dc_duplicate(tree):
    """Comultiplication: at each node, attach the subtree from that point.
    (Lean: comult)

    comult <s, v> = <s, p -> <sub(s,p), q -> v(shift(s,p,q))>>.
    Returns a new tree where every node carries "_subtree": the original
    subtree from that position.  JSON-serializable."""
    result = {k: v for k, v in tree.items() if k != "children"}
    result["_subtree"] = tree
    children = tree.get("children") or []
    result["children"] = [dc_duplicate(c) for c in children]
    return result


def dc_extend(f, tree):
    """CoKleisli extension: apply f at every position.  (Lean: extend)

    extend(f) <s, v> = <s, p -> f(<sub(s,p), ...>)>.
    Returns a tree of same shape where every node carries "_value": f(subtree).
    When f = dc_extract, extend(extract) = id (right unit law, Lean:
    extend_counit)."""
    result = {k: v for k, v in tree.items() if k != "children"}
    result["_value"] = f(tree)
    children = tree.get("children") or []
    result["children"] = [dc_extend(f, c) for c in children]
    return result


def dc_compose(f, g, tree):
    """CoKleisli composition: g .* f = g o extend(f).  (Lean: cokleisli_comp)

    Associativity: (h .* g) .* f = h .* (g .* f), proved in Lean
    (cokleisli_assoc via extend_extend)."""
    extended = dc_extend(f, tree)
    return g(extended)


def dc_strength(registry):
    """Canonical strength: factor uniform context out of the labelled tree.
    (Lean: strength)

    sigma <s, v> = (fst(v(root(s))), <s, snd o v>).
    In practice: split the registry-level metadata (conjecture, status,
    dates) from the tree of nodes.  Returns (context_dict, tree_dict)."""
    context = {k: v for k, v in registry.items() if k != "tree"}
    return context, registry.get("tree")


# ---- Canonical trust (tau) --------------------------------------------------

def dc_tau(dep, tree):
    """Compute canonical trust bottom-up. (Lean: tau, sound_le_tau, tau_sound)

    tau(n) = min(own_trust_rank, min(tau(c) for c in premise_children)).
    Attempt children are excluded — they are exploration, not dependencies.
    Dead-end children are excluded — they are abandoned.

    Returns a dict: node_id -> {"claimed": str, "canonical": str,
    "canonical_rank": int, "status": "TIGHT"|"CONSERVATIVE"|"INFLATED"}."""
    results = {}

    def compute(node):
        trust = node.get("trust")
        own_rank = dep.trank(trust)
        is_special = trust == "dead-end" or trust in dep.special

        # always recurse into children for reporting
        min_child = own_rank if not is_special else len(dep.trust_chain)
        for child in node.get("children") or []:
            child_tau = compute(child)
            if child.get("role") == "attempt":
                continue  # don't constrain parent
            ct = child.get("trust")
            if ct == "dead-end" or ct in dep.special:
                continue
            if child_tau >= 0 and child_tau < min_child:
                min_child = child_tau

        if is_special:
            results[node.get("id")] = {
                "claimed": trust, "canonical": trust,
                "canonical_rank": -1, "status": "TIGHT"}
            return -1

        tau_rank = min(own_rank, min_child) if own_rank >= 0 else -1
        canonical = (dep.trust_chain[tau_rank]
                     if 0 <= tau_rank < len(dep.trust_chain) else trust)

        if own_rank < 0:
            status = "TIGHT"
        elif tau_rank > own_rank:
            status = "CONSERVATIVE"
        elif tau_rank < own_rank:
            status = "INFLATED"
        else:
            status = "TIGHT"

        results[node.get("id")] = {
            "claimed": trust, "canonical": canonical,
            "canonical_rank": tau_rank, "status": status}
        return tau_rank

    compute(tree)
    return results


def report_tau(dep, tree):
    """Human-readable tau report: per-node TIGHT / CONSERVATIVE / INFLATED."""
    results = dc_tau(dep, tree)
    lines = []
    for node, path in walk(tree):
        nid = node.get("id")
        r = results.get(nid)
        if r is None:
            continue
        loc = "/".join(path)
        s = r["status"]
        if s == "TIGHT":
            lines.append(f"  {loc}: {r['claimed']} = tau  [TIGHT]")
        elif s == "CONSERVATIVE":
            lines.append(f"  {loc}: claims {r['claimed']}, tau = "
                         f"{r['canonical']}  [CONSERVATIVE — safe to upgrade]")
        else:
            lines.append(f"  {loc}: claims {r['claimed']}, tau = "
                         f"{r['canonical']}  [INFLATED — boundary violation]")
    return lines


# ---- Multi-hop phi (resolve-transitive) ------------------------------------

def resolve_transitive(dep, tree, registry_dir):
    """Follow shared stubs across registries, composing phi at each hop.

    Detects cycles. Reports the hop chain and composed trust grade for
    each shared stub."""
    cache = {}
    lines = []
    for node, path in walk(tree):
        shared = node.get("shared")
        if shared is None:
            continue
        loc = "/".join(path)
        hops = []
        current_ref = shared
        visited = set()
        trust = None
        cycle = False
        while current_ref is not None:
            if current_ref in visited:
                cycle = True
                break
            visited.add(current_ref)
            parsed = parse_shared(current_ref)
            if parsed is None:
                break
            reg, nid = parsed
            key = reg_key(dep, "", reg)
            if key is None:
                hops.append(f"{current_ref} [UNRESOLVABLE]")
                break
            canon_tree, err = load_by_key(dep, registry_dir, key, cache)
            if err or canon_tree is None:
                hops.append(f"{current_ref} [{err}]")
                break
            target = find_node(canon_tree, nid)
            if target is None:
                hops.append(f"{current_ref} [NOT FOUND]")
                break
            iface = (dep.interfaces.get(key.split("/", 1)[0])
                     if "/" in key else None)
            raw_trust = target.get("trust")
            if iface is not None:
                mapped = iface["phi"].get(raw_trust)
                hops.append(f"{current_ref} [{raw_trust} -> {mapped} via phi]")
                trust = mapped
            else:
                hops.append(f"{current_ref} [{raw_trust}]")
                trust = raw_trust
            current_ref = target.get("shared")

        if cycle:
            lines.append(f"  {loc} -> CYCLE at {current_ref}")
        elif hops:
            chain = " -> ".join(hops)
            lines.append(f"  {loc} -> {chain}")
            if len(hops) > 1:
                lines.append(f"    composed trust: {trust}")
        else:
            lines.append(f"  {loc} -> {shared} [parse error]")
    return lines or ["  (no shared stubs in this registry)"]


DC_OPS = {"extract", "sub", "duplicate", "extend", "strength",
          "tau", "resolve-transitive"}


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(
        description=__doc__.splitlines()[0],
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--deployment", required=True, type=Path,
                    help="deployment descriptor JSON (the (T, phi) data)")
    ap.add_argument("--root", type=Path, default=Path("."),
                    help="deployment root; relative descriptor paths and "
                         "'read' entries resolve against it (default: cwd)")
    ap.add_argument("--sources", default=None,
                    help="sources index path (default: descriptor's "
                         "default_path under --root); 'skip' disables")
    ap.add_argument("--chunks-dir", default=None,
                    help="corpus dir override; 'skip' disables on-disk checks")
    sub = ap.add_subparsers(dest="cmd", required=True)

    v = sub.add_parser("validate", help="validate a registry")
    v.add_argument("registry", type=Path)
    v.add_argument("--files-dir", default=None,
                   help="base for node 'file' paths (default: --root); "
                        "'skip' disables")
    v.add_argument("--registry-dir", default=None,
                   help="sibling registries for 'shared' refs (default: the "
                        "registry's directory); 'skip' disables")

    s = sub.add_parser("sources", help="validate the sources index "
                                       "(+ machine refs in FILES)")
    s.add_argument("files", nargs="*", type=Path)

    r = sub.add_parser("report", help="print a report")
    r.add_argument("name", choices=sorted(REGISTRY_REPORTS | FILE_REPORTS))
    r.add_argument("targets", nargs="+", type=Path,
                   help="a registry (registry reports) or files (file reports)")
    r.add_argument("--registry-dir", default=None)

    o = sub.add_parser("ops", help="directed container operations "
                                   "(Lean: Directed.lean, CoKleisli.lean)")
    o.add_argument("op", choices=sorted(DC_OPS))
    o.add_argument("registry", type=Path)
    o.add_argument("path_indices", nargs="*", type=int,
                   help="child indices for 'sub' (e.g. 2 0 = 3rd child, "
                        "then 1st child)")
    o.add_argument("--registry-dir", default=None)

    args = ap.parse_args()
    dep = load_deployment(args.deployment, args.root)

    # corpus dir (chunk deployments only)
    if args.chunks_dir == "skip":
        chunks_dir = None
    elif args.chunks_dir:
        chunks_dir = Path(args.chunks_dir)
    elif dep.corpus_dir:
        chunks_dir = dep._resolve(dep.corpus_dir)
        if not chunks_dir.is_dir():
            print(f"note: {chunks_dir} not found; skipping on-disk chunk checks",
                  file=sys.stderr)
            chunks_dir = None
    else:
        chunks_dir = None

    # descriptor-level lint of the cross-agent interfaces (Def 3.1)
    iface_errors, iface_warnings = lint_interfaces(dep, args.deployment)

    src_data, src_warning = load_sources(dep, args.sources)
    warnings = iface_warnings + ([src_warning] if src_warning else [])
    sources, src_problems = (None, [])
    if src_data is not None:
        sources, src_problems = validate_sources(dep, src_data, chunks_dir)

    if args.cmd == "sources":
        problems = iface_errors + src_problems + check_files(
            dep, args.files, sources, chunks_dir)
        for p in problems:
            print(p)
        if problems:
            print(f"\n{len(problems)} problem(s). Advisory: fix what's real.")
            return 1
        n = len(args.files)
        print(f"sources index OK ({len(sources or {})} sources)"
              + (f"; {n} file(s) resolve cleanly" if n else ""))
        return 0

    if args.cmd == "ops":
        try:
            registry = json.loads(args.registry.read_text())
        except (OSError, json.JSONDecodeError) as exc:
            print(f"ERROR: cannot read registry: {exc}")
            return 1
        tree = registry.get("tree")
        if not isinstance(tree, dict):
            print("ERROR: no tree to report on")
            return 1

        if args.op == "extract":
            print(json.dumps(dc_extract(tree), indent=2))
        elif args.op == "sub":
            path = tuple(args.path_indices or [])
            try:
                subtree = dc_sub(tree, path)
            except (IndexError, KeyError) as exc:
                print(f"ERROR: {exc}")
                return 1
            print(json.dumps(subtree, indent=2))
        elif args.op == "duplicate":
            print(json.dumps(dc_duplicate(tree), indent=2))
        elif args.op == "extend":
            result = dc_extend(dc_extract, tree)
            print(json.dumps(result, indent=2))
        elif args.op == "strength":
            context, t = dc_strength(registry)
            print(json.dumps({"context": context, "tree_root":
                              dc_extract(t) if t else None}, indent=2))
        elif args.op == "tau":
            print(f"# tau: {registry.get('conjecture', '?')}")
            for line in report_tau(dep, tree):
                print(line)
        elif args.op == "resolve-transitive":
            registry_dir = (args.registry_dir
                            or str(args.registry.resolve().parent))
            print(f"# resolve-transitive: {registry.get('conjecture', '?')}")
            for line in resolve_transitive(dep, tree, registry_dir):
                print(line)
        return 0

    if args.cmd == "report":
        if args.name in FILE_REPORTS:
            if args.name == "footprint":
                report_footprint(dep, args.targets, sources or {})
            elif args.name == "shallow":
                report_shallow(dep, args.targets, sources or {})
            else:
                report_certificate_gap(dep, args.targets, sources, chunks_dir)
            return 0
        reg_path = args.targets[0]
        try:
            registry = json.loads(reg_path.read_text())
        except (OSError, json.JSONDecodeError) as exc:
            print(f"ERROR: cannot read registry: {exc}")
            return 1
        tree = registry.get("tree")
        if not isinstance(tree, dict):
            print("ERROR: no tree to report on")
            return 1
        own = reg_path.stem
        registry_dir = args.registry_dir or str(reg_path.resolve().parent)
        print(f"# {args.name}: {registry.get('conjecture', '?')}")
        if args.name == "cross-refs":
            lines = report_cross_refs(dep, tree, own, registry_dir)
        else:
            lines = {"successful-path": report_successful_path,
                     "dead-ends": report_dead_ends,
                     "frontier": report_frontier}[args.name](dep, tree)
        for line in lines:
            print(line)
        return 0

    # validate
    try:
        registry = json.loads(args.registry.read_text())
    except (OSError, json.JSONDecodeError) as exc:
        print(f"ERROR: cannot read registry: {exc}")
        return 1

    files_dir = None if args.files_dir == "skip" else (
        args.files_dir or str(dep.root))
    registry_dir = None if args.registry_dir == "skip" else (
        args.registry_dir or str(args.registry.resolve().parent))

    errors = iface_errors + src_problems + validate_registry(
        dep, registry, args.registry.stem, files_dir, registry_dir,
        sources, warnings)

    if warnings:
        print(f"\n{len(warnings)} warning(s) in {args.registry}:")
        for w in warnings:
            print(f"  ~ {w}")
    if errors:
        print(f"\n{len(errors)} problem(s) in {args.registry}:")
        for e in errors:
            print(f"  - {e}")
        return 1
    print(f"OK: {args.registry} is valid (status: {registry.get('status')}, "
          f"deployment: {dep.name})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
