"""Tests for the android-system-image package."""
import glob
import os
import re

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

PKG = "android-system-image"
PKG_FILE = "pkgs/a/android-system-image.lua"
VERSIONS = ["24-default-x86_64", "24-default-arm64-v8a"]


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
    """The design this recipe deliberately took, per its own header: one
    package, per-(api,tag,abi) version keys, no `latest`, no per-arch hash
    table -- and why each alternative was rejected.
    """

    @pytest.mark.static
    def test_both_verified_versions_present(self, source_text):
        for v in VERSIONS:
            assert f'["{v}"]' in source_text, f"missing version key {v}"

    @pytest.mark.static
    def test_two_sha256_present_and_64_hex(self, source_text):
        hashes = re.findall(r'sha256\s*=\s*"([0-9a-fA-F]{64})"', source_text)
        assert len(hashes) == 2, f"expected 2 sha256 entries, found {len(hashes)}"
        assert len(set(hashes)) == 2, "the two system images must not share a hash"

    @pytest.mark.static
    def test_no_latest_key(self, source_text):
        # Deliberate: version keys here are not totally ordered (API level,
        # tag and abi are three independent axes), so a `latest` alias
        # would silently pick one arbitrarily. See the header's "ONE
        # PACKAGE, MANY VERSIONS" section.
        code = re.sub(r'--.*', '', source_text)
        assert '"latest"' not in code

    @pytest.mark.static
    def test_no_per_arch_hash_table(self, source_text):
        # Rejected shape (b) in the header: `sha256 = { x86_64 = ...,
        # arm64-v8a = ... }` would claim these two images are
        # interchangeable builds of one release, which they are not (one
        # of them does not even boot on the host class this was measured
        # on -- see android-emulator.lua).
        code = re.sub(r'--.*', '', source_text)
        assert not re.search(r'sha256\s*=\s*\{', code)

    @pytest.mark.static
    def test_no_cn_mirror_invented(self, source_text):
        code = re.sub(r'--.*', '', source_text)
        assert 'gitcode.com' not in code
        assert 'xlings-res' not in code
        assert 'dl.google.com' in code

    @pytest.mark.static
    def test_wider_host_arch_than_sibling_packages(self, source_text):
        # Deliberately wider than android-emulator.lua / android-platform-
        # tools.lua's {"x86_64"}: this payload is guest content, host-arch
        # independent (contributing.md SS5.2), unlike those two which are
        # host executables Google builds only for linux-x86_64.
        m = re.search(r'archs\s*=\s*\{([^}]*)\}', source_text)
        assert m, "no archs field"
        archs = set(re.findall(r'"([^"]+)"', m.group(1)))
        assert archs == {"x86_64", "aarch64"}

    @pytest.mark.static
    def test_no_os_arch_call(self, source_text):
        code = re.sub(r'--.*', '', source_text)
        assert 'os.arch(' not in code

    @pytest.mark.static
    def test_no_bare_binary_shim_registered(self, source_text):
        # Data-only payload -- config() must register only package.name,
        # matching contributing.md SS5.2's convention for a content payload.
        config_body = source_text.split("function config()", 1)[1]
        config_body = config_body.split("\nfunction uninstall()", 1)[0]
        adds = re.findall(r'xvm[.:]\s*add\s*\(\s*"([^"]+)"', config_body)
        assert adds == []
        assert "xvm.add(package.name)" in config_body


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    @pytest.mark.parametrize("version", VERSIONS)
    def test_install(self, version):
        # ~300-420 MB per image.
        assert_install_succeeds(f"{PKG}@{version}", timeout=600)


class TestVerify:
    @staticmethod
    def _installed_dir(version: str) -> str:
        for ns in ("xim", "local"):
            hits = sorted(glob.glob(os.path.join(xpkgs_dir(), f"{ns}-x-android-system-image", version)))
            if hits:
                return hits[-1]
        pytest.fail(f"no android-system-image@{version} payload found under {xpkgs_dir()}")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_android_system_image(self):
        assert_xvm_registered("android-system-image")

    @pytest.mark.verify
    @skip_if_not('linux')
    @pytest.mark.parametrize("version", VERSIONS)
    def test_installed_layout(self, version):
        d = self._installed_dir(version)
        for name in ("system.img", "ramdisk.img", "userdata.img",
                      "build.prop", "source.properties"):
            assert os.path.isfile(os.path.join(d, name)), f"missing {name} under {d}"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_x86_64_build_prop_matches_measured_api_level(self):
        # The exact fact android-emulator.lua's header boots against.
        d = self._installed_dir("24-default-x86_64")
        with open(os.path.join(d, "build.prop"), encoding="utf-8") as f:
            content = f.read()
        assert "ro.build.version.sdk=24" in content

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_arm64_build_prop_matches_measured_api_level(self):
        d = self._installed_dir("24-default-arm64-v8a")
        with open(os.path.join(d, "build.prop"), encoding="utf-8") as f:
            content = f.read()
        assert "ro.build.version.sdk=24" in content
