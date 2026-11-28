# micro

micro 是稳定版终端文本编辑器，安装后可用 `micro` 打开和编辑文件。包名为 `xim:micro`，覆盖 Linux、macOS 和 Windows 的 x86_64 与 aarch64。

## 来源与更新

- GLOBAL 使用 micro 官方仓库的 MIT 许可发布包。六份归档的实测 SHA256 均与上游同名 `.sha` 文件、GitHub 发布资产摘要一致。[上游 2.0.15 版本](https://github.com/micro-editor/micro/releases/tag/v2.0.15)
- Linux x86_64 选择 `linux64-static`，aarch64 选择 `linux-arm64`。macOS 使用 `osx` 和 `macos-arm64`，Windows 使用 `win64` 和 `win-arm64`。
- 自动更新按六个目标各自的文件名检查新版本。配方启用合并后镜像，目前只声明 GLOBAL。

## 链接与安装

- 两份 Linux ELF 均为静态链接。两份 Mach-O 均链接 macOS 自带的 libSystem、libresolv、CoreFoundation 和 Security。两份 Windows PE 的导入表均只有 kernel32.dll。
- 所有归档均以 `micro-<version>/` 为顶层目录。安装钩子将目录内容放入版本目录，并校验可执行文件和两份许可证。上游自带的手册与文档一并保留。
- 配置钩子注册 `micro` 命令，卸载钩子移除其 xvm 注册。钩子只操作 xlings 管理的文件。

## 验证

在 Linux x86_64 上用隔离的 xlings 2026.11.23.1 安装 2.0.15，通过 xvm 命令在伪终端打开文件、输入文本、保存并退出，核对了文件内容。另验证了重复安装、列出内置插件、卸载、再次卸载和清除本地配方。其余五个目标在本地检查了归档结构、二进制架构和动态依赖。

## 修订记录

- 2026-11-27 首次添加 2.0.15，六个目标均使用上游发布的二进制包。
