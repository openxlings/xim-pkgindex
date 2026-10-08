"""测试 glibc 包"""
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not

PKG = "glibc"
PKG_FILE = "pkgs/g/glibc.lua"


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


class TestStatic:
    @pytest.mark.static
    def test_required_fields(self, meta):
        assert_required_fields(meta)

    @pytest.mark.static
    def test_valid_spec(self, meta):
        assert_valid_spec(meta)

    @pytest.mark.static
    def test_valid_type(self, meta):
        assert_valid_type(meta)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestIsolation:
    @pytest.mark.isolation
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)

    @pytest.mark.isolation
    def test_no_bashrc(self):
        assert_no_bashrc_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_no_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_new_api(self):
        assert_uses_new_api(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(PKG)


class TestRevisionOrdering:
    """`latest` is not the only way a recipe reaches this package.

    33 recipes depend on it as a bare `xim:glibc` and follow the `latest`
    ref; 35 more ask for a RANGE (`xim:glibc@>=2.38`, `>=2.39`). A range is
    answered by `select_version_` -> `semver::select_best`, which returns the
    maximum satisfying version and never looks at `latest`. So a revision
    that sorts below the artifact it supersedes is not untidy -- it leaves
    every one of those 35 resolving straight back to the copy being replaced,
    silently and with no error anywhere.

    That is not hypothetical: `2.44r1` was the first choice here and has
    exactly this defect, because xlings' semver reads a missing segment as
    numeric 0 and lets it beat an alpha segment (`compare("6.5","6.5rc1")>0`
    in its own pinned corpus), making `2.44r1` a PRE-release of 2.44.

    The property below is what makes the ranges safe to leave alone.
    """

    @staticmethod
    def _versions(meta):
        """The version keys and the `latest` ref, read out of the recipe text.

        XpkgMeta does not carry the version table, and a Lua evaluator is not
        worth pulling in for two regexes over a table this file owns.
        """
        import re
        # Scoped to the `package = {...}` literal, which ends at the first
        # `import(`. Searching the whole file for `["x"] =` also finds the
        # env-var tables in config(), and a criterion that matches
        # LD_LIBRARY_PATH is not reading the version table.
        head = meta.raw_content.split('\nimport(', 1)[0]
        # Lua comments stripped first. A version that is only MENTIONED -- in
        # a "restore this when X ships" note, say -- is not in the table, and
        # a criterion that cannot tell those apart is reading prose. This bit
        # already: a commented-out restore snippet made the check report a
        # `latest` that pointed below an entry that was not there.
        head = '\n'.join(l for l in head.splitlines()
                          if not l.lstrip().startswith('--'))
        keys = re.findall(r'\["([^"]+)"\]\s*=', head)
        ref = re.search(r'\["latest"\]\s*=\s*\{\s*ref\s*=\s*"([^"]+)"', head)
        return [k for k in keys if k != 'latest'], (ref.group(1) if ref else None)

    @pytest.mark.meta
    def test_latest_ref_sorts_at_or_above_every_other_version(self, meta):
        versions, latest = self._versions(meta)
        assert latest, "no `latest` ref found"
        assert latest in versions, f"latest -> {latest} is not a published key"

        def key(v):
            # xlings semver, restricted to what this file uses: digits and
            # dots, missing segment = 0.
            return [int(p) for p in v.split('.')]

        others = [v for v in versions if v != latest]
        assert others, "nothing to compare against"
        for v in others:
            assert key(latest) > key(v), (
                f"latest -> {latest} does not sort above {v}; a ranged "
                f"dependency (>=2.38, >=2.39) would resolve to {v} instead"
            )

    @pytest.mark.meta
    def test_every_published_version_is_pure_dotted_digits(self, meta):
        # The moment a version carries a letter, the sort rule above stops
        # being the simple one and `select_best` can disagree with `latest`.
        import re
        versions, _ = self._versions(meta)
        for v in versions:
            assert re.fullmatch(r'\d+(\.\d+)*', v), \
                f"{v} is not dotted digits; see TestRevisionOrdering"


# ── binary relocation (openxlings/xlings#621) ─────────────────────────────

import os
import re
import shutil
import stat
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
RELOCATE_HARNESS = REPO / "tests" / "lua" / "glibc_relocate_harness.lua"
BUILD_SCRIPT = REPO / ".agents" / "tools" / "graphics" / "build-glibc.sh"

RESERVED = b"/nonexistent/xlings-use-rpath-not-default-search"
PADDING_TAG = b"padding-to-255-bytes-for-install-time-relocation"
PADDED = RESERVED + b"/" + PADDING_TAG
PADDED = PADDED + b"_" * (255 - len(PADDED))
ELF_HEAD = b"\x7fELF\x02\x01\x01\x00" + b"\x00" * 56


def _lua():
    return shutil.which("lua5.4") or shutil.which("lua")


needs_lua_relocate = pytest.mark.skipif(_lua() is None, reason="no lua interpreter")


def _run(mode, install_dir, placeholder=PADDED):
    args = [_lua(), str(RELOCATE_HARNESS), str(REPO / PKG_FILE), mode, str(install_dir)]
    if mode == "relocate":
        args.append(placeholder.decode())
    return subprocess.run(args, capture_output=True, text=True)


def _expected(content, to):
    """The rewrite, restated independently of the recipe: every occurrence
    of the placeholder becomes the install directory `/`-padded to 255
    bytes."""
    return content.replace(PADDED, to + b"/" * (len(PADDED) - len(to)))


def _nul_offsets(content):
    return [i for i, b in enumerate(content) if b == 0]


class TestBinaryRelocation:
    """install() overwrites the padded prefix inside the payload's binaries
    with the install directory followed by `/` up to 255 bytes, so that no
    string and no compiled-in length changes; refuses an install directory
    longer than the placeholder; and then asserts that the reserved prefix
    is gone. Run against synthetic files through tests/lua/
    glibc_relocate_harness.lua; the end-to-end run on the real payload is in
    the pull request."""

    @pytest.mark.static
    def test_recipe_and_build_script_spell_the_same_prefix(self):
        script = BUILD_SCRIPT.read_text(encoding="utf-8")
        recipe = (REPO / PKG_FILE).read_text(encoding="utf-8")
        assert f'RESERVED_PREFIX="{RESERVED.decode()}"' in script
        assert f'PREFIX="$RESERVED_PREFIX/{PADDING_TAG.decode()}"' in script
        assert 'while (( ${#PREFIX} < 255 )); do PREFIX+="_"; done' in script
        assert f'local RESERVED_PREFIX = "{RESERVED.decode()}"' in recipe
        assert f'RESERVED_PREFIX .. "/{PADDING_TAG.decode()}"' in recipe
        assert 'string.rep("_", 255 - #PADDING_HEAD)' in recipe

    @needs_lua_relocate
    @pytest.mark.static
    @pytest.mark.parametrize("arch,loader", [
        ("x86_64", "ld-linux-x86-64.so.2"),
        ("aarch64", "ld-linux-aarch64.so.1"),
    ])
    def test_revision_selects_matching_runtime_and_immutable_resource(self, arch, loader):
        result = subprocess.run([
            _lua(), str(REPO / "tests/lua/glibc_metadata_harness.lua"),
            str(REPO / PKG_FILE), arch,
        ], capture_output=True, text=True)
        assert result.returncode == 0, result.stdout + result.stderr
        interp, abi, revision, version, digest, global_url, cn_url, keys = result.stdout.strip().split("\t")
        assert interp == f"lib64/{loader}"
        assert abi == f"linux-{arch}-glibc"
        assert int(revision) >= 2
        assert re.fullmatch(r"[0-9a-f]{64}", digest)
        suffix = f"/releases/download/{version}-r{revision}/glibc-{version}-r{revision}-linux-{arch}.tar.gz"
        assert global_url == "https://github.com/xlings-res/glibc" + suffix
        assert cn_url == "https://gitcode.com/xlings-res/glibc" + suffix
        if arch == "aarch64":
            assert keys.split(",") == [version], "ARM must not select older x86-only archives"
        else:
            assert {"2.39", "2.44", "2.44.2", version} <= set(keys.split(","))

    @needs_lua_relocate
    @pytest.mark.static
    def test_every_occurrence_is_rewritten_and_no_length_changes(self, tmp_path):
        payload = tmp_path / "home" / "alice" / ".xlings" / "data" / "xpkgs" / "xim-x-glibc" / "2.44.3"
        (payload / "lib").mkdir(parents=True)
        to = str(payload).encode()
        assert len(to) > len(RESERVED), "the case the padding exists for"
        content = (ELF_HEAD + b"prefix-of-string:" + PADDED + b"/share/locale/%L/%N:"
                   + PADDED + b"/share/locale/%l/%N\0" + b"other\0"
                   + PADDED + b"/lib/locale\0" + b"\x01\x02" + PADDED + b"/etc")
        lib = payload / "lib" / "libc.so.6"
        lib.write_bytes(content)
        lib.chmod(0o755)
        (payload / "lib" / "libc.so").write_bytes(b"GROUP ( " + PADDED + b"/lib/libc.so.6 )\n")
        os.symlink("lib", payload / "lib64")

        result = _run("relocate", payload)
        assert result.returncode == 0, result.stdout + result.stderr
        assert "RELOCATED 1" in result.stdout
        assert "relocated 4 occurrence(s) in 1 binary file(s)" in result.stdout

        new = lib.read_bytes()
        assert len(new) == len(content)
        assert new == _expected(content, to)
        assert PADDED not in new and RESERVED not in new
        assert new.count(to + b"/" * (255 - len(to))) == 4
        # Every C string keeps its length: the NULs are where they were.
        assert _nul_offsets(new) == _nul_offsets(content)
        assert to + b"/" * (255 - len(to)) + b"/lib/locale\0" in new
        assert stat.S_IMODE(lib.stat().st_mode) == 0o755
        # Text is relocate_build_paths' job, and the symlink is not followed.
        assert (payload / "lib" / "libc.so").read_bytes().count(PADDED) == 1
        assert (payload / "lib64").is_symlink()
        assert not list(payload.rglob("*.xlings-relocate"))

    @needs_lua_relocate
    @pytest.mark.static
    def test_hard_links_are_each_relocated(self, tmp_path):
        payload = tmp_path / "p"
        (payload / "bin").mkdir(parents=True)
        (payload / "libexec").mkdir()
        content = ELF_HEAD + PADDED + b"/libexec/getconf\0"
        (payload / "bin" / "getconf").write_bytes(content)
        os.link(payload / "bin" / "getconf", payload / "libexec" / "POSIX_V7_LP64_OFF64")
        result = _run("relocate", payload)
        assert result.returncode == 0, result.stdout + result.stderr
        for f in (payload / "bin" / "getconf", payload / "libexec" / "POSIX_V7_LP64_OFF64"):
            assert f.read_bytes() == _expected(content, str(payload).encode())

    @needs_lua_relocate
    @pytest.mark.static
    def test_install_dir_of_exactly_255_bytes_needs_no_padding(self, tmp_path):
        deep = tmp_path
        while len(str(deep)) + 1 + 60 < 255:
            deep = deep / ("d" * 60)
        deep = deep / ("e" * (255 - len(str(deep)) - 1))
        deep.mkdir(parents=True)
        assert len(str(deep)) == 255
        content = ELF_HEAD + PADDED + b"/lib/locale\0"
        (deep / "libc.so.6").write_bytes(content)
        result = _run("relocate", deep)
        assert result.returncode == 0, result.stdout + result.stderr
        assert (deep / "libc.so.6").read_bytes() == ELF_HEAD + str(deep).encode() + b"/lib/locale\0"

    @needs_lua_relocate
    @pytest.mark.static
    def test_install_dir_longer_than_the_placeholder_is_refused_untouched(self, tmp_path):
        deep = tmp_path
        while len(str(deep)) <= 260:
            deep = deep / ("d" * 60)
        deep.mkdir(parents=True)
        content = ELF_HEAD + PADDED + b"/lib/locale\0"
        (deep / "libc.so.6").write_bytes(content)
        result = _run("relocate", deep)
        assert result.returncode == 1
        assert "at most 255 bytes" in result.stdout
        assert str(deep) in result.stdout
        assert (deep / "libc.so.6").read_bytes() == content

    @needs_lua_relocate
    @pytest.mark.static
    def test_payload_without_the_padded_prefix_is_left_alone(self, tmp_path):
        content = ELF_HEAD + RESERVED + b"/lib/locale\0"
        (tmp_path / "libc.so.6").write_bytes(content)
        result = _run("relocate", tmp_path)
        assert result.returncode == 0 and "RELOCATED 0" in result.stdout, result.stdout
        assert (tmp_path / "libc.so.6").read_bytes() == content

    @needs_lua_relocate
    @pytest.mark.static
    def test_an_unpadded_reserved_prefix_left_behind_fails_the_install(self, tmp_path):
        (tmp_path / "libc.so.6").write_bytes(ELF_HEAD + PADDED + b"/lib/locale\0")
        (tmp_path / "ld.so").write_bytes(ELF_HEAD + RESERVED + b"/etc/ld.so.cache\0")
        result = _run("relocate", tmp_path)
        assert result.returncode == 1
        assert "still name " + RESERVED.decode() in result.stdout
        assert "ld.so" in result.stdout

    @needs_lua_relocate
    @pytest.mark.static
    def test_a_differently_padded_prefix_is_refused(self, tmp_path):
        other = RESERVED + b"/" + PADDING_TAG + b"_" * 10
        (tmp_path / "libc.so.6").write_bytes(ELF_HEAD + other + b"/lib/locale\0")
        result = _run("relocate", tmp_path)
        assert result.returncode == 1
        assert "must spell the same PREFIX" in result.stdout

    @needs_lua_relocate
    @pytest.mark.static
    def test_assert_covers_text_files(self, tmp_path):
        (tmp_path / "ldd").write_bytes(b'#!/bin/bash\nRTLDLIST="' + RESERVED + b'/lib/ld.so"\n')
        (tmp_path / "doc").write_bytes(b"see docs/nonexistent/xlings-use-rpath-not-default-search\n")
        result = _run("assert", tmp_path)
        assert result.returncode == 1
        # `doc` names the prefix inside a longer relative path, not as one.
        assert re.search(r"1 file\(s\) still name .* own data: ldd\s*$", result.stdout), \
            result.stdout
