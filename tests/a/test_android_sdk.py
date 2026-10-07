"""Tests for the android-sdk package (an ANDROID_HOME assembled from symlinks)."""
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
from tests.lib.platform_utils import skip_if_not, xpkgs_dir, project_root

PKG = "android-sdk"
PKG_FILE = "pkgs/a/android-sdk.lua"

DECLARED = (
    "xim:android-platform-tools@37.0.1-4",
    "xim:android-build-tools@36.1.0",
    "xim:android-platform@36-r2",
)


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope='module')
def source_text():
    with open(os.path.join(project_root(), PKG_FILE), encoding="utf-8") as handle:
        return handle.read()


@pytest.fixture(scope='module')
def code(source_text):
    """Lua source with line comments stripped, so assertions see declarations."""
    return "\n".join(
        line for line in source_text.splitlines() if not line.lstrip().startswith("--")
    )


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


class TestDesign:
    @pytest.mark.static
    def test_minimum_components_are_exact_store_keys(self, code):
        """dep_install_dir does not dereference `ref`: a pin that can land on
        an alias key (`android-platform@36` -> `36-r2`) returns a path that
        does not exist. Each declared component is the exact key, on both
        hosts."""
        for dep in DECLARED:
            assert code.count(f'"{dep}"') == 2, f"{dep} should be pinned on linux and macosx"
        assert ">=" not in code

    @pytest.mark.static
    def test_hosts_are_linux_and_macosx_only(self, meta, source_text):
        """The tree is symlinks; Windows needs Developer Mode or elevation to
        create one, so the host is declared as a gap instead of offered."""
        assert set(meta.platforms) == {"linux", "macosx"}, meta.platforms
        assert "WINDOWS IS NOT OFFERED" in source_text

    @pytest.mark.static
    def test_tree_slots_follow_source_properties(self, code):
        """Directory names in the tree come from each component's own
        source.properties, the file sdkmanager and AGP read, not from the
        xlings version key ("36-r2" must become platforms/android-36)."""
        for key in ("Pkg.Revision", "AndroidVersion.ApiLevel",
                    "SystemImage.TagId", "SystemImage.Abi"):
            assert f'"{key}"' in code, key
        for slot in ('"platform-tools"', '"build-tools"', '"platforms"', '"ndk"',
                     '"emulator"', '"system-images"'):
            assert slot in code, slot

    @pytest.mark.static
    def test_other_installed_components_are_scanned(self, code):
        """The SDK-Manager behaviour: versions installed beside the declared
        ones are linked too, under any index namespace, and the store root is
        derived from a dependency's own install dir rather than hard-coded."""
        for name in ("android-build-tools", "android-platform", "android-ndk",
                     "android-emulator", "android-system-image"):
            assert f'"{name}"' in code, name
        assert '"-x-" .. name' in code
        assert "path.directory(path.directory(declared[1][2]))" in code
        assert "xpkgs" not in code, "the store root must not be hard-coded"

    @pytest.mark.static
    def test_tree_is_built_in_config_so_reconfig_rescans(self, code):
        config = code.split("function config()", 1)[1].split("function uninstall()", 1)[0]
        assert "assemble()" in config
        install = code.split("function install()", 1)[1].split("function config()", 1)[0]
        assert "assemble()" not in install

    @pytest.mark.static
    def test_symlinks_are_removed_without_following_them(self, code):
        """os.tryrm on a tree of symlinks to other packages' payloads must not
        be trusted; `rm -rf` removes a link without following it."""
        assert 'rm -rf "%s"' in code
        assert "ln -sfn" in code

    @pytest.mark.static
    def test_no_licence_file_is_written(self, code):
        """Measured: AGP builds without one when the tree is complete, and
        writing it would accept the SDK licence on the user's behalf and let
        AGP download into the store behind xlings' back."""
        assert "android-sdk-license" not in code
        assert '"licenses"' not in code

    @pytest.mark.static
    def test_no_jdk_dependency_or_java_home(self, code):
        """Gradle 8.11 (Godot 4.7's template) refuses JDK 25; the JDK is the
        project's choice, not the tree's."""
        assert "jdk" not in code.lower()
        assert "JAVA_HOME" not in code

    @pytest.mark.static
    def test_android_home_declared_for_the_subos(self, code):
        assert 'var = "ANDROID_HOME"' in code
        assert 'var = "ANDROID_SDK_ROOT"' in code
        assert code.count('value = "${pkgdir}/sdk"') == 2
        assert 'type(subos.env) == "function"' in code

    @pytest.mark.static
    def test_android_home_declaration_says_why(self, source_text):
        """The spec requires a privileged-looking subos.env declaration to say
        why it is needed; xlings' install-time report lists this one."""
        idx = source_text.index('var = "ANDROID_HOME"')
        preceding = source_text[max(0, idx - 1200):idx]
        assert "Not a loader variable" in preceding

    @pytest.mark.static
    def test_root_printer_is_valid_shell_and_prints_the_tree(self, source_text, tmp_path):
        m = re.search(r'ROOT_PRINTER_TEMPLATE = \[==\[(.*?)\]==\]', source_text, re.S)
        assert m, "the embedded android-sdk-root template was not found"
        script = m.group(1) % "/opt/example/android-sdk/1.0.0/sdk"
        p = tmp_path / "android-sdk-root"
        p.write_text(script, encoding="utf-8")
        r = subprocess.run(["bash", "-n", str(p)], capture_output=True, text=True)
        assert r.returncode == 0, r.stderr
        r = subprocess.run(["bash", str(p)], capture_output=True, text=True)
        assert r.stdout.strip() == "/opt/example/android-sdk/1.0.0/sdk"

    @pytest.mark.static
    def test_uninstall_is_version_scoped(self, code):
        body = code.split("function uninstall()", 1)[1]
        assert 'xvm.remove("android-sdk-root", version)' in body
        assert "xvm.remove(package.name, version)" in body


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        # platform-tools + build-tools (with its JDK) + platform: ~350 MB.
        assert_install_succeeds(PKG, timeout=900)


class TestVerify:
    @staticmethod
    def _sdk_root() -> str:
        for ns in ("xim", "local"):
            hits = sorted(glob.glob(os.path.join(xpkgs_dir(), f"{ns}-x-android-sdk", "*", "sdk")))
            if hits:
                return hits[-1]
        pytest.fail(f"no android-sdk tree found under {xpkgs_dir()}")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_android_sdk_root(self):
        assert_xvm_registered("android-sdk-root")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_tree_has_the_android_studio_layout(self):
        root = self._sdk_root()
        assert os.access(os.path.join(root, "platform-tools", "adb"), os.X_OK)
        assert os.path.isfile(os.path.join(root, "build-tools", "36.1.0", "apksigner"))
        assert os.path.isfile(os.path.join(root, "build-tools", "36.1.0", "zipalign"))
        assert os.path.isfile(os.path.join(root, "platforms", "android-36", "android.jar"))
        for slot in ("platform-tools", os.path.join("build-tools", "36.1.0"),
                     os.path.join("platforms", "android-36")):
            assert os.path.islink(os.path.join(root, slot)), f"{slot} should be a symlink"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_root_printer_names_the_tree(self):
        r = subprocess.run(["android-sdk-root"], capture_output=True, text=True)
        assert r.returncode == 0, r.stderr
        assert r.stdout.strip() == self._sdk_root()
