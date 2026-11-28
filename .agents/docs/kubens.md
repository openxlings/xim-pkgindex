# kubens

`xim:kubens` 提供稳定版 `kubens` 命令，用于查询或切换当前 Kubernetes 上下文的命名空间。上游采用 Apache-2.0 许可证。[上游项目](https://github.com/ahmetb/kubectx)

## 来源

0.11.0 的六份 GLOBAL 归档来自上游 GitHub Release，覆盖 Linux、macOS 和 Windows 的 x86_64、aarch64。下载路径为 `releases/download/v<版本>/kubens_v<版本>_<系统>_<架构>.<扩展名>`。上游将 macOS 命名为 `darwin`，将 aarch64 命名为 `arm64`。Windows 使用 ZIP，其余平台使用 tar.gz。

六份归档的 SHA-256 均与发布的 `checksums.txt` 和 Release API 摘要一致。自动更新器按此矩阵检查 GLOBAL 资源。当前启用 `ci.mirror`，尚无单独配置的 CN 下载源。[发布归档和校验清单](https://github.com/ahmetb/kubectx/releases/tag/v0.11.0)

## 链接与安装

两个 Linux ELF 均为静态链接。两个 macOS 程序均使用系统的 libSystem、libresolv、CoreFoundation 和 Security。两个 Windows PE 的导入表都只有 kernel32.dll。包无需额外的运行时依赖。

归档根目录只有许可证和可执行文件。安装钩子将两者解压到版本目录，并检查都已就位。配置和卸载钩子分别注册和注销 xvm 命令。用户运行切换命令时，kubens 会更新 kubeconfig，并在缓存中记录当前上下文的上一次命名空间。

## 验证

在 Linux x86_64 上使用临时 HOME 和 XLINGS_HOME 注册、搜索、安装、重复安装并卸载。通过子系统命令验证版本，再以临时 kubeconfig 和缓存运行 `kubens second --force` 和 `kubens - --force`，每次通过 `--current` 检查结果。该操作无需连接集群。卸载后验证版本目录、注册和命令入口已清理。其余五个目标在本机验证了归档内容、架构和链接情况，未执行原生安装。

## 修订记录

- 2026-11-28 首次收录上游 0.11.0。
