# xlings setup & links

## 1) 安装 xlings（开发 xpkg 前置）

> 目标：本地可执行 `xlings --version`。

常用安装命令（来自本仓库 CI/工作流中使用的安装方式）：

```bash
# 方式 A：quick_install（GitHub）
export XLINGS_NON_INTERACTIVE=1
curl -fsSL https://raw.githubusercontent.com/openxlings/xlings/main/tools/other/quick_install.sh | bash
```

```bash
# 方式 B：d2learn 安装脚本
export XLINGS_NON_INTERACTIVE=1
curl -fsSL https://d2learn.org/xlings-install.sh | bash
```

安装后建议执行：

```bash
xlings --version
```

## 2) 核心链接

- xlings 仓库：<https://github.com/openxlings/xlings>
- openxlings GitHub 组织：<https://github.com/openxlings>
- xlings 文档入口：<https://xlings.d2learn.org>
- 社区论坛：<https://forum.d2learn.org>
- 本仓库（包索引）：<https://github.com/openxlings/xim-pkgindex>
- 包索引页面：<https://openxlings.github.io/xim-pkgindex>
- 索引机制：xlings 的 `docs/specs/index-distribution.md`（分发、镜像、区域链）与 `docs/specs/index-version-contract.md`；本仓库的命名空间与官方资源见 `docs/00-what-this-index-is.md`、`docs/11-official-resources.md`

## 3) 说明

- 若安装命令更新，优先以 xlings 仓库 README 为准。
- 本 skill 只保留常用命令；完整安装矩阵（平台差异）请查看上方链接。
