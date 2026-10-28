# openkal 程序

[English](../14-openkal-programs.md) | **简体中文**

为 ok 映像目标（`x86_64-openkal`、`aarch64-openkal`）构建的程序，每个架构一个映像；同一个映像经加载器
`okrun` 在 Linux、macOS、Windows 上运行。配方因此只陈述一次：一个资产对应所有系统。参照的配方是
`pkgs/o/okrun.lua`（加载器）与 `pkgs/m/mcpp-ide.lua`（程序）。

## 资产

在 openkal-platform 上执行 `mcpp pack --target <arch>-openkal` 写出**通用包**
（[mcpp SPEC-014](https://github.com/mcpp-community/mcpp/blob/main/docs/specs/packaging.md)）：
一个归档，单一顶层目录，包含

| 路径 | 内容 |
|---|---|
| `lib/<arch>/<name>.oke` | 每个架构的映像 |
| `bin/<name>`、`bin/<name>.cmd` | 启动器：选择本机架构并启动 `okrun` |
| `libexec/okrun/<os>-<arch>/` | 每个系统的加载器，仅 `--mode self-contained` 的包携带 |
| `mcpp-package.json` | 包的描述：腿、系统、启动方式、每个文件及其 sha256 |

归档对每个系统都是同一个文件，因此 sha256 只有一个值。

## 配方

- `archs` 写出包中映像的架构。
- `linux`、`macosx`、`windows` 三个表写同一个 URL 与同一个 sha256。
- 不携带加载器的包在每个表中依赖它：`deps = { "xim:okrun" }`；`--mode self-contained` 的包携带其所列每个系统的加载器，
  无依赖。
- `install()` 把归档的唯一顶层目录移到安装目录；`config()` 以 xvm 注册启动器：`bindir` 为 `bin/`，
  Windows 上命令为 `.cmd` 启动器（`alias = "<name>.cmd"`）。

`mcpp emit xpkg --package <归档> --url <发布前缀>` 由 `mcpp-package.json` 写出以上部分；配方补上索引陈述而包
不陈述的内容（作者、许可证、CN 镜像、版本历史）。

## 加载器

`okrun` 是每个系统与架构的加载器程序，由 openkal-image 的 `release binaries` 工作流在 openkal-platform
的托管安排上构建（Linux 为静态，macOS 不需要 SDK，Windows 不需要 MSVC 运行时）；ok 映像的链接与打包工具 `okld`
以同样方式构建与描述。每个配方按系统分表，每个架构一个资产与一个 sha256，覆盖工作流构建的行（`linux-x86_64`、
`linux-aarch64`、`macos-aarch64`、`windows-x86_64`），由 `mcpp emit xpkg --package` 从四个归档写出。

包不是通用包的程序（每个系统一个归档，例如 `mcppls`，其载荷携带一个系统的 clangd）保持按系统分表的配方。

## 资源

GLOBAL 为上游发布；CN 为 `gitcode.com/xlings-res/<package>` 上的相同字节（以 `gtc release upload` 上传并经下载
校验），一个 sha256 同时服务两个区域。
