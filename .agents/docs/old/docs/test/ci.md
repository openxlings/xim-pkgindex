# CI Workflow 说明

## 概述

xpkg 测试通过 GitHub Actions 自动运行，workflow 文件位于 `.github/workflows/ci-xpkg-test.yml`。

## 触发条件

```yaml
on:
  push:
    paths: ['pkgs/**', 'tests/**']
  pull_request:
    paths: ['pkgs/**', 'tests/**']
```

当 `pkgs/` 或 `tests/` 目录下的文件发生变更时，无论是 push 还是 PR，都会触发测试。

## Job 结构

```
┌─────────────────────────┐
│  static-and-isolation   │  L0 + L2
│  ・无需 xlings           │  ~5 秒
│  ・Python + pytest       │
└───────────┬─────────────┘
            │ needs
            ▼
┌─────────────────────────┐
│  index-registration     │  L1
│  ・需要安装 xlings       │  ~30 秒
│  ・xlings install --add-xpkg 验证  │
└─────────────────────────┘
```

### Job 1: `static-and-isolation`

**不需要 xlings**，纯 Python 静态分析。

| Step | 说明 |
|------|------|
| Checkout | 拉取代码 |
| Setup Python 3.12 | 安装 Python |
| Install pytest | `pip install pytest` |
| **L0 Static Analysis** | `pytest tests/ -m static --tb=short -q` |
| **L2 Isolation Compliance** | `pytest tests/ -m isolation --tb=short -q` |

检查内容:
- 包定义字段完整性 (name, description, type, spec)
- spec/type 值合法性
- 拼写错误检查
- subos 隔离合规 (xvm API 使用、shell 配置、PATH 修改)

### Job 2: `index-registration`

**需要 xlings**，依赖 Job 1 通过后才运行。

| Step | 说明 |
|------|------|
| Checkout | 拉取代码 |
| Setup Python 3.12 | 安装 Python |
| Install pytest | `pip install pytest` |
| Install xlings | 非交互安装 xlings (`XLINGS_NON_INTERACTIVE=1`) |
| **L1 Index Registration** | `pytest tests/ -m index --tb=short -q` |

检查内容:
- 每个包文件能被 `xlings install --add-xpkg` 成功注册到索引数据库

## 与现有 CI 的关系

本 workflow (`ci-xpkg-test.yml`) 与原有的 `ci-test.yml` **并行运行，互不影响**:

| Workflow | 文件 | 关注点 |
|----------|------|--------|
| `ci-test.yml` | 原有 | 变更文件的 `xlings install --add-xpkg` 验证 + LD_LIBRARY_PATH lint |
| `ci-xpkg-test.yml` | 新增 | **全量**静态分析 + 隔离合规 + 索引注册 |

主要区别:
- 原有 CI 只检查**变更的**文件
- 新增 CI 检查**所有** 57 个包文件
- 新增 CI 额外检查 subos 隔离合规

## 失败处理

### xfail (预期失败)

已知问题通过 `@pytest.mark.xfail` 标记，不阻塞 CI:

```
429 passed, 6 xfailed  ← CI 通过
```

当前 xfail 项:
- `nvm`: shell 函数特性，需要 bashrc 集成
- `msvc`, `python`, `seeme-report`, `vs-buildtools`: 使用旧 API

### 真正的失败

如果新提交引入了新问题（如拼写错误、缺少必填字段、使用了 `os.exec("xvm add ...")`），CI 会报 FAILED:

```
1 failed, 428 passed, 6 xfailed  ← CI 失败
```

修复方法: 根据错误信息修改包文件，参考 [测试使用指南](usage.md)。

## 本地运行

在提交前本地运行 CI 同等级别的检查:

```bash
# 完全等同于 CI Job 1
pip install pytest
pytest tests/ -m static --tb=short -q
pytest tests/ -m isolation --tb=short -q

# 完全等同于 CI Job 2 (需要 xlings)
pytest tests/ -m index --tb=short -q
```

## 扩展: L3/L4 测试

L3 (生命周期) 和 L4 (功能验证) 目前**不在 CI 中运行**，因为:
- 需要实际下载和安装包（耗时长、依赖网络）
- 部分包需要 GUI 环境
- 部分包依赖 XLINGS_RES 资源服务器

手动运行:

```bash
# 安装并验证单个包
pytest tests/c/test_cmake.py -m "lifecycle or verify" -v

# 全量安装验证 (非常耗时)
pytest tests/ -m "lifecycle or verify" --timeout=300
```
