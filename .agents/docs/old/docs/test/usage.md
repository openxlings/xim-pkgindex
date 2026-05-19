# xpkg 测试使用指南

## 快速开始

### 环境准备

```bash
pip install pytest
```

### 运行测试

```bash
# 静态检查 (不需要 xlings, 秒级完成)
pytest tests/ -m static

# 隔离合规检查
pytest tests/ -m isolation

# 静态 + 隔离 一起跑
pytest tests/ -m "static or isolation"

# 索引注册检查 (需要 xlings 已安装)
pytest tests/ -m index

# 安装生命周期 (需要 xlings, 会实际安装包)
pytest tests/ -m lifecycle

# 功能验证 (需要包已安装)
pytest tests/ -m verify

# 全部
pytest tests/
```

### 测试单个包

```bash
# cmake 的所有测试
pytest tests/c/test_cmake.py

# cmake 只跑静态检查
pytest tests/c/test_cmake.py -m static

# 同时测多个包
pytest tests/c/test_cmake.py tests/n/test_ninja.py -m "static or isolation"
```

### 查看详细输出

```bash
# 显示每个测试名称
pytest tests/ -m static -v

# 失败时显示详细错误
pytest tests/ -m isolation --tb=long

# 只显示失败的
pytest tests/ -m isolation --tb=short -q
```

---

## 为新包添加测试

当你向 `pkgs/` 添加了一个新的 xpkg 包文件，需要在 `tests/` 中添加对应的测试。

### 步骤 1: 创建测试文件

测试文件路径必须与包文件路径对应:

```
pkgs/n/mypackage.lua  →  tests/n/test_mypackage.py
```

> 注意: 文件名中的 `-` 替换为 `_` (Python 模块命名规范)

### 步骤 2: 编写测试

最小模板 — 只需改 3 处 (`PKG`, `PKG_FILE`, docstring):

```python
"""测试 mypackage 包"""
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

PKG = "mypackage"                    # ← 包名
PKG_FILE = "pkgs/n/mypackage.lua"    # ← 包文件相对路径


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


# ── L0: 静态分析 (必须) ──
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


# ── L1: 索引注册 (必须) ──
class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


# ── L2: 隔离合规 (必须) ──
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


# ── L3: 生命周期 (推荐) ──
class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        assert_install_succeeds(PKG)


# ── L4: 功能验证 (推荐) ──
class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_version(self):
        assert_command_output("mypackage --version", contains="mypackage")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_registered(self):
        assert_xvm_registered("mypackage")
```

### 步骤 3: 运行验证

```bash
# 先跑静态 + 隔离，确保包定义合规
pytest tests/n/test_mypackage.py -m "static or isolation" -v

# 再跑索引注册
pytest tests/n/test_mypackage.py -m index -v
```

### 步骤 4: 提交

测试文件和包文件一起提交，CI 会自动运行 L0 + L2 + L1 检查。

---

## 测试级别详解

### L0: 静态分析 (`@pytest.mark.static`)

纯文件分析，不需要任何运行时环境。

| 断言函数 | 检查内容 |
|----------|----------|
| `assert_required_fields(meta)` | `name`, `description`, `type`, `spec` 字段存在 |
| `assert_valid_spec(meta)` | `spec` 值为 `"0"` 或 `"1"` |
| `assert_valid_type(meta)` | `type` 值为 `package/script/config/template/bugfix` |
| `assert_no_typos(path)` | 无已知拼写错误 (如 `debain`) |

### L1: 索引注册 (`@pytest.mark.index`)

需要 xlings 已安装。

| 断言函数 | 检查内容 |
|----------|----------|
| `assert_xim_add_succeeds(path)` | `xlings install --add-xpkg` 能成功注册到索引数据库 |

### L2: 隔离合规 (`@pytest.mark.isolation`)

检查包是否符合 subos 环境隔离架构。

| 断言函数 | 检查内容 |
|----------|----------|
| `assert_no_exec_xvm(path)` | 不通过 `os.exec("xvm add ...")` 调用 xvm，应使用 `xvm.add()` API |
| `assert_no_bashrc_modification(path)` | 不修改 `.bashrc` / shell profile |
| `assert_no_direct_path_modification(path)` | 不直接调用 `os.addenv("PATH")` |
| `assert_uses_new_api(path)` | 使用 `xim.libxpkg.*` 而非旧版 `xim.base.runtime` 等 |
| `assert_no_direct_pkg_manager(path)` | 不直接调用 `brew install` / `apt install` |

### L3: 生命周期 (`@pytest.mark.lifecycle`)

需要 xlings 已安装，会实际执行安装/卸载。

| 断言函数 | 检查内容 |
|----------|----------|
| `assert_install_succeeds(name, timeout)` | `xlings install` 成功 |
| `assert_uninstall_succeeds(name)` | `xlings remove` 成功 |

### L4: 功能验证 (`@pytest.mark.verify`)

需要包已安装，验证程序实际可用。

| 断言函数 | 检查内容 |
|----------|----------|
| `assert_command_available(cmd)` | `which <cmd>` 成功 |
| `assert_command_output(cmd, contains, regex)` | 命令执行成功且输出匹配 |
| `assert_xvm_registered(target)` | 目标在 xvm 中已注册 |
| `assert_xvm_shim_exists(target)` | `subos/current/bin/` 中有对应 shim 文件 |
| `assert_platform_supported(meta, platform)` | 包支持指定平台 |

---

## 特殊场景

### ref 包 (别名包)

ref 包只需验证 `is_ref` 属性:

```python
class TestStatic:
    @pytest.mark.static
    def test_is_ref(self, meta):
        assert meta.is_ref, "应为 ref 包"
```

### 仅 Windows 的包

用 `skip_if_not` 跳过 Linux 不可用的测试:

```python
@pytest.mark.lifecycle
@skip_if_not('windows')
def test_install(self):
    assert_install_succeeds(PKG)
```

### 已知问题

用 `xfail` 标记预期会失败的测试，不阻塞 CI:

```python
@pytest.mark.isolation
@pytest.mark.xfail(reason="nvm 是 shell 函数, 需要 bashrc 集成")
def test_no_bashrc(self):
    assert_no_bashrc_modification(PKG_FILE)
```

### 自定义功能测试

除了 `--version` 检查，可以测试实际功能:

```python
@pytest.mark.verify
@skip_if_not('linux')
def test_compile(self):
    """gcc 能编译简单 C 程序"""
    assert_command_output(
        "echo 'int main(){return 0;}' | gcc -x c - -o /tmp/test && /tmp/test && echo OK",
        contains="OK"
    )
```

---

## 通用模块

| 模块 | 路径 | 说明 |
|------|------|------|
| `xpkg_parser` | `tests/lib/xpkg_parser.py` | 解析 `.lua` 文件提取 `XpkgMeta` |
| `assertions` | `tests/lib/assertions.py` | 所有断言函数 |
| `xvm_client` | `tests/lib/xvm_client.py` | `XvmClient.info()`, `.is_registered()`, `.shim_exists()` |
| `xlings_client` | `tests/lib/xlings_client.py` | `XlingsClient.install()`, `.remove()`, `.xim_add_xpkg()` |
| `platform_utils` | `tests/lib/platform_utils.py` | `current_platform()`, `skip_if_not()`, `xlings_home()` |
