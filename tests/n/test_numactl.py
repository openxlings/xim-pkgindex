"""Tests for numactl (libnuma) package."""
import glob
import json
import os
import re
import subprocess
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
)
from tests.lib.platform_utils import skip_if_not, xlings_home, xpkgs_dir, under_test

PKG = "numactl"
PKG_FILE = "pkgs/n/numactl.lua"


def _code(content: str) -> str:
    return "\n".join(
        line for line in content.splitlines() if not line.lstrip().startswith("--")
    )


@pytest.fixture(scope="module")
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
    def test_declares_glibc_and_build_deps(self, meta):
        code = _code(meta.raw_content)
        assert '"xim:glibc"' in code
        assert '"xim:gcc@16.2.0"' in code
        assert '"xim:make@4.3"' in code
        assert "selfcontain.seal" in code
        assert 'type = "group"' in code


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
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG), timeout=300)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_payload_and_xvm_nodes(self):
        hits = []
        for ns in ("xim", "local"):
            hits += sorted(glob.glob(os.path.join(xpkgs_dir(), f"{ns}-x-numactl", "*")))
        assert hits, f"no numactl payload under {xpkgs_dir()}"
        payload = hits[-1]
        assert os.path.exists(os.path.join(payload, "lib", "libnuma.so.1"))
        assert os.path.isfile(os.path.join(payload, "include", "numa.h"))
        pc = os.path.join(payload, "lib", "pkgconfig", "numa.pc")
        assert os.path.isfile(pc)
        assert f"prefix={payload}" in open(pc, encoding="utf-8").read()

        subos_name = os.environ.get("XLINGS_TEST_SUBOS", "current")
        ws_file = os.path.join(xlings_home(), "subos", subos_name, ".xlings.json")
        if not os.path.isfile(ws_file):
            ws_file = os.path.join(xlings_home(), "subos", "default", ".xlings.json")
        with open(ws_file, encoding="utf-8") as f:
            ws = json.load(f).get("workspace", {})
        for node in ("numactl", "libnuma.so.1"):
            assert node in ws and ws[node].get("active"), f"missing xvm node {node}"

        r = subprocess.run(
            ["readelf", "-d", os.path.realpath(os.path.join(payload, "lib", "libnuma.so.1"))],
            capture_output=True, text=True, check=True,
        )
        m = re.search(r"(?:RUNPATH|RPATH).*\[(.*)\]", r.stdout)
        assert m, f"libnuma.so.1 missing RUNPATH/RPATH: {r.stdout}"
        home = os.path.realpath(xlings_home())
        for entry in m.group(1).split(":"):
            if entry and entry != "$ORIGIN":
                assert entry.startswith(home + "/"), f"host leak in RUNPATH: {entry}"
