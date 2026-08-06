# 快速开始

[English](quick-start.en.md) | **简体中文**

装好 xlings,然后从这个索引里装第一个包。

## 1. 安装 xlings

```bash
# Linux / macOS
curl -fsSL https://d2learn.org/xlings-install.sh | bash
```

```powershell
# Windows · PowerShell
irm https://d2learn.org/xlings-install.ps1.txt | iex
```

## 2. 装一个包

包名就是本索引每个包页面上显示的那个:

```bash
xlings install gcc -y
gcc --version
```

再来一个:

```bash
xlings install mcpp -y
mcpp --version
```

装好的东西放在 xlings 自己的目录里,不动系统环境;`-y` 跳过确认。

## 3. 找包、看装了什么

```bash
xlings search gcc     # 搜索包
xlings list           # 列出已安装的包
xlings remove gcc     # 卸载
```

浏览也可以直接用这个站:每个包页面写着它提供哪些命令(`programs`)、支持哪些架构、是否受 xvm 多版本管理。

## 4. 索引更新了

```bash
xlings update
```

拉取最新的包索引。本站的[统计页](../stats/)能看到索引里有多少包、最近加了什么。

## 接下来

**用**

- [xlings 文档](https://xlings.d2learn.org/documents/xim/intro.html) —— 完整命令、多版本管理、SubOS 隔离
- [论坛](https://forum.d2learn.org/category/9/xlings) —— 提问和反馈

**贡献一个包**

- [贡献指南](contributing.md) —— 端到端流程
- [XPackage V2 规范](V2/xpackage-spec.md) —— 描述符字段与约束
- [新增一个包](V1/add-xpackage.md) —— 从零写一个配方

**自建索引**

- [xim-pkgindex-template](https://github.com/openxlings/xim-pkgindex-template) —— 自建 / 镜像 / 私有包索引的模板仓库
