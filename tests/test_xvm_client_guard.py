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


@pytest.fixture
def native_registry(tmp_path, monkeypatch):
    monkeypatch.setenv('XLINGS_HOME', str(tmp_path))
    monkeypatch.setenv('XLINGS_TEST_SUBOS', 'default')
    monkeypatch.setattr(xvm_client, '_run', lambda *a, **k: pytest.fail('native assertions must not use legacy xvm'))
    path = tmp_path / 'subos/default/.xlings.json'
    path.parent.mkdir(parents=True)
    return path


@pytest.mark.static
def test_native_subos_registration_reads_the_real_workspace_file(native_registry):
    import json
    native_registry.write_text(json.dumps({'workspace': {'go': {
        'active': 'local:1.27.3', 'installed': ['local:1.27.0', 'local:1.27.3']}}}))
    assert XvmClient.info('go') == {'program': 'go', 'version': 'local:1.27.3'}
    assert XvmClient.is_registered('go')
    assert not XvmClient.is_registered('absent')


@pytest.mark.static
@pytest.mark.parametrize('content', [
    'not JSON',
    '{"workspace": ["go"]}',
    '{"workspace": {"go": {"active": "local:1.27.3", "installed": []}}}',
    '{"workspace": {"go": "local:1.27.3"}}',
])
def test_broken_native_registry_is_not_reported_as_unregistered(native_registry, content):
    native_registry.write_text(content)
    with pytest.raises(RuntimeError, match='cannot read native registration'):
        XvmClient.info('go')


@pytest.mark.static
def test_missing_native_registry_fails_instead_of_querying_another_home(native_registry):
    with pytest.raises(RuntimeError, match='cannot read native registration'):
        XvmClient.info('go')
