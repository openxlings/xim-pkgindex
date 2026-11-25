"""The agent-facing files, statically.

- AGENTS.md exists, stays short (progressive disclosure: detail belongs in a skill), and
  everything it points to exists;
- every skill is `.agents/skills/<name>/SKILL.md` with frontmatter whose name is
  the directory and whose description is non-empty, and every `references/...`
  file a skill names exists;
- AGENTS.md and the skills are English only (the docs are bilingual; these are not).
  `.agents/docs/` may be in either language;
- none of them, nor the templates and READMEs, names a person's home directory.
"""
import re
from pathlib import Path

import pytest

pytestmark = pytest.mark.static

ROOT = Path(__file__).resolve().parents[1]
AGENTS = ROOT / "AGENTS.md"
SKILLS = ROOT / ".agents" / "skills"
CJK = re.compile(r"[　-〿㐀-䶿一-鿿＀-￯]")
PATH = re.compile(r"`((?:\.agents/|docs/|tests/|libs/|pkgs/)[A-Za-z0-9_./<>*-]+?)`")


def _skills():
    return sorted(p for p in SKILLS.glob("*/SKILL.md"))


def test_agents_md_exists_and_is_short():
    assert AGENTS.is_file()
    assert len(AGENTS.read_text(encoding="utf-8").splitlines()) <= 100, "AGENTS.md is the minimal core: move detail to a skill"


def test_agents_md_points_only_at_things_that_exist():
    text = AGENTS.read_text(encoding="utf-8")
    missing = []
    for target in PATH.findall(text):
        if any(ch in target for ch in "<>*"):
            continue
        if not (ROOT / target).exists():
            missing.append(target)
    for target in re.findall(r"\]\(([^)\s]+)\)", text):
        if not re.match(r"^[a-z]+:", target) and not (ROOT / target.split("#")[0]).exists():
            missing.append(target)
    assert not missing, f"AGENTS.md names files that do not exist: {missing}"


@pytest.mark.parametrize("skill", _skills(), ids=lambda p: p.parent.name)
def test_a_skill_is_well_formed(skill):
    text = skill.read_text(encoding="utf-8")
    front = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    assert front, f"{skill.parent.name}: no frontmatter"
    fields = dict(re.findall(r"^(\w+):\s*(.+)$", front.group(1), re.M))
    assert fields.get("name") == skill.parent.name, "frontmatter name must be the directory name"
    assert fields.get("description", "").strip(), "frontmatter description is empty"
    for ref in re.findall(r"`(references/[A-Za-z0-9_./-]+)`", text):
        assert (skill.parent / ref).is_file(), f"{skill.parent.name} names {ref}, which does not exist"


def test_every_skill_is_listed_in_agents_md():
    text = AGENTS.read_text(encoding="utf-8")
    for skill in _skills():
        assert f".agents/skills/{skill.parent.name}/SKILL.md" in text, f"AGENTS.md does not point at {skill.parent.name}"


def _english_only_files():
    return [AGENTS] + sorted(p for p in SKILLS.rglob("*") if p.is_file())


@pytest.mark.parametrize("path", _english_only_files(), ids=lambda p: str(p.relative_to(ROOT)))
def test_agent_files_are_english(path):
    match = CJK.search(path.read_text(encoding="utf-8"))
    assert not match, f"{path.relative_to(ROOT)} must be English only (found {match.group(0)!r})"


# A person's home directory is private. CI's own (`runner`) and placeholders are not.
PERSONAL_PATH = re.compile(
    r"(?:/home/|/Users/|[A-Za-z]:\\Users\\)(?!(?:runner|user|u|me|you|name|xlings|<)[/\\\s`\"')]?)[A-Za-z][\w.-]*[/\\]")


def _published_files():
    files = [AGENTS, ROOT / "README.md", ROOT / "README.zh.md"]
    files += sorted(p for p in SKILLS.rglob("*") if p.is_file())
    files += sorted((ROOT / ".github" / "ISSUE_TEMPLATE").glob("*"))
    files += [ROOT / ".github" / "PULL_REQUEST_TEMPLATE.md"]
    return files


@pytest.mark.parametrize("path", _published_files(), ids=lambda p: str(p.relative_to(ROOT)))
def test_no_personal_home_directory(path):
    match = PERSONAL_PATH.search(path.read_text(encoding="utf-8"))
    assert not match, f"{path.relative_to(ROOT)} names a personal path: {match.group(0)!r}"
