"""Tests for the android-ndk package."""
import glob
import os
import re
import subprocess

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, xpkgs_dir

PKG = "android-ndk"
PKG_FILE = "pkgs/a/android-ndk.lua"

# Relative layout this recipe documents and mcpp's toolchain registry
# hardcodes -- see the header comment in pkgs/a/android-ndk.lua.
HOST_TAG = "linux-x86_64"
TOOLCHAIN_REL = os.path.join("toolchains", "llvm", "prebuilt", HOST_TAG)
CLANGXX_REL = os.path.join(TOOLCHAIN_REL, "bin", "clang++")
SYSROOT_REL = os.path.join(TOOLCHAIN_REL, "sysroot")
SHAREV1_REL = os.path.join(TOOLCHAIN_REL, "share", "libc++", "v1")


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope='module')
def source_text():
    from tests.lib.platform_utils import project_root
    with open(os.path.join(project_root(), PKG_FILE), encoding="utf-8") as handle:
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
    """The facts this recipe pins by hand, and the ones it deliberately
    refuses to declare, per the header comment in pkgs/a/android-ndk.lua.
    """

    @pytest.mark.static
    def test_version_keys_are_dotted_digits(self, source_text):
        head = source_text.split('\nimport(', 1)[0]
        head = '\n'.join(l for l in head.splitlines()
                         if not l.lstrip().startswith('--'))
        keys = [k for k in re.findall(r'\["([^"]+)"\]\s*=', head)
                if k != 'latest']
        assert keys, "no version keys found"
        for k in keys:
            assert re.fullmatch(r'\d+(\.\d+)*', k), (
                f"{k} is not dotted digits -- the release name (\"r30\") "
                f"must never become a version key, only Pkg.Revision"
            )

    @pytest.mark.static
    def test_sha256_present_and_64_hex(self, source_text):
        m = re.search(r'sha256\s*=\s*"([0-9a-fA-F]{64})"', source_text)
        assert m, "missing a 64-hex-character sha256"

    @pytest.mark.static
    def test_both_regions_and_the_upstream_one_is_kept(self, source_text):
        """REVERSED, AND THE CLAUSE IS WHY.

        This pinned the absence of a CN entry, on SDK Agreement 3.4: "you may
        not copy [...], redistribute [...] the SDK or any part of the SDK".
        Section 3.5 is the one that decides: distribution of components
        "licensed under an open source software license are governed SOLELY by
        the terms of that open source software license and NOT the License
        Agreement". Verified inside the archive rather than asserted -- the
        payload carries an Apache-2.0 LICENSE or NOTICE for its contents, so
        3.5 governs.

        Asserts BOTH entries. The GLOBAL one is not optional: a recipe that
        named only the mirror would make every user depend on a re-host, which
        is the inverse mistake and one pkgs/p/python.lua actually had.
        """
        code = re.sub(r'--.*', '', source_text)
        assert 'dl.google.com' in code, "the upstream URL was dropped"
        assert 'gitcode.com/xlings-res' in code, "no CN mirror"
        assert re.search(r'GLOBAL\s*=', code), "no GLOBAL key"
        assert re.search(r'CN\s*=', code), "no CN key"

    @pytest.mark.static
    def test_every_host_upstream_publishes_for(self, meta):
        """REVERSED. This pinned `linux` only, which was true of the recipe and
        not of upstream: Google publishes android-ndk for every host this index
        serves. Declaring one was an incomplete addition rather than a
        conclusion, so the test now asserts the completion -- one per host, and the darwin archive is a UNIVERSAL build serving both Apple arches.

        Execution evidence remains Linux-only and the recipe says so; the
        index's own macos-install-test and windows-test are the measurement for
        the other two legs.
        """
        for host in ("linux", "macosx", "windows"):
            assert meta.platforms.get(host), f"no {host} table"

    @pytest.mark.static
    def test_arch_scope_is_stated_per_platform(self, source_text):
        """REVERSED with the platform completion. `archs` is a statement about
        the PACKAGE and the platform tables carry the truth per host -- the
        shape 7zip.lua, bun.lua and cuda-nvcc.lua use. Upstream publishes one
        archive per host, so no table needs an `arch_alias` for selection and
        the `os.arch()`-is-unbound pitfall does not arise.
        """
        m = re.search(r'archs\s*=\s*\{([^}]*)\}', source_text)
        assert m, "no archs field"
        archs = re.findall(r'"([^"]+)"', m.group(1))
        assert archs == ["x86_64", "aarch64"], (
            f"expected both host arches, with the platform tables deciding "
            f"what each host is served, got {archs}"
        )

    @pytest.mark.static
    def test_no_ci_automation_declared(self, source_text):
        # A version bump here needs a human to re-verify the module surface
        # and the ctype workaround (see the header comment) -- `ci.mirror`
        # would also re-host an archive this recipe deliberately does not.
        code = re.sub(r'--.*', '', source_text)
        assert not re.search(r'\bci\s*=\s*\{', code)

    @pytest.mark.static
    def test_no_deps_declared(self, source_text):
        # Self-contained payload (bundled libc++/libc++abi/libunwind, only
        # core host glibc crossed) -- see contributing.md section 5.1 and
        # the header comment for the measurement this rests on.
        code = re.sub(r'--.*', '', source_text)
        assert not re.search(r'\bdeps\s*=', code)

    @pytest.mark.static
    def test_no_bare_clang_shim_registered(self, source_text):
        # Registering "clang"/"clang++" here would collide with xim:llvm's
        # own xvm registrations the moment both are installed together.
        config_body = source_text.split("function config()", 1)[1]
        config_body = config_body.split("\nfunction uninstall()", 1)[0]
        adds = re.findall(r'xvm[.:]\s*add\s*\(\s*"([^"]+)"', config_body)
        assert adds == [], (
            f"config() registers bare name(s) {adds}; this recipe must "
            f"register only package.name (see the xvm_enable comment)"
        )
        assert "xvm.add(package.name)" in config_body

    @pytest.mark.static
    def test_no_os_arch_call(self, source_text):
        # os.arch() is not bound in the xim install-hook runtime on this
        # engine (pkgs/n/node.lua, pkgs/j/jdk-zulu.lua) -- this recipe does
        # not need per-host-arch selection at all (single upstream Linux
        # build), and must not reach for it anyway.
        code = re.sub(r'--.*', '', source_text)
        assert 'os.arch(' not in code

    @pytest.mark.static
    def test_expected_libcpp_version_pinned(self, source_text):
        m = re.search(r'EXPECTED_LIBCPP_VERSION\s*=\s*"(\d+)"', source_text)
        assert m, "no EXPECTED_LIBCPP_VERSION constant found"
        # 210000 == LLVM/libc++ 21, matching NDK r30's clang 21.0.0 --
        # measured against the actually-downloaded payload (see the recipe
        # header and the task report). A change here without re-verifying
        # the payload is exactly the drift the install()-time check guards.
        assert m.group(1) == "210000"

    @pytest.mark.static
    def test_install_refuses_on_libcpp_version_mismatch(self, source_text):
        install_body = source_text.split("function install()", 1)[1]
        install_body = install_body.split("\nfunction config()", 1)[0]
        assert "EXPECTED_LIBCPP_VERSION" in install_body
        assert "actual_version ~= EXPECTED_LIBCPP_VERSION" in install_body

    @pytest.mark.static
    def test_install_runs_a_real_precompile_selftest(self, source_text):
        # The strongest check (R4, docs/V2/xpackage-spec.md): install()
        # must actually invoke the compiler on the vendored std.cppm with
        # the bionic ctype workaround, not merely check that files exist.
        assert "--precompile" in source_text
        assert "-D__BIONIC_CTYPE_INLINE=" in source_text
        assert "selftest_std_module(dir)" in source_text


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        # A 700+ MB download plus a ~2.3 GB extraction is measured to take
        # well under the default 180s on a fast connection, but this is the
        # single heaviest install in the index by payload size, so the
        # budget is widened rather than shared with small-package defaults.
        assert_install_succeeds(PKG, timeout=900)


class TestVerify:
    @staticmethod
    def _installed_pkgdir() -> str:
        """Read the store directly, matching test_appimagetool.py's own
        helper: a namespace can be `local` (this recipe, before merge) or
        `xim` (after) -- both are tried, newest version wins.
        """
        for ns in ("xim", "local"):
            hits = sorted(glob.glob(os.path.join(xpkgs_dir(), f"{ns}-x-android-ndk", "*")))
            if hits:
                return hits[-1]
        pytest.fail(f"no android-ndk payload found under {xpkgs_dir()}")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_android_ndk(self):
        assert_xvm_registered("android-ndk")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_installed_layout(self):
        pkgdir = self._installed_pkgdir()
        assert os.path.isfile(os.path.join(pkgdir, CLANGXX_REL)), (
            f"no clang++ at {CLANGXX_REL} under {pkgdir}"
        )
        assert os.path.isdir(os.path.join(pkgdir, SYSROOT_REL, "usr", "include", "android")), (
            f"no bionic sysroot under {pkgdir}"
        )
        assert os.path.isfile(os.path.join(pkgdir, SHAREV1_REL, "std.cppm"))
        assert os.path.isfile(os.path.join(pkgdir, SHAREV1_REL, "std.compat.cppm"))

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_module_surface_file_count(self):
        pkgdir = self._installed_pkgdir()
        std_dir = os.path.join(pkgdir, SHAREV1_REL, "std")
        compat_dir = os.path.join(pkgdir, SHAREV1_REL, "std.compat")
        std_incs = glob.glob(os.path.join(std_dir, "*.inc"))
        compat_incs = glob.glob(os.path.join(compat_dir, "*.inc"))
        # Measured against the actual r30 payload: 110 and 21. A floor
        # rather than an exact match, so a future point release adding one
        # header is not the failure this asserts against -- the vendor
        # dropping the surface entirely (measured to have happened at some
        # point between r27 and r30's predecessor) is.
        assert len(std_incs) >= 100, f"only {len(std_incs)} std/*.inc files in {std_dir}"
        assert len(compat_incs) >= 15, f"only {len(compat_incs)} std.compat/*.inc files in {compat_dir}"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_import_std_compiles_and_links(self, tmp_path):
        """The end-to-end proof this package exists for: a module interface
        unit compiles, and a program that `import std;`s links against the
        installed payload's OWN clang++, sysroot and module surface --
        nothing else. This is the exact program and shape used to verify
        the recipe by hand; see the task report for the original run.

        Execution is NOT attempted: there is no Android device or emulator
        on this host. The assertion stops at "compiles and links" plus a
        `file`-reported ELF/arch check, which is the strongest claim that
        can honestly be made here.
        """
        pkgdir = self._installed_pkgdir()
        clangxx = os.path.join(pkgdir, CLANGXX_REL)
        stdcppm = os.path.join(pkgdir, SHAREV1_REL, "std.cppm")

        main_cpp = tmp_path / "main.cpp"
        main_cpp.write_text(
            "import std;\n"
            "int main() {\n"
            "  std::vector<int> v{3,1,2};\n"
            "  std::ranges::sort(v);\n"
            '  return std::format("{}-{}-{}", v[0], v[1], v[2]) == "1-2-3" ? 0 : 1;\n'
            "}\n"
        )

        target = "aarch64-linux-android24"
        std_pcm = tmp_path / "std.pcm"
        std_o = tmp_path / "std.o"
        main_o = tmp_path / "main.o"
        app = tmp_path / "app"

        def run(*args, timeout=60):
            r = subprocess.run(list(args), cwd=tmp_path, capture_output=True,
                                text=True, timeout=timeout)
            assert r.returncode == 0, (
                f"command failed (exit={r.returncode}): {' '.join(args)}\n"
                f"stdout: {r.stdout}\nstderr: {r.stderr}"
            )

        run(clangxx, f"--target={target}", "-std=c++23",
            "-D__BIONIC_CTYPE_INLINE=", "--precompile", stdcppm,
            "-o", str(std_pcm))
        run(clangxx, f"--target={target}", "-std=c++23",
            "-c", str(std_pcm), "-o", str(std_o))
        run(clangxx, f"--target={target}", "-std=c++23",
            "-D__BIONIC_CTYPE_INLINE=", f"-fmodule-file=std={std_pcm}",
            "-c", str(main_cpp), "-o", str(main_o))
        run(clangxx, f"--target={target}", "-std=c++23",
            str(main_o), str(std_o), "-o", str(app))

        assert app.is_file(), "link reported success but produced no file"

        file_out = subprocess.run(["file", str(app)], capture_output=True, text=True)
        assert "ELF 64-bit LSB pie executable" in file_out.stdout
        assert "ARM aarch64" in file_out.stdout
