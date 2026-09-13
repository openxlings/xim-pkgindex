"""测试 vulkan-validation-layers 包"""
import json
import os
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
)
from tests.lib.platform_utils import skip_if_not, xpkgs_dir

PKG = "vulkan-validation-layers"
PKG_FILE = "pkgs/v/vulkan-validation-layers.lua"
VERSION = "1.4.357.0"
LAYER_SO = "libVkLayer_khronos_validation.so"
MANIFEST = "share/vulkan/explicit_layer.d/VkLayer_khronos_validation.json"


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

    @pytest.mark.static
    def test_declares_the_layer_directory_and_the_variable(self):
        # The two halves of discovery: the manifest into the subos, and the
        # subos share on XDG_DATA_DIRS. One without the other is a layer the
        # loader never sees, which fails as the host bug this package closes.
        with open(PKG_FILE, encoding="utf-8") as f:
            body = f.read()
        assert "graphics.declare_vulkan_layer(" in body
        assert '["XDG_DATA_DIRS"] = true' in body


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
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(PKG, timeout=600)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_manifest_names_the_payload_library(self):
        # After install() the manifest must point at the library by absolute
        # payload path: the file it names exists, and it is not a relative
        # path that config()'s copy into the subos would leave dangling.
        root = os.path.join(xpkgs_dir(), "xim-x-" + PKG, VERSION)
        manifest = os.path.join(root, MANIFEST)
        assert os.path.isfile(manifest), manifest
        with open(manifest, encoding="utf-8") as f:
            lib = json.load(f)["layer"]["library_path"]
        assert os.path.isabs(lib), lib
        assert lib == os.path.join(root, "lib", LAYER_SO), lib
        assert os.path.isfile(lib), lib
