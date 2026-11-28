"""A corrective revision derived from a published archive (tools/res/revision.py).

The derived archive holds every file of the one it comes from, unchanged,
under the new top directory, the aliases `--same` names with an existing
member's bytes, and what `--add` names; a zip is the same bytes on every run.
"""
import hashlib
import io
import lzma
import subprocess
import sys
import tarfile
import zipfile
from pathlib import Path

import pytest

pytestmark = pytest.mark.static
SCRIPT = Path(__file__).resolve().parents[2] / "tools/res/revision.py"


def revision(*args, stdin=None):
    return subprocess.run([sys.executable, "-I", str(SCRIPT), *map(str, args)], input=stdin,
                          capture_output=True)


@pytest.fixture
def from_zip(tmp_path):
    path = tmp_path / "pkg-1.0-r3-windows.zip"
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("pkg-1.0-r3-windows/", "")
        z.writestr("pkg-1.0-r3-windows/bin/lld-link.exe", b"MZ" + bytes(range(256)) * 400)
        z.writestr("pkg-1.0-r3-windows/lib/a.txt", "a\n")
    return path


def test_zip_renames_and_adds_byte_identical_aliases(tmp_path, from_zip):
    note = tmp_path / "note"
    note.write_text("why\n")
    out = tmp_path / "pkg-1.0-r4-windows.zip"
    r = revision("zip", from_zip, out, "pkg-1.0-r3-windows", "pkg-1.0-r4-windows",
                 "--same", "bin/lld-link.exe=bin/ld.lld.exe", "--add", f"README.provenance={note}")
    assert r.returncode == 0, r.stderr.decode()
    with zipfile.ZipFile(out) as z, zipfile.ZipFile(from_zip) as a:
        assert sorted(z.namelist()) == sorted(
            ["pkg-1.0-r4-windows/", "pkg-1.0-r4-windows/bin/lld-link.exe", "pkg-1.0-r4-windows/bin/ld.lld.exe",
             "pkg-1.0-r4-windows/lib/a.txt", "pkg-1.0-r4-windows/README.provenance"])
        lld = a.read("pkg-1.0-r3-windows/bin/lld-link.exe")
        assert z.read("pkg-1.0-r4-windows/bin/ld.lld.exe") == lld == z.read("pkg-1.0-r4-windows/bin/lld-link.exe")
        assert z.getinfo("pkg-1.0-r4-windows/README.provenance").compress_type == zipfile.ZIP_STORED
        assert z.read("pkg-1.0-r4-windows/README.provenance") == b"why\n"
        assert z.testzip() is None


def test_zip_is_the_same_bytes_every_time(tmp_path, from_zip):
    digests = set()
    for n in range(2):
        out = tmp_path / f"out{n}.zip"
        assert revision("zip", from_zip, out, "pkg-1.0-r3-windows", "pkg-1.0-r4-windows",
                        "--same", "bin/lld-link.exe=bin/ld.lld.exe").returncode == 0
        digests.add(hashlib.sha256(out.read_bytes()).hexdigest())
    assert len(digests) == 1


@pytest.mark.parametrize("args,said", [
    (("other-top", "pkg-1.0-r4-windows"), b"another top directory"),
    (("pkg-1.0-r3-windows", "pkg-1.0-r4-windows", "--same", "bin/none.exe=bin/x.exe"), b"is not in"),
    (("pkg-1.0-r3-windows", "pkg-1.0-r4-windows", "--same", "bin/lld-link.exe=lib/a.txt"), b"already in"),
])
def test_zip_refuses_what_it_cannot_derive(tmp_path, from_zip, args, said):
    r = revision("zip", from_zip, tmp_path / "out.zip", *args)
    assert r.returncode == 1 and said in r.stderr


def test_tar_renames_and_keeps_every_member(tmp_path):
    src = tmp_path / "base-14.5.tar.xz"
    with lzma.open(src, "wb") as raw, tarfile.open(fileobj=raw, mode="w", format=tarfile.GNU_FORMAT) as t:
        for name, mode, body in (("base-14.5", 0o775, None), ("base-14.5/usr", 0o755, None),
                                 ("base-14.5/usr/crt1.o", 0o444, b"\x7fELF crt"), ("base-14.5/mcpp.toml", 0o664, b"m")):
            info = tarfile.TarInfo(name)
            info.mode, info.mtime = mode, 1_700_000_000
            if body is None:
                info.type = tarfile.DIRTYPE
                t.addfile(info)
            else:
                info.size = len(body)
                t.addfile(info, io.BytesIO(body))
        link = tarfile.TarInfo("base-14.5/usr/Scrt1.o")
        link.type, link.linkname = tarfile.SYMTYPE, "crt1.o"
        t.addfile(link)
    note = tmp_path / "note"
    note.write_text("derived\n")
    out = tmp_path / "base-14.5-r3.tar.xz"
    r = revision("tar", src, out, "base-14.5", "base-14.5-r3", "--add", f"README.provenance={note}")
    assert r.returncode == 0, r.stderr.decode()
    with tarfile.open(out) as t:
        members = {m.name: m for m in t.getmembers()}
        assert set(members) == {"base-14.5-r3", "base-14.5-r3/usr", "base-14.5-r3/usr/crt1.o",
                                "base-14.5-r3/mcpp.toml", "base-14.5-r3/usr/Scrt1.o", "base-14.5-r3/README.provenance"}
        assert t.extractfile("base-14.5-r3/usr/crt1.o").read() == b"\x7fELF crt"
        assert members["base-14.5-r3/usr/crt1.o"].mode == 0o444
        assert members["base-14.5-r3/mcpp.toml"].mode == 0o664
        assert members["base-14.5-r3/usr/Scrt1.o"].linkname == "crt1.o"
        assert t.extractfile("base-14.5-r3/README.provenance").read() == b"derived\n"


def test_tar_digests_names_upstream_members(tmp_path):
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode="w") as t:
        for name, body in (("up-1.0/bin/ld.lld.exe", b"lld"), ("up-1.0/bin/x.exe", b"x")):
            info = tarfile.TarInfo(name)
            info.size = len(body)
            t.addfile(info, io.BytesIO(body))
    r = revision("tar-digests", "bin/ld.lld.exe", stdin=stream.getvalue())
    assert r.returncode == 0
    assert r.stdout.decode().split() == [hashlib.sha256(b"lld").hexdigest(), "bin/ld.lld.exe"]
    missing = revision("tar-digests", "bin/wasm-ld.exe", stdin=stream.getvalue())
    assert missing.returncode == 1 and b"not in the stream" in missing.stderr
