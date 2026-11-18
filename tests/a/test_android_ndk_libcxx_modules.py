"""Tests for the android-ndk-libcxx-modules package and the script that makes it."""
import hashlib
import os
import re
import subprocess
import sys
import zipfile

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
)
from tests.lib.platform_utils import project_root

PKG = "android-ndk-libcxx-modules"
PKG_FILE = "pkgs/a/android-ndk-libcxx-modules.lua"
SCRIPT = os.path.join("tools", "res", "android-ndk", "libcxx_modules.py")


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


def read(rel):
    with open(os.path.join(project_root(), rel), encoding="utf-8") as handle:
        return handle.read()


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


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestPinnedFacts:
    @pytest.mark.static
    def test_one_payload_for_every_host(self):
        """The sources describe the target's libc++, so every host gets the
        same bytes: one sha256, on linux, macosx and windows."""
        code = re.sub(r'--.*', '', read(PKG_FILE))
        for host in ("linux", "macosx", "windows"):
            assert re.search(host + r'\s*=\s*\{', code), f"no {host} table"
        digests = set(re.findall(r'sha256\s*=\s*"([0-9a-f]{64})"', code))
        assert len(digests) == 1, f"expected one sha256 for every host, found {sorted(digests)}"

    @pytest.mark.static
    def test_versions_are_the_ndk_releases_that_need_it(self):
        """Every version here is an xim:android-ndk version, and every
        android-ndk version entry depends on its own; tools/res/build.sh knows
        each one's release name."""
        mine = set(re.findall(r'\["(\d+\.\d+\.\d+)"\]', re.sub(r'--.*', '', read(PKG_FILE))))
        ndk = re.sub(r'--.*', '', read("pkgs/a/android-ndk.lua"))
        assert mine == set(re.findall(r'\["(\d+\.\d+\.\d+)"\]', ndk))
        build = read("tools/res/build.sh")
        inputs = read("tools/res/inputs.txt")
        for version in mine:
            assert f"xim:android-ndk-libcxx-modules@{version}" in ndk
            assert re.search(re.escape(version) + r'\) release=r\d+', build), version
            for host in ("linux", "windows"):
                assert re.search(rf'^android-ndk-{host} {re.escape(version)} [0-9a-f]{{64}}$', inputs, re.M), (
                    f"no digest for the {host} archive of {version} in tools/res/inputs.txt")

    @pytest.mark.static
    def test_no_ci_automation_declared(self):
        # A new release is assessed and built together with xim:android-ndk.
        assert not re.search(r'\bci\s*=\s*\{', re.sub(r'--.*', '', read(PKG_FILE)))


def ndk(path, host, revision="30.0.1", clang="21.0.0\nbased on r1\n", headers=None, surface=True):
    """A miniature NDK archive with the members the script reads."""
    headers = {"__config": "#  define _LIBCPP_VERSION 210000\n", "vector": "v\n"} if headers is None else headers
    tc = f"android-ndk-r30/toolchains/llvm/prebuilt/{host}/"
    with zipfile.ZipFile(path, "w") as z:
        z.writestr("android-ndk-r30/source.properties", f"Pkg.Desc = Android NDK\nPkg.Revision = {revision}\n")
        z.writestr("android-ndk-r30/NOTICE.toolchain", "Apache-2.0 WITH LLVM-exception\n")
        z.writestr(tc + "AndroidVersion.txt", clang)
        for name, text in headers.items():
            z.writestr(tc + "sysroot/usr/include/c++/v1/" + name, text)
        if surface:
            for name in ("std.cppm", "std.compat.cppm", "std/vector.inc", "std.compat/cstdio.inc"):
                z.writestr(tc + "share/libc++/v1/" + name, f"// {name}\n")
    return str(path)


def run_script(*args):
    return subprocess.run([sys.executable, "-I", os.path.join(project_root(), SCRIPT), *args],
                          capture_output=True, text=True)


class TestScript:
    @pytest.mark.static
    def test_extract_takes_the_sources_and_lists_them(self, tmp_path):
        a = ndk(tmp_path / "linux.zip", "linux-x86_64")
        b = ndk(tmp_path / "windows.zip", "windows-x86_64", surface=False)
        out = tmp_path / "out"
        r = run_script("extract", "30.0.1", a, b, str(out))
        assert r.returncode == 0, r.stderr
        lines = (out / "MANIFEST").read_text().splitlines()
        assert [l.split("  ", 1)[1] for l in lines] == sorted(
            "share/libc++/v1/" + n for n in ("std.cppm", "std.compat.cppm", "std/vector.inc", "std.compat/cstdio.inc"))
        for line in lines:
            digest, rel = line.split("  ", 1)
            assert hashlib.sha256((out / rel).read_bytes()).hexdigest() == digest
        assert (out / "share/licenses/android-ndk-libcxx-modules/NOTICE.toolchain").is_file()

    @pytest.mark.static
    @pytest.mark.parametrize("change, message", [
        ({"revision": "30.0.2"}, "not 30.0.1"),
        ({"clang": "21.0.0\nbased on r2\n"}, "different clang revisions"),
        ({"headers": {"__config": "#  define _LIBCPP_VERSION 210000\n", "vector": "w\n"}}, "headers differ"),
        ({"headers": {"__config": "#  define _LIBCPP_VERSION 210000\n"}}, "headers differ"),
        ({"surface": True}, "not needed"),
    ])
    def test_extract_refuses_archives_that_do_not_agree(self, tmp_path, change, message):
        a = ndk(tmp_path / "linux.zip", "linux-x86_64")
        b = ndk(tmp_path / "windows.zip", "windows-x86_64", **{"surface": False, **change})
        r = run_script("extract", "30.0.1", a, b, str(tmp_path / "out"))
        assert r.returncode != 0 and message in r.stderr, r.stderr

    @pytest.mark.static
    def test_probe_reports_each_archive(self, tmp_path):
        a = ndk(tmp_path / "linux.zip", "linux-x86_64")
        b = ndk(tmp_path / "windows.zip", "windows-x86_64", surface=False)
        r = run_script("probe", a, b)
        assert r.returncode == 0, r.stderr
        assert "module sources present (4 files)" in r.stdout
        assert "module sources ABSENT" in r.stdout
        assert "clang same, libc++ headers identical" in r.stdout


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        assert_install_succeeds(PKG)
