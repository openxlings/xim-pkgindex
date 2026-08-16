# xim-pkgindex: MSVC 工具链包设计方案

> 状态: **已 review，待实施**（尚未落地任何 `.lua`）— review 结论见 §11
> 日期: 2026-08-16
> 目标: 让 MSVC 成为 **xlings 生态内的 payload 包** —— 不装到 C 盘、支持多版本共存、纯命令行获取，
> 与 `gcc.lua` / `llvm.lua` 同范式。
>
> 触发来源: Sunrisepeak/xrgui#3（用 mcpp 给 xrgui 加 Windows/MSVC 构建）。那个 PR 为了让 mcpp 用上
> 指定的 MSVC，不得不在 CI 里**把 `vswhere.exe` 挪开**——本方案要消掉的正是这类 workaround。

---

## 0. TL;DR（给 review 的一页纸）

- **现有 `msvc.lua` / `vs-buildtools.lua` 不符合范式，且不是改一改的事，需要重写。**
  根因是 `type = "config"` ——按 V1 spec 该类型「用于系统配置操作，无需下载资源文件」，
  等于从声明上就放弃了 payload，把安装位置交给微软的安装器。
- **拆 3 个包**：
  1. `windows-sdk` —— **新增**，`type = "package"`。索引里目前**完全没有**这个包，
     而没有它，payload 里的 MSVC toolset 编不了任何东西。
  2. `msvc` —— **重写**为 `type = "package"`，版本 = **toolset build**（如 `14.4x.xxxxx`）而非产品年份（`2022`），payload 化 + `xvm_enable`，多版本共存。
  3. `vs-buildtools` —— **降级为 legacy 别名**或直接废弃。它现在的 `install()` 是 `return true`，
     `xlings install vs-buildtools` 并不会装上 Build Tools。
- **获取路径**：VS channel manifest → 按 ID 取 payload（`.vsix` 即 zip）→ 解压到 payload 目录。
  **无安装器、无管理员、无注册表、无重启**。这是同时满足「不装 C 盘 / 多版本 / 纯命令行」的唯一路径。
- **env 分两层挂，不是二选一**（§6，有 xlings 源码依据）：
  `VSINSTALLDIR` 走 **`subos.env`**（构建系统要*发现*它，而构建系统不被 shim 包裹）；
  `INCLUDE` / `LIB` 走 **`xvm.add{envs=}`**（只给 `cl`/`link` 的 shim，避免污染整个 subos）。
- **`subos.env` 是兼容层，不是记录**（§6.1）：工具链的记录是"项目里声明的版本 → payload"，
  与 gcc 同形。否则"用哪个编译器"会变成机器的属性——xrgui#3 就是这么踩的。
- **首个可交付里程碑是「xlings 生态内 `cl` 命令行可用」**（阶段 2），不被许可/保留期的验证阻塞。
- **待验证见 §9**：许可边界、Insiders payload 保留期、清单结构。前两条决定能否直接回写 xrgui#3。

---

## 1. 现状与差距（有证据）

### 1.1 现有两个包的实际内容

`pkgs/m/msvc.lua`：

```lua
type = "config",
deps = { "xim:vs-buildtools@2022" },
["2022"] = {},                      -- 版本是产品年份

function installed()
    local msvc_path = [[C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC]]
    return os.isdir(msvc_path) or toolchain.load("msvc"):check() == "2022"
end

function install()
    os.exec("vs_BuildTools.exe" ..
        -- " --installPath " .. vs_install_path ..     ← 被注释掉了
        " --add " .. msvc_component ..
        " --includeRecommended" ..
        -- " --quiet " ..                              ← 被注释掉了
        " --passive " ..
        " --wait ")
    return true                                        ← 不检查结果
end
```

`pkgs/v/vs-buildtools.lua`：只下载 1MB 的 bootstrapper，`install()` 是 `return true`，
`sha256` 被注释掉了。

### 1.2 对照 `gcc.lua`（同为 toolchain，符合范式）

| 维度 | `gcc.lua` | `msvc.lua` |
|---|---|---|
| `type` | `package` | **`config`** —— 声明上放弃 payload |
| 落地位置 | `data/xpkgs/xim-x-gcc/<ver>/` | `--installPath` 注释掉 → `C:\Program Files (x86)\...` |
| `installed()` | 查 payload | 查 host 硬编码路径 **或** `toolchain.load("msvc"):check()`，**两个答案源都指向 host** |
| 多版本 | `{9.4.0, 11.5.0, 15.1.0, 16.1.0}` 实测并存 | 无 `xvm_enable` / 无 `programs` → 不能 `xlings use` |
| 版本粒度 | 编译器版本 | 产品年份 `"2022"` |
| 依赖 | `xim:glibc` / `xim:binutils` / `xim:linux-headers`，全在生态内 | 依赖 host 的 Windows SDK（索引里无此包） |

### 1.3 与 V2 spec 的冲突

- **R3（删除答案源，而非调和答案源）**：`installed()` 有两个答案源（硬编码路径 / xmake toolchain 探测），
  正是 spec 开篇说的「一个问题有多个答者，平时一致，第二个版本或第二台机器上就不一致」。
- **R4（对产物断言，而非对意图断言）**：`install()` 执行完 `os.exec` 直接 `return true`，
  从不检查 MSVC 是否真的装上了。

### 1.4 其他实际问题（与范式无关，但都是 bug）

- `--passive` **带 GUI**（`--quiet` 被注释掉），且要管理员权限 —— 谈不上纯命令行。
- `installed()` 硬编码 `2022\BuildTools` 路径。在 GitHub `windows-2025-vs2026` 镜像上装的是
  VS 2026 Enterprise，该判定永远为假。
- `uninstall()` 里 `if not os.isfile(...) then pkgmanager.install("vs-buildtools") end`
  —— 卸载时反过来装依赖。
- bootstrapper 的 URL 钉死了，但**安装结果没钉住**：bootstrapper 永远拉当前 bits。
  xrgui#3 里 `MSVC_TOOLSET: 14.52.36629` 那条注释说的「没法钉版本」就是这个原因。

---

## 2. 目标与非目标

### 目标

1. **不装到 C 盘**：payload 落在 `data/xpkgs/xim-x-msvc/<toolset>/`。
2. **多版本共存**：与 gcc 一致，多个 toolset 并存，`xlings use msvc <ver>` 切换。
3. **纯命令行**：无 GUI、无管理员、无注册表、无重启。
4. **可钉版本**：版本粒度到 toolset build，而不是 `2022`。
5. **构建系统能发现它**：mcpp / xmake / cmake 不改代码也能用（§8）。

### 非目标

- 不做完整 VS（IDE、MFC/ATL、Clang-cl、v141 之类旧 toolset、ARM64 交叉）——首版只做
  **HostX64/TargetX64 + CRT + Windows SDK**，够编 C++ 即可。
- 不替代 `vs_BuildTools.exe` 的全部功能；需要 IDE 的用户继续用官方安装器。

---

## 3. 包拆分

### 3.1 `windows-sdk`（新增）

**索引里目前没有这个包**，而它是硬依赖：MSVC toolset 只提供 STL 和编译器，
`ucrt` / `um` / `shared` 的头和库来自 Windows SDK。

xrgui#3 的构建日志可证——错误里的 CRT 头来自 SDK 而非任何 VS 实例：

```
C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\ucrt\corecrt_malloc.h(89)
```

```lua
name = "windows-sdk",
type = "package",
archs = { "x86_64" },
programs = { "rc", "mt" },        -- 资源编译器等
xvm_enable = true,
xpm = { windows = {
    ["latest"]         = { ref = "<sdk-ver>" },
    ["<sdk-ver>"]      = { ... },
}}
```

payload 布局保持官方形状，便于消费者按惯例拼路径：

```
xpkgs/xim-x-windows-sdk/<sdk-ver>/
├── Include/<sdk-full>/{ucrt,um,shared,winrt}/
├── Lib/<sdk-full>/{ucrt,um}/x64/
└── bin/<sdk-full>/x64/{rc.exe,mt.exe}
```

### 3.2 `msvc`（重写）

```lua
name    = "msvc",
type    = "package",              -- 不再是 config
archs   = { "x86_64" },
programs = { "cl", "link", "lib", "ml64", "dumpbin" },
xvm_enable = true,

xpm = { windows = {
    deps = { "xim:windows-sdk@<sdk-ver>" },
    ["latest"]        = { ref = "<toolset-a>" },
    ["<toolset-a>"]   = { ... },   -- 版本 = toolset build，如 14.44.xxxxx
    ["<toolset-b>"]   = { ... },
}}
```

> 本文里的 toolset / SDK 版本号**一律是占位符**，不是选定的基线——
> 真实可用版本由阶段 0 从 channel manifest 枚举得出（§10）。
> 唯二有实测依据的是 xrgui#3 里出现过的 `14.51.36231`（镜像预装）
> 与 `14.52.36629`（Insiders），而后者属于风险 #2。

payload 布局**必须保留 `VC/Tools/MSVC/<ver>/` 这层**，理由见 §8：

```
xpkgs/xim-x-msvc/<toolset>/
└── VC/
    ├── Tools/MSVC/<toolset>/
    │   ├── bin/Hostx64/x64/{cl.exe,link.exe,lib.exe,...}
    │   ├── include/          # STL，含 std.ixx
    │   └── lib/x64/
    └── Redist/MSVC/<toolset>/     # 可选，vcredist DLL
```

### 3.3 `vs-buildtools`（废弃 / 降级）

保留名字做 legacy 别名指向 `msvc`，或标 `status = "deprecated"`。
它现在的语义（下载一个 exe）对用户是误导。

---

## 4. 获取路径：channel manifest（**关键，且部分未验证**）

VS 的分发是**清单驱动**的，这正是能钉住版本的地方——bootstrapper 做不到：

```
1. channel manifest  (aka.ms/vs/<major>/release/channel)   → JSON，列出各 manifest 的 URL
2. package manifest  (由上一步指向)                          → 列出每个 package 的
                                                              id / version / payloads[{url,sha256,size}]
3. 按 id 前缀挑 payload:
     Microsoft.VC.<ver>.Tools.HostX64.TargetX64.*
     Microsoft.VC.<ver>.CRT.{Headers,x64.Desktop}.*
     Win10SDK_10.0.*
4. 下载 → 校验 sha256 → 解包
     .vsix  → zip，内容在 Contents/ 下
     .msi   → msiexec /a 或 lessmsi（SDK 走这条）
5. 归一化到 §3 的布局
```

### 4.1 阶段 0 实测结论（2026-08-16，已坐实）

上面的路线**已全部验证**，不再是推测：

| 事实 | 实测结果 |
|---|---|
| channel → package manifest | `aka.ms/vs/17/release/channel` (92 KB) → `Microsoft.VisualStudio.Manifests.VisualStudio` 17.14.37531.7 → 18 MB **纯 JSON**，19354 个 package |
| 一份清单里有多少 toolset | **16 个并存**：14.29 → 14.44（即 VS 2022 17.0 → 17.14）。多版本共存不用自己造，微软本来就这么发 |
| payload 是否可钉 | 每个 payload 带 `url` + `sha256` + `size`；实测下载 `CRT.Headers.base.vsix`，**sha256 逐位吻合** |
| `.vsix` 是什么 | **就是 zip**（`file` 报 Zip archive），内容在 `Contents/` 下 |
| 解压后的布局 | `Contents/VC/Tools/MSVC/14.44.35207/...` —— **去掉 `Contents/` 正好是 mcpp 要的形状**，`bin/Hostx64/x64/cl.exe`、`modules/std.ixx` 都在 |
| 目录版本 vs 包版本 | **不同**：Tools 包 14.44.35228 / Headers 14.44.35220 / CRT 14.44.35226，但**都解到同一个 `14.44.35207` 目录**。所以包版本取**目录版本** |
| MSVC toolset 体积 | 4 个 vsix = **83.5 MB**（Tools 26.7 + Headers 2.1 + CRT.x64.Desktop 51.5 + Redist.X64 3.2） |
| Windows SDK 形态 | `Win11SDK_10.0.26100`，**229 个 payload / 530 MB**，MSI + CAB，无 vsix 形式 |
| `Microsoft.Windows.SDK.BuildTools` 能否代替 | **不能**。它是 nupkg（单 zip，22.5 MB）但**只有 `bin/` 工具**，无 ucrt/um/shared 头、无 libs——实测确认 |
| MSI → CAB 映射 | CAB 名是不透明哈希，清单里查不到；映射在 MSI 的 `Media` 表里。**可离线解出**（`7z x` 出 `!_StringData` 再取 `.cab`），于是能作为静态数据钉进包里 |
| SDK 精确子集 | 4 个 MSI + **15 个 CAB = 19 个文件 / 139 MB**（整包 530 MB） |
| **旧 payload 保留期（风险 #2）** | VS **2019**（16.11）的 channel manifest 今天仍可解析，其 payload 可取回（HTTP 206）。**release 通道是多年级别**；Insiders 未测，故首版不做 |

> 仍未实测的只剩**安装路径本身**（`msiexec /a` 解包、`tar -xf` 解 vsix、xvm/subos 注册），
> 因为那只在 Windows 上跑。这正是 CI 的 `windows-test` job 要回答的问题。

**为什么不镜像到 xlings-res**：见 §9 许可一节。首选形状是**安装时从微软 CDN 下载**，
与现有 CI 里装 Vulkan SDK 的形状一致。

---

## 5. 与 `type = "res"` 的关系

`2026-06-14-virtualbox-ubuntu-package-design.md` 提过 `type = "res"`（受管资源包）。
MSVC **不适用**：它有可执行文件、要进 PATH、要多版本切换，是标准 `package`。
SDK 同理。

---

## 6. env 挂在哪：`xvm` 还是 `subos`？—— **两层都要，各司其职**

这是 review 时最值得确认的一条。结论**不是二选一**，因为两者能触达的进程不同。
依据来自 xlings 源码：

| 机制 | 实现 | 触达范围 |
|---|---|---|
| `xvm.add{envs=}` | `src/core/xvm/shim.cppm` 的 `setup_envs()`：*"Set environment variables for a program **before exec**"* | **只有经 shim 启动的进程** |
| `subos.env` | `src/core/subos.cppm` 的 `apply_subos_env_()`，进入 subos 时应用 | **subos 内所有进程**，含用户自己的二进制 |

V2 spec 对 `subos.env` 的说明也点明了这个边界：

> The process that has to see them is the *user's own binary*, which xlings never wraps,
> so the per-shim `envs` on `xvm.add` cannot reach it.

对 MSVC 而言：

| 变量 | 谁需要 | 挂哪 | 理由 |
|---|---|---|---|
| `VSINSTALLDIR` | **构建系统**（mcpp / xmake / cmake）拿它*发现*工具链 | **`subos.env`** | 构建系统是用户自己的二进制，永远不经 shim，xvm envs 够不着 |
| `INCLUDE` / `LIB` | `cl.exe` / `link.exe` 自己 | **`xvm.add{envs=}`** | 它们正是被 shim 的程序；放进 subos 全局会**污染**同一 subos 里其他编译器 |
| `PATH`（toolset bin） | 用户直接敲 `cl` | xvm 注册（`programs`）天然解决 | —— |

```lua
function config()
    local tag = package.name .. "@" .. pkginfo.version()

    -- 全局：让构建系统"发现"这套工具链
    if type(subos.env) == "function" then
        subos.env{ var = "VSINSTALLDIR", op = "set",
                   value = "${pkgdir}", binding = tag }
    end

    -- 仅 shim：编译器内部所需，不外泄
    xvm.add("cl", { bindir = "${pkgdir}/VC/Tools/MSVC/<ver>/bin/Hostx64/x64",
                    envs = { INCLUDE = "...", LIB = "..." } })
end
```

两点补充：

- **必须用 `${pkgdir}` 占位符**。spec 明文禁止写死绝对路径（*"a literal absolute path
  pins the manifest to the machine that wrote it"*）。
- **`subos.env` 强制「一个包一个版本一个 subos」**（`duplicate_bindings`）。
  这与多版本不矛盾：**多版本活在 payload store**，subos 里只有一个 active，
  `xlings use msvc <ver>` 切换——和 gcc 完全一致。

### 6.1 那 `subos.env` 岂不是把工具链变成了"机器的属性"？

（review 提出的问题，值得单独写清楚，因为它决定了这套东西的正确性边界。）

**是的，如果把 `subos.env` 当成记录，就会这样——所以它不能是记录。**

一个环境变量是**机器本地状态**。若"这份构建用的是哪个编译器"由它决定，那么：

- 同一份源码在两台机器上会被不同的编译器编译，而项目里看不出任何差别；
- 装了不同 VS 的机器结果不同，且**不会有任何报错**——这正是 xrgui#3 的实际经历：
  同一个 job 里 mcpp 选中系统预装的 `14.51.36231`，xmake 用 `14.52.36629`，
  两边都"正常"跑，直到 14.51 在模板实例化时 ICE 才暴露。

所以本方案的记录不是 env，而是**声明 + payload**：

| 层 | 内容 | 跨机器一致？ |
|---|---|---|
| **记录** | 项目里写 `[toolchain] windows = "msvc@<toolset>"` | ✅ 在仓库里，随源码走 |
| **解析** | `<toolset>` → `xpkgs/xim-x-msvc/<toolset>/`，由版本 + sha256 定址 | ✅ 同版本 = 同字节 |
| **兼容层** | `subos.env` 的 `VSINSTALLDIR` | ❌ 机器本地，**仅用于兜底** |

`subos.env` 存在的唯一理由是：**有些构建系统只会探测 host，不认声明**。
给它们一个指向 payload 的钩子，好过让它们去翻 `Program Files`。
一旦构建系统支持"显式声明优先于探测"，env 就退出正确性的关键路径，只剩便利性。

参照物就在生态里：**gcc 已经是这个形状**。mcpp 解析 `gcc@16.1.0` 直接得到
`xpkgs/xim-x-gcc/16.1.0/bin/g++`，不读 env、不探测 host、跨机器一致。
MSVC 之所以是例外，恰恰因为它是 mcpp 唯一不自己安装的工具链
（`msvc.cppm`: *"mcpp does not install MSVC"*）。

> 这也说明 §8 的两条 mcpp 需求不是锦上添花：
> **显式声明必须优先于探测**，否则 payload 装了也可能被系统 VS 抢走；
> 这才是 xrgui#3 里要挪开 `vswhere.exe` 的根本原因。

### 6.2 产物分发到别的 Windows 上能跑吗

上面讲的是**构建可复现**；"分发到不同 Windows 电脑"还有第二层含义——
**编出来的 exe 拿到别的机器上能不能跑**。这一层与工具链在哪无关，只取决于 CRT 链接方式：

| 链接方式 | 目标机需要什么 | mcpp 现状（源码核实，2026.8.15.3） |
|---|---|---|
| `/MD`（动态） | 匹配版本的 VC 运行时 DLL | **默认**（`linkage = "dynamic"`） |
| `/MT`（静态） | 无 | **已实现**——`[build] linkage = "static"`。`flags.cppm:611` 与 `prepare.cppm:4980` 共用同一个 `msvc_crt_flag()`，所以**项目 TU 和 std 模块必然一致**（这正是 #422 的修法） |
| UCRT | Windows 10+ 自带 | 不用管 |

所以要产出**可直接分发、不依赖目标机装运行时**的 exe，是有办法的：
`linkage = "static"`。payload 里的 `Redist/MSVC/<toolset>/`（§3.2）则是走 `/MD` 时
要一起分发的那份运行时，**随 toolset 版本走**——又回到同一个结论：
版本是声明出来的，不是机器给的。

> ⚠️ **同一件事有两个旋钮，且它们不一致**（值得给 mcpp 提 issue）：
>
> - `[build] linkage = "static"` → 真的发 `/MT`
> - `[build] cxx_runtime = "self-contained"` → 在 MSVC 上**仍未实现**，warn 一次后退回 host-coupled
>
> `distribution.cppm:202` 的注释说 *"Under the MSVC runtime mcpp never made that promise —
> there is no /MT emission at all"*，但 `flags.cppm:605` 明写
> *"/MD default, /MT under static linkage"* 并确实发了 `/MT`。
> 两处说法对不上，用户侧的表现就是：**想要静态 CRT 时写 `cxx_runtime` 无效、写 `linkage` 才有效**，
> 而前者的名字看起来更像是干这个的。
>
> 这正是 xlings V2 spec **R3（删除答案源，而非调和答案源）** 说的形状。
> 建议 mcpp 侧：要么让 `cxx_runtime = "self-contained"` 在 MSVC 上直接映射到静态 CRT，
> 要么在诊断里明确指向 `linkage`。
>
> （xrgui#3 里 `cxx_runtime = "host-coupled"` 的结论不受影响：那里要的就是 `/MD`，
> 与 xmake 的 `set_runtimes("MD")` 一致。）

---

## 7. 多版本共存

xlings 已有全套机制，不需要新造。实测（同一台机器）：

```
xpkgs/xim-x-gcc/{9.4.0, 11.5.0, 15.1.0, 16.1.0}     ← 四个 GCC 并存
xlings use mcpp 2026.8.15.3                          ← 切换 active 版本
```

MSVC 照搬：`xpkgs/xim-x-msvc/{<toolset-a>, <toolset-b>}`，`xlings use msvc <ver>`
改写 `VSINSTALLDIR` 与 shim 指向。

**顺带说明**：MSVC 本身就是为并存设计的——一个 VS 实例内
`VC\Tools\MSVC\<ver>\` 可以有多份，`vcvarsall.bat -vcvars_ver=` 就是在其中选。
xrgui#3 的 CI 里更直接证明了**实例级并存**：同一台 runner 上
`C:\Program Files\...\18\Enterprise\...\14.51.36231` 与
`C:\VS2026Insider\...\14.52.36629` 同时存在且同时被两条构建腿使用。

---

## 8. 与 mcpp 的衔接（为什么布局必须是那样）

mcpp 的 MSVC 发现顺序（`src/toolchain/msvc.cppm`）：

```
1. vswhere -latest -products * -requires ...VC.Tools.x86.x64     ← 没带 -prerelease
2. VSINSTALLDIR / VS*COMNTOOLS
3. Program Files\Microsoft Visual Studio\<year>\<edition>
```

第 2 步的判据只有一条：

```cpp
if (auto* dir = std::getenv("VSINSTALLDIR"); dir && *dir) {
    std::filesystem::path p{dir};
    if (std::filesystem::exists(p / "VC" / "Tools" / "MSVC"))   // ← 只要这个目录在
        return p;
}
```

**所以 §3.2 的 payload 保留 `VC/Tools/MSVC/<ver>/` 这层，mcpp 现状即可识别**，
不需要 mcpp 改一行。

两个已知摩擦点（mcpp 侧，作者已确认不是问题）：

1. **vswhere 抢先**：机器上若同时装了系统 VS，第 1 步成功，第 2 步永远不执行。
   这正是 xrgui#3 里要挪开 `vswhere.exe` 的原因。
   → mcpp 让显式 `VSINSTALLDIR` 优先即可，本方案随之不再需要那个 workaround。
2. **Windows SDK 路径写死**：`find_windows_sdk()` 只扫两个绝对路径，
   无 env 覆盖、无注册表：

   ```cpp
   for (const char* base : {"C:\\Program Files (x86)\\Windows Kits\\10",
                            "C:\\Program Files\\Windows Kits\\10"}) {
   ```

   → payload 化的 SDK 需要 mcpp 认 `WindowsSdkDir` / `WindowsSdkVersion`
   （vcvars 本来就导出这两个）。**这是本方案对 mcpp 的唯一硬需求。**

---

## 9. 风险与待验证（**开工前必须先有结论**）

| # | 项 | 现状 | 影响 |
|---|---|---|---|
| 1 | **许可边界** | 未确认 | 决定「镜像到 xlings-res」还是「安装时从微软 CDN 下载」。**后者更稳妥**，形状与 Vulkan SDK 一致。这一条不清楚就不该开工 |
| 2 | **payload 保留期** | ✅ release 通道已验证（VS2019 仍可取回）；Insiders 未测 | release 通道的 payload 微软长期保留；**Insiders 会轮换**。钉了 URL 的包会不会几个月后 404，必须拿一个旧 manifest 实测。**建议首版只做 release 通道**，Insiders 另议 |
| 3 | ~~清单结构 / payload id~~ | ✅ **已实测**，见 §4.1 | —— |
| 4 | 解包后可用性 | 部分验证：布局、`cl.exe`、`std.ixx` 都在；**实际编译只能靠 Windows CI** | 交给 `windows-test` job |
| 5 | ~~体积~~ | ✅ toolset 83.5 MB + SDK 139 MB = **222.6 MB** | 远小于整包，不必进 res 镜像 |
| 6 | ARM64 / x86 目标 | 首版不做 | 多目标会让 payload 膨胀，先只做 x64 |

---

## 10. 分阶段落地与验收标准

验收一律按 **R4（对产物断言，而非对意图断言）**——「跑过了」不算，「产物符合预期」才算。

> **里程碑取向（review 决定）**：先把 **xlings 生态内 `cl` 命令行可用** 做出来，
> 那是第一个自身就有价值、可独立交付的点。多版本、构建系统接入都排在它之后。

**阶段 0：可行性 PoC（不写包）**
- 拉一份 release channel manifest，解析出 toolset + SDK 的 payload 列表
- 下载解包成 §3 布局
- 验收（三条都要）：
  1. `cl.exe hello.cpp` 编译链接通过，**全程无安装器、无管理员**
  2. 用一个**数月前的旧 manifest** 复测 URL 是否仍可取回（风险 #2）
  3. 记录体积与 payload id 清单（风险 #3、#5）

**阶段 1：`windows-sdk` 包**
- 验收：`installed()` 只查 payload，不查 host；
  `Include/<ver>/ucrt/corecrt.h` 与 `Lib/<ver>/ucrt/x64/ucrt.lib` 存在

**阶段 2：`msvc` 包（单版本）—— 🎯 第一个可交付里程碑**
- 目标：`xlings install msvc@<ver>` 之后，**开箱即可命令行编译**
- 验收：
  - `cl` 经 xvm shim 可直接编译链接一个含 `import std;` 的程序
  - **全程无 GUI、无管理员**
  - `C:\Program Files*` 与注册表下**无新增**（对产物断言，不是"我们没调安装器"）
  - `xlings uninstall msvc` 后 payload 目录消失，shim 失效

**阶段 3：多版本 + `xlings use`**
- 验收：两个 toolset 并存；`xlings use msvc <ver>` 前后 `cl` 报告的版本随之改变

**阶段 4：接入 mcpp / 回写 xrgui#3**
- 前置：mcpp 侧适配 issue（§11 第 4 条）已落地
- 验收：xrgui 的 `mcpp-windows.yml` **删掉「挪开 `vswhere.exe`」那一步**后 CI 仍绿

---

## 11. Review 结论（2026-08-16）

| # | 议题 | 结论 |
|---|---|---|
| 1 | 现有 `msvc.lua` / `vs-buildtools.lua` | **改**（重写，不是修补） |
| 2 | 拆 3 个包（`windows-sdk` / `msvc` / `vs-buildtools` 降级） | ok |
| 3 | payload 保留 `VC/Tools/MSVC/<ver>/` 布局 | ok |
| 4 | 对 mcpp 的适配需求 | **提 issue**：① 显式声明/`VSINSTALLDIR` 优先于 vswhere 探测；② `find_windows_sdk()` 认 `WindowsSdkDir`；③ `cxx_runtime` 与 `linkage` 在 MSVC 静态 CRT 上说法不一（§6.2） |
| 5 | 风险 #1（许可）/ #2（保留期） | **去验证**；同时**先做 xlings 生态内命令行可用**这一段，不被验证结论阻塞 |
| 6 | §6 env 分层（`VSINSTALLDIR`→subos，`INCLUDE`/`LIB`→xvm shim） | 认可，并追加 §6.1：**env 是兼容层，不是记录** |

### 仍未定，但不阻塞阶段 0–2

- **通道**：首版做 release 通道；Insiders 待风险 #2 的实测结论。
  （注意 xrgui#3 需要的恰是 Insiders，所以这条决定"这套方案能否直接回写 xrgui"）
- **SDK 拆包粒度**：`windows-sdk` 单包起步，若体积过大再拆 headers / libs。
- **镜像 vs 安装时下载**：默认走"安装时从微软 CDN 下载"，等风险 #1 有结论再议镜像。
