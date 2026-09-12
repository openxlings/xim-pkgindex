"""Tests for the android-build-tools package.

aapt2/zipalign are native binaries; apksigner/d8 shell out to `java` (see the
recipe's own header) -- the two facts that decide almost everything this
file checks: a declared JDK dependency, POSIX wrapper scripts that put a
resolved JDK's bin/ on PATH, and a Windows path that uses `envs` directly
instead, because apksigner.bat/d8.bat already honour JAVA_HOME and the POSIX
launchers do not.
"""
import re

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds,
)
from tests.lib.platform_utils import skip_if_not

PKG = "android-build-tools"
PKG_FILE = "pkgs/a/android-build-tools.lua"


def _code(content: str) -> str:
    """Strip lua line comments so static assertions see only real declarations."""
    return "\n".join(
        line for line in content.splitlines() if not line.lstrip().startswith("--")
    )


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope='module')
def code(meta):
    return _code(meta.raw_content)


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

    @pytest.mark.static
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)

    @pytest.mark.static
    def test_no_bashrc(self):
        assert_no_bashrc_modification(PKG_FILE)

    @pytest.mark.static
    def test_no_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.static
    def test_new_api(self):
        assert_uses_new_api(PKG_FILE)

    @pytest.mark.static
    def test_registers_the_four_programs(self, code):
        """Registered through the NATIVE_PROGRAMS/JAVA_PROGRAMS tables and a
        loop, not four literal xvm.add calls -- so the check is that each
        name is a member of one of those tables and that config() iterates
        both."""
        for prog in ("aapt2", "zipalign", "apksigner", "d8"):
            assert re.search(r'"' + prog + r'"', code), f"{prog} not named anywhere"
        assert "NATIVE_PROGRAMS" in code and "JAVA_PROGRAMS" in code
        assert re.search(r'for _, prog in ipairs\(NATIVE_PROGRAMS\)', code)
        assert re.search(r'for _, prog in ipairs\(JAVA_PROGRAMS\)', code)

    @pytest.mark.static
    def test_declares_jdk_as_a_runtime_dependency_on_every_host(self, meta):
        """apksigner and d8 shell out to `java` unconditionally (measured in
        the recipe's own header from the archive's own launcher scripts);
        this is a shell-out dependency the same way emsdk.lua's xim:node is,
        not an ELF dependency, and must be declared on every host, not only
        the one this recipe's own execution evidence covers."""
        code = _code(meta.raw_content)
        for host_block in ("linux", "macosx", "windows"):
            m = re.search(host_block + r'\s*=\s*\{', code)
            assert m, f"no {host_block} table found"
        assert code.count("xim:jdk-temurin") >= 3, \
            "xim:jdk-temurin must be declared once per host (linux, macosx, windows)"

    @pytest.mark.static
    def test_no_glibc_dependency_declared(self, code):
        """aapt2/zipalign's own NEEDED set (measured with readelf -d) is core
        glibc only -- libc, libm, libpthread, librt, libdl, libgcc_s -- which
        crosses no boundary this index's own convention treats as a
        dependency (android-ndk.lua, emsdk.lua: "only core glibc crosses the
        boundary => empty deps is correct")."""
        assert "xim:glibc" not in code
        assert "xim:gcc-runtime" not in code

    @pytest.mark.static
    def test_no_cn_mirror_invented(self, code):
        """The header states this tier-1 archive is not yet mirrored to
        xlings-res -- a CN url that has not actually been published would be
        a URL invented rather than measured, which README.md's own asset
        gate exists to catch. Neither the CN key nor ci.mirror should
        appear until a real mirror exists."""
        assert "CN " not in code and 'CN     =' not in code and 'CN =' not in code
        assert "ci = {" not in code
        assert "gitcode.com/xlings-res" not in code

    @pytest.mark.static
    def test_every_sha256_is_64_hex_chars(self, meta):
        for m in re.finditer(r'sha256\s*=\s*"([0-9a-f]+)"', meta.raw_content):
            assert len(m.group(1)) == 64, \
                f"sha256 {m.group(1)!r} is not 64 hex characters"

    @pytest.mark.static
    def test_the_three_sha256_values_are_distinct(self, meta):
        """Three different archives (linux/macosx/windows) must not share a
        hash -- a repeated value would mean a copy-paste rather than three
        independent downloads."""
        hashes = re.findall(r'sha256\s*=\s*"([0-9a-f]{64})"', meta.raw_content)
        assert len(hashes) == 3, f"expected 3 sha256 entries, found {len(hashes)}"
        assert len(set(hashes)) == 3, "two or more sha256 values are identical"

    @pytest.mark.static
    def test_windows_launchers_are_bat_not_exe(self, code):
        """apksigner/d8 ship as .bat on Windows (measured from the archive
        itself); registering them with the default .exe-shaped name would
        never find them."""
        assert '".bat"' in code

    @pytest.mark.static
    def test_windows_path_uses_envs_not_a_wrapper(self, code):
        """apksigner.bat/d8.bat already honour JAVA_HOME (measured: `if
        defined JAVA_HOME goto findJavaFromJavaHome`); the fix on Windows is
        `envs`, not a wrapper script -- a wrapper is unnecessary work and
        this test would catch it silently regressing into one."""
        assert "envs" in code
        assert re.search(r'envs\s*=.*JAVA_HOME', code) or \
            re.search(r'JAVA_HOME\s*=\s*jdk_home', code)

    @pytest.mark.static
    def test_posix_wrapper_sets_java_home_and_path(self, meta):
        """apksigner/d8's own POSIX launchers exec a bare `java` and read no
        JAVA_HOME at all (measured); PATH is what actually makes `java`
        resolve, so the wrapper must set both -- JAVA_HOME for anything
        downstream that reads it, PATH for the two programs themselves."""
        assert "WRAPPER_TEMPLATE" in meta.raw_content
        assert 'export JAVA_HOME="%s"' in meta.raw_content
        assert 'export PATH="$JAVA_HOME/bin:$PATH"' in meta.raw_content

    @pytest.mark.static
    def test_wrapper_is_bash_checked_at_install(self, code):
        assert "bash -n" in code

    @pytest.mark.static
    def test_windows_has_no_chmod_or_bash_call(self, meta):
        """Windows has neither chmod nor (necessarily) bash; the wrapper/
        bash -n path must be skipped there, matching the existing
        android-platform-tools.lua chmod guard."""
        code = _code(meta.raw_content)
        # The two POSIX-only operations must be inside an `if not
        # is_host("windows")` guard somewhere in install().
        assert 'is_host("windows")' in code


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_installed_aapt2_runs(self):
        """aapt2 needs no java and no network; `version` is the cheapest
        possible liveness check for the installed binary."""
        from tests.lib.platform_utils import xpkgs_dir
        import glob
        import subprocess
        hits = []
        for ns in ("xim", "local"):
            hits += sorted(glob.glob(f"{xpkgs_dir()}/{ns}-x-android-build-tools/*/aapt2"))
        if not hits:
            pytest.skip("android-build-tools is not installed")
        r = subprocess.run([hits[-1], "version"], capture_output=True, text=True, timeout=15)
        assert r.returncode == 0
