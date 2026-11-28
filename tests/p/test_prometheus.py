"""Prometheus and promtool: isolated installation, rule evaluation, and HTTP queries."""
import json
import os
from pathlib import Path
import socket
import subprocess
import time
import urllib.error
import urllib.request

import pytest

from tests.lib.assertions import (
    assert_install_succeeds,
    assert_no_bashrc_modification,
    assert_no_direct_path_modification,
    assert_no_direct_pkg_manager,
    assert_no_exec_xvm,
    assert_no_typos,
    assert_required_fields,
    assert_uses_new_api,
    assert_valid_spec,
    assert_valid_type,
    assert_valid_xvm_node_kinds,
    assert_xim_add_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

PKG = "prometheus"
PKG_FILE = "pkgs/p/prometheus.lua"


def _program(name):
    subos = Path(xlings_home()) / "subos"
    selected = os.environ.get("XLINGS_TEST_SUBOS", "current")
    bindir = subos / selected / "bin"
    if selected == "current" and not bindir.is_dir():
        bindir = subos / "default" / "bin"
    executable = bindir / (name + (".exe" if os.name == "nt" else ""))
    assert executable.is_file(), f"Missing installed shim: {executable}"
    return str(executable)


def _run(name, *args):
    return subprocess.run(
        [_program(name), *args],
        text=True,
        encoding="utf-8",
        capture_output=True,
        timeout=20,
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
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestIsolation:
    @pytest.mark.isolation
    @pytest.mark.parametrize("assertion", [
        assert_no_exec_xvm,
        assert_no_bashrc_modification,
        assert_no_direct_path_modification,
        assert_uses_new_api,
        assert_no_direct_pkg_manager,
    ])
    def test_isolation(self, assertion):
        assertion(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        assert_install_succeeds(under_test(PKG))


class TestVerify:
    @pytest.mark.verify
    @pytest.mark.parametrize("name", ["prometheus", "promtool"])
    def test_version(self, name):
        result = _run(name, "--version")
        assert result.returncode == 0, result.stdout + result.stderr
        expected = os.environ.get("XLINGS_TEST_VERSION", "3.16.0")
        assert f"{name}, version {expected}" in result.stdout + result.stderr

    @pytest.mark.verify
    @pytest.mark.parametrize("name", ["prometheus", "promtool"])
    def test_xvm_registered(self, name):
        assert_xvm_registered(name)

    @pytest.mark.verify
    def test_config_validation(self, tmp_path):
        config = tmp_path / "prometheus.yml"
        config.write_text("global:\n  scrape_interval: 15s\nscrape_configs: []\n", encoding="utf-8")
        result = _run("promtool", "check", "config", str(config))
        assert result.returncode == 0, result.stdout + result.stderr
        config.write_text("global:\n  scrape_interval: not-a-duration\n", encoding="utf-8")
        result = _run("promtool", "check", "config", str(config))
        assert result.returncode != 0, "promtool accepted an invalid scrape interval"

    @pytest.mark.verify
    def test_rule_evaluation(self, tmp_path):
        rules = tmp_path / "rules.yml"
        rules.write_text(
            "groups:\n- name: xpkg\n  rules:\n"
            "  - record: xpkg_double\n    expr: xpkg_input * 2\n",
            encoding="utf-8",
        )
        spec = tmp_path / "rule-tests.yml"
        spec.write_text(
            "rule_files:\n- rules.yml\nevaluation_interval: 1m\ntests:\n"
            "- interval: 1m\n  input_series:\n"
            "  - series: xpkg_input\n    values: '3 4 5'\n"
            "  promql_expr_test:\n  - expr: xpkg_double\n    eval_time: 2m\n"
            "    exp_samples:\n    - labels: '{__name__=\"xpkg_double\"}'\n      value: 10\n",
            encoding="utf-8",
        )
        result = _run("promtool", "test", "rules", str(spec))
        assert result.returncode == 0, result.stdout + result.stderr

    @pytest.mark.verify
    def test_server_query(self, tmp_path):
        config = tmp_path / "prometheus.yml"
        config.write_text("scrape_configs: []\n", encoding="utf-8")
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        url = f"http://127.0.0.1:{port}/api/v1/query?query=1%2B1"
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with (tmp_path / "server.log").open("w+", encoding="utf-8") as log:
            process = subprocess.Popen(
                [_program("prometheus"), f"--config.file={config}",
                 f"--storage.tsdb.path={tmp_path / 'data'}",
                 f"--web.listen-address=127.0.0.1:{port}"],
                stdout=log,
                stderr=subprocess.STDOUT,
            )
            try:
                deadline = time.monotonic() + 15
                while True:
                    if process.poll() is not None:
                        log.seek(0)
                        pytest.fail(f"Prometheus exited before serving queries:\n{log.read()}")
                    try:
                        with opener.open(url, timeout=1) as response:
                            result = json.load(response)
                        break
                    except urllib.error.URLError:
                        if time.monotonic() >= deadline:
                            log.seek(0)
                            pytest.fail(f"Prometheus did not become ready:\n{log.read()}")
                        time.sleep(0.1)
                assert result["status"] == "success", result
                assert result["data"]["resultType"] == "scalar", result
                assert result["data"]["result"][1] == "2", result
            finally:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
