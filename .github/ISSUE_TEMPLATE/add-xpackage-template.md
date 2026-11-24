---
name: Add XPackage | 添加 XPackage
about: Propose a package for the official index (or announce the pull request that adds it)
title: "[XPackage]: "
labels: add-xpkg
assignees: ''

---

<!-- Before posting, remove local paths, user names, e-mail addresses and tokens: an edit keeps the old text in the history. | 提交前请去掉本地路径、用户名、邮箱和 token：编辑会在历史中保留旧文本。 -->

<!-- You do not have to be the upstream's author. A package needs official information and
resources (or a well-known mirror), and an install you have actually run.
Rules: AGENTS.md. Format: docs/specs/xpackage-v2.md. Path: docs/10-adding-a-package.md. -->

## Basic info | 基础信息

- Name | 名称:
- One sentence | 简介:
- Home page / upstream repository | 主页或上游仓库:
- License | 许可证:
- Commands it provides | 提供的命令:

## Source | 来源

- Where the binaries come from | 资源来源 (pick one | 选一):
  - [ ] the upstream's own release | 上游自己的发布
  - [ ] the upstream's official repository release | 上游官方仓库的 release
  - [ ] a well-known third-party release | 知名第三方 release
  - [ ] my own repack or patched build (needs `namespace = "<you>"`) | 我自己的重新打包 / 补丁构建（需要命名空间）
- Download URLs per platform and architecture | 各平台与架构的下载地址:
- Checksums published by the source? | 来源是否发布校验和:
- CN mirror (a well-known one, checked), or "none" (a maintainer adds it later) | CN 镜像（知名且已核对），没有就写“无”（维护者以后补充）:
- Static (musl) build available? Otherwise, which libraries does it need? | 是否有静态 (musl) 构建？否则依赖哪些库:
- Does it need compiling to install? (then it is not an xpkg, see AGENTS.md) | 是否需要从源码编译才能安装:

## Platforms | 平台

- [ ] linux x86_64  - [ ] linux aarch64  - [ ] macosx aarch64  - [ ] macosx x86_64
- [ ] windows x86_64  - [ ] windows aarch64
- Which I can test myself | 我能亲自测试的:

## Local test info | 本地测试信息

Use an isolated home, never your own | 使用隔离的 home，不要用自己的:

```bash
TMP_HOME="$(mktemp -d)"
XLINGS_HOME="$TMP_HOME" xlings config --add-xpkg pkgs/<letter>/<name>.lua
XLINGS_HOME="$TMP_HOME" xlings search <name>
XLINGS_HOME="$TMP_HOME" xlings install <name>@<version> -y   # then run the program
XLINGS_HOME="$TMP_HOME" xlings list <name>
XLINGS_HOME="$TMP_HOME" xlings remove <name> -y
```

Paste the output or a screenshot, per platform | 按平台贴输出或截图:

...

## Pull request | 对应的 PR

Link it here once it is open | PR 开启后在此链接:

...

### Authorship | 作者
Authorship: <by-human | human-and-ai | by-ai>
Agent: <optional | 可选>
Model: <optional | 可选>
