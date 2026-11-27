#!/usr/bin/env python3
"""The architecture tools: the model (tools/xpkg_arch.py), the checks K1 and
K3 (tools/xpkg_ci.py arch-check), the census and the migration tool's byte
reader and recipe rewriter (tools/arch-migrate).

The recipes are written to a scratch directory and loaded as Lua, as the
tools load the index's; ELF files are built byte by byte. No network.
"""
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
from pathlib import Path
import io
import shutil
import struct
import subprocess
import sys
import tarfile

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import xpkg_arch as xa  # noqa: E402

_loader = SourceFileLoader("arch_migrate", str(ROOT / "tools" / "arch-migrate"))
_spec = spec_from_loader("arch_migrate", _loader)
am = module_from_spec(_spec)
_loader.exec_module(am)

LUA = next((p for p in (shutil.which(n) for n in ("lua5.4", "lua5.3", "lua")) if p), None)
needs_lua = pytest.mark.skipif(LUA is None, reason="no Lua interpreter")

H1 = "1" * 64
H2 = "2" * 64

RECIPE = '''package = {
    spec = "2",
    name = "foo",
    archs = {"x86_64", "aarch64"},
    xpm = {
        linux = {
            ["latest"] = { ref = "1.1.0" },
            ["1.0.0"] = {
                url = "https://example.org/foo-1.0.0-x86_64.tar.gz",
                sha256 = "%(h1)s",
            },
            ["1.1.0"] = {
                url = "https://example.org/foo-1.1.0-x86_64.tar.gz",
                sha256 = "%(h1)s",
                revision = 1,
            },
            ["0.9.0"] = "XLINGS_RES",
            ["2.0.0"] = {
                x86_64 = { url = "https://example.org/foo-2.0.0-x86_64.tar.gz", sha256 = "%(h1)s" },
                aarch64 = { url = "https://example.org/foo-2.0.0-aarch64.tar.gz", sha256 = "%(h2)s" },
            },
            ["3.0.0"] = {
                url = "https://example.org/foo-3.0.0.tar.gz",
                sha256 = { x86_64 = "%(h1)s", aarch64 = "%(h1)s" },
            },
        },
        macosx = {
            ["1.0.0"] = { url = "https://example.org/foo-1.0.0-darwin.tar.gz", sha256 = "%(h2)s" },
        },
    },
}

function install() return true end
''' % {"h1": H1, "h2": H2}


def _load(tmp_path, text, name="foo.lua"):
    d = tmp_path / "pkgs" / "f"
    d.mkdir(parents=True, exist_ok=True)
    (d / name).write_text(text)
    rel = f"pkgs/f/{name}"
    item = xa.load_recipes([rel], root=tmp_path)[rel]
    assert "package" in item, item
    return item["package"]


@pytest.fixture
def scratch(tmp_path):
    # The dumper finds the recipe sandbox beside it, as in the checkout.
    (tmp_path / "tools").mkdir()
    (tmp_path / ".github" / "scripts").mkdir(parents=True)
    shutil.copy(ROOT / "tools" / "xpkg_arch_dump.lua", tmp_path / "tools")
    shutil.copy(ROOT / ".github/scripts/recipe-sandbox.lua", tmp_path / ".github/scripts")
    return tmp_path


@pytest.mark.static
@needs_lua
def test_entries_are_read_and_classified_as_the_client_reads_them(scratch):
    pkg = _load(scratch, RECIPE)
    linux = xa.platforms(pkg)["linux"]
    assert xa.latest_entry(linux).version == "1.1.0"
    assert xa.classify(pkg, linux.entries["1.0.0"]) == "Weak"
    assert xa.classify(pkg, linux.entries["2.0.0"]) == "Strong"
    assert linux.entries["2.0.0"].architectures() == {"x86_64", "aarch64"}
    assert xa.classify(pkg, linux.entries["3.0.0"]) == "Strong"
    # XLINGS_RES as a string is one artifact without a name, as libxpkg reads it.
    assert xa.classify(pkg, linux.entries["0.9.0"]) == "Weak"


@pytest.mark.static
@needs_lua
def test_k1_names_every_linux_entry_with_one_unnamed_artifact(scratch):
    pkg = _load(scratch, RECIPE)
    found = sorted(f.message.split("]")[0] for f in xa.check_k1("foo.lua", pkg))
    assert found == ['xpm.linux["0.9.0"', 'xpm.linux["1.0.0"', 'xpm.linux["1.1.0"']
    # macOS has one host architecture: its unnamed entry is that one, not a finding.
    assert not [f for f in xa.check_k1("foo.lua", pkg) if "macosx" in f.message]


@pytest.mark.static
@needs_lua
def test_k3_judges_only_when_every_entry_says_what_it_is(scratch):
    pkg = _load(scratch, RECIPE)
    assert xa.check_k3("foo.lua", pkg) == []          # Linux 1.0.0 names nothing yet
    named = RECIPE.replace('sha256 = "' + H1 + '",\n            },\n            ["1.1.0"]',
                           'sha256 = { x86_64 = "' + H1 + '" },\n            },\n            ["1.1.0"]')
    named = named.replace(f'sha256 = "{H1}",\n                revision = 1',
                          f'sha256 = {{ x86_64 = "{H1}" }},\n                revision = 1')
    named = named.replace('["0.9.0"] = "XLINGS_RES",', "")
    named = named.replace('archs = {"x86_64", "aarch64"}', 'archs = {"x86_64"}')
    pkg = _load(scratch, named)
    assert xa.check_k1("foo.lua", pkg) == []
    (f,) = xa.check_k3("foo.lua", pkg)
    assert f.fix == ["x86_64", "aarch64"]
    assert "entries list aarch64" in f.message
    fixed = xa.fix_archs_text(named, f.fix)
    assert 'archs = {"x86_64", "aarch64"}' in fixed
    assert xa.check_k3("foo.lua", _load(scratch, fixed)) == []


@pytest.mark.static
@needs_lua
def test_k3_does_not_judge_a_hook_only_linux_entry(scratch):
    text = RECIPE.replace('archs = {"x86_64", "aarch64"}', 'archs = {"x86_64"}')
    start = text.index("        linux = {")
    end = text.index("        macosx = {")
    text = text[:start] + '        linux = { ["1.0.0"] = {} },\n' + text[end:]
    pkg = _load(scratch, text)
    assert xa.check_k1("foo.lua", pkg) == []
    assert xa.check_k3("foo.lua", pkg) == []


# ── the byte reader ────────────────────────────────────────────────────────

def _elf(machine=62, etype=2, interp=None, pie=False, osabi=0):
    """A 64-bit little-endian ELF file with the program headers asked for."""
    phs = []
    blobs = b""
    base = 64 + 56 * 2
    if interp:
        s = interp.encode() + b"\0"
        phs.append((3, base + len(blobs), len(s)))
        blobs += s
    if pie:
        dyn = struct.pack("<qQ", 0x6FFFFFFB, 0x08000000) + struct.pack("<qQ", 0, 0)
        phs.append((2, base + len(blobs), len(dyn)))
        blobs += dyn
    ident = b"\x7fELF" + bytes([2, 1, 1, osabi]) + b"\0" * 8
    hdr = ident + struct.pack("<HHIQQQIHHHHHH", etype, machine, 1, 0, 64, 0, 0, 64, 56, len(phs), 0, 0, 0)
    table = b"".join(struct.pack("<IIQQQQQQ", t, 0, off, 0, 0, size, size, 0) for t, off, size in phs)
    table += b"\0" * (56 * 2 - len(table))
    return hdr + table + blobs


@pytest.mark.static
def test_read_elf_tells_programs_libraries_and_systems_apart():
    prog = am.read_elf(_elf(interp="/lib64/ld-linux-x86-64.so.2", etype=3))
    assert prog["machine"] == "x86_64" and prog["program"] and prog["os"] == "linux"
    lib = am.read_elf(_elf(machine=183, etype=3))
    assert lib["machine"] == "aarch64" and not lib["program"]
    spie = am.read_elf(_elf(etype=3, pie=True))
    assert spie["program"] and spie["pie"] and not spie["interp"]
    bsd = am.read_elf(_elf(etype=3, osabi=9))
    assert bsd["os"] == "freebsd"
    assert am.read_elf(b"#!/bin/sh\n" + b"\0" * 60) is None


def _tar(members):
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tf:
        for name, data in members:
            ti = tarfile.TarInfo(name)
            ti.size = len(data)
            ti.mode = 0o755
            tf.addfile(ti, io.BytesIO(data))
    buf.seek(0)
    return buf


@pytest.mark.static
def test_verdicts():
    def v(members):
        return am.verdict(am.summarize(am.scan_tar(_tar(members))))
    assert v([("share/font.ttf", b"\0" * 100)]) == "none"
    assert v([("bin/x", _elf(etype=2)), ("lib/l.so", _elf(etype=3))]) == "programs:x86_64"
    assert v([("bin/x", _elf(etype=3, pie=True))]) == "programs:x86_64"
    assert v([("lib/l.so", _elf(machine=183, etype=3))]).startswith("undecided:no Linux program")
    assert v([("bin/a", _elf(etype=2)), ("bin/b", _elf(machine=183, etype=2))]) == \
        "undecided:programs of aarch64+x86_64"
    assert v([("bin/a", _elf(etype=2, osabi=9))]).startswith("undecided")


@pytest.mark.static
def test_probe_swaps_the_architecture_word():
    assert "https://e.org/bat-x-aarch64-unknown-linux-musl.tar.gz" in \
        am.candidate_urls("https://e.org/bat-x-x86_64-unknown-linux-musl.tar.gz")
    assert "https://e.org/t_linux_arm64.tar.gz" in am.candidate_urls("https://e.org/t_linux_amd64.tar.gz")


# ── the recipe rewriter ────────────────────────────────────────────────────

@pytest.mark.static
@needs_lua
def test_rewrites_keep_bytes_and_name_architectures(scratch):
    text = am.rewrite_entry(RECIPE, "1.0.0", hashes={"x86_64": H1})
    text = am.rewrite_entry(text, "0.9.0", hashes={"x86_64": H1, "aarch64": H2})
    text = am.rewrite_entry(text, "1.1.0", per_arch={
        "x86_64": {"url": "https://example.org/foo-1.1.0-x86_64.tar.gz", "sha256": H1},
        "aarch64": {"url": "https://example.org/foo-1.1.0-aarch64.tar.gz", "sha256": H2}}, bump=True)
    pkg = _load(scratch, text)
    linux = xa.platforms(pkg)["linux"]
    assert linux.entries["1.0.0"].sha256_by_arch == {"x86_64": H1}
    assert linux.entries["1.0.0"].url.endswith("foo-1.0.0-x86_64.tar.gz")
    res = linux.entries["0.9.0"]
    assert res.url == "XLINGS_RES" and res.sha256_by_arch == {"x86_64": H1, "aarch64": H2}
    e = linux.entries["1.1.0"]
    assert set(e.archs) == {"x86_64", "aarch64"} and e.archs["aarch64"]["sha256"] == H2
    assert e.raw["revision"] == 2
    assert xa.check_k1("foo.lua", pkg) == []
    # The rest of the recipe is untouched.
    assert text.endswith("function install() return true end\n")
    assert 'macosx = {\n            ["1.0.0"] = { url = "https://example.org/foo-1.0.0-darwin.tar.gz"' in text


@pytest.mark.static
@needs_lua
def test_an_entry_without_a_digest_gets_the_downloads(scratch):
    text = RECIPE.replace(f'                url = "https://example.org/foo-1.0.0-x86_64.tar.gz",\n'
                          f'                sha256 = "{H1}",\n',
                          '                url = "https://example.org/foo-1.0.0-x86_64.tar.gz",\n')
    text = am.rewrite_entry(text, "1.0.0", hashes={"x86_64": H2})
    pkg = _load(scratch, text)
    assert xa.platforms(pkg)["linux"].entries["1.0.0"].sha256_by_arch == {"x86_64": H2}


@pytest.mark.static
@needs_lua
def test_k1_leaves_a_git_repository_alone(scratch):
    text = RECIPE.replace('url = "https://example.org/foo-1.0.0-x86_64.tar.gz",\n'
                          f'                sha256 = "{H1}",',
                          'url = "https://example.org/foo.git",')
    pkg = _load(scratch, text)
    assert not [f for f in xa.check_k1("foo.lua", pkg) if '"1.0.0"' in f.message]
