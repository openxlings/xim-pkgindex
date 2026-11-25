"""测试 clice 包"""
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

PKG = "clice"
PKG_FILE = "pkgs/c/clice.lua"


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
    def test_v100_covers_all_six_assets(self, meta):
        # v1.0.0 上游六个平台/架构资产的实测摘要必须全部出现在配方里:
        # linux(x86_64/aarch64) macosx(x86_64/aarch64) windows(x86_64/aarch64)
        expected = [
            "9dd181aac9c81cae76b255e953da21c9e603fc5b406447eb26c95eaf67ed969a",
            "b7eb6ce65afb9cdc5229dadf1b1a561485dcdb292a06d68857cd6097716f08ba",
            "28a941dad640cf24b6d7d76477ee178353e67a8490ec7b87bfe5b612e999ece2",
            "941acd6ec4c746444a54006452209cd0ef98f5a34eee5089520016c40a41f82c",
            "4c236c9aa107f52ecfe958a141690364bb225feb23c9b9d967cfa1911b47dedb",
            "0893adddb2969916a8a9bfdcb1957eda1687d2d989f6241d99dd74e29394d9e5",
        ]
        for h in expected:
            assert h in meta.raw_content, f"missing measured sha256 {h}"


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


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_clice(self):
        assert_command_output("clice --version", contains="clice version")
