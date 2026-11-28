# broot

`xim:broot` 提供稳定版终端文件浏览器 `broot`，可交互搜索、预览文件和打印目录树。

## 来源与平台

- 上游为 [Canop/broot](https://github.com/Canop/broot)，许可证为 MIT。
- 上游在[正式发行页](https://github.com/Canop/broot/releases/tag/v1.62.0)为多个平台发布同一个 ZIP。GLOBAL 模板为 `https://github.com/Canop/broot/releases/download/v${version}/broot_${version}.zip`。
- 版本 1.62.0 的归档 SHA-256 为 `13630ae5d3b011ddc81fca05cb80dbee6189dad3ba393dd477f5f687c7b5106d`。单独下载与 xlings 安装缓存中的归档均与 GitHub Release 资产摘要一致。
- 支持 Linux x86_64、Linux aarch64、macOS aarch64 和 Windows x86_64。上游未发布 macOS x86_64、Windows aarch64 程序。
- 自动更新跟踪 GitHub Releases，按各平台实际支持的架构声明 URL。当前使用 GLOBAL 下载并启用 `ci.mirror`。

## 链接与安装

两个 Linux 程序取自 musl 目录，均为静态 ELF，无动态段。macOS 程序使用系统框架与系统动态库。Windows GNU 程序仅导入系统 DLL 和系统提供的 UCRT API。各平台都只需 `xim:7zip` 作为构建依赖。

安装时，7-Zip 把当前目标的单个程序直接提取到包目录。CI 固定版本客户端的安装钩子没有提供 `os.arch()`，因此 Linux 上读取解析器已选定的 `7zz` 的 ELF 机器类型，选择同架构的 musl 程序。默认配置与 `br` 函数均已嵌入可执行文件。

配置和卸载只注册、移除 xvm 的 `broot` 命令。是否启用上游提供的 `br` shell 集成由用户在运行程序时决定。

## 验证

在隔离的 Linux x86_64 环境中，已通过 xlings 2026.11.23.1 安装，并确认程序与原归档字节一致。通过 xvm 导出了默认配置，用 `:pt` 打印含嵌套文件的测试目录树。重复安装、卸载后重装、重复卸载及覆盖项清理均已验证。其余三个目标在 Linux 上检查了归档内容、可执行文件格式和动态依赖，未原生运行。

## 修订记录

- 2026-11-28 — 新增 1.62.0，按四个受支持目标选择可执行文件。
