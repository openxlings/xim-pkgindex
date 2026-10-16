# 这个索引是什么

[English](../00-what-this-index-is.md) | **简体中文**

xim-pkgindex 是 [xlings](https://github.com/openxlings/xlings) 的官方包索引：
`xlings install` 读取的配方、配方指向的资源，以及保证它们可安装的测试。站点见
[index.xlings.org](https://index.xlings.org)。

## 里面有什么

| 路径 | 内容 |
|---|---|
| `pkgs/<首字母>/<name>.lua` | 每个包一个配方（xpkg：元数据、平台—版本资源矩阵、钩子） |
| `pkgs/luban/<name>.lua` | 只为 Luban 存在的包：各 edition、启动配置、`luban-os`、`xdesk`、`labwc-desktop`、`luban-fonts` |
| `libs/` | 配方共用的 Lua 模块（`sysroot`、`relocate`、`graphics`、`luban` 等） |
| `tests/` | 与 `pkgs/` 一一对应的 pytest 测试，以及全仓库的检查 |
| `tools/res/` | 本索引自己构建的资源所用的构建工厂 |
| `xim-indexrepos.lua` | 默认的子索引 |
| `index-compat.json` | 本索引需要的最低客户端版本 |
| `.xpkgindex.json` | 站点配置 |

配方以数据为主：它安装的资源及其 sha256、它提供的程序、它的依赖。钩子只做数据
做不到的事。格式见 [XPackage V2](../specs/xpackage-v2.md)。

## 命名空间

每个索引是一个命名空间。本索引是 `xim`，并且始终存在：用户自己的 `index_repos`
是追加到它之后，而不是替换它。

| 类别 | 例子 | 来源 |
|---|---|---|
| 官方索引 | `xim:gcc` | 本仓库 |
| 默认子索引 | `awesome:...`、`scode:...`、`d2x:...` | 本仓库的 `xim-indexrepos.lua` |
| 第三方或私有索引 | `ros2:...` | 用户的 `index_repos` |

裸名字（`gcc`）先在主索引中查找；只有所有主索引都没有时才查子索引。显式命名空间
（`xim:gcc`）只查那一个索引。两个主索引都能回答同一个裸名字时报错，要求写出命名空间。

本索引中的配方不带命名空间声明的依赖，指的是**本索引**中同名的包。

## 它怎样到达一台机器

用户不会克隆这个仓库。`main` 的每次变更都会发布成一个带版本的工件（一个 tarball 和
一个带 sha256 的指针，GitHub 与 GitCode 各一份），`xlings update` 获取它的版本可以使用的
最新快照。机制见 xlings 的
[索引分发](https://github.com/openxlings/xlings/blob/main/docs/specs/index-distribution.md)；
客户端可以使用哪个快照见
[索引版本契约](https://github.com/openxlings/xlings/blob/main/docs/specs/index-version-contract.md)。
本索引在 `index-compat.json` 中声明它的下限。

## 其他索引

| 仓库 | 命名空间 | 用途 |
|---|---|---|
| [xim-pkgindex-template](https://github.com/openxlings/xim-pkgindex-template) | 自定 | 自建、镜像或私有索引 |
| [xim-pkgindex-fromsource](https://github.com/openxlings/xim-pkgindex-fromsource) | `fromsource` | 从源码构建的包 |
| [xim-pkgindex-d2x](https://github.com/d2learn/xim-pkgindex-d2x) | `d2x` | d2x 课程项目 |
