"""测试 mcpp-short-cmd 短命令包"""
import re

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_shim_exists,
)
from tests.lib.platform_utils import skip_if_not

PKG = "mcpp-short-cmd"
INSTALL_PKG = "local:mcpp-short-cmd@0.0.1"
PKG_FILE = "pkgs/m/mcpp-short-cmd.lua"

# The contract this package exists for: short name -> the mcpp command line it
# expands to. Rule: one letter per word except the last, which stays whole
# (`mcpp self doctor` -> `msdoctor`); `mp` is the bare `mcpp` entry point.
EXPECTED_ALIASES = {
    "mp": "mcpp",
    "mnew": "mcpp new",
    "mbuild": "mcpp build",
    "mrun": "mcpp run",
    "mtest": "mcpp test",
    "mclean": "mcpp clean",
    "madd": "mcpp add",
    "mremove": "mcpp remove",
    "mupdate": "mcpp update",
    "msearch": "mcpp search",
    "mpublish": "mcpp publish",
    "mpack": "mcpp pack",
    "mexpkg": "mcpp emit xpkg",
    "mxparse": "mcpp xpkg parse",
    "mtinstall": "mcpp toolchain install",
    "mtlist": "mcpp toolchain list",
    "mtdefault": "mcpp toolchain default",
    "mcdir": "mcpp cache dir",
    "mclist": "mcpp cache list",
    "mcinfo": "mcpp cache info",
    "mcgc": "mcpp cache gc",
    "milist": "mcpp index list",
    "miadd": "mcpp index add",
    "miremove": "mcpp index remove",
    "miupdate": "mcpp index update",
    "msdoctor": "mcpp self doctor",
    "msenv": "mcpp self env",
    "msconfig": "mcpp self config",
    "msversion": "mcpp self version",
    "msexplain": "mcpp self explain",
}


def _short_cmd_table(content: str) -> dict:
    """解析 SHORT_CMDS 表 -> {short: 完整 mcpp 命令行}"""
    block = re.search(r"local SHORT_CMDS = \{(.*?)\n\}", content, re.DOTALL)
    assert block, "missing SHORT_CMDS table"
    pairs = re.findall(r'\{\s*"([^"]+)",\s*"([^"]*)"\s*\}', block.group(1))
    return {short: ("mcpp " + sub).strip() for short, sub in pairs}


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
    def test_alias_mapping_is_complete(self, meta):
        assert _short_cmd_table(meta.raw_content) == EXPECTED_ALIASES

    @pytest.mark.static
    def test_short_names_are_unique(self, meta):
        block = re.search(r"local SHORT_CMDS = \{(.*?)\n\}", meta.raw_content, re.DOTALL)
        shorts = re.findall(r'\{\s*"([^"]+)",\s*"[^"]*"\s*\}', block.group(1))
        assert len(shorts) == len(set(shorts)), "duplicate short command name"

    @pytest.mark.static
    def test_programs_match_alias_table(self, meta):
        assert set(meta.programs) == set(EXPECTED_ALIASES)

    @pytest.mark.static
    def test_is_payload_free(self, meta):
        # Nothing is downloaded: no url / sha256 anywhere, and every version
        # entry is an empty table.
        assert not re.search(r'\burl\s*=', meta.raw_content)
        assert "sha256" not in meta.raw_content
        assert '["0.0.1"] = {}' in meta.raw_content

    @pytest.mark.static
    def test_depends_on_mcpp_on_every_platform(self, meta):
        for platform in ("linux", "macosx", "windows"):
            block = re.search(
                platform + r"\s*=\s*\{(.*?)\n        \}", meta.raw_content, re.DOTALL)
            assert block, f"missing {platform} xpm block"
            assert re.search(r'["\']xim:mcpp["\']', block.group(1)), \
                f"{platform} missing dependency: xim:mcpp"

    @pytest.mark.static
    def test_aliases_target_the_mcpp_shim(self, meta):
        # Aliases must go through the `mcpp` shim rather than a resolved binary
        # path, so `xlings use mcpp <ver>` keeps switching what they drive.
        assert '("mcpp " .. sub)' in meta.raw_content
        assert re.search(r'xvm\.add\(short,\s*\{\s*alias\s*=\s*alias', meta.raw_content)
        assert "pkginfo.install_dir()" not in meta.raw_content

    @pytest.mark.static
    def test_registers_package_name_as_group(self, meta):
        # `group` is the package-name placeholder: it keeps `xlings remove`
        # working without creating a bogus `mcpp-short-cmd` shim.
        assert re.search(
            r'xvm\.add\(package\.name,\s*\{\s*type\s*=\s*"group"\s*\}\)',
            meta.raw_content)

    @pytest.mark.static
    def test_uninstall_removes_every_alias(self, meta):
        hook = re.search(r"function uninstall\(\)(.*?)\nend", meta.raw_content, re.DOTALL)
        assert hook, "missing uninstall hook"
        body = hook.group(1)
        assert "ipairs(SHORT_CMDS)" in body
        assert "xvm.remove(entry[1])" in body
        assert "xvm.remove(package.name)" in body


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
        assert_install_succeeds(INSTALL_PKG, timeout=420)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_short_cmd_shims(self):
        for short in ("mp", "mbuild", "mrun", "mtest", "msversion"):
            assert_xvm_shim_exists(short)

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_mp_forwards_args(self):
        # `mp` is the bare mcpp entry point; args must reach the real binary.
        assert_command_output("mp --version", regex=r"mcpp \d")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_subcommand_alias_expands(self):
        # `msversion` -> `mcpp self version`
        assert_command_output("msversion", regex=r"mcpp \d")
