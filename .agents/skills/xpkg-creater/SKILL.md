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

### 2.3 config() 约束

`config()` 负责将该版本注册到 xvm（subos 隔离路由）：
- 使用 `xvm.add("tool")`
- 或 `xvm.add("tool", { bindir = ..., alias = ... })`
- 可执行文件不在安装根目录时，必须明确 `bindir`

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
