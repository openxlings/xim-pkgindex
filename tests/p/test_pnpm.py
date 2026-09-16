"""测试 pnpm 包"""
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

PKG = "pnpm"
PKG_FILE = "pkgs/p/pnpm.lua"


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope='module')
def code(meta):
    """The recipe without its comments, so a test never matches prose."""
    return "\n".join(l for l in meta.raw_content.splitlines()
                      if not l.lstrip().startswith("--"))


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


class TestResources:
    """The version matrix: what is mirrored, and the two asset shapes 7.x and 8+
    publish. Byte-identity of every CN copy below was checked by download on
    2026-09-16; the sha256 in the recipe is what re-checks it at install time."""

    @pytest.mark.static
    def test_mirrored_versions_carry_both_urls(self, code):
        """12.1.0, 11.12.0 and 7.33.7 are on xlings-res/pnpm, once per platform.

        7.33.7's copies were published 2026-09-16 and its three assets carry a
        `.sha256` sidecar each, the shape the other two already had. A version
        someone reaches for because a lockfile pins it is exactly the one that
        needs a mirror."""
        import re
        cn = re.findall(r'CN = "([^"]+)"', code)
        assert len(cn) == 9, cn
        for version in ("12.1.0", "11.12.0"):
            for asset in ("pnpm-linux-x64.tar.gz", "pnpm-darwin-arm64.tar.gz", "pnpm-win32-x64.zip"):
                url = f"https://gitcode.com/xlings-res/pnpm/releases/download/{version}/{asset}"
                assert url in cn, url
        for asset in ("pnpm-linuxstatic-x64", "pnpm-macos-arm64", "pnpm-win-x64.exe"):
            url = f"https://gitcode.com/xlings-res/pnpm/releases/download/7.33.7/{asset}"
            assert url in cn, url

    @pytest.mark.static
    def test_unmirrored_versions_say_so_by_having_one_url(self, code):
        """12.0.0 and 11.0.5 are not on the mirror (checked), so they carry
        GLOBAL alone rather than a CN URL that would 404."""
        import re
        for version in ("12.0.0", "11.0.5"):
            block = re.search(r'\["' + re.escape(version) + r'"\] = \{(.*?)\n            \},', code, re.S)
            assert block, version
            assert "CN =" not in block.group(1), f"{version} claims a mirror it is not on"

    @pytest.mark.static
    def test_the_mirrored_seven_assets_are_the_ones_the_recipe_downloads(self, code):
        """A CN URL naming a different asset than GLOBAL would pass every static
        check and then fail the sha256 at install time, in China only."""
        import re
        for block in re.findall(r'url = \{(.*?)\},', code, re.S):
            g = re.search(r'GLOBAL = "([^"]+)"', block)
            c = re.search(r'CN = "([^"]+)"', block)
            assert g and c, block
            assert g.group(1).rsplit("/", 1)[1] == c.group(1).rsplit("/", 1)[1], block

    @pytest.mark.static
    def test_seven_is_a_bare_executable_on_every_platform(self, code):
        """7.x publishes one self-contained executable per platform, not the
        archive-plus-dist/ that 8+ ships. install() has to handle both."""
        for asset in ("v7.33.7/pnpm-linuxstatic-x64", "v7.33.7/pnpm-macos-arm64",
                      "v7.33.7/pnpm-win-x64.exe"):
            assert asset in code, asset

    @pytest.mark.static
    def test_seven_on_linux_takes_the_static_asset(self, code):
        """Upstream publishes both for this release and they are not equivalent:

            pnpm-linux-x64        dynamic, INTERP -> whatever glibc the host has
            pnpm-linuxstatic-x64  statically linked, no INTERP, no .dynamic

        The dynamic one cannot be closed over this index's glibc, because
        reaching it means letting elfpatch rewrite a `pkg` single-file
        executable and that loses the payload appended after the ELF image.
        The static one needs nothing from the machine at all, so it is the one
        that makes `xlings install pnpm@7.33.7` self-contained."""
        assert "pnpm-linuxstatic-x64" in code
        assert "v7.33.7/pnpm-linux-x64" not in code, \
            "the dynamic asset would depend on the host loader"

    @pytest.mark.static
    def test_install_handles_both_asset_shapes(self, code):
        install = code[code.index("function install()"):code.index("function config()")]
        assert 'os.isdir("dist")' in install, "the 8+ archive's dist/ must still move"
        assert "pnpm-linux-x64" in install and "pnpm-macos-arm64" in install, \
            "the 7.x bare executable must be recognised by its asset name"
        assert "chmod +x" in install, "a downloaded executable arrives without the bit"

    @pytest.mark.static
    def test_nothing_opts_out_of_elfpatch(self, code):
        """An opt-out would be the wrong shape of fix here.

        `elfpatch.skip()` on the dynamic asset does keep the binary whole, but
        it keeps it whole by leaving it bound to the host's glibc -- the one
        thing a package in this index exists to avoid. The static asset removes
        the question: patchelf refuses a file with no `.dynamic` section
        ("cannot find section '.dynamic'") and leaves it byte-identical, so
        there is nothing to opt out of. Verified 2026-09-16, both directions.

        8+ is an ordinary node build that is supposed to be patched."""
        body = "\n".join(line for line in code.splitlines()
                          if not line.lstrip().startswith("--"))
        assert "elfpatch" not in body, \
            "the comments may explain elfpatch; the code must not call it"

    @pytest.mark.static
    def test_the_bare_executable_is_actually_run_after_elfpatch(self, code):
        """config() is the first hook after elfpatch, and for this shape nothing
        short of running the binary can see the damage -- every existence check
        passes on a broken one (contributing.md 5.1)."""
        config = code[code.index("function config()"):code.index("function uninstall()")]
        assert "--version" in config and "os.iorun" in config
        assert 'os.isdir(path.join(dir, "dist"))' in config, \
            "the run is scoped to the payload with no dist/, i.e. the 7.x one"
        assert "pkginfo.version()" in config, "the reported version must be compared, not just printed"


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
    def test_pnpm(self):
        assert_command_output("pnpm --version")

