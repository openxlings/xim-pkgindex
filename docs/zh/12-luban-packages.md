# Luban 的包

[English](../12-luban-packages.md) | **简体中文**

Luban 的 edition、策略和启动层都是本索引中的普通配方：xpkg 格式不变，数据写在配方里，
只有 `libs/luban.lua` 写盘。Luban 是什么、edition 怎样使用，见
[xlings 的 Luban 文档](https://github.com/openxlings/xlings/tree/main/docs/zh/luban)。

## `luban:` 命名空间

官方的、为 Luban 做的包发布在 `luban` 命名空间：edition（`luban:core`、`luban:desktop`）、
桌面组件（`luban:labwc`、`luban:lxqt`、`luban:kde`、`luban:xdesk`）、Qt 运行时、工具集，以及为它们
构建的整包。通用软件留在 `xim`（fish、mesa、内核），用户在宿主上运行的程序也是（`xim:luban`、
`xim:luban-os`）。任何人都可以依赖 `luban:` 的包——任何 SubOS、任何系统：命名空间说明谁发布，
不限制谁使用。

luban 中的短名就是这个命名空间里的名字：`--edition desktop` 即 `luban:desktop`，`--desktop kde`
即 `luban:kde`。新增官方桌面就是在这里新增它的配方；luban 与 Luban OS 应用里没有名单。

`xim`、`luban`、`subos`、`config` 是**保留的**：`index-compat.json` 声明它们（`namespaces.reserved`），
认识这个字段的客户端只从本索引接受这些命名空间的包——别处写 `namespace = "luban"` 的配方被拒绝，
并指出它的索引与文件。规则在客户端、是通用的：任何索引都可以这样保留自己的命名空间。

已发布的 `subos:luban-*` edition 与 `xim:labwc-desktop` 冻结：保留、照常解析（实例与旧 edition 引用它们），
不再更新。接替者声明 `replaces = "<旧名字>"`，客户端只认同一索引内的声明。

## 类别

| 类别 | `type` | 命名空间 | 版本 | 写盘 |
|---|---|---|---|---|
| edition | `subos` | `luban`（冻结的：`subos`） | 发布日期 `YYYY.M.D.N` | `luban.edition({id, variant, versions, files})` |
| 桌面组件（`luban:labwc`、`luban:foot`） | `package` | `luban` | 上游版本，本索引的构建加 `-rN` | 配方自己；`luban_component` 放置 |
| 组合包（`luban:compositor`、`luban:xdesk`）或工具集（`luban:tools-dev`） | `package` | `luban` | 发布日期，或所组合的版本 | 它的依赖、会话与配置 |
| 策略 | `subos-policy` | `xim` | 发布日期 | `luban.policy(json)` |
| 启动层 | `package` | `xim` | 发布日期 | `luban.boot(json)` |
| 上游软件（内核、limine、busybox 等） | `package` | `xim` | 上游版本，重建时加 `-rN` | 配方自己 |

每个组件在注释里写明它的形态与理由（整包、运行时、由原子包组成的组合包）：形态改变时，名字与约定
（会话文件、`X-Luban-Shell`、自检、默认终端）不变。

## edition 的清单

`luban:` 的 edition 由表写出清单（`luban.manifest`）：键的顺序固定，`replaces` 写它接替的冻结 edition，
`luban` 对象写给认识 Luban 的读者：

| 键 | 含义 |
|---|---|
| `luban.settings` | 它预设的设置（`mode`、`enter`、`desktop`、`login_shell`）：低于用户自己的设置；同时写进根的 `usr/share/luban/settings.json`，旧的 luban 读这个文件 |
| `luban.os` | 它怎样称呼自己（`name`、`version`）：基于 Luban 的发行版说自己的名字 |
| `luban.requires` | 它对读取或运行它的一方的要求（opencaps 名字，如 `root-layout>=2`）；缺少时在创建前说明 |

```lua
manifest = {
    subos_kind = "rootfs", min_client = "2026.10.18.1",
    from = "luban:core@2026.10.18.1", replaces = "subos:luban-desktop",
    abi = { kernel = "linux", libc = "gnu" },
    packages = { "luban:xdesk@2026.10.18.1", "luban:foot@1.27.0-r1" },
    luban = { settings = { mode = "machine", enter = "desktop", desktop = "xdesk-classic" } },
    workspace = {},
}
```

## Luban 怎样呈现一个包：`extensions.luban`

配方在包级的 `extensions`（xpackage 字段，见 [`specs/xpackage-v2.md`](../specs/xpackage-v2.md)）里告诉 Luban 怎样呈现它：
xlings 原样带出，Luban OS 的新建页与 `luban search` 读它（xlings 设计 2026-10-19 §5.4、§20）。每个键都可以不写，不写时 Luban 用自己的默认。

| 键 | 类型 | 含义 | 不写时 |
|---|---|---|---|
| `tier` | 整数 1–4 | 桌面的轻重：T1 Compositor（只有窗口）、T2 labwc、T3 LXQt、T4 KDE Plasma；xdesk 不在这条轴上 | "未分级"，排在最后 |
| `gpu` | `"better"` / `"needed"` | 对宿主 GPU 的期望 | 不提示 |
| `title` | `{ en = "...", zh = "..." }` | 卡片上的名字；技术名词在各语言里都写英文 | 包名 |
| `summary` | `{ en = "...", zh = "..." }` | 卡片上的一行描述 | `description` |
| `size` | 整数（字节） | 创建它要下载的大小 | 不显示 |
| `highlights` | 程序名的列表 | 卡片上列出的几个程序 | 应用自带的文字 |

范围外的值按"没写"处理（`luban search --desktops -v` 说明忽略了什么）。`extensions` 不改变安装的内容，不提升 `revision`。

```lua
extensions = {
    luban = {
        tier = 3,
        title = { en = "LXQt", zh = "LXQt" },
        summary = { en = "Traditional: a panel, a desktop, a file manager and settings",
                    zh = "传统桌面：面板、桌面、文件管理器和设置" },
    },
},
```

## 规则

1. **已发布版本的输出永不改变。**
   `tests/fixtures/luban-published.json` 记录每个已发布版本写出的每个文件的 sha256 和权限位，
   `tests/test_luban_published.py` 比对。一个版本合入 `main` 时把它加进去：
   `LUBAN_PUBLISHED_ADD=pkgs/l/<recipe>.lua@<version> pytest -k add_published`。
   fixture 只增不改。
2. **用到新客户端字段的 edition 写 `min_client`。** 新字段设计成旧客户端忽略后仍然安全
   （`boot.profile` 被忽略时退回 `boot.kernel`）。
3. **每个 edition 都 `from` 一个官方层**（nano 除外），并写明 `abi`。
4. **新 edition 只引用 `luban-init`**；`xlings-init` 只为已发布的版本保留。
5. **更新频繁的工具不锁版本**（agent 的 CLI）：`subos new` 安装当时的最新版并记录在实例
   中，`luban upgrade` 再移动它。其余的包精确锁定。
6. **preview 的 edition**（`status = "preview"`）在 luban 中没有短名。
   桌面不是 edition：edition 预设一个，`luban new --desktop` 选另一个（包的 `categories` 含 `luban-desktop` 即被提供）。
7. **edition 只为它声明的架构构建。** `archs` 只列出启动并测试过的架构；它锁定的每个包在
   这些架构上都存在，`scripts/test-luban-editions.sh` 在 x86_64 和 aarch64 上运行。
8. **上层系统的包覆盖下层的同名程序。** edition 的包替换它所基于的 edition 里同名的程序：core 的 procps-ng 的 `ps`
   就是系统的 `ps`，而不是 tiny 的 BusyBox applet。它的自检确认这一点（只有 procps 支持 `ps -C`）。
9. **某个架构上拿不到的，edition 在那个架构上不带，并写明。** core 2026.10.19.1 是 tiny 加 bash、fish、vim、nvim、git、gh、
   mcpp、ninja、coreutils、gcc、binutils、make、openssl、xz、zlib、yazi 和 procps-ng，x86_64 上另有 cmake 和 xmake：
   上游不发布 linux aarch64 的 xmake，cmake 的图形库在本索引里只有 x86_64。
10. **每个官方桌面都带指针主题**（`luban:cursors`，经 `luban:labwc` 或 `luban:xdesk`）：任何底座加任何官方桌面都有默认光标主题
    （`tests/l/test_luban_desktop_extensions.py`）。
