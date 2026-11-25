"""Which llvm archives the payload check takes (.github/scripts/llvm-payload-plan.py).

The versions whose entries a change touches, else the newest; each on every
host the recipe serves it on, by the url and sha256 the recipe states for that
host; an archive whose release is a tools/res resource is built by the run.
"""
import importlib.util
import shutil
from pathlib import Path

import pytest

pytestmark = [pytest.mark.static,
              pytest.mark.skipif(not (shutil.which("lua5.4") or shutil.which("lua")), reason="no Lua interpreter")]
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("llvm_payload_plan", ROOT / ".github/scripts/llvm-payload-plan.py")
planner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(planner)

D = "0" * 64
GH = "https://github.com/xlings-res/llvm/releases/download"


def recipe(windows_23, linux_23=None):
    linux_23 = linux_23 or f'''{{
                revision = 3,
                x86_64 = {{ url = {{ GLOBAL = "{GH}/23.1.3-r3/l-x.tar.gz", CN = "c" }}, sha256 = "{D}" }},
                aarch64 = {{ url = {{ GLOBAL = "{GH}/23.1.3-r3/l-a.tar.gz", CN = "c" }}, sha256 = "{D}" }},
            }}'''
    return f'''package = {{
    name = "llvm",
    xpm = {{
        linux = {{
            deps = {{ "xim:glibc@>=2.39" }},
            ["latest"] = {{ ref = "22.1.8" }},
            ["22.1.8"] = {{ revision = 1, x86_64 = {{ url = "{GH}/22.1.8/l.tar.gz", sha256 = "{D}" }} }},
            ["23.1.3"] = {linux_23},
        }},
        macosx = {{
            ["23.1.3"] = {{ url = {{ GLOBAL = "{GH}/23.1.3-r3/m.tar.xz" }}, sha256 = "{D}" }},
        }},
        windows = {{
            ["22.1.8"] = "XLINGS_RES",
            ["23.1.3"] = {windows_23},
        }},
    }},
}}
function install() return true end
'''


R3 = f'{{ revision = 3, url = {{ GLOBAL = "{GH}/23.1.3-r3/w.zip" }}, sha256 = "{D}" }}'
R4 = f'{{ revision = 4, floor = 4, url = {{ GLOBAL = "{GH}/23.1.3-r4/w.zip" }}, sha256 = "{"1" * 64}" }}'


@pytest.fixture
def trees(monkeypatch):
    texts = {}
    monkeypatch.setattr(planner, "show", lambda ref, path: texts.get(ref))
    monkeypatch.setattr(planner, "resources", lambda: {("llvm", "23.1.3-r4"): "res-llvm-23.1.3-r4-x86_64"})
    return texts


def test_a_changed_version_is_taken_on_every_host_it_is_served_on(trees):
    trees.update(base=recipe(R3), head=recipe(R4))
    result = planner.plan("base", "head")
    assert result["versions"] == ["23.1.3"]
    hosts = {(i["platform"], i["arch"]): i for i in result["include"]}
    assert set(hosts) == {("linux", "x86_64"), ("linux", "aarch64"), ("macosx", "arm64"), ("windows", "x86_64")}
    assert hosts[("linux", "aarch64")]["url"].endswith("/l-a.tar.gz")
    assert hosts[("linux", "aarch64")]["runner"] == "ubuntu-24.04-arm"
    assert hosts[("macosx", "arm64")]["artifact"] == ""
    windows = hosts[("windows", "x86_64")]
    assert windows["artifact"] == "res-llvm-23.1.3-r4-x86_64" and windows["file"] == "w.zip"
    assert windows["sha256"] == "1" * 64
    assert result["resources"] == [{"what": "llvm", "version": "23.1.3-r4"}]


def test_without_a_changed_entry_the_newest_version_is_taken(trees):
    trees.update(base=recipe(R3), head=recipe(R3))
    result = planner.plan("base", "head")
    assert result["versions"] == ["23.1.3"] and result["resources"] == []
    assert all(i["artifact"] == "" for i in result["include"])


def test_a_version_not_served_on_a_host_is_not_taken_there(trees):
    only_x86 = f'{{ revision = 4, x86_64 = {{ url = "{GH}/23.1.3-r4/l-x.tar.gz", sha256 = "{D}" }} }}'
    trees.update(base=recipe(R3), head=recipe(R3, linux_23=only_x86))
    hosts = {(i["platform"], i["arch"]) for i in planner.plan("base", "head")["include"]}
    assert ("linux", "aarch64") not in hosts and ("linux", "x86_64") in hosts


def test_an_entry_without_a_digest_is_refused(trees):
    trees.update(base=recipe(R3), head=recipe(f'{{ revision = 4, url = "{GH}/23.1.3-r4/w.zip" }}'))
    with pytest.raises(SystemExit, match="names no archive by url and sha256"):
        planner.plan("base", "head")
