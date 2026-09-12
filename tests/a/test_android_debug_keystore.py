"""Tests for the android-debug-keystore package.

A one-file data payload: the properties worth locking are that it is
generated exactly once (never regenerated for a routine version bump), that
its sha256 is present and well-formed, and that no `ci` automation exists
that would either mirror itself or move `latest` to a version nothing built.
"""
import re

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds,
)
from tests.lib.platform_utils import skip_if_not

PKG = "android-debug-keystore"
PKG_FILE = "pkgs/a/android-debug-keystore.lua"

# The exact convention this recipe's own header states it reproduces.
EXPECTED_ALIAS = "androiddebugkey"
EXPECTED_STOREPASS = "android"
EXPECTED_DNAME = "CN=Android Debug,O=Android,C=US"


def _code(content: str) -> str:
    return "\n".join(
        line for line in content.splitlines() if not line.lstrip().startswith("--")
    )


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope='module')
def code(meta):
    return _code(meta.raw_content)


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
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)

    @pytest.mark.static
    def test_no_bashrc(self):
        assert_no_bashrc_modification(PKG_FILE)

    @pytest.mark.static
    def test_no_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.static
    def test_new_api(self):
        assert_uses_new_api(PKG_FILE)

    @pytest.mark.static
    def test_documents_the_exact_keytool_command(self, meta):
        """The generation command must be reproduced verbatim in the header
        so a future re-generation (should one ever be needed) uses the same
        alias/password/dname convention -- this is the one thing the header
        says must never silently drift."""
        rc = meta.raw_content
        assert EXPECTED_ALIAS in rc
        assert EXPECTED_DNAME in rc
        assert "-genkeypair" in rc
        assert "-validity 10000" in rc
        assert "-keyalg RSA" in rc
        assert "-keysize 2048" in rc

    @pytest.mark.static
    def test_sha256_present_and_well_formed(self, meta):
        hashes = re.findall(r'sha256\s*=\s*"([0-9a-f]{64})"', meta.raw_content)
        assert len(hashes) == 3, "one sha256 per host (linux, macosx, windows)"
        assert len(set(hashes)) == 1, \
            "a keystore's bytes carry no host information -- all three must match"

    @pytest.mark.static
    def test_no_ci_automation(self, code):
        """Regenerating draws a fresh RSA keypair every time (keytool's own
        behaviour) -- `ci.update` moving `latest` to an unbuilt version, or
        `ci.mirror` mirroring xlings-res to itself, would both be wrong for
        a self-built artifact, the same reasoning picolibc-riscv.lua states
        for its own case."""
        assert "ci = {" not in code

    @pytest.mark.static
    def test_source_is_a_regional_map_not_the_xlings_res_magic_string(self, code):
        """The bare `"xlings-res"` string's auto-URL template includes
        os/arch tokens that do not fit a single host-independent file;  an
        explicit source map with no such tokens is used instead (the same
        shape picolibc-riscv.lua uses for its own host-independent
        artifact)."""
        assert re.search(r'source\s*=\s*\{', code)
        assert "github.com/xlings-res/android-debug-keystore" in code
        assert "gitcode.com/xlings-res/android-debug-keystore" in code

    @pytest.mark.static
    def test_install_moves_the_raw_download_no_extraction(self, code):
        assert "install_file()" in code
        assert "debug.keystore" in code

    @pytest.mark.static
    def test_umbrella_registration_only(self, code):
        """A data payload with no bin/<name> to shim -- `type = "group"`,
        not a program registration that would produce a dangling shim."""
        assert re.search(r'xvm\.add\(package\.name,\s*\{\s*type\s*=\s*"group"', code)


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)
