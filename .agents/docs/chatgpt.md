# ChatGPT 桌面版

该包使用 OpenAI 官方固定版本资源，由 xlings 保存独立程序目录并切换启动入口。
提供 Linux x86_64 和 macOS ARM64；不提供 Windows、macOS Intel。
官方也有 Linux ARM64 deb，但 `glibc`、`gcc-runtime` 等基础包还没有 ARM64 payload，
所以配方暂不声明 Linux ARM64，等基础资源到位后再加。包状态为 `dev`。

当前收录 `26.924.22138` 和 `26.917.71314`，`latest` 指向前者。

## 使用

```sh
xlings install chatgpt@26.924.22138 --yes
xlings use chatgpt 26.924.22138
xlings list
chatgpt
```

其他索引的本地测试包需要使用搜索结果中的命名空间，例如 `local:chatgpt`。
切换前完全退出应用；运行中的实例不会随 xvm 切换，也可能接收后续启动的请求。
已安装版本通过 `xlings list` 查询；应用参数直接传给官方程序，不拦截或改写。

## 安装边界

- Linux 提取官方 deb 中的完整 `usr/lib/chatgpt`，不调用 dpkg、apt、dnf 或 pacman，不执行包内安装脚本，不配置系统软件源
- deb 是程序内容的分发容器；用户态运行库通过 xlings 的 deps 提供，不要求宿主安装 Debian 包管理器
- deb 的 ar、xz、tar 三层均由声明的 xlings `7zip` 解包；它只在 `install()` 里用，声明在 `deps.build`，不进用户的 PATH（`install()` 用 `pkginfo.build_dep("7zip")` 取路径，见 docs/contributing.md §5.5）
- macOS 使用官方 appcast 中的完整 ZIP，保留 `.app` 结构并在安装时检查版本和代码签名；不修改签名、不清除隔离属性、不覆盖 `/Applications`
- 通过 xvm 将 `chatgpt` 直接注册为 `ChatGPT` 二进制的别名；本包不修改全局 PATH、默认浏览器、URL 协议处理器或系统桌面入口
- 卸载删除该版本程序和 xvm 注册；不删除账号、配置、项目或会话数据

## Linux 发行版

官方预览版列出的环境为 Ubuntu 24.04/26.04、Debian 13、Fedora 43/44 和当前 Arch。
CachyOS 等 Arch 衍生发行版单独记录验证结果，不能视为官方支持承诺。
Alpine/musl 不在支持范围内。

Linux 运行库需要通过包的 `deps` 声明，由 xlings 安装和提供。
不提供要求用户自行补装发行版库的 `--check-deps` 命令。
配方声明 glibc、GCC、GTK 3、NSS/NSPR、AT-SPI、CUPS、ALSA、X11、Mesa、USB、TPM，
以及 Chromium 通过 dlopen 使用的 libsecret（系统密钥环存凭据，缺失时退化为明文存储）和 libnotify。
新增的运行库 payload 由 `.agents/tools/repack/repack.py` 从 conda-forge / Debian（snapshot.debian.org）
的固定构建重打包，发布到 xlings-res 的 GitHub 与 GitCode 两个镜像；安装期不解析 conda 或 deb 格式。
需要跟随安装目录的构建前缀（gtk3 的模块目录）记录在 payload 的 `RELOCATE.json`，
安装时由 `libs/relocate.lua` 改写；属于宿主的路径（CUPS 的 `/etc/cups` 和 socket、udev hwdb）
在重打包时就映射到宿主路径。
原生模块使用的内置 libvips 仍来自 ChatGPT 自身资源：它的目录写在 `exports.runtime.libdirs`，
elfpatch 会把它放在包内每个 ELF 的 RUNPATH 最前面。
gtk3 在安装时把 GSettings schema 编译进 payload，再声明到 `<subos>/share/glib-2.0/schemas`；
`graphics.consumer_envs()` 给出的 `XDG_DATA_DIRS` 已包含 `<subos>/share`，因此不再设置 `GSETTINGS_SCHEMA_DIR`。
Pango 补充 glibc 依赖以启用 elfpatch，并提高配方 revision。

新增运行库都同时发布了 x86_64 和 ARM64 payload；Linux ARM64 仍缺 glibc 加载器、GCC 及部分图形基础库，
不能把资源存在、安装成功或静态检查通过当作桌面运行验收。
内核、显示服务、设备驱动和桌面会话仍属于宿主边界，不通过关闭 sandbox 绕过安全策略。

## 不带 Qt UI 集成

官方 deb 里的 `app/libqt5_shim.so`、`app/libqt6_shim.so` 是 Chromium 的 Qt UI 集成，`ChatGPT` 按
`libqt%d_shim.so` 的名字 dlopen 它们，版本来自 `--qt-version` 或 `KDE_SESSION_VERSION`，
**只在 KDE 会话或显式传 `--ui-toolkit=qt` 时才会加载**；其他桌面一律走 GTK，而 gtk3 本来就是
`ChatGPT` 的 DT_NEEDED。为这两个 shim，闭包里要多 10 个包（`qt5`、`qt-base`、`brotli`、`zstd` 和
六个 `xcb-util*`），约 620 MB，而应用本体是 1.5 GB。

所以 `install()` 删掉这两个文件，`deps` 里没有 `qt5`、`qt-base`：KDE 用户得到 GTK 外观，
而不是原生 Qt 对话框，换来每个用户少装 10 个包（新 home 上的安装计划 89 → 79 个包）。
同一版本的 `revision` 增为 1，已安装的旧 payload 在下次安装时被替换，此后 `qt5` 和 `qt-base`
可以被回收。

“shim 缺失时回退到 GTK 而不是崩溃”由 `.github/workflows/chatgpt-runtime.yml` 的
`chatgpt-launch.sh` 在虚拟 X 服务器上验证：默认、`XDG_CURRENT_DESKTOP=KDE KDE_SESSION_VERSION=6`、
`--ui-toolkit=qt` 三种启动都要求应用保持运行 30 秒，且进程里没有映射任何 Qt 库；
`chatgpt.sh` 另检查载荷里没有 `libqt*_shim.so`。如果以后要恢复 KDE 下的 Qt 外观，
只需要 `libqt6_shim.so` 和 `qt-base`（`qt5` 是 Plasma 5 才用），不需要恢复两者。

## ELF 处理

应用自带若干静态链接的辅助程序：codex app-server、`codex-code-mode-host`、`node_repl`、`rg`、`tectonic`。
自动 elfpatch 会给没有解释器的 ELF 也写 RPATH，这会损坏 static-pie（运行即 core dump）。
所以配方在 `install()` 里调用 `elfpatch.skip()` 关闭自动 patch，改为只给动态链接的 x86_64 ELF
（带 `PT_INTERP` 或 `DT_NEEDED` 的文件）设置 loader 和依赖闭包；静态程序和其他架构的 prebuild 保持原样。
libxpkg 修好后（openxlings/libxpkg#43），这段接管代码可以删掉。
`.github/workflows/chatgpt-runtime.yml` 会真正运行装出来的辅助程序，并检查动态库全部解析在 xlings 内。

## Chromium 沙箱与 AppArmor

官方 deb 的 postinst 会安装 `/etc/apparmor.d/chatgpt`，允许 `/usr/lib/chatgpt/ChatGPT`
创建用户命名空间，Chromium 沙箱需要这个权限。该 profile 按路径绑定，覆盖不到 xlings 的安装目录。
安装时会为当前版本生成同样内容、路径指向本版本的 profile：
`<版本目录>/share/apparmor/xlings-chatgpt`。在限制非特权用户命名空间的宿主上
（`cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns` 输出 1，Ubuntu 23.10 起默认如此），
需要由用户以 root 加载一次：

```sh
# 以 root 执行；v 为已安装版本，路径按实际 XLINGS_HOME 调整
v=26.924.22138
install -m 0644 ~/.xlings/data/xpkgs/xim-x-chatgpt/$v/share/apparmor/xlings-chatgpt /etc/apparmor.d/xlings-chatgpt-$v
apparmor_parser -r /etc/apparmor.d/xlings-chatgpt-$v
```

xlings 不执行任何 root 操作，也不替用户加 `--no-sandbox`。安装钩子的输出在成功时不会显示给用户，
所以提示放在启动时：`chatgpt` 命令是安装生成的 `bin/chatgpt` 启动脚本。宿主限制了用户命名空间、
且本版本的 profile 没有加载（`/sys/kernel/security/apparmor/policy/profiles/*/name` 里没有
`xlings-chatgpt-<版本>`）时，它打印两种做法并以 1 退出，而不是让 Chromium 报
`No usable sandbox!` 后崩溃：一是 profile 的内容和可直接复制执行的 `sudo` 命令（带实际路径），
二是 `chatgpt --no-sandbox`（无需 root，但关闭渲染进程隔离）。用户自己传的 `--no-sandbox`
原样放行。profile 按版本绑定路径，
升级后需要为新版本再加载一次。

## 代理

Chromium 在 GNOME 会话里读桌面的系统代理（`org.gnome.system.proxy`），不读 `https_proxy`
这类环境变量。系统代理为“关闭”而只在 shell 里导出了代理变量时，界面会停在图标和转圈，日志里是
`accountsHttpStatus=0` 和 `Timed out while fetching post-login Statsig bootstrap`。官方 deb
在同一宿主上表现相同。在系统设置里打开网络代理，或启动时指定：

```sh
chatgpt --proxy-server=http://127.0.0.1:7897
```

## 宿主边界

打开链接用的 `xdg-open`（官方依赖 `xdg-utils`）、桌面会话的无障碍总线、密钥环守护进程、
通知守护进程和 cupsd 都由宿主桌面提供；本包只提供它们的客户端库。

## 更新和版本数据

xvm 为该应用进程设置 `CODEX_SPARKLE_ENABLED=false`，关闭所收录版本的内置更新器。
此开关来自已检查的应用实现，不是稳定公开 API；每次收录新版本都必须重新确认其语义。
直接启动内部二进制或双击 `.app` 会绕过 xvm，因此不受该开关约束。
安装时校验资源 SHA256 和包内版本；不添加逐次启动时的宿主元数据解析。

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

首轮实测覆盖隔离 `XLINGS_HOME` 中的 CachyOS x86_64 两版本安装、切换和卸载。
首轮 CI 覆盖 Linux x86_64、macOS ARM64 的 latest 安装和卸载。
改为 xvm 直接启动后的验证以对应提交的 CI 和测试结果为准。
本轮在隔离 home 实装新增依赖，使用 xlings 加载器检查主程序和当前架构的 glibc 原生模块。
`pytest tests/c/test_chatgpt.py -m verify` 可复验已安装版本的库解析；检查禁止宿主库兜底，跳过归档内不属于当前 glibc 平台的预构建模块。
GUI 登录、Linux ARM64 运行和跨发行版桌面兼容性仍未完成验收。

## 官方资料

- [Linux 安装说明](https://learn.chatgpt.com/docs/linux/linux-app)
- [macOS 更新清单](https://persistent.oaistatic.com/codex-app-prod/appcast.xml)
- [应用更新策略](https://learn.chatgpt.com/docs/enterprise/manage-app-updates)
