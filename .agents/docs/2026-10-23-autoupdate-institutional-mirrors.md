# 常用包与 xlings-res 的机构镜像调研

日期：2026-10-23。范围：现有常用包，包括使用 xlings-res 的包，不要求所有包统一迁移。
这是调研与迁移建议；本次没有修改包声明、历史版本、hooks 或生产调度。

## 结论与接入原则

可以使用更多可信机构的镜像，不限于 USTC/清华，也不限于当前 GLOBAL-only 包。
历史使用 xlings-res 不是排除条件；若机构镜像提供更新、完整、适用的上游原版资产，后续版本可以改用
`source = 上游版本目录`、`GLOBAL = 上游资产`、`CN = 已核实镜像资产`。不能继续从旧 xlings-res
仓库发现版本，否则只更换 CN 下载模板仍会被旧发布版本限制。

这里验证的是**同一候选版本**的 GLOBAL/CN 字节一致，不要求新版本的 hash 与旧版本相同。
既有 xlings-res 版本块、手工补充、历史镜像与 latest 策略保持不变。必需资源默认 true；
包可以显式配置 optional，选择所有必需目标完整可用的最新版本交集。

必须区分原版转存、重打包、工具链拆分：原版资产可以直接迁移；改过顶层目录、ABI、依赖或组件的包，
要先适配并验证安装流程，不能只换下载地址。仅提供源码或发行版 deb/rpm 的镜像不等于适用的独立二进制。
机构归属、同步状态、真实资产和持续可用性分开评价；本次成功不是长期 SLA 证明。

## 本次实际验证通过的优先项

| 包 | 当前索引 | 新镜像候选 | 覆盖与结果 | 迁移动作 |
|---|---|---|---|---|
| 7zip | 26.02，自动更新 GLOBAL-only，历史使用过 xlings-res | NJU 26.05 | Linux x64/ARM64、macOS universal、Windows x64/ARM64；5 对资产完整下载，逐对 SHA256 一致 | 增加 CN 版本路径模板，保留现有 GitHub source/GLOBAL |
| Neovim | 0.12.5，GLOBAL 为上游，CN 为 GitCode xlings-res | NJU 0.12.6 | Linux x64/ARM64、macOS x64/ARM64、Windows x64；5 对资产完整下载，逐对 SHA256 一致 | 新候选的 CN 改用 NJU，避免等待 GitCode 补发；旧版本 CN 不改 |

合计完整下载 **125,720,846 bytes**，10 对资产全部一致。CN 最终响应均为 HTTPS NJU 主机，未跳回 GitHub。
随后在本地临时索引中，仅替换自动更新 CN 模板，使用现有 xpkgindex-update 对两包分别执行真实 check/apply：
均返回 update-ready 并成功追加 26.05 / 0.12.6，固定计划分别下载 16,047,678 / 109,673,168 bytes，
两包均通过 published history guard。未修改生产索引配方，未创建版本提案 PR。
这证明两组模板可以直接用于当前工具；安装/功能/卸载仍应在候选 PR 的各平台 runner 验证。

实际目录按 release **标题**命名，并非统一使用 tag：

- [7zip 26.05](https://mirrors.nju.edu.cn/github-release/ip7z/7zip/7-Zip%2026.05/)
- [Neovim 0.12.6](https://mirrors.nju.edu.cn/github-release/neovim/neovim/Nvim%200.12.6/)

对应 CN 模板可直接从现有 GLOBAL 矩阵替换前缀：

```text
7zip:
  https://github.com/ip7z/7zip/releases/download/${version}/
  -> https://mirrors.nju.edu.cn/github-release/ip7z/7zip/7-Zip%20${version}/
  文件名仍使用 7z${version:compact}-linux-x64.tar.xz 等现有规则。

Neovim:
  https://github.com/neovim/neovim/releases/download/v${version}/
  -> https://mirrors.nju.edu.cn/github-release/neovim/neovim/Nvim%20${version}/
  文件名仍使用 nvim-linux-x86_64.tar.gz 等现有规则。
```

不使用 `LatestRelease` 作为持久资源地址，因为它会随下一次发布改变。部分镜像只保留新版本，
每次更新仍需重新核实候选，不根据目录存在就认定未来版本可用。

## 常用包中已找到较新资源、需要适配的项目

以下只核实目录/元数据与文件名，尚未完成所有资产的完整下载、hash 和原生安装验证。

| 包 | 索引状态与可用镜像 | 已发现的较新资源 | 为什么还不能直接切换 |
|---|---|---|---|
| mingw-gcc | 当前 xlings-res 16.1.0；[NJU WinLibs](https://mirrors.nju.edu.cn/github-release/brechtsanders/winlibs_mingw/) | GCC 16.2.0 + MinGW-w64 14.0.0，多个 UCRT/MSVCRT、LLVM、revision 组合 | 当前重打包把 mingw64 顶层目录重命名，install hook 依赖该目录；上游标签还有 GCC/CRT/revision 多个变化维度，不能仅按 GCC 版本猜唯一资产 |
| Python | 默认 3.13.12，历史还含 3.15.0；[NJU standalone](https://mirrors.nju.edu.cn/github-release/astral-sh/python-build-standalone/) 与 [npmmirror standalone](https://registry.npmmirror.com/-/binary/python-build-standalone/) | 构建 20261021；已列出 CPython 3.13.17 多平台 install_only 资产 | CPython 版本与 standalone 日期不同，一次构建包含多个 CPython 版本；当前工具不能从构建标签直接推断包版本，macOS 当前安装来源也需单独对齐 |
| Bun | 当前 1.3.11，通过 npm 安装；[npmmirror Bun](https://registry.npmmirror.com/-/binary/bun/bun-v1.4.4/) | 1.4.4，目录列出 Linux/macOS/Windows x64、ARM64 ZIP | 可迁移为直接下载，但当前 hooks 使用 npm/node_modules 布局；需要改为直接安装二进制并做原生验证 |
| Git | Windows 2.51.1，Linux 2.53.0-1 自建静态版；[NJU Git for Windows](https://mirrors.nju.edu.cn/github-release/git-for-windows/git/)、[npmmirror](https://registry.npmmirror.com/-/binary/git-for-windows/) | NJU 2.56.0.windows.2；npmmirror 还列出 .windows.3 | Windows PortableGit/MinGit 与当前重打包布局需适配；Windows 版本不代表 Linux 静态构建也有该版本。当前自动更新的跨平台统一版本要求仍需处理 |
| Node / Go / Gradle | 已有上游 + USTC/NJU/腾讯镜像接入 | [华为云 toolkit](https://mirrors.huaweicloud.com/repository/toolkit/) 还提供 nodejs、go、gradle 目录，适合作为替代候选站点 | 目录可达不等于完整资产已通过验证；本次只核实 Gradle 9.8.2 sidecar 可达。现有资源声明每区只支持一组模板，尚无同一区域多站点自动选择 |
| Rustup | 当前已使用 USTC | 北外有官方 Rustup 帮助文档 | 本次请求 `/rustup/` 根目录返回 404；这不能证明具体资产缺失，也不能把帮助页当成资产验证结果 |

LLVM slim/tools、libllvm、Git Linux 静态构建等属于自建/拆分链路。
例如 [NJU LLVM](https://mirrors.nju.edu.cn/github-release/llvm/llvm-project/) 虽有更新版本目录，
也不能直接认定它覆盖索引的 slim、tools、开发库和 sysroot 布局。
[北外说明](https://mirrors.bfsu.edu.cn/help/github-release/)明确指出其 LLVM Release 镜像仅含源码。
CMake/Ninja 等项目本轮未核实到适合当前完整矩阵的新机构镜像；搜索命中的发行版包或 HarmonyOS 构建不等于上游独立发行资产。

## 可用的机构与服务目录

| 站点 | 本次核查 | 对自动更新的意义 |
|---|---|---|
| [NJU](https://mirrors.nju.edu.cn/github-release/) | 目录除 TUNA 常见项目外，还包括 ip7z/7zip、neovim、WinLibs、python-build-standalone 等 | 本轮最明确的新增覆盖，已有 7zip/Neovim 完整字节验证 |
| [BFSU](https://mirrors.bfsu.edu.cn/help/github-release/) | 提供精选 GitHub Release；例如 deno v2.9.8 目录有六种常见平台/架构 ZIP | 可用，但不是任意 GitHub 仓库的通用代理；与 TUNA 有共同维护团队，不能据此假设完全独立故障域 |
| [中科院软件所 ISCAS](https://mirror.iscas.ac.cn/github-release/) | 有精选项目；实际 PowerShell 目录停留在 v7.4.10，本索引尚无 PowerShell 主程序包 | 可列候选站点，但应按项目检查时效；不能因机构知名就认为总有最新版 |
| [华为云](https://mirrors.huaweicloud.com/repository/toolkit/) | 工具二进制目录包括 Node、Go、Gradle、Git for Windows、Python、Electron 等 | 适合已有 HTTPS URL 模型；新增 CN 主机前要更新索引准入策略并完成具体资产验证 |
| [npmmirror/cnpm](https://github.com/cnpm/binary-mirror-config) | 官方文档提供 JSON 元数据与 CDN；本次目录列出 99 类二进制项目，包括 Bun、standalone Python、Git for Windows | 优先使用实际下载地址而非 JSON 列表地址；ripgrep-prebuilt 来自 microsoft/ripgrep-prebuilt，不能默认等同本索引 BurntSushi/ripgrep 原版资产 |
| [SJTUG](https://mirror.sjtu.edu.cn/docs) | GNU 等专门资源镜像可达；`/github-release/` 返回 No route | 可以逐类使用其资源；不能拼通用 GitHub 前缀。部分端点带 Cerberus 挑战，必须核实自动化客户端下载到真实资产 |
| [SUSTech](https://mirrors.sustech.edu.cn/) | 本次 `/github-release/` 最终跳到 HTTP TUNA | 不作为独立已验证 CN；采用明确 HTTPS 原站模板并重新验证 |
| [阿里云](https://developer.aliyun.com/mirror/) | 有 GNU、Apache、Rust、发行版、包管理器等目录 | 可作项目候选，发行版仓库存在不能证明可直接替代现有独立归档 |

NJU 的 `AnInsomniacy/` 实际仅列出 **motrix-next**，请求 `aria2-next/` 为 404。
同一个 owner 有镜像不等于其每个仓库都被镜像，不能把 aria2-next 加上猜测地址。

## 工具支持、准入和后续迁移

当前 xpkgindex-update 支持上述公开 HTTPS 资源模板，不要求资产主机与 source 主机相同。
版本发现当前识别 GitHub releases/tags；机构镜像可只承担下载，不必扩展发现模式。
NJU/BFSU/SJTUG 已在索引 CN 主机准入集合；ISCAS、华为云和 registry.npmmirror.com 尚未在该集合，
接入需要索引层审核，工具本身不需增加每站专用 adapter。cdn.npmmirror.com 已在集合。
同一个 CN 目前只声明一个 URL/矩阵，多镜像候选和自动优选仍是后续能力，不宣称已经支持。

迁移顺序建议：7zip、Neovim（已验证）→ Bun、WinLibs（布局/版本身份适配）→ Python、Git（版本发现模型适配）。
不要为了绕过解析器，把未知 source 或不一致的版本强行声明为已支持；也不应因为 xlings-res 滞后就放弃使用已验证的新镜像。
MirrorZ/CERNET 可辅助发现站点与同步状态，但不代替每个候选资产验证，也不将自动跳转地址直接固化到版本资源：
[MirrorZ 协议](https://github.com/mirrorz-org/mirrorz)、[CERNET 帮助](https://help.mirrors.cernet.edu.cn/)。

## 验证记录与复现

原始 HTML/JSON、逐文件 SHA256、探测脚本与临时索引保留在本地 `/tmp/xim-mirror-expansion/`，不加入 PR。
其中 `hash-pairs.json` 有原始固定 URL、字节数、SHA256 和最终主机，未保存下载签名查询串。
如需复现，将上述版本和 URL 分别完整下载，用 SHA256 比对两侧；再把本文 CN 前缀应用于临时索引的现有完整矩阵，
使用 workflow 固定工具运行 check/apply。不要直接修改历史版本测试镜像。

### 本次完整下载的 hash

| 包 / 资产 | 单侧字节数 | SHA256（GLOBAL = CN） |
|---|---:|---|
| 7zip / `7z2605-linux-arm64.tar.xz` | 1317128 | `0b71f6cfc34669b3bf69f2347efd3429f77020665003a13b9cdc53b784270421` |
| 7zip / `7z2605-linux-x64.tar.xz` | 1579976 | `22cf82fcc6eb7474f1d5bb4f02c0f8ebd573a718089d6833dc30f8350a3b232e` |
| 7zip / `7z2605-mac.tar.xz` | 1868068 | `12ef6830317743cfd3f0ab1724bde43fcc270d8b6d8564f8c12c2a2b7f993570` |
| 7zip / `7z2605-arm64.exe` | 1595161 | `86d5790d5dd84cab4636c3bb7fab10d3ed7cd3e57e6119401bd2769e28165268` |
| 7zip / `7z2605-x64.exe` | 1663506 | `fd99e86f57d8f429ef5ed045bf98315af962e2309b0f1ba87a147a44c71647d0` |
| nvim / `nvim-linux-arm64.tar.gz` | 11367117 | `8f1f64a0bdb97247034038c3823c6cbad5bdf9ecd5751b85494b71c3ee04c815` |
| nvim / `nvim-linux-x86_64.tar.gz` | 11404582 | `474430d53e6264f6d6dd18db42d6dc9df3a1b56ca9e88a325bbf860e1a811d87` |
| nvim / `nvim-macos-arm64.tar.gz` | 9595887 | `1dbd148222b051ba6c307c4d17a318ed083df018a4f6a5a0ce46955ffc9ab87b` |
| nvim / `nvim-macos-x86_64.tar.gz` | 9844257 | `481424f1dbc85f637d57e47d27d042aa9c883e5a4fe9ee64fc4ee9573b221998` |
| nvim / `nvim-win64.zip` | 12624741 | `4e12b7103b601ffc8f25954b4da100f339faa73dccb69a5b135e897fa3d893ed` |
