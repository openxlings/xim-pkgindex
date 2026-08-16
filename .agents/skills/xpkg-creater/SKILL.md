---
name: xpkg-creater
description: 在 xim-pkgindex 中创建/更新 xpkg 包（V2/兼容 V1），遵守 xlings SubOS 隔离规范，补齐多架构资源与测试，并在本地与测试集验证通过后再提交 PR。
---

# xpkg-creater

用于在 `xim-pkgindex` 仓库中新增或维护 xpkg 包文件，确保满足：
- XPackage Spec V2（新包推荐 `spec = "2"`，历史 V1 继续兼容）
- hooks 约束（尤其 `install` / `config`）
- subos 环境隔离规范
- 本地验证 + 测试集验证 + CI 要求

> 详细安装命令、测试命令清单、相关链接见：
> - `references/xlings-setup-and-links.md`
> - `references/testing-and-acceptance.md`

## 0) xlings 工具入口（必须具备）

开发/验证 xpkg 之前，先确保环境可用：
- 已安装 `xlings`（用于 `xim/xlings/xvm` 命令）
- `xlings` 命令在 shell 中可执行

安装方式与快速命令见 `references/xlings-setup-and-links.md`。

## 1) 包格式规范

一个 xpkg 文件由两部分组成：
1. `package = { ... }` 元数据域
2. hooks 函数域（`installed/build/install/config/uninstall`，按需实现）

### 1.1 必填与推荐字段

至少保证：
- `spec = "2"`（仅维护历史配方时可继续使用 `"1"`）
- `name`
- `description`
- `type`（常见：`package/script/config/template`）
- `xpm`（平台、版本、资源映射）

常见推荐字段：
- `archs`, `status`, `categories`, `keywords`
- `authors/maintainers/licenses/repo/docs/homepage`
- `xvm_enable = true`（需要 xvm 管理时）

### 1.2 xpm 写法要点

- 按平台配置：`windows/linux/macosx/ubuntu/debian/...`
- 版本常用：
  - `{"latest" = { ref = "x.y.z" }}`
  - `{"x.y.z" = { url = "...", sha256 = "..." }}`
  - `"XLINGS_RES"`
- 新包默认来源推荐使用 `xpm.source`：
  - `source = "xlings-res"`：官方资源服务器，版本项提供每个架构的 `sha256`
  - `source = "https://.../${version}/...${arch}..."`：第三方 URL template
- URL 不规则时使用版本项 per-arch resource map；特殊版本用显式 `url` 覆盖默认 source。
- 多架构条目的 `sha256` 必须覆盖每个受支持架构；缺失时版本检查器必须 fail closed。
- 可选 `ci = { mirror = true, update = true }` 只声明是否加入官方自动化；扫描周期统一由
  仓库 `.github/xpkg-ci.yml` 管理，不能在单个包中写入周期。
- 平台继承：`ubuntu = { ref = "linux" }`
- script/config 类型可使用空资源：`["0.0.1"] = {}`

#### 资源选择策略（默认使用 xlings-res）

官方二进制优先使用 `xpm.source = "xlings-res"`，并为每个平台/架构写入权威 SHA256。
第三方 release 使用 URL template + per-arch SHA256；只有 URL 不规则时才展开 per-arch
resource map。显式版本 `url` 可以覆盖根级或平台级 source。

```lua
xpm = {
    source = "xlings-res",
    linux = {
        ["latest"] = { ref = "1.0.0" },
        ["1.0.0"] = {
            sha256 = {
                x86_64 = "<linux-x86_64-sha256>",
                aarch64 = "<linux-aarch64-sha256>",
            },
        },
    },
},
```

参考实现：`docs/V2/xpackage-spec.md` 与 `pkgs/g/github-gh.lua`

### 1.2.1 XLINGS_RES 镜像发布要求

> 这里的 `XLINGS_RES` / 镜像表解析的是**软件包二进制**，走资源服务器
> `GLOBAL = github.com/xlings-res`、`CN = gitcode.com/xlings-res`。这与「索引仓库本身」
> 的分发（索引即资源 / Y-asset）是同一套资源服务路径但不同资产，互不混淆。
> 索引机制全貌见 `docs/design/index-distribution.md`（同步自 xlings v0.4.55 源码）。

当某个版本使用 `xpm.source = "xlings-res"`（历史写法为 `"XLINGS_RES"`）时，该版本已经进入 xlings 多镜像资源服务链路。发布前必须同时满足：

- `https://github.com/xlings-res/<pkg>` 与 `https://gitcode.com/xlings-res/<pkg>` 都存在同名 tag/release。
- 两边 release 都包含该版本声明会使用的全部平台资产；文件名必须符合 xlings-res 约定。
- 两边资产必须来自同一个权威上游 release 或同一次构建产物；发布后从 GitHub RES、GitCode RES、权威上游各下载一次并比对 sha256，确认字节一致。
- 每个归档都要发布同名 `.sha256` sidecar；索引版本项必须为每个受支持架构写入与 sidecar 一致的 SHA256。
- `version-check.py --apply` 缺少平台、架构、资产或 sidecar 时必须 fail closed，不得生成不完整条目。
- 如果补发历史版本，发布后确认两边 `latest` 仍指向应当作为最新的版本，不要因为补旧版本导致 latest 倒退。
- PR 描述或汇报中写清楚 GitHub RES、GitCode RES 的 release/tag，以及 sha256 校验结果。

如果 GitHub RES 和 GitCode RES 任一侧缺资源、版本不一致、资产不一致，不能把该版本切到 `"XLINGS_RES"`；先补齐镜像资源，再改包索引。

## 2) hooks 实现规范（核心）

### 2.1 import 规范
优先使用新版 API：
- `import("xim.libxpkg.pkginfo")`
- `import("xim.libxpkg.xvm")`
- `import("xim.libxpkg.system")`（可选）
- `import("xim.libxpkg.log")`（可选）

避免旧 API：
- `import("xim.base.runtime")`
- `import("common")`
- `import("platform")`

### 2.1.1 通用 Lua/API 边界

一般情况下，新增或维护 xpkg 只能使用三类能力：
- XPackage Spec V1 规定的 `package` 元数据、`xpm` 描述和 lifecycle hooks。
- 标准 Lua 语法与标准库（例如 `string/table/io/os.getenv/pcall/error` 等）。
- 必要的 `xim.libxpkg.*` API（例如 `pkginfo/xvm/system/log/json`）。

不要默认引入 xmake 私有 runtime/API。除非某个既有包的兼容性约束已经证明必须使用，否则避免：
- `core.*`、`detect.*`、`runtime.*`、`xim.base.runtime`
- `common`、`platform`
- `path.*`、`os.host()`、`is_host()`、`try { ... }`、`raise(...)`

测试也应默认锁定这条边界：import 只能来自 `xim.libxpkg.*`，路径、错误处理、文件 IO 优先用标准 Lua 或 `libxpkg` 可移植封装。

**hook runtime 里没绑定的东西会静默毁掉安装。** 已确认不可用的：

| 写法 | 现象 | 换成 |
|------|------|------|
| `os.exists(p)` | `attempt to call a nil value (field 'exists')` | `os.isdir(p) or os.isfile(p)` |
| `os.arch()` | 返回 nil / `_RUNTIME.arch` 为空 | 从 `pkginfo.install_file()` 推导 |
| `os.curdir()` | `attempt to call a nil value (field 'curdir')` | `os.cd` 之后用一个已知目录回去(`pkginfo.install_dir()`) |
| `os.execv(...)` | 同上 | `system.exec` / `os.exec` |
| `os.files(...)` | 同上 | `os.dirs` 递归,或交给 `xcopy` / shell |
| `path.absolute(p)` | 同上 | `pkginfo.install_dir()` 本来就是绝对路径 |

> **先 grep,再写。** 上面五条都是同一个形状,而每一条在写下去之前都能用一条
> 命令排除:
>
> ```bash
> grep -rn "os\.curdir" pkgs/ | wc -l    # 0 → 别用
> ```
>
> **整个 index 里零处使用的 sandbox API,基本可以认定它不在 runtime 里。**
>
> 另外两条不在上表里,因为它们**存在**、只是行为和你以为的不一样:
>
> - `os.cd(dir)` 之后 **`system.exec` 不继承那个 cwd**(`os.exec` 才继承)。
>   照抄别的 recipe 的「cd 之后用相对路径」时,先看清它用的是哪一个 ——
>   命令可以拼得完全正确,然后找不到自己的文件。
> - `path.join` 在 Windows 上**混用分隔符**(保留已有的 `\`、新加 `/`)。
>   `"C:\Windows/System32/tar.exe"` 执行不了,`msiexec` 也拒收。
>   凡是要交给 Windows 程序的路径都过一遍 `winpath()` —— **包括可执行文件
>   本身的路径**,不只是它的参数。

#### Windows 上的 `tar`:PATH 会替你选,而两个 tar 能力不同

runner 上同时存在两个 `tar`,**它们不是同一个程序**:

| | 来源 | 读 zip? | `C:\...` 参数 |
|---|---|---|---|
| bsdtar | `%SystemRoot%\System32\tar.exe`(Win10 1803+) | ✅ | 正常 |
| GNU tar | Git for Windows / MSYS2 | ❌ **完全不支持** | 当成 `host:path`,报 `Cannot connect to C:` |

`.vsix` / `.zip` 只有 bsdtar 读得了。而**哪一个被选中取决于 PATH 顺序** ——
同一个 GitHub 镜像上,index 自己的 windows-test 拿到 bsdtar 通过,
mcpp 的 e2e 拿到 GNU tar 失败,recipe 一个字都没变。

所以:**解 zip 时写绝对路径的 `System32\tar.exe`,不要写裸 `tar`。**
钉死之后盘符问题也随之消失(那是 GNU tar 独有的),路径可以放心用绝对的。
`--force-local` 不是答案 —— GNU tar 认、bsdtar 拒收,是拿一个坏环境换另一个。
> 这不是概率判断:能用的东西早就有人用了。而代价是不对称的 —— 猜对省几秒,
> 猜错要等一轮 Windows CI(约 4 分钟)才知道,而且失败信息出现在
> install hook 里、离你写的那一行有几层。

危险的地方在于**表现形式**：install hook 抛错之后，安装目录里往往只剩一个 `.xpkg.lua`、
没有 payload，而外层可能仍然打印 `✓ N package(s) installed`。所以
`install()` 结尾一定要断言真正的产物存在（`raise(...)` 或 `return os.isfile(exe)`），
别只 `return true`；验收时也要真的去 `ls` 安装目录，不要只看安装命令的退出码。

注意 `raise()` 本身也不进汇总 —— 它不会让外层报失败；而 hook 里的 **Lua 运行时错误会**
浮出来（`[error] [pkg] failed: ...`）。所以 `raise` 只是给读日志的人看的，不能当成保护。

#### "安装目录是空的"最常见的原因不是 hook 有问题

**xlings 在同名同版本已经装在另一个 namespace 下时，会整个跳过 install hook，并且照样
打印成功。** `xim:foo@1.2.3` 已装的情况下，每一次 `local:foo@1.2.3` 安装都是静默 no-op，
只写下 `.xpkg.lua` —— 看起来和 install hook 坏掉一模一样。测之前先清两边：

```bash
rm -rf ~/.xlings/data/xpkgs/{xim,local}-x-<pkg>/<version>
```

（这条是用 hook 里塞 `io.writefile` 探针确认的：日志文件根本没生成。曾因此把一个好端端的
`os.mv` 误判成 bug —— 实测 xlings 会重新解压、归档没了也会重新下载，`os.mv` 连装两次没问题。）

另外：往 local index 里放两个 `package.name` 相同的文件，会让**整个 local repo 静默从搜索
路径消失**（`package 'local:foo' not found, searched repos: [xim, scode]`）。删掉重复文件即恢复。

### 2.1.2 配置型包的 Lua 边界

对 `type = "config"` 且会写入用户工具配置的包（例如 Claude/LLM 配置）：
- 只使用标准 Lua 语法、`package` 元数据、hooks，以及必要的 `xim.libxpkg.*` import。
- 不使用 xmake 私有 import/API：`core.*`、`detect.*`、`xim.base.runtime`、`runtime.*`、`is_host()`、`os.host()`、`path.*`、`try { ... }`。
- Lua 错误使用标准 `error(...)`，不要使用 `raise(...)`。
- `install()` 保持轻量，默认 `return true`；实际配置写入放在 `config()`。
- 修改已有 JSON 配置时先读取并保留原对象，只更新本包负责的 key；写入前备份，并用 `log.info/log.warn/log.error` 说明结果，敏感 token 不要明文打印。
- 如果用户未输入新 key 但已有有效配置，使用 `log.warn` 提示继续复用旧 key 且不改 token；如果没有可复用 key，使用 `log.error` 后失败。
- 针对独立行为（例如修复 Claude token 缓存的 env 项）单独抽成函数，便于测试锁定边界。

### 2.2 install() 约束

`install()` 只负责安装动作本身：
- 使用 `pkginfo.install_file()` 获取下载/解压后的输入路径
- 使用 `pkginfo.install_dir()` 作为目标安装目录
- 可先 `os.tryrm(pkginfo.install_dir())` 再 `os.mv(...)`
- 若是 Linux 预构建 ELF，必要时做可重定位修复（如 patchelf）

### 2.2.1 installed() 约束 —— 「装好了」必须等于「能用」⚠️

`installed()` 的含义是:**payload 处于「这份 recipe 产出的状态」**,
不是「这儿有个目录」。两者只在 recipe 变更时不一样,而那正是它要紧的时候。

2026-08-16 这一轮 MSVC 生态里,**九层缺陷有四层是这一条**:每一层的
windows-test 都是绿的,而包对使用者是坏的。

#### (a) 必须查文件,不能查目录

```lua
-- ❌ 目录在 ≠ 里面有东西
if os.isdir(path.join(d, "Lib", VER, "um", "x64")) then return true end

-- ✅ 查那个只有它才提供的文件
if not os.isfile(path.join(d, "Lib", VER, "um", "x64", "kernel32.lib")) then
    return false
end
```

真实后果:少了带 `kernel32.lib` 的那个 MSI,目录照样存在(另外 341 个 um 库
落进去了),`installed()` 说 yes,而**任何程序的链接都失败**。

> Windows 文件系统**大小写不敏感**,`os.isfile("kernel32.lib")` 照样匹配磁盘上的
> `Kernel32.Lib`。不要用"文件名大小写不确定"当作查目录的理由。

#### (b) 必须是覆盖,不是抽样

一个 payload 一条断言,而且那条断言的文件**只有那个 payload 提供**。
这样哪个 payload 没下来/没解开/没合并,报错就点名哪一个。

`windows-sdk` 的做法(8 个 payload → 7 条断言):

| 断言的文件 | 唯一提供它的 payload |
|---|---|
| `Include/<v>/ucrt/corecrt.h` | Universal CRT |
| `Include/<v>/um/winnt.h` | Store Apps Headers |
| `Include/<v>/shared/windef.h` | Store Apps Headers OnecoreUap |
| `Lib/<v>/um/x64/kernel32.lib` | Store Apps Libs |
| `Lib/<v>/um/x64/gdi32.lib` | Desktop Libs x64 |
| `bin/<v>/x64/rc.exe` / `mt.exe` | Store Apps Tools |

选 `gdi32.lib` 而不是随便一个库,是因为它**只在** Desktop Libs 里 ——
那 365 个库和 Store Apps Libs 的 116 个**完全不相交**。抽样会漏,覆盖不会。

#### (c) 必须能表达「什么**不该**在」

包的版本号**不会**因为 recipe 改了就变。所以对已经装了旧布局的机器,
`installed()` 是**唯一**能把它们拉回来的东西:

```lua
-- 新 recipe 不再安装 vctip.exe(它占着 payload 让整个包卸不掉)。
-- 只写"不装"对已经装了的机器毫无作用 —— 必须让 installed() 认出旧产物。
for _, d in ipairs(bin_arch_dirs()) do
    if os.isfile(path.join(d, "vctip.exe")) then return false end
end
```

> **新增**的文件靠断言"它在"就能发现;**删掉**的文件必须显式说"它不该在"。

#### (d) 失败时要点名缺哪个文件

```lua
local missing = {}
for _, f in ipairs(required_files()) do
    if not os.isfile(f) then table.insert(missing, f) end
end
log.error("... 不在应该在的位置:\n    " .. table.concat(missing, "\n    "))
```

「wanted: <四个路径>」不算 —— 那是把清单再抄一遍,读的人还得自己比对。

### 2.3 config() 约束

`config()` 负责将该版本注册到 xvm（subos 隔离路由）：
- 使用 `xvm.add("tool")`
- 或 `xvm.add("tool", { bindir = ..., alias = ... })`
- 可执行文件不在安装根目录时，必须明确 `bindir`

### 2.3.1 共享名与 flavor 版本（注册前必查）

一个 xvm 名字（程序名或 lib 名）可能被**多个包**提供：`java` 来自每个 JDK 发行版，
`gcc` 来自 gcc.lua 和 musl-gcc.lua，`crt1.o`/`libc.so` 来自 glibc.lua 和 musl.lua。
用裸版本号注册共享名有**两种**失败方式，长得完全不一样：

| 情况 | 结果 |
|------|------|
| 两个包注册**同名同版本** | xvm 直接拒绝，第二个包整批 config 失败：`another package already owns this exact name and version` |
| 两个包注册**同名不同版本** | **接受**，名字变成双 owner。一次 `xvm use` 落到另一侧就静默改写共享 `lib/` 里的符号链接 |

第二种更危险，因为安装当下一切正常。实测（musl 加入前）：

```
crt1.o = {"active": "glibc-2.39", "installed": ["glibc-2.39", "musl-1.2.5"]}
```

`crt1.o` 一旦切到 musl 那侧，该 subos 里所有 glibc C 链接全部静默挂掉。

**做法**：共享名注册到 **`<version>-<flavor>`**，并在配方里把撞名集合**单独列成一张表**。

```lua
-- 和 glibc.lua 的 glibc_libs 求交集算出来的，不是眼估的
local SHARED_LIBS = { "crt1.o", "crti.o", "crtn.o", "Scrt1.o", "libc.a",
                      "libc.so", "libdl.a", "libm.a", "libpthread.a",
                      "librt.a", "libutil.a" }
local MUSL_ONLY_LIBS = { "ld-musl-x86_64.so.1", "rcrt1.o", "libcrypt.a",
                         "libresolv.a", "libxnet.a" }
local FLAVOR = "musl"
local function flavor_version() return pkginfo.version() .. "-" .. FLAVOR end
```

规则：

1. **撞名集合要算，不要估。** 拿对方配方里的注册表和自己 payload 里真实的目录求交集，
   并用测试锁住这个集合 —— 上游改了文件集，测试要能发现。
2. **撞名的必须带 flavor；不撞名的也一起带**，这样整组能被同一次 `xlings use` 切换，
   将来第三个包进来也是撞上约定而不是撞上一个恰好空着的版本号。
3. **绑定根用 `type = "group"`。** 根节点不对应任何可执行文件（没有 `bin/musl`），
   留成默认的 program 类型会生成一个永远失败的 shim
   （`subos/*/bin/musl -> bin/xlings`），`self doctor` 会把它报成 orphan
   （openxlings/xlings#452）。
4. **`uninstall()` 必须版本内收敛**：`xvm.remove(name, <stored key>)`。
   用裸名删会把对方包的注册一起删掉。

   ⚠️ **`xvm.add` 会自己补索引命名空间前缀，`xvm.remove` 不会。**
   从 `local:` 或任何非 `xim` 的索引仓库安装时，`version = "1.2.5-musl"` 实际存成
   `local:1.2.5-musl`；卸载时传裸键匹配不到，根节点删了、所有 lib 节点全留下。
   **CI 抓不到**——`posix-test.sh` 的卸载后检查只看 `bin/` 里残留的 shim，
   而 lib 节点不产生 shim。照 glibc.lua 的 `__version_key()` 写：

   ```lua
   function __stored_version()
       local store = path.filename(path.directory(pkginfo.install_dir()))
       local ns = store:match("^(.-)%-x%-")   -- <data>/xpkgs/<ns>-x-<name>/<version>
       local bare = flavor_version()
       if ns and ns ~= "" and ns ~= "xim" then return ns .. ":" .. bare end
       return bare
   end
   ```

   验收方式：装完 → 看 `subos/<name>/.xlings.json` 的 `workspace` → 卸载 → 再看一次，
   必须回到 `null`。只跑 `posix-test.sh` 不足以说明卸载干净。
5. **头文件同理。** 两个 libc 的 `stdio.h`/`features.h` 内容不同，散进共享
   `usr/include` 后落地的那个会静默赢下整个 subos 的编译 —— 非 system libc 的头
   要落到自己的命名空间（`usr/include/musl`）。

已有先例（新包照抄即可）：`jdk-temurin/corretto/zulu` 的 `25.0.4+7-temurin`、
`musl-gcc.lua` 的 `16.1.0-musl`、`musl.lua` 的 `1.2.5-musl`。

### 2.4 禁止事项（隔离合规）

- 不要 `os.exec("xvm add ...")` / `os.exec("xvm remove ...")`
- 不要修改 `.bashrc` / shell profile
- 不要直接 `os.addenv("PATH")` 或 `os.setenv("PATH")`
- 不要直接 `apt install` / `brew install` / `pacman -S`

依赖请通过 `xpm.<platform>.deps` 声明；命令路由请通过 xvm shim 完成。

## 3) 新增/修改包的标准流程

1. 在 `pkgs/<首字母>/<name>.lua` 新增或修改包。
2. 若新增包，创建镜像测试文件：
   - `tests/<首字母>/test_<name_with_underscore>.py`
   - 测试默认锁定：只 import `xim.libxpkg.*`，只使用标准 Lua + xpkg 规范，不使用 `path.*`/`os.host()`/`try {}`/`raise()` 等 xmake 私有 API。
   - 对写用户配置的 `type = "config"` 包，额外锁定：`install()` 轻量，实际写入在 `config()`。
3. 先跑本地直接命令验证（索引/安装/搜索/卸载）。
4. 再跑测试集验证（L0~L4，至少 L0/L1/L2）。
5. 准备 PR：写清楚包用途、安装/卸载行为、系统影响、测试结果。

详细步骤与命令见 `references/testing-and-acceptance.md`。

## 4) PR 提交硬性要求

- 本地通过直接命令验证 + pytest 测试验证。
- 新增包必须带对应 `tests/` 测试文件。
- 不破坏 subos 隔离。
- PR 描述中必须包含：
  1) 包的作用
  2) 安装时做了什么
  3) 卸载时做了什么
  4) 是否修改系统配置/环境变量
  5) 本地测试与 CI 测试结果

## 5) 最小骨架（V2）

```lua
package = {
  spec = "2",
  name = "demo",
  description = "demo package",
  type = "package",
  archs = {"x86_64"},
  status = "stable",
  categories = {"tools"},
  keywords = {"demo"},
  xvm_enable = true,
  xpm = {
    source = "xlings-res",
    linux = {
      ["latest"] = { ref = "1.0.0" },
      ["1.0.0"] = {
        sha256 = { x86_64 = "<sha256>", aarch64 = "<sha256>" },
      },
    },
  },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
  os.tryrm(pkginfo.install_dir())
  os.mv("demo", pkginfo.install_dir())
  return true
end

function config()
  xvm.add("demo")
  return true
end

function uninstall()
  xvm.remove("demo")
  return true
end
```
