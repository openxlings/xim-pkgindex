"""测试 qemu-user-aarch64 包"""
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output,
)
from tests.lib.platform_utils import skip_if_not

PKG = "qemu-user-aarch64"
PKG_FILE = "pkgs/q/qemu-user-aarch64.lua"


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope='module')
def source_text():
    from tests.lib.platform_utils import project_root
    import os
    with open(os.path.join(project_root(), PKG_FILE), encoding="utf-8") as handle:
        return handle.read()


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


class TestPinnedFacts:
    """The two things a rename upstream would break silently.

    Both are pinned because the failure mode is a 404 at install time on a
    machine nobody in CI is holding -- which is how the sibling qemu recipes
    justify the same shape.
    """

    @pytest.mark.static
    def test_asset_is_the_host_prefixed_one(self, source_text):
        # `x86_64_qemu-aarch64-static.tar.gz`, not the bare name. Upstream
        # publishes both; the prefixed one says which HOST it is for, and this
        # package is x86_64-only on purpose.
        assert "x86_64_qemu-aarch64-static.tar.gz" in source_text
        assert "/qemu-aarch64-static.tar.gz" not in source_text, \
            "the bare asset name does not say which host it is built for"

    @pytest.mark.static
    def test_version_key_is_dotted_digits(self, source_text):
        # Upstream tags `v7.2.0-1`. The version KEY drops the packaging suffix
        # because this index answers ranges with select_best -- the maximum
        # satisfying version -- and an alpha segment sorts BELOW the plain one,
        # so `7.2.0-1` would be a pre-release of `7.2.0` to every range
        # expression (measured on glibc, see that recipe).
        import re
        head = source_text.split('\nimport(', 1)[0]
        head = '\n'.join(l for l in head.splitlines()
                         if not l.lstrip().startswith('--'))
        keys = [k for k in re.findall(r'\["([^"]+)"\]\s*=', head)
                if k != 'latest']
        assert keys, "no version keys found"
        for k in keys:
            assert re.fullmatch(r'\d+(\.\d+)*', k), \
                f"{k} is not dotted digits; a range would sort it below the release"

    @pytest.mark.static
    def test_x86_64_only(self, meta):
        # Not a gap. User-mode emulation exists to run a FOREIGN binary on
        # this host; on an aarch64 host an aarch64 binary just runs.
        assert meta.raw_content.count('archs = {"x86_64"}') == 1


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(PKG)

    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_it_actually_emulates(self):
        # `--version` and not just "the file exists": a user-mode emulator
        # that unpacks and cannot run is the failure this package removes, and
        # the payload is static so there is nothing to blame but the binary.
        assert_command_output("qemu-aarch64-static --version", "qemu-aarch64")
