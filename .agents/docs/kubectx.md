# kubectx

`xim:kubectx` 提供稳定版 `kubectx`，用于列出、查看和切换 kubeconfig 中的 Kubernetes 上下文。

## 来源和平台

上游项目使用 Apache-2.0 许可证。Linux、macOS 和 Windows 均支持 x86_64 和 ARM64。[上游发布页](https://github.com/ahmetb/kubectx/releases/tag/v0.11.0)

GLOBAL 使用上游发布的 `kubectx_v<版本>_<系统>_<架构>` 归档。macOS 对应 `darwin`，ARM64 对应 `arm64`。Windows 使用 ZIP，其他系统使用 tar.gz。六份下载的 SHA-256 均与发布页的 `checksums.txt` 及 GitHub API 摘要一致。

`extensions.autoupdate` 跟踪 GitHub Releases，三个平台的 `latest` 均指向 0.11.0。包声明 `ci.mirror = true`，目前只配置 GLOBAL。

## 依赖和安装

两种 Linux ELF 均为静态链接。两种 macOS 程序均链接系统的 libSystem、libresolv、CoreFoundation 和 Security。两种 Windows 程序的 PE 导入表只列出 kernel32.dll。通过参数选择上下文可独立运行；交互选择器 fzf 是可选工具。

安装钩子将归档直接解压到版本目录，检查命令和 LICENSE。配置和卸载钩子分别注册和移除 xvm 命令。只有用户执行切换命令时，kubectx 才会修改 kubeconfig 并记录上一个上下文。

## 验证

在 Linux x86_64 的隔离环境中，使用 `xlings 2026.11.23.1` 验证了注册、搜索、安装、重复安装、卸载、重复卸载和删除本地包定义。通过子系统入口在临时 kubeconfig 中切换两个上下文并切回，卸载后检查了入口和注册记录。其余五个构建在本地只核对了归档、架构和链接信息。

## 修订记录

- 2026-11-27 新增 0.11.0 版本。
