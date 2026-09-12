"""Tests for the cubism-sdk-web package."""
import re

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_valid_xvm_node_kinds,
)

PKG = "cubism-sdk-web"
PKG_FILE = "pkgs/c/cubism-sdk-web.lua"


def _code(content: str) -> str:
    """Strip lua line comments so static assertions see only real declarations."""
    return "\n".join(
        line for line in content.splitlines() if not line.lstrip().startswith("--")
    )


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
    def test_no_ci_block(self, meta):
        """`ci = {}` -- no `mirror`, no `update`. The Proprietary licence
        over `Core/` grants no redistribution, so nothing here may republish
        the archive, and a version bump needs its hash and licence set
        re-measured rather than mechanically advanced."""
        code = _code(meta.raw_content)
        assert re.search(r'ci\s*=\s*\{\s*\}', code), "ci must be an empty table"
        assert "mirror" not in code
        assert "update" not in code

    @pytest.mark.static
    def test_no_cn_mirror_entry(self, meta):
        """One region only -- the upstream URL, no `CN` entry and no
        `gitcode.com` re-hosting. See the header: republishing the archive
        would republish Live2D's proprietary Core binary."""
        code = _code(meta.raw_content)
        assert "gitcode.com" not in code
        assert re.search(r'\bCN\s*=', code) is None

    @pytest.mark.static
    def test_upstream_url_and_sha256_are_pinned(self, meta):
        code = _code(meta.raw_content)
        assert "https://cubism.live2d.com/sdk-web/bin/CubismSdkForWeb-5-r.5.zip" in code
        assert "67064a7fb1812cf502f5c4a03bfe12cc638c75a621bb4acf06bb28763df06ba0" in code

    @pytest.mark.static
    def test_sha256_matches_lib_live2d_pin(self, meta):
        """Corroborating evidence only -- see the header comment: this
        recipe's pin comes from this recipe's own anonymous download, and
        happens to equal Lib-Live2D's `tools/fetch_cubism.py` pin."""
        code = _code(meta.raw_content)
        measured = re.search(r'sha256\s*=\s*"([0-9a-f]{64})"', code)
        assert measured, "no sha256 pinned"
        assert measured.group(1) == \
            "67064a7fb1812cf502f5c4a03bfe12cc638c75a621bb4acf06bb28763df06ba0"

    @pytest.mark.static
    def test_licenses_are_the_three_titles_read_from_the_archive(self, meta):
        """A wrong member is worse than none: each entry is the licence's
        own title, as printed in the file that states it, not a
        paraphrase or a generic 'Proprietary'."""
        code = _code(meta.raw_content)
        for title in (
            "Live2D Proprietary Software License",
            "Live2D Open Software License",
            "Free Material License",
        ):
            assert title in code, f"missing licence title: {title}"
        # And not a placeholder in their stead.
        assert '"Proprietary"' not in code

    @pytest.mark.static
    def test_install_verifies_all_licensed_trees(self, meta):
        """install() must check a file under each of Core/, Framework/, and
        the Core licence text -- one check per licence this package
        declares, not merely 'the directory exists'."""
        code = _code(meta.raw_content)
        install_body = code[code.index("function install()"):code.index("function config()")]
        assert "Core/live2dcubismcore.js" in install_body
        assert "Core/live2dcubismcore.d.ts" in install_body
        assert "Framework/src/live2dcubismframework.ts" in install_body
        assert "Core/LICENSE.md" in install_body
        assert install_body.count("os.isfile") >= 4, \
            "the post-move checks must test files, one per licensed tree"

    @pytest.mark.static
    def test_bare_registration_no_bindir(self, meta):
        """This package ships no program: `xvm.add` must be called with no
        second (bindir) argument, and nothing here may add to PATH."""
        code = _code(meta.raw_content)
        config_body = code[code.index("function config()"):code.index("function uninstall()")]
        assert re.search(r'xvm\.add\s*\(\s*"cubism-sdk-web"\s*\)', config_body), \
            "xvm.add must be called with only the package name"


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
