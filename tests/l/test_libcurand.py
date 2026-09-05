"""测试 libcurand 包"""
import re

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_valid_xvm_node_kinds,
)

PKG = "libcurand"
PKG_FILE = "pkgs/l/libcurand.lua"


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
        """版本号逐字取自 NVIDIA 的 redistrib manifest。

        这些组件不用日期版本也不用本仓库自己的编号:消费者拿到的
        `<pkg>@X.Y.Z` 必须就是 NVIDIA 发布的那一个,否则「对齐上游」
        这条规则在这里就断了。判据落在版本键的形状上 —— 日期版本
        (2026.09.05)与上游版本(13.3.33)第一段位数不同。
        """
        vers = [v for v in re.findall(r'\["(\d[^"]*)"\]\s*=', meta.raw_content)]
        assert vers, "no numeric version keys declared"
        for v in vers:
            head = v.split(".")[0]
            assert head.isdigit() and len(head) <= 2, (
                f"{v} does not look like an upstream CUDA version"
            )


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
