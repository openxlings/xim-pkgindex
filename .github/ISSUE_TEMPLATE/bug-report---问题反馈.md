---
name: Bug report | 问题反馈
about: A package fails to install, run or remove; or an xpkg is wrong
title: '[bug]: '
labels: bug
assignees: ''

---

<!-- Before posting, remove local paths, user names, e-mail addresses and tokens: an edit keeps the old text in the history. | 提交前请去掉本地路径、用户名、邮箱和 token：编辑会在历史中保留旧文本。 -->

### Package and version | 包与版本

`<namespace>:<name>@<version>` (for example `xim:gcc@16.1.0`):

### Environment | 环境

- OS and architecture | 系统与架构:
- xlings version (`xlings --version`) | xlings 版本:
- Region / mirror in use, if relevant | 区域与镜像:

### What happened | 问题描述

### To reproduce | 复现步骤

In an isolated home if you can | 尽量在隔离的 home 中:

```bash
XLINGS_HOME="$(mktemp -d)" xlings install <name>@<version> -y
```

### Expected | 预期结果

### Logs | 日志

The full output, not only the last line | 完整输出，而不只是最后一行:

### What you already tried | 已尝试的方案

### Additional context | 额外补充

<!-- For CI failures: the run link and the failing job. -->

### Authorship | 作者
Authorship: <by-human | ai-and-human>
Agent: <optional | 可选>
Model: <optional | 可选>
