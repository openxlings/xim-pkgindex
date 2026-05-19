# xpkg 包测试框架设计文档

> 相关文档: [使用指南](usage.md) | [CI 说明](ci.md)

## 1. 概述

### 1.1 目标

为 xim-pkgindex 仓库中的所有 xpkg 包提供自动化测试，覆盖包的**完整生命周期**（注册 → 安装 → 配置 → 使用 → 卸载）以及 **subos 环境隔离合规**检查，确保每次包修改不会引入回归问题。

### 1.2 设计原则

- **镜像结构**: `tests/` 目录与 `pkgs/` 一一对应
- **分层测试**: 从轻量级静态检查到重量级安装验证，按需选择
- **通用抽象**: 可复用的测试逻辑提取到通用模块
- **声明式配置**: 每个包测试文件通过声明式配置 + 自定义 hook 定义测试行为
- **CI 友好**: 支持并行、超时控制、结果报告

## 2. 架构

### 2.1 目录结构

```
tests/
├── conftest.py                   # pytest 全局 fixtures
├── pytest.ini                    # pytest 配置
├── lib/
│   ├── __init__.py
│   ├── runner.py                 # 测试运行器核心
│   ├── xpkg_parser.py            # lua 包文件解析器
│   ├── assertions.py             # 通用断言函数
│   ├── xvm_client.py             # xvm 操作封装
│   ├── xlings_client.py          # xlings install/remove 封装
│   └── platform_utils.py         # 平台检测工具
├── b/
│   ├── test_binutils.py
│   └── test_brew.py
├── c/
│   ├── test_cmake.py
│   ├── test_code.py
│   └── ...
└── ...                           # 与 pkgs/ 镜像
```

### 2.2 测试层级

| 层级 | 名称 | 标记 | 需要 xlings | 耗时 | 说明 |
|------|------|------|-------------|------|------|
| L0 | 静态分析 | `@mark.static` | 否 | <1s/包 | lua 语法、字段完整性、拼写检查 |
| L1 | 索引注册 | `@mark.index` | 是 | <2s/包 | `xlings install --add-xpkg` 能否成功注册 |
| L2 | 隔离合规 | `@mark.isolation` | 否 | <1s/包 | subos 架构合规性检查 |
| L3 | 安装卸载 | `@mark.lifecycle` | 是 | 10-180s/包 | install → config → verify → uninstall |
| L4 | 功能验证 | `@mark.verify` | 是 | 5-30s/包 | 安装后程序可用性验证 |

### 2.3 运行方式

```bash
# 全量静态检查 (CI 必跑)
pytest tests/ -m static

# 隔离合规
pytest tests/ -m isolation

# 指定包的完整测试
pytest tests/c/test_cmake.py -m "not lifecycle"
pytest tests/c/test_cmake.py   # 包含安装

# 全量
pytest tests/ -m "static or isolation"

# 按平台过滤
pytest tests/ -m "static and linux"
```

## 3. 通用模块设计

### 3.1 `xpkg_parser.py` — lua 包文件解析器

解析 `.lua` 包文件提取元数据，无需运行 lua。

```python
class XpkgMeta:
    name: str
    spec: str
    description: str
    pkg_type: str          # package | script | config | template
    programs: list[str]    # 可执行程序列表
    platforms: dict        # {linux: {...}, windows: {...}, ...}
    deps: dict             # {linux: [...], windows: [...]}
    is_ref: bool           # 是否是 ref 包
    ref_target: str | None
    imports: list[str]     # import 语句列表
    has_install: bool
    has_config: bool
    has_uninstall: bool

def parse_xpkg(lua_path: str) -> XpkgMeta
```

### 3.2 `assertions.py` — 通用断言

```python
# ── 静态分析断言 ──
def assert_required_fields(meta: XpkgMeta)
def assert_valid_spec(meta: XpkgMeta)
def assert_valid_type(meta: XpkgMeta)
def assert_no_typos(lua_path: str)

# ── 隔离合规断言 ──
def assert_no_exec_xvm(lua_path: str)
def assert_no_bashrc_modification(lua_path: str)
def assert_no_direct_path_modification(lua_path: str)
def assert_uses_new_api(lua_path: str)
def assert_no_direct_pkg_manager(lua_path: str)

# ── 索引注册断言 ──
def assert_xim_add_succeeds(lua_path: str)

# ── 生命周期断言 ──
def assert_install_succeeds(pkg_name: str, timeout: int = 180)
def assert_uninstall_succeeds(pkg_name: str)

# ── 功能验证断言 ──
def assert_command_available(cmd: str)
def assert_command_output(cmd: str, contains: str = None, regex: str = None)
def assert_xvm_registered(target: str)
def assert_xvm_shim_exists(target: str)
def assert_file_exists_in_xpkg(pkg_name: str, version: str, relative_path: str)

# ── 平台断言 ──
def assert_platform_supported(meta: XpkgMeta, platform: str)
```

### 3.3 `xvm_client.py` — xvm 操作封装

```python
class XvmClient:
    def add(target, version=None, bindir=None, alias=None) -> bool
    def remove(target, version=None) -> bool
    def list(target=None) -> list[dict]
    def info(target) -> dict | None
    def is_registered(target) -> bool
    def shim_path(target) -> str | None
```

### 3.4 `xlings_client.py` — xlings 安装封装

```python
class XlingsClient:
    def install(pkg_name: str, timeout: int = 180) -> Result
    def remove(pkg_name: str) -> Result
    def search(pkg_name: str) -> list
```

### 3.5 `platform_utils.py`

```python
def current_platform() -> str        # linux | windows | macosx
def current_arch() -> str            # x86_64 | arm64
def skip_if_not(platform: str)       # pytest skip 装饰器
def xlings_home() -> str
def subos_bin_dir() -> str
def xpkgs_dir() -> str
```

## 4. 每包测试文件结构

每个测试文件是一个标准 pytest 模块，覆盖包的完整生命周期：

```python
# tests/c/test_cmake.py
"""cmake 包测试"""
import pytest
from tests.lib.assertions import *
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.platform_utils import skip_if_not

PKG = "cmake"
PKG_FILE = "pkgs/c/cmake.lua"

@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)

# ── L0: 静态分析 ──
class TestStatic:
    @pytest.mark.static
    def test_required_fields(self, meta):
        assert_required_fields(meta)

    @pytest.mark.static
    def test_valid_spec(self, meta):
        assert_valid_spec(meta)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)

# ── L1: 索引注册 ──
class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)

# ── L2: 隔离合规 ──
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

# ── L3: 生命周期 ──
class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(PKG)

    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_uninstall(self):
        assert_uninstall_succeeds(PKG)

# ── L4: 功能验证 ──
class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_command_available(self):
        assert_command_available("cmake")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_version_output(self):
        assert_command_output("cmake --version", contains="cmake version")

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_basic_functionality(self):
        """cmake 能生成一个最小项目"""
        assert_command_output(
            "cd /tmp && mkdir -p cmake_test && cd cmake_test && "
            "echo 'cmake_minimum_required(VERSION 3.10)' > CMakeLists.txt && "
            "echo 'project(test)' >> CMakeLists.txt && "
            "cmake . && echo OK",
            contains="OK"
        )
```

## 5. 任务拆分

### Phase 1: 基础框架 (P1)

| 任务 | 说明 | 验收标准 |
|------|------|----------|
| T1.1 | 创建 `tests/lib/xpkg_parser.py` | 能解析所有 57 个 lua 文件的元数据，不报错 |
| T1.2 | 创建 `tests/lib/assertions.py` — 静态分析断言 | L0 断言全部可用 |
| T1.3 | 创建 `tests/lib/assertions.py` — 隔离合规断言 | L2 断言全部可用 |
| T1.4 | 创建 `tests/lib/platform_utils.py` | 平台检测正确 |
| T1.5 | 创建 `tests/conftest.py` + `pytest.ini` | `pytest tests/ -m static` 能运行 |
| T1.6 | 为所有 57 个包生成基础测试文件 (L0+L2) | 每个包至少有静态+隔离测试 |

### Phase 2: 运行时测试 (P2)

| 任务 | 说明 | 验收标准 |
|------|------|----------|
| T2.1 | 创建 `tests/lib/xvm_client.py` | xvm add/remove/list/info 封装可用 |
| T2.2 | 创建 `tests/lib/xlings_client.py` | xlings install/remove 封装可用，支持超时 |
| T2.3 | 创建 `tests/lib/assertions.py` — 索引注册断言 | L1 断言可用 |
| T2.4 | 创建 `tests/lib/assertions.py` — 生命周期断言 | L3 断言可用 |
| T2.5 | 创建 `tests/lib/assertions.py` — 功能验证断言 | L4 断言可用 |

### Phase 3: 包测试完善 (P3)

| 任务 | 说明 | 验收标准 |
|------|------|----------|
| T3.1 | 为所有 type=package 的包添加 L3+L4 测试 | 安装验证覆盖率 100% |
| T3.2 | 为工具类包添加功能性测试 | gcc 编译、cmake 生成、node 执行等 |
| T3.3 | 为 script 类包添加 xscript 调用测试 | script 类包能通过 xscript 调用 |
| T3.4 | 为 config 类包添加配置生效测试 | 配置类包生效验证 |

### Phase 4: CI 集成 (P4)

| 任务 | 说明 | 验收标准 |
|------|------|----------|
| T4.1 | GitHub Actions workflow: L0+L2 | PR 触发，全量静态+隔离检查 |
| T4.2 | GitHub Actions workflow: L1 | push 到 main 触发索引注册检查 |
| T4.3 | 测试报告生成 (JUnit XML + 汇总) | CI 中可查看测试结果 |

## 6. 验收标准

### 6.1 整体验收

- [ ] `pytest tests/ -m static` 全部通过 (0 FAIL)
- [ ] `pytest tests/ -m isolation` 仅已知问题有 WARN (0 FAIL)
- [ ] `pytest tests/ -m "static or isolation"` 可在 30 秒内完成
- [ ] 每个 `pkgs/<x>/<name>.lua` 都有对应的 `tests/<x>/test_<name>.py`
- [ ] 测试框架文档完整

### 6.2 单包测试验收

每个包的测试文件须覆盖:

- [ ] L0: 必填字段、spec 版本、拼写检查
- [ ] L2: xvm 调用方式、shell 配置、PATH 修改、API 版本
- [ ] L1: xlings install --add-xpkg 注册 (需 xlings)
- [ ] L3: install + uninstall (如果当前平台支持)
- [ ] L4: 至少一个功能验证命令 (如 `--version`)

### 6.3 通用模块验收

- [ ] `xpkg_parser.py` 能解析所有 57 个包文件
- [ ] `assertions.py` 每个断言函数有对应的 docstring
- [ ] `xvm_client.py` 封装了 add/remove/list/info
- [ ] `xlings_client.py` 支持超时、自动确认

## 7. 已知限制

| 限制 | 说明 | 影响范围 |
|------|------|----------|
| 平台限制 | CI 只能在 Linux 上运行 L3/L4 | Windows/macOS 包的安装测试跳过 |
| nvm 特殊性 | nvm 是 shell 函数，无法通过 shim 验证 | nvm 的 L4 需要 `source nvm.sh` |
| GUI 应用 | 无头环境无法验证 GUI 应用启动 | griddycode/project-graph 等只验证 xvm 注册 |
| XLINGS_RES | 部分包依赖 xlings 资源服务器 | 网络不可达时 L3 超时 |
