"""xim / xlings ecosystem plugin for xpkgindex.

The framework core deliberately knows nothing about xvm, programs or archs —
those are xlings concepts, and they used to sit in the core model where they
leaked onto every other ecosystem's pages (an mcpp package page rendered
"XVM Managed: No", which means nothing there). They live here now.

Note the namespace difference from mcpp: in xlings a descriptor's `namespace`
is a classification label, while package references resolve as
`[index:]name[@version]` against the *index repo* name. So the namespace must
NOT be joined into the install command — `xlings install config.claude-llm`
is not a thing.
"""

from __future__ import annotations

import os
from typing import Any, Dict, List, Optional

from xpkgindex.models import Block, Facet, FacetValue, Identity, RowSpec
from xpkgindex.plugins import Plugin

TYPE_TONES = {
    "package": "neutral",
    "config": "module",
    "script": "tool",
    "template": "header",
    "bugfix": "tool",
}


class XimPlugin(Plugin):
    api_version = 1
    name = "xim"

    def on_index(self, ctx) -> None:
        # Omitting the namespace means "this index's default namespace", which
        # xlings takes from the index name — `xim` for the official index
        # (docs/design/index-distribution.md §1.1). So a descriptor without a
        # `namespace` field is not un-namespaced; it is in `xim`.
        ctx.meta.set("default_namespace",
                     os.path.basename(ctx.root).replace("-pkgindex", "") or "xim")

    def identity(self, raw: Dict[str, Any], path: str) -> Optional[Identity]:
        """Short name, explicitly.

        This mirrors what `xlings install` accepts. It is spelled out rather
        than left to the core default so that a future change to that default
        cannot silently rewrite 154 install commands.
        """
        name = str(raw.get("name") or "")
        if not name:
            name = os.path.basename(path)[: -len(".lua")]
        return Identity.plain(str(raw.get("namespace") or ""), name)

    def on_package(self, pkg, raw: Dict[str, Any]) -> None:
        ext = {
            "programs": raw.get("programs") or [],
            "archs": raw.get("archs") or [],
            "xvm_enable": bool(raw.get("xvm_enable")),
            "categories": raw.get("categories") or [],
            "keywords": raw.get("keywords") or [],
            "authors": raw.get("authors") or [],
            "maintainers": raw.get("maintainers") or [],
            "contributors": raw.get("contributors") or "",
            "aliases": raw.get("aliases") or [],
        }
        pkg.extensions["xim"] = ext

        pkg.facets["type"] = pkg.type or "package"
        if pkg.status:
            pkg.facets["status"] = pkg.status
        if ext["categories"]:
            pkg.facets["category"] = str(ext["categories"][0])
        if ext["xvm_enable"]:
            pkg.extensions.setdefault("_badges", []).append("xvm")

    def facets(self) -> List[Facet]:
        return [
            Facet(key="type", label="kind", weight=10, values=[
                FacetValue(key=k, label=k, tone=t) for k, t in TYPE_TONES.items()
            ]),
            Facet(key="category", label="category", weight=30),
            Facet(key="status", label="status", weight=40),
        ]

    def row(self, pkg) -> RowSpec:
        """Card layout: for a tool index the whole question is "what do I type
        to get this", so the row's one strip is the copyable install command
        and the binary you end up with sits beside it."""
        ext = pkg.extensions.get("xim", {})
        programs = [str(p) for p in ext.get("programs") or []]
        return RowSpec(
            variant="card",
            tone=TYPE_TONES.get(pkg.type, "neutral"),
            lead=pkg.type or "package",
            code=(f"$ {programs[0]}" if programs else ""),
            badges=list(pkg.extensions.get("_badges", [])),
        )

    def detail_blocks(self, pkg) -> List[Block]:
        ext = pkg.extensions.get("xim", {})
        blocks: List[Block] = []

        programs = [str(p) for p in ext.get("programs") or []]
        if programs:
            blocks.append(Block(
                kind="code", weight=10,
                data={"role": "interface", "code": f"$ {programs[0]}",
                      "tone": TYPE_TONES.get(pkg.type, "tool"),
                      "label": pkg.type or "package"}))

        items = []
        if programs:
            items.append({"key": "programs", "value": ", ".join(programs), "mono": True})
        if ext.get("archs"):
            items.append({"key": "architectures",
                          "value": ", ".join(str(a) for a in ext["archs"]), "mono": True})
        items.append({"key": "xvm managed", "value": "yes" if ext.get("xvm_enable") else "no"})
        if pkg.status:
            items.append({"key": "status", "value": pkg.status})
        if ext.get("aliases"):
            items.append({"key": "aliases",
                          "value": ", ".join(str(a) for a in ext["aliases"]), "mono": True})
        if items:
            blocks.append(Block(kind="kv", title="Package", data={"items": items}, weight=30))

        people = []
        if ext.get("authors"):
            people.append({"key": "authors", "value": ", ".join(str(a) for a in ext["authors"])})
        if ext.get("maintainers"):
            people.append({"key": "maintainers",
                           "value": ", ".join(str(a) for a in ext["maintainers"])})
        if ext.get("contributors"):
            people.append({"key": "contributors", "value": str(ext["contributors"])})
        if people:
            blocks.append(Block(kind="kv", title="Credits", data={"items": people}, weight=40))

        tags = [str(k) for k in ext.get("keywords") or []]
        if tags:
            blocks.append(Block(kind="list", title="Keywords", collapsed=True, weight=60,
                                data={"items": tags}))
        return blocks
