# xim-pkgindex

[English](README.md) | **简体中文**

[xlings](https://github.com/openxlings/xlings) 的官方包索引：编译器、运行时、工具和环境的
配方，覆盖 Linux、macOS、Windows，x86_64 与 aarch64。

[![xpkg test](https://github.com/openxlings/xim-pkgindex/actions/workflows/ci-xpkg-test.yml/badge.svg?branch=main)](https://github.com/openxlings/xim-pkgindex/actions/workflows/ci-xpkg-test.yml)
[![site](https://github.com/openxlings/xim-pkgindex/actions/workflows/pkgindex-deloy.yml/badge.svg)](https://index.xlings.org)

## 安装 xlings

```bash
curl -fsSL https://d2learn.org/xlings-install.sh | bash
```

```powershell
irm https://d2learn.org/xlings-install.ps1.txt | iex
```

## 使用这个索引

```bash
xlings search gcc
xlings install gcc -y
xlings update
```

每个包的版本和命令可以在 [index.xlings.org](https://index.xlings.org) 上浏览。

## 贡献一个包

1. 把[模板](docs/specs/xpackage-template.lua)复制为 `pkgs/<首字母>/<name>.lua`。
2. 添加 `tests/<首字母>/test_<name>.py`。
3. 发起 PR —— 完整路径见[添加一个包](docs/zh/10-adding-a-package.md)。

格式见 [XPackage V2](docs/specs/xpackage-v2.md)；全部文档在 [docs/zh/](docs/zh/README.md)。

### 用 AI agent 贡献

agent（Claude Code、Cursor、Copilot 等）可以走完整个流程；`.agents/skills/` 中的 skill
写明了它必须遵守的规则。把下面的提示词交给它：

```
Read the README and docs/10-adding-a-package.md of
https://github.com/openxlings/xim-pkgindex, and follow
.agents/skills/xpkg-creater/SKILL.md and .agents/skills/pr-workflow/SKILL.md:
add the package <name> (upstream: <url>) for every platform and architecture
it publishes, with its test, verify it in an isolated XLINGS_HOME, then open
a pull request with what you ran.
```

像审阅其他人的 PR 一样审阅它的 PR：资源、sha256，以及安装确实运行过。

## 其他索引

| 仓库 | 命名空间 | 用途 |
|---|---|---|
| [xim-pkgindex-template](https://github.com/openxlings/xim-pkgindex-template) | 自定 | 自建、镜像或私有索引 |
| [xim-pkgindex-fromsource](https://github.com/openxlings/xim-pkgindex-fromsource) | `fromsource` | 从源码构建的包 |
| [xim-pkgindex-d2x](https://github.com/d2learn/xim-pkgindex-d2x) | `d2x` | d2x 课程项目 |

## 社区

[论坛](https://forum.d2learn.org/category/9/xlings) · QQ 群 167535744 ·
[Issues](https://github.com/openxlings/xim-pkgindex/issues)
