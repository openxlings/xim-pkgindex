"""nfpm"""
import os
import subprocess
import tempfile

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not, under_test

PKG = "nfpm"
PKG_FILE = "pkgs/n/nfpm.lua"

# One file installed below a private prefix, the shape a build plugin stages.
_CONFIG = """\
name: sample
arch: amd64
platform: linux
version: 0.1.0
maintainer: Example <dev@example.com>
description: Sample application
license: MIT
contents:
  - src: ./hello
    dst: /opt/sample/bin/hello
    file_info:
      mode: 0755
"""


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
        assert_install_succeeds(under_test(PKG))


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        assert_command_output("nfpm --version", contains="2.49.0")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("nfpm")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_writes_deb_and_rpm_reproducibly(self):
        # The work a build plugin asks of it: the same staged tree gives the same bytes twice.
        with tempfile.TemporaryDirectory() as work:
            with open(os.path.join(work, "hello"), "w", encoding="utf-8") as handle:
                handle.write("#!/bin/sh\necho hello\n")
            with open(os.path.join(work, "nfpm.yaml"), "w", encoding="utf-8") as handle:
                handle.write(_CONFIG)
            environment = dict(os.environ, SOURCE_DATE_EPOCH="1700000000")
            digests = []
            for run in ("first", "second"):
                target = os.path.join(work, run)
                os.mkdir(target)
                for packager in ("deb", "rpm"):
                    subprocess.run(["nfpm", "package", "-f", "nfpm.yaml", "-p", packager, "-t", target],
                                   cwd=work, env=environment, check=True, capture_output=True)
                digests.append({name: open(os.path.join(target, name), "rb").read() for name in os.listdir(target)})
            assert sorted(digests[0]) == ["sample-0.1.0-1.x86_64.rpm", "sample_0.1.0_amd64.deb"]
            assert digests[0] == digests[1]
