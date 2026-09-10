"""测试 appimagetool 包"""
import base64
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
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, xpkgs_dir

# A closed local port: any attempt to reach the network through it fails
# immediately (connection refused) rather than hanging on a real timeout or,
# worse, quietly succeeding because the CI runner happens to have outbound
# access an offline-build assertion did not intend to rely on.
_DEAD_PROXY = "http://127.0.0.1:1"
_OFFLINE_ENV_OVERRIDES = {
    "APPIMAGE_EXTRACT_AND_RUN": "1",
    "http_proxy": _DEAD_PROXY, "https_proxy": _DEAD_PROXY, "all_proxy": _DEAD_PROXY,
    "HTTP_PROXY": _DEAD_PROXY, "HTTPS_PROXY": _DEAD_PROXY, "ALL_PROXY": _DEAD_PROXY,
}

# Well-known minimal 1x1 transparent PNG, used as a stand-in icon.
_TINY_PNG_B64 = (
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8A"
    "AQUBAScY42YAAAAASUVORK5CYII="
)

PKG = "appimagetool"
PKG_FILE = "pkgs/a/appimagetool.lua"


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope='module')
def source_text():
    from tests.lib.platform_utils import project_root
    import os
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
    """The facts this recipe pins by hand rather than letting anything infer.

    GitHub's own "latest release" for AppImage/appimagetool resolves to the
    mutable "continuous" tag (see pkgs/a/appimagetool.lua for the measured
    reasoning), so nothing here may accidentally start treating "continuous"
    as a version, and the two published archs must each carry the real
    sha256 measured against the downloaded asset, not a placeholder.
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
                f"{k} is not dotted digits -- \"continuous\" or any other "
                f"non-numeric upstream tag must never become a version key"
            )

    @pytest.mark.static
    def test_no_continuous_tag_in_urls(self, source_text):
        # The rolling tag is fine to discuss in a comment; it must never
        # appear in a resolvable url, or an install would fetch a moving
        # target no sha256 in this file actually describes.
        code = re.sub(r'--.*', '', source_text)
        assert '/continuous/' not in code

    @pytest.mark.static
    def test_both_archs_have_real_sha256(self, source_text):
        for arch in ("x86_64", "aarch64"):
            m = re.search(rf'{arch}\s*=\s*"([0-9a-fA-F]{{64}})"', source_text)
            assert m, f"missing a 64-hex-character sha256 for {arch}"

    @pytest.mark.static
    def test_linux_only(self, meta):
        assert meta.platforms.get("linux")
        assert "macosx" not in meta.platforms
        assert "windows" not in meta.platforms

    @pytest.mark.static
    def test_no_type2_runtime_download_url(self, source_text):
        # type2-runtime is discussed at length in a comment (the measurement
        # that justifies carving the runtime out of appimagetool itself
        # rather than fetching it) -- it must never appear in a resolvable
        # download address, or an install would grow a second network
        # dependency this recipe was extended specifically to avoid.
        code = re.sub(r'--.*', '', source_text)
        assert 'type2-runtime' not in code
        # SANITY, AND NOT A SPELLING. The strip above must not have eaten the
        # real address, and the assertion has to survive the recipe changing
        # WHERE it declares one: this test was written against a per-version
        # `url =` and went red -- with the recipe correct -- when the addresses
        # moved to a regional `source` map. What is being checked is that a
        # resolvable address is still present, so that is what it asks.
        assert 'https://' in code

    @pytest.mark.static
    def test_install_carves_a_runtime_stub(self, source_text):
        # Lightweight regression guard: the carving mechanism itself (not
        # just its outcome) stays in install() -- `--appimage-offset` to
        # find the boundary, the "hsqs" magic to confirm it, and a
        # `runtime-` prefixed output name a consumer hardcodes.
        install_body = source_text.split("function install()", 1)[1]
        install_body = install_body.split("\nfunction config()", 1)[0]
        assert "--appimage-offset" in install_body
        assert "hsqs" in install_body
        assert '"runtime-"' in install_body


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(PKG)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_appimagetool_version(self):
        # `--appimage-extract-and-run`, unconditionally: appimagetool is
        # itself a type-2 AppImage, so a plain invocation makes it try to
        # FUSE-mount its own payload before it can answer anything --
        # including --version. A CI runner is exactly the kind of host
        # likely to lack libfuse2/fuse3 (measured in pkgs/a/appimagetool.lua),
        # and the flag is a documented no-op cost on a host that does have
        # FUSE, so this is the one invocation shape that is correct on both.
        assert_command_output(
            "appimagetool --appimage-extract-and-run --version",
            "appimagetool",
        )

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_appimagetool(self):
        assert_xvm_registered("appimagetool")

    @staticmethod
    def _installed_pkgdir() -> str:
        """Read the store directly rather than through `xvm info` / the
        shim, matching test_ncurses.py's own L4 helpers ("都直接读盘/跑
        载荷, 不经 shim"). `xvm info <name>` is measured to be unusable
        for this on the machine this suite was written on: it prints a
        generic "[Runtime Tips]" PATH message instead of real package
        info for EVERY package, not just this one -- reproduced against
        ninja.lua's own pre-existing `test_xvm_ninja`, which fails the
        same way here. A namespace can be `local` (this recipe, before it
        is merged) or `xim` (after) -- both are tried, newest version wins.
        """
        for ns in ("xim", "local"):
            hits = sorted(glob.glob(os.path.join(xpkgs_dir(), f"{ns}-x-appimagetool", "*")))
            if hits:
                return hits[-1]
        pytest.fail(f"no appimagetool payload found under {xpkgs_dir()}")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_runtime_stub_installed(self):
        # The installed layout must carry BOTH files a consumer hardcodes:
        # `appimagetool` and `runtime-<arch>`. See pkgs/a/appimagetool.lua
        # for why the second file is carved from the first rather than
        # downloaded: it removes a per-build network fetch (measured to be
        # otherwise unavoidable) and a second pinned, mutable-tag asset.
        pkgdir = self._installed_pkgdir()
        runtimes = glob.glob(os.path.join(pkgdir, "runtime-*"))
        assert runtimes, f"no runtime-<arch> file found in {pkgdir}"
        for rt in runtimes:
            assert os.access(rt, os.X_OK), f"{rt} is not executable"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_offline_appimage_build_using_installed_runtime(self, tmp_path):
        """Build and run an AppImage using ONLY files already present in
        the installed package directory, with the network unreachable --
        the exact shape mcpp.dist.appimage runs in on a CI runner or inside
        a container, and the property the runtime-carving install() logic
        exists to guarantee.
        """
        pkgdir = self._installed_pkgdir()
        appimagetool_bin = os.path.join(pkgdir, "appimagetool")
        runtimes = glob.glob(os.path.join(pkgdir, "runtime-*"))
        assert runtimes, f"no runtime-<arch> file found in {pkgdir}"
        runtime_file = runtimes[0]
        arch = os.path.basename(runtime_file).removeprefix("runtime-")

        appdir = tmp_path / "AppDir"
        appdir.mkdir()
        apprun = appdir / "AppRun"
        apprun.write_text("#!/bin/sh\necho offline-appimagetool-smoke-ok\nexit 0\n")
        apprun.chmod(0o755)
        (appdir / "smoke.desktop").write_text(
            "[Desktop Entry]\n"
            "Type=Application\n"
            "Name=Smoke\n"
            "Exec=AppRun\n"
            "Icon=smoke\n"
            "Categories=Utility;\n"
        )
        (appdir / "smoke.png").write_bytes(base64.b64decode(_TINY_PNG_B64))

        out_appimage = tmp_path / "smoke.AppImage"
        env = {
            **os.environ,
            "ARCH": arch,
            **_OFFLINE_ENV_OVERRIDES,
        }

        build = subprocess.run(
            [appimagetool_bin, "--runtime-file", runtime_file,
             str(appdir), str(out_appimage)],
            capture_output=True, text=True, timeout=60, env=env,
        )
        assert build.returncode == 0, (
            f"offline AppImage build failed (exit={build.returncode}):\n"
            f"{build.stdout}\n{build.stderr}"
        )
        assert out_appimage.is_file(), "build reported success but produced no file"
        assert "Downloading runtime file" not in (build.stdout + build.stderr), (
            "the build reached for the network instead of using --runtime-file"
        )

        os.chmod(out_appimage, 0o755)
        run = subprocess.run(
            [str(out_appimage)], capture_output=True, text=True, timeout=30,
            env={**os.environ, **_OFFLINE_ENV_OVERRIDES},
        )
        assert run.returncode == 0, (
            f"the produced AppImage did not run (exit={run.returncode}):\n"
            f"{run.stdout}\n{run.stderr}"
        )
        assert "offline-appimagetool-smoke-ok" in run.stdout
