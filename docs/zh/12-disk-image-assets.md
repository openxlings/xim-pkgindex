# 磁盘镜像资产与命名

[English](../12-disk-image-assets.md) | **简体中文**

"某系统的官方介质,装配为可引导镜像"的资产类:这类包是什么、如何命名、配方声明什么。这里没有任何引擎词汇——引擎不知道这些名字;该类资产服务任何引导镜像的消费者。

## 类定义

磁盘镜像包携带**一个系统的字节,为模拟器准备好**:发布者的官方介质,装配为带串口控制台的可引导镜像,在两个资源服务器发布且双侧同一 sha。它是资产,不是机制:模拟器、控制台对话与退出码约定属于引导它的 runner,永不属于这个包。

## 命名

| 规则 | 声明 |
|---|---|
| 包名 | `<system>-disk-image`——名物,不名机制,不名格式 |
| 资产名 | 携带格式(`*.qcow2`、`*.vfd` 等);包名永不携带 |
| 前缀 | 通用资产无前缀;契约是某构建系统会话的工具携带该系统前缀 |
| 归属 | 配方写明所装配介质的发布者 |
| 溯源 | 重打包字节有记录,双镜像,sha 一致 |

为什么是 `disk-image` 而非其他:`disk` 单用可能读作硬件;`image` 单用已被容器占用;`iso` 在介质换成 qcow2 那天就撒谎;`boot-` 前缀说的东西磁盘镜像本身已经说了。

## 该类配方声明什么

```lua
-- <system>-disk-image.lua —— 资产包:只安装,不上 PATH
package = {
    spec = "2",
    name = "<system>-disk-image",
    description = "<Publisher> 官方 <version> 介质,装配为带串口控制台的可引导磁盘镜像,供模拟器 runner 使用",
    licenses = { "<publisher license>" },
    repo = "<publisher source>",
    type = "package",
    status = "dev",
    archs = { "x86_64", "aarch64" },
    xpm = {
        ["<os>"] = {
            source = {
                GLOBAL = "https://github.com/xlings-res/<system>-disk-image/releases/download/${version}/<system>-${version}.<arch>.qcow2",
                CN = "https://gitcode.com/xlings-res/<system>-disk-image/releases/download/${version}/<system>-${version}.<arch>.qcow2",
            },
            ["latest"] = { ref = "<version>" },
            ["<version>"] = { sha256 = { ["x86_64"] = "…", ["aarch64"] = "…" } },
        },
    },
}
-- install():镜像落在包根下;config()/uninstall():无。消费者是命名镜像路径的 runner 声明。
```

## 矫正变更

| 变更 | 通道 |
|---|---|
| 镜像字节必须变,版本不能变 | 同键,抬升打包 revision;updater 通道强制抬升完整 |
| 格式变更 | 资产名携带;包名永不携带 |
| 介质发布者变更 | 新版本条目,带自己的归属 |
