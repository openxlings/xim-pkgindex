"""测试 glibc 包"""
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

PKG = "glibc"
PKG_FILE = "pkgs/g/glibc.lua"


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


class TestRevisionOrdering:
    """`latest` is not the only way a recipe reaches this package.

    33 recipes depend on it as a bare `xim:glibc` and follow the `latest`
    ref; 35 more ask for a RANGE (`xim:glibc@>=2.38`, `>=2.39`). A range is
    answered by `select_version_` -> `semver::select_best`, which returns the
    maximum satisfying version and never looks at `latest`. So a revision
    that sorts below the artifact it supersedes is not untidy -- it leaves
    every one of those 35 resolving straight back to the copy being replaced,
    silently and with no error anywhere.

    That is not hypothetical: `2.44r1` was the first choice here and has
    exactly this defect, because xlings' semver reads a missing segment as
    numeric 0 and lets it beat an alpha segment (`compare("6.5","6.5rc1")>0`
    in its own pinned corpus), making `2.44r1` a PRE-release of 2.44.

    The property below is what makes the ranges safe to leave alone.
    """

    @staticmethod
    def _versions(meta):
        """The version keys and the `latest` ref, read out of the recipe text.

        XpkgMeta does not carry the version table, and a Lua evaluator is not
        worth pulling in for two regexes over a table this file owns.
        """
        import re
        # Scoped to the `package = {...}` literal, which ends at the first
        # `import(`. Searching the whole file for `["x"] =` also finds the
        # env-var tables in config(), and a criterion that matches
        # LD_LIBRARY_PATH is not reading the version table.
        head = meta.raw_content.split('\nimport(', 1)[0]
        # Lua comments stripped first. A version that is only MENTIONED -- in
        # a "restore this when X ships" note, say -- is not in the table, and
        # a criterion that cannot tell those apart is reading prose. This bit
        # already: a commented-out restore snippet made the check report a
        # `latest` that pointed below an entry that was not there.
        head = '\n'.join(l for l in head.splitlines()
                          if not l.lstrip().startswith('--'))
        keys = re.findall(r'\["([^"]+)"\]\s*=', head)
        ref = re.search(r'\["latest"\]\s*=\s*\{\s*ref\s*=\s*"([^"]+)"', head)
        return [k for k in keys if k != 'latest'], (ref.group(1) if ref else None)

    @pytest.mark.meta
    def test_latest_ref_sorts_at_or_above_every_other_version(self, meta):
        versions, latest = self._versions(meta)
        assert latest, "no `latest` ref found"
        assert latest in versions, f"latest -> {latest} is not a published key"

        def key(v):
            # xlings semver, restricted to what this file uses: digits and
            # dots, missing segment = 0.
            return [int(p) for p in v.split('.')]

        others = [v for v in versions if v != latest]
        assert others, "nothing to compare against"
        for v in others:
            assert key(latest) > key(v), (
                f"latest -> {latest} does not sort above {v}; a ranged "
                f"dependency (>=2.38, >=2.39) would resolve to {v} instead"
            )

    @pytest.mark.meta
    def test_every_published_version_is_pure_dotted_digits(self, meta):
        # The moment a version carries a letter, the sort rule above stops
        # being the simple one and `select_best` can disagree with `latest`.
        import re
        versions, _ = self._versions(meta)
        for v in versions:
            assert re.fullmatch(r'\d+(\.\d+)*', v), \
                f"{v} is not dotted digits; see TestRevisionOrdering"
