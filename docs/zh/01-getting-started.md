# 快速开始

[English](../01-getting-started.md) | **简体中文**

安装 xlings，然后从这个索引安装第一个包。

## 安装 xlings

```bash
curl -fsSL https://d2learn.org/xlings-install.sh | bash
```

```powershell
irm https://d2learn.org/xlings-install.ps1.txt | iex
```

前者用于 Linux 和 macOS，后者用于 Windows PowerShell。

## 安装一个包

包名就是每个包页面上的名字：

```bash
xlings install gcc -y
gcc --version
```

再装一个：

```bash
xlings install mcpp -y
mcpp --version
```

所有东西都装进 xlings 自己的目录，不进系统；`-y` 回答确认提示。

## 查找，以及查看已安装的

```bash
xlings search gcc     # search
xlings list           # what is installed
xlings remove gcc     # uninstall
```

[index.xlings.org](https://index.xlings.org) 上每个包的页面列出它提供的命令、支持的
架构，以及能否用 `xlings use` 切换版本。

## 索引更新之后

```bash
xlings update
```

获取索引的最新快照。站点的[统计页](https://index.xlings.org/stats/)显示索引中有多少包、
最近新增了什么。

## 接下来

- 使用 xlings：[xlings 文档](https://github.com/openxlings/xlings/tree/main/docs/zh) ——
  版本、项目、SubOS
- 贡献一个包：[添加一个包](10-adding-a-package.md)
- 运行自己的索引：[xim-pkgindex-template](https://github.com/openxlings/xim-pkgindex-template)
- 提问：[论坛](https://forum.d2learn.org/category/9/xlings)
