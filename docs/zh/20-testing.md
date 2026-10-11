# 测试

[English](../20-testing.md) | **简体中文**

每个配方旁边都有一个 pytest 模块，仓库还有自己的检查。本章说明怎样运行它们、怎样添加
一个，以及 CI 运行什么。

## 层级

| 层级 | 标记 | 需要 | 检查 |
|---|---|---|---|
| L0 静态 | `static` | 无 | Lua 语法、必填字段、`spec` / `type` 取值、已知拼写错误 |
| L1 索引 | `index` | xlings | 配方能注册（`xlings config --add-xpkg`） |
| L2 隔离 | `isolation` | 无 | 不用 `os.exec("xvm ...")`、不改 shell 配置、不改 `PATH`、使用 `xim.libxpkg.*` API、不调用宿主包管理器 |
| L3 生命周期 | `lifecycle` | xlings、网络 | 安装与卸载成功 |
| L4 功能 | `verify` | 包已安装 | 它的程序能运行，并做到应做的事 |

## 运行

```bash
pip install pytest
pytest tests/ -m static                                  # seconds, no xlings
pytest tests/ -m "static or isolation"                   # what every pull request runs first
pytest tests/c/test_cmake.py -m "static or isolation" -v # one package
```

L1、L3、L4 会调用 xlings 并真正安装。只在隔离的 `XLINGS_HOME` 中运行它们，绝不针对你
自己的 home：

```bash
XLINGS_HOME="$(mktemp -d)" pytest tests/c/test_cmake.py -m "lifecycle or verify" -v
```

## 添加一个测试

测试模块与配方对应：`pkgs/n/my-package.lua` → `tests/n/test_my_package.py`（`-` 换成 `_`）。

```python
"""mypackage"""
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

PKG = "mypackage"
PKG_FILE = "pkgs/m/mypackage.lua"


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
        assert_install_succeeds(PKG)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version(self):
        assert_command_output("mypackage --version", contains="mypackage")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered("mypackage")
```

- 别名包（`ref`）断言 `meta.is_ref`，其余很少。
- 只适用于某个平台的测试标记 `@skip_if_not("windows")`。
- 已知问题标记 `@pytest.mark.xfail(reason=...)`，不阻塞 CI。
- 功能测试尽量做真实的事（编译器能编译、虚拟机能启动）；`--version` 看不出坏掉的库路径。

## 共用模块

| 模块 | 提供 |
|---|---|
| `tests/lib/xpkg_parser.py` | `parse_xpkg()` → `XpkgMeta`，不运行 Lua |
| `tests/lib/assertions.py` | 上面用到的所有断言 |
| `tests/lib/xvm_client.py` | `XvmClient.info()`、`.is_registered()`、`.shim_exists()` |
| `tests/lib/xlings_client.py` | `XlingsClient.install()`、`.remove()`、`.xim_add_xpkg()` |
| `tests/lib/platform_utils.py` | `current_platform()`、`skip_if_not()`、`xlings_home()` |

## 全仓库的检查

有些规则覆盖所有配方，各有自己的测试或脚本：

| 检查 | 位置 |
|---|---|
| 依赖坐标与分离的 `deps` 写法 | `tests/test_dep_query_coordinates.py`、`tests/test_deps_shape.py` |
| 库载荷中没有编译器运行时 | `tests/test_no_compiler_runtime_in_payloads.py` |
| 已发布的 Luban 版本输出不变 | `tests/test_luban_published.py` |
| 资源变化时提高 `revision` | `.github/scripts/check-revision.lua` |
| 载荷中没有硬链接 | `.github/scripts/check-payload-hard-links.py` |
| 依赖的命名空间在本索引中可解析 | `.github/scripts/check-dep-namespace.sh` |
| workflow 和脚本中不调用宿主包管理器 | `tools/lint_host_deps.sh` |
| 文档的结构与链接 | `tests/test_docs.py` |

## CI 运行什么

| Workflow | 何时 | 运行 |
|---|---|---|
| `ci-xpkg-test.yml` | `pkgs/`、`libs/`、`tests/` 有改动 | 对所有配方跑 L0 和 L2，然后 L1 |
| `ci-test.yml` | `pkgs/` 或 `libs/` 有改动 | 在 Linux、macOS、Windows 上安装改动涉及的包 |
| `ci-tools.yml` | `tools/`、`scripts/` 或 workflow 有改动 | 工具自己的测试与仓库 lint |
| `ci-sweep.yml` | 每周 | 按 ISO 周次安装所有配方中的一片 |
| `luban-agent-workspace.yml` | Luban 的配方或它们锁定的包有改动 | 在 x86_64 和 aarch64 上构建并启动 edition |
| `site-check.yml` | `pkgs/`、`docs/` 或站点配置有改动 | 以 strict 模式构建站点 |

L3 和 L4 在 CI 中只针对改动涉及的包运行，以及在每周轮转中运行：每次推送都在每个平台上
安装全部配方，超出了预算。
