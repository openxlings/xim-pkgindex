"""测试 musl-gcc 包"""
import re
from pathlib import Path

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

PKG = "musl-gcc"
PKG_FILE = "pkgs/m/musl-gcc.lua"


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


def _keys(text: str, function: str) -> set[str]:
    """The names a `local function <function>(triple)` table maps."""
    body = text[text.index(f"local function {function}("):]
    body = body[:body.index("\nend\n")]
    return set(re.findall(r'\["([^"]+)"\]\s*=', body))


class TestFlavorGroup:
    """`xlings use gcc <ver>-musl` switches gcc.lua's whole group of names:
    a name left at the glibc release mixes two compilers (gcc-ar loads its
    own gcc's LTO plugin) and `self doctor` reports the group incoherent
    (openxlings/xlings#740 §2)."""

    @pytest.mark.static
    def test_the_flavor_publishes_every_name_of_the_gcc_group(self):
        repo = Path(__file__).resolve().parents[2]
        musl = (repo / PKG_FILE).read_text(encoding="utf-8")
        gcc = (repo / "pkgs/g/gcc.lua").read_text(encoding="utf-8")
        published = _keys(musl, "__gcc_flavor_progs") | _keys(musl, "__gcc_flavor_tools")
        common = gcc[gcc.index("local linux_programs_common = {"):]
        common = set(re.findall(r'"([^"]+)"', common[:common.index("}")]))
        assert common | {"cc"} <= published, sorted(common | {"cc"} - published)


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
    def test_musl_gcc(self):
        assert_command_output("musl-gcc --version 2>&1 | head -1", contains="GCC")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_musl_gcc(self):
        assert_xvm_registered("musl-gcc")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_flavor_tools(self):
        for name in ("gcc-ar", "gcc-nm", "gcc-ranlib", "gcov"):
            assert_xvm_registered(name)

