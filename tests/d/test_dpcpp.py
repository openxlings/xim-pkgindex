"""测试 dpcpp 包"""
import re

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_valid_xvm_node_kinds,
)

PKG = "dpcpp"
PKG_FILE = "pkgs/d/dpcpp.lua"


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
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_version_is_upstream(self, meta):
        """版本号逐字取自上游 release tag。

        版本号取自上游 tag,不用日期版本也不用本仓库自己的编号。
        """
        vers = [v for v in re.findall(r'\["(\d[^"]*)"\]\s*=', meta.raw_content)]
        assert vers, "no numeric version keys declared"
        # 上游 tag 是 `v7.1.0`,包里写 `7.1.0`。自建的 Windows 版本也用这个号,
        # 因为它就是那份源码 —— 版本说的是「你拿到的是哪一版上游」。
        assert "7.1.0" in vers


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
