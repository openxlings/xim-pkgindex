"""The docs as a contract, statically.

- every English chapter (docs/*.md) has its mirror under docs/zh/ with the same
  ##/### headings in the same order and the same code blocks byte for byte, and
  both carry their language line; README.md and README.zh.md likewise;
- every relative link in the READMEs and docs/ resolves (docs/specs/legacy and
  docs/migrations are history and only checked for links);
- nothing that must not be published is there: personal paths, links into
  .agents/, a host package manager's install command in a code block.
"""
import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
FENCE = re.compile(r"^```.*?^```", re.DOTALL | re.MULTILINE)
LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")


def _headings(text):
    body = FENCE.sub("", text)
    return [line.split(" ", 1)[0] for line in body.splitlines()
            if line.startswith("## ") or line.startswith("### ")]


def _pairs():
    pairs = [(ROOT / "README.md", ROOT / "README.zh.md",
              "**English** | [简体中文](README.zh.md)", "[English](README.md) | **简体中文**")]
    for en in sorted(DOCS.glob("*.md")):
        pairs.append((en, DOCS / "zh" / en.name,
                      f"**English** | [简体中文](zh/{en.name})",
                      f"[English](../{en.name}) | **简体中文**"))
    return pairs


@pytest.mark.static
@pytest.mark.parametrize("en,zh,line_en,line_zh", _pairs(), ids=lambda p: getattr(p, "name", ""))
def test_a_chapter_and_its_translation_agree(en, zh, line_en, line_zh):
    assert zh.is_file(), f"{en.relative_to(ROOT)} has no Chinese mirror at {zh.relative_to(ROOT)}"
    et, zt = en.read_text(encoding="utf-8"), zh.read_text(encoding="utf-8")
    assert line_en in et.splitlines()[:4], f"{en.relative_to(ROOT)}: no language line `{line_en}`"
    assert line_zh in zt.splitlines()[:4], f"{zh.relative_to(ROOT)}: no language line `{line_zh}`"
    assert _headings(et) == _headings(zt), "the headings differ"
    assert FENCE.findall(et) == FENCE.findall(zt), "the code blocks differ"


@pytest.mark.static
def test_every_translation_has_an_original():
    for zh in sorted((DOCS / "zh").rglob("*.md")):
        assert (DOCS / zh.relative_to(DOCS / "zh")).is_file(), f"{zh} has no English original"


def _published():
    return [ROOT / "README.md", ROOT / "README.zh.md"] + sorted(DOCS.rglob("*.md"))


@pytest.mark.static
def test_every_relative_link_resolves():
    broken = []
    for path in _published():
        body = FENCE.sub("", path.read_text(encoding="utf-8"))
        for target in LINK.findall(body):
            if re.match(r"^[a-z]+:", target) or target.startswith("#"):
                continue
            file = target.split("#", 1)[0]
            if file and not (path.parent / file).exists():
                broken.append(f"{path.relative_to(ROOT)}: {target}")
    assert not broken, "broken links:\n  " + "\n  ".join(broken)


FORBIDDEN = [
    (re.compile(r"/home/(?!user\b|u\b|runner\b)[a-z][\w.-]*/"), "a personal home path"),
    (re.compile(r"\]\((\.\./)*\.agents/"), "a link into .agents/"),
    (re.compile(r"\.agents/docs/\d{4}-"), "a reference to a working document in .agents/docs"),
]
HOST_INSTALL = re.compile(r"^\s*(sudo\s+)?(apt(-get)?\s+install|dnf\s+install|yum\s+install|"
                          r"brew\s+install|pacman\s+-S|zypper\s+in(stall)?)\b", re.MULTILINE)


@pytest.mark.static
def test_nothing_unpublishable():
    found = []
    for path in _published():
        if "legacy" in path.parts or "migrations" in path.parts:
            continue
        text = path.read_text(encoding="utf-8")
        for pattern, what in FORBIDDEN:
            match = pattern.search(text)
            if match:
                found.append(f"{path.relative_to(ROOT)}: {what}: {match.group(0)!r}")
        for block in FENCE.findall(text):
            match = HOST_INSTALL.search(block)
            if match:
                found.append(f"{path.relative_to(ROOT)}: a host package manager: {match.group(0).strip()!r}")
    assert not found, "\n  ".join(found)
