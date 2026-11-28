# oh-my-posh

Oh My Posh 是可自定义的 shell 提示符引擎。稳定版包 `xim:oh-my-posh` 提供同名命令，支持 Linux、macOS 和 Windows 的 x86_64、aarch64 架构。[上游项目（MIT）](https://github.com/JanDeDobbeleer/oh-my-posh)

## 发布文件

GLOBAL 采用官方 GitHub Release 的单文件程序。文件名为 `posh-{linux,darwin,windows}-{amd64,arm64}`，Windows 文件带 `.exe` 后缀。六个文件的 SHA256 均与上游 `checksums.txt` 和发布 API 摘要一致。[v33.4.1](https://github.com/JanDeDobbeleer/oh-my-posh/releases/tag/v33.4.1)

自动更新覆盖这六个文件。配方声明 `ci.mirror = true`，由仓库在合并后镜像；当前下载地址来自上游。

## 依赖和安装

两个 Linux ELF 均为静态程序。两个 macOS 程序均依赖系统提供的 libSystem、libresolv、CoreFoundation 和 Security。两个 Windows 程序的 PE 导入表均只有 kernel32.dll。各平台都无需额外的 xim 运行时依赖。

安装时将单文件复制为包目录内的 `oh-my-posh` 或 `oh-my-posh.exe`，并在 Unix 系统上赋予执行权限。配置钩子通过 xvm 注册命令，卸载钩子注销命令。字体、额外主题和 shell 初始化由用户自行选择。

## 验证

在 Linux x86_64 的临时 HOME 和 XLINGS_HOME 中，用 xlings 2026.11.23.1 注册并安装包，确认提示符命令报告 33.4.1，用本地配置渲染纯文本提示符并导出 JSON。重复安装后卸载，确认命令入口已清理。其余五个目标在本机进行了架构、链接依赖和摘要检查。

## 修订记录

- 2026-11-27 新增 33.4.1，收录三个平台的核心程序。
