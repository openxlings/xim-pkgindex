"""xvm CLI 缺失不得被折叠成「未注册」— silent-success 同族守卫

closure-lifecycle 首跑的实测教训: quick_install 的新 home 没有独立的 xvm
CLI (它是 xim 包, 不是 xlings 自带), `xvm info java` 得到 bash 的
command not found (exit 127), 旧的 info() 把它当普通失败返回 None,
is_registered 进而报「xvm 未注册: java」—— 在 shim 生效、载荷正确的 home
上给出一个业务层面的否定。查询工具缺失必须 raise, 不是返回否。
"""
import pytest

import tests.lib.xvm_client as xvm_client
from tests.lib.xvm_client import XvmClient


@pytest.mark.static
def test_missing_xvm_cli_raises_instead_of_reporting_unregistered(monkeypatch):
    monkeypatch.setattr(
        xvm_client, "_run",
        lambda cmd, timeout=10: (127, "bash: line 1: xvm: command not found"))
    with pytest.raises(RuntimeError, match="xlings install xvm"):
        XvmClient.info("java")


@pytest.mark.static
def test_normal_failure_still_reads_as_unregistered(monkeypatch):
    """非 127 的普通失败语义不变 — 40+ 个测试文件共用这个 helper"""
    monkeypatch.setattr(
        xvm_client, "_run", lambda cmd, timeout=10: (1, "target missing"))
    assert XvmClient.info("java") is None
    assert XvmClient.is_registered("java") is False


@pytest.mark.static
def test_registered_target_still_parses(monkeypatch):
    out = "Program: java\nVersion: 25.0.4-zulu\nSPath: /x/bin"
    monkeypatch.setattr(
        xvm_client, "_run", lambda cmd, timeout=10: (0, out))
    info = XvmClient.info("java")
    assert info == {"program": "java", "version": "25.0.4-zulu", "spath": "/x/bin"}
