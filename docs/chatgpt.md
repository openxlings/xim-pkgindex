# ChatGPT 桌面版

该包使用 OpenAI 官方固定版本资源，由 xlings 保存独立程序目录并切换启动入口。
支持 Linux x86_64、ARM64 和 macOS ARM64；不提供 Windows 或 macOS Intel 资源。
包状态为 `dev`，平台声明表示有对应资源，不代表所有桌面环境已完成验收。

当前收录 `26.924.22138` 和 `26.917.71314`，`latest` 指向前者。

## 使用

```sh
xlings install chatgpt@26.924.22138 --yes
xlings use chatgpt 26.924.22138
chatgpt --version
chatgpt --check-deps
chatgpt
```

其他索引的本地测试包需要使用搜索结果中的命名空间，例如 `local:chatgpt`。
切换前完全退出应用；运行中的实例不会随 xvm 切换，也可能接收后续启动的请求。
`--version` 读取应用元数据，不启动 GUI，也不把 Electron 的版本号当作 ChatGPT 版本。

## 安装边界

- Linux 提取官方 deb 中的完整 `usr/lib/chatgpt`，不调用 dpkg、apt、dnf 或 pacman，不执行包内安装脚本，不配置系统软件源
- deb 是程序内容的分发容器；是否能运行取决于宿主 glibc、桌面库和安全策略，而不是宿主是否使用 dpkg
- 解包工具通过 xlings 的 `7zip` 依赖提供，宿主还需提供 tar
- macOS 使用官方 appcast 中的完整 ZIP，保留 `.app` 结构并在安装时检查版本和代码签名；不修改签名、不清除隔离属性、不覆盖 `/Applications`
- 通过 xvm 注册 `chatgpt` 启动器；本包不修改全局 PATH、默认浏览器、URL 协议处理器或系统桌面入口
- 卸载删除该版本程序和 xvm 注册；不删除账号、配置、项目或会话数据

## Linux 发行版

官方预览版列出的环境为 Ubuntu 24.04/26.04、Debian 13、Fedora 43/44 和当前 Arch。
CachyOS 等 Arch 衍生发行版单独记录验证结果，不能视为官方支持承诺。
Alpine/musl 不在支持范围内。

`chatgpt --check-deps` 显示发行版和 glibc，并检查程序中的 ELF 文件，报告缺失的库名称。
检查使用宿主 `/usr/bin/ldd`，避免 PATH 中 xlings 的 glibc 工具造成误报，并排除包内 musl 备用模块。
此命令不安装系统依赖，也不会修改 AppArmor、SELinux、用户命名空间或 sandbox 权限。
静态 ELF 检查不等于动态加载、GPU、音频、密钥环、portal 或完整桌面功能通过。
包内可选组件也可能报告缺失库，需要结合实际功能判断。

依赖包的名称由发行版决定：

| 环境 | 常见依赖名称示例 |
| --- | --- |
| Ubuntu / Debian | `libgtk-3-0` 或发行版的 t64 对应包、`libnss3`、`libgbm1`、`libsecret-1-0`、`libssl3`、`libtss2-*` |
| Fedora | `gtk3`、`nss`、`mesa-libgbm`、`libsecret`、`openssl-libs`、`tpm2-tss` |
| Arch / CachyOS | `gtk3`、`nss`、`mesa`、`libsecret`、`openssl`、`tpm2-tss` |

这些名称是诊断提示，不是已验证的完整安装命令或依赖闭包。
Ubuntu 的 AppArmor 规则可能绑定系统安装路径，移到 xlings 目录后需重新验证用户命名空间授权。
Fedora 需要验证 SELinux 下用户目录中的执行行为。不能通过默认添加 `--no-sandbox` 绕过这些检查。
Wayland 按官方默认使用 XWayland；需要原生 Wayland 时可以显式传入 `--ozone-platform=wayland`。

## 更新和版本数据

启动器为该应用进程设置 `CODEX_SPARKLE_ENABLED=false`，关闭所收录版本的内置更新器。
此开关来自已检查的应用实现，不是稳定公开 API；每次收录新版本都必须重新确认其语义。
直接启动内部二进制或双击 `.app` 会绕过启动器，因此不受该开关约束。
启动器同时检查包内版本是否与登记版本一致，发现变化时失败并要求重新安装。

多个程序版本默认继续使用应用自己的数据位置；程序隔离不等于账号和数据隔离。
本包不迁移或回滚用户数据，旧版本读取新版本写入的数据仍可能不兼容。
旧版能否继续连接 OpenAI 服务也不由 xlings 保证。

## 资源维护

- Linux 固定 URL 来自官方 Debian 仓库，逐架构校验 SHA256
- macOS 固定 URL 来自官方 appcast，完整下载后计算 SHA256，并保留官方签名
- `latest` 仅引用明确版本，不能把持续变化的下载链接绑定到固定版本
- 不自动复制到第三方镜像；官方资源使用专有许可
- 不启用当前面向 GitHub Releases 的自动升级扫描

## 验证记录

已在隔离的 `XLINGS_HOME` 中验证 CachyOS x86_64 上两个官方版本的安装和入口切换。
宿主 ELF 检查报告缺少可选 Qt 5 shim 所需的 Qt 5 库；这不是完整 GUI 运行证明。macOS、Linux ARM64 和其他发行版的真实桌面测试尚未完成，
不得把静态测试、资源存在或命令输出版本号当作这些平台的 GUI 验收通过。

## 官方资料

- [Linux 安装说明](https://learn.chatgpt.com/docs/linux/linux-app)
- [macOS 更新清单](https://persistent.oaistatic.com/codex-app-prod/appcast.xml)
- [应用更新策略](https://learn.chatgpt.com/docs/enterprise/manage-app-updates)
