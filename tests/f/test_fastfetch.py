from pathlib import Path

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_config_registers_package_name,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_direct_pkg_manager,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_platform_supported,
)

XPKG_PATH = Path(__file__).resolve().parents[2] / "pkgs" / "f" / "fastfetch.lua"


def test_fastfetch_static_checks():
    pkg = parse_xpkg(XPKG_PATH)
    assert pkg.name == "fastfetch"
    assert pkg.spec == "2"
    for plat in ("linux", "macosx", "windows"):
        assert_platform_supported(pkg, plat)
    assert_config_registers_package_name(pkg)
    assert_no_bashrc_modification(XPKG_PATH)
    assert_no_direct_path_modification(XPKG_PATH)
    assert_no_direct_pkg_manager(XPKG_PATH)
    assert_no_exec_xvm(XPKG_PATH)
    assert_no_typos(XPKG_PATH)
