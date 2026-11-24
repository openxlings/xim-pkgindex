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

你不必是上游的作者。一个包需要官方的信息与资源（或知名镜像），以及一次你真正运行过的安装。

1. 把[模板](docs/specs/xpackage-template.lua)复制为 `pkgs/<首字母>/<name>.lua`。
2. 添加 `tests/<首字母>/test_<name>.py`。
3. 在隔离的 `XLINGS_HOME` 中验证，然后发起 PR ——
   完整路径见[添加一个包](docs/zh/10-adding-a-package.md)。

几条经验规则：

- **来源**：先用上游自己的发布，其次是知名第三方发布。只有存在知名镜像时才加 CN 镜像；
  否则跳过 CN，由有 `xlings-res` 权限的维护者以后补充。
- **二进制**：优先选官方来源的静态（musl）构建，安装过程中绝不编译。
- **你自己的重新打包或补丁构建**放在你自己的命名空间下（`<你>:<name>`），由你托管，并在
  PR 里写明可复现的过程。
- **Luban OS** 的包目前只接受 bug 修复；新功能先开 issue。
- 只改任务需要的部分；`.github/`、`libs/`、`tools/` 留给维护者。

新包可使用固定声明模板接入[自动更新](docs/zh/13-ci-mirror-and-update.md)。
建议上游 GitHub 仓库至少有 50 stars，这是建议而非强制门槛。

格式见 [XPackage V2](docs/specs/xpackage-v2.md)；全部文档在 [docs/zh/](docs/zh/README.md)。

### 用 AI agent 贡献

agent（Claude Code、Cursor、Copilot 等）可以走完整个流程。它会读取 [AGENTS.md](AGENTS.md)，
其中写明规则，并指向其余内容所在的 skill。把下面的提示词交给它：

```
Read AGENTS.md of https://github.com/openxlings/xim-pkgindex and follow it,
with the skills it points to. Task: add the package <name> (upstream: <url>)
for every platform and architecture its official source publishes. Verify it
in an isolated XLINGS_HOME, then open a pull request that says what you ran
and what you could not.
```

做其他事时沿用同样的开头，只换任务：*把 `<name>` 升级到 `<version>`*，或
*修复 `<name>`：`<现象>`*。一个包，最小的改动。

像审阅其他人的 PR 一样审阅它的 PR：来源及其档位、sha256、程序是否真的运行过，
以及它声明没能运行的部分。

### 还没准备好写配方？

发一个 [issue](https://github.com/openxlings/xim-pkgindex/issues/new/choose)：提议一个包、
报告 bug、请求新版本、申请把某个资源托管到 `xlings-res`，或在动手前讨论一个 Luban 新功能。

## 其他索引

| 仓库 | 命名空间 | 用途 |
|---|---|---|
| [xim-pkgindex-template](https://github.com/openxlings/xim-pkgindex-template) | 自定 | 自建、镜像或私有索引 |
| [xim-pkgindex-fromsource](https://github.com/openxlings/xim-pkgindex-fromsource) | `fromsource` | 从源码构建的包 |
| [xim-pkgindex-d2x](https://github.com/d2learn/xim-pkgindex-d2x) | `d2x` | d2x 课程项目 |

## 社区

[论坛](https://forum.d2learn.org/category/9/xlings) · QQ 群 167535744 ·
[Issues](https://github.com/openxlings/xim-pkgindex/issues)
