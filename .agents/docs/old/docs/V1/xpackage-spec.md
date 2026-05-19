# XPackage Spec V1

> `spec = "1"`

## 运行时环境

### 设计原则

xpkg 包脚本的运行时环境 = **标准 Lua 5.4** + **libxpkg 标准库**。

- 不依赖 xmake 特有 API（`is_host()`、`format()`、`runtime.*` 等）
- 不依赖宿主工具的实现细节
- 任何符合规范的解析器/执行器都能正确处理

### 可用 API 清单

**标准 Lua：** `string`、`table`、`math`、`os`（基础）、`io`（基础）、`pcall`、`type`、`tostring`、`tonumber`、`pairs`、`ipairs`、`require`、`setmetatable` 等

**libxpkg 扩展（prelude）：**

| 分类 | 函数 | 说明 |
|------|------|------|
| 平台 | `os.host()` | 返回 `"linux"` / `"windows"` / `"macosx"` |
| 文件 | `os.isfile(path)` | 文件是否存在 |
| 文件 | `os.isdir(path)` | 目录是否存在 |
| 文件 | `os.mv(src, dst)` | 移动（支持跨设备） |
| 文件 | `os.cp(src, dst)` | 复制 |
| 文件 | `os.dirs(pattern)` | 目录列表 |
| 路径 | `path.join(...)` | 拼接路径 |
| 路径 | `path.filename(p)` | 取文件名 |
| 路径 | `path.directory(p)` | 取目录名 |
| IO | `io.readfile(path)` | 读文件 |
| IO | `io.writefile(path, content)` | 写文件 |
| 字符串 | `string.split(s, sep)` | 分割字符串 |
| 控制流 | `try { fn, catch = { handler } }` | 异常处理 |
| 输出 | `cprint(fmt, ...)` | 带颜色打印 |

**libxpkg 模块（通过 `import()` 导入）：**

| 模块 | 导入方式 | 核心 API |
|------|---------|---------|
| pkginfo | `import("xim.libxpkg.pkginfo")` | `name()`, `version()`, `install_file()`, `install_dir()`, `dep_install_dir()`, `deps_list()` |
| xvm | `import("xim.libxpkg.xvm")` | `add()`, `remove()`, `setup()`, `teardown()`, `use()`, `has()` |
| system | `import("xim.libxpkg.system")` | `exec()`, `rundir()`, `xpkgdir()`, `bindir()`, `subos_sysrootdir()`, `unix_api()` |
| log | `import("xim.libxpkg.log")` | `info()`, `warn()`, `error()`, `debug()` |
| utils | `import("xim.libxpkg.utils")` | `filepath_to_absolute()`, `try_download_and_check()`, `input_args_process()` |
| pkgmanager | `import("xim.libxpkg.pkgmanager")` | `install()`, `remove()` |
| elfpatch | `import("xim.libxpkg.elfpatch")` | `patch_elf_loader_rpath()`, `auto()`, `apply_auto()`, `closure_lib_paths()` |
| json | `import("xim.libxpkg.json")` | `encode()`, `decode()`, `loadfile()`, `savefile()` |
| base64 | `import("xim.libxpkg.base64")` | `encode()`, `decode()` |

### 包文件结构规则

```lua
-- ① package 表：纯静态数据，只用标准 Lua 字面量和 string.format()
package = {
    spec = "1",
    name = "example",
    -- ...
    xpm = { ... },  -- 按平台分区定义 URL，不用函数动态计算
}

-- ② import 区：导入 libxpkg 模块
local pkginfo = import("xim.libxpkg.pkginfo")
local xvm     = import("xim.libxpkg.xvm")

-- ③ hook 函数：所有运行时逻辑在此
function installed() ... end
function install()   ... end
function config()    ... end
function uninstall() ... end
```

**关键约束：**

1. **`package` 表必须静态可求值** — 只用字面量和 `string.format()`，不调用运行时函数
2. **按平台分区定义资源** — 使用 xpm 的 `linux = {...}` / `windows = {...}`，不用 `is_host()` 判断
3. **运行时初始化放在 hook 函数内** — 顶层作用域不调用 `path.join()`、`os.getenv()`、`system.*` 等
4. **只用规范定义的 API** — `string.format()` 而非 `format()`，`os.host()` 而非 `is_host()`

### 禁用 API 与替代方案

| 禁用（xmake 特有） | 替代（xpkg 规范） |
|-------------------|-----------------|
| `is_host("linux")` | `os.host() == "linux"` |
| `format(...)` | `string.format(...)` |
| `runtime.get_pkginfo()` | `import("xim.libxpkg.pkginfo")` |
| `os.scriptdir()` | `system.xpkgdir()` 或 `pkginfo.install_dir()` |
| 顶层 `path.join(...)` | 移入 hook 函数内 |

## Package 域

### 基础字段

```lua
package = {
    spec = "1",  -- 规范版本号 (必填)

    -- 基础信息
    name = "package-name",          -- 包名 (必填)
    description = "描述信息",        -- 包描述 (必填)
    type = "package",               -- 包类型 (必填): "package" | "script" | "template" | "config"

    homepage = "https://example.com",
    repo = "https://example.com/repo",
    docs = "https://example.com/docs",
    forum = "https://forum.example.com",

    authors = {"Author1", "Author2"},
    maintainers = {"Maintainer1"},
    contributors = "https://github.com/xxx/graphs/contributors",
    licenses = {"MIT"},

    -- xim 包信息
    archs = {"x86_64", "arm64"},           -- 支持的架构
    status = "stable",                      -- 状态: "dev" | "stable" | "deprecated"
    categories = {"category1", "category2"},
    keywords = {"keyword1", "keyword2"},

    -- 可执行程序列表
    programs = {"program1", "program2"},

    -- xvm (xlings版本管理) 集成
    xvm_enable = true,

    -- 平台资源配置
    xpm = { ... },
}
```

### 引用包 (Ref Package) - 废弃

可以通过 `ref` 字段创建包别名, 指向另一个已有的包:

```lua
package = { spec = "1", type = "package", ref = "nodejs" }
```

### xpm 字段详解

`xpm` 描述包在各平台下的依赖和资源。**没有描述的平台/系统和版本不会添加到本地索引数据库中, 即不可查询和安装。**

```lua
xpm = {
    -- 平台key: windows, linux, macosx, ubuntu, archlinux, manjaro, ...
    linux = {
        deps = {"dep1", "dep2@1.0.0"},    -- 可选: 平台依赖
        ["latest"] = { ref = "1.0.0" },   -- 版本引用: latest -> 1.0.0
        ["1.0.0"] = {                      -- 完整URL格式
            url = "https://example.com/pkg-1.0.0.tar.gz",
            sha256 = "abc123..."           -- 可选: sha256 校验
        },
        ["0.9.0"] = "XLINGS_RES",         -- 自动生成URL (从xlings镜像)
    },
    macosx = {
        ["latest"] = { ref = "1.0.0" },
        ["1.0.0"] = "XLINGS_RES",
    },
    ubuntu = { ref = "linux" },            -- 平台引用: 继承linux的配置
}
```

**版本值的三种格式:**

| 格式 | 说明 | 示例 |
|------|------|------|
| `{ url = "...", sha256 = "..." }` | 完整URL + 可选校验 | `["1.0.0"] = { url = "https://...", sha256 = nil }` |
| `"XLINGS_RES"` | 自动从xlings镜像生成URL | `["1.0.0"] = "XLINGS_RES"` |
| `{ ref = "x.x.x" }` | 引用另一个版本 | `["latest"] = { ref = "1.0.0" }` |
| `{ }` | 空资源 (用于script/config等无需下载的包) | `["0.0.1"] = { }` |

**镜像 URL 格式:**

`url` 字段除了普通字符串，还支持镜像表格式，为不同地区提供不同的下载源：

```lua
["1.0.0"] = {
    url = {
        GLOBAL = "https://github.com/xxx/releases/download/v1.0.0/pkg.tar.gz",
        CN     = "https://gitee.com/xxx/releases/download/v1.0.0/pkg.tar.gz",
    },
    sha256 = "abc123..."
}
```

解析优先级：`GLOBAL` > `CN`。

## Hooks 域

Hooks 是安装/卸载时实际执行的 Lua 函数。通过 `import` 导入辅助模块:

```lua
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")
import("xim.libxpkg.log")
import("xim.libxpkg.utils")
```

### Hook 执行流程

1. `installed()` - 检测是否已安装
2. download - 自动下载资源 (框架处理)
3. deps - 处理依赖 (框架处理)
4. `build()` - 构建 (可选)
5. `install()` - 安装
6. `config()` - 配置
7. `uninstall()` - 卸载

### Hook 函数说明

**installed()** - 检测包是否已安装

```lua
function installed()
    -- 返回 boolean 或 包含版本号的字符串
    return os.iorun("program --version")
end
```

**install()** - 安装包

```lua
function install()
    -- pkginfo.install_file() 下载的文件路径 (压缩包已自动解压)
    -- pkginfo.install_dir()  安装目标目录
    os.mv("program", pkginfo.install_dir())
    return true
end
```

**config()** - 配置包 (通常注册到xvm)

```lua
function config()
    xvm.add("program-name")
    -- 或指定 bindir:
    -- xvm.add("program-name", { bindir = path.join(pkginfo.install_dir(), "bin") })
    return true
end
```

**uninstall()** - 卸载包

```lua
function uninstall()
    xvm.remove("program-name")
    return true
end
```

**build()** - 构建包 (可选)

```lua
function build()
    os.exec("make -j$(nproc)")
    return true
end
```

### 辅助模块 API

**pkginfo** (`xim.libxpkg.pkginfo`)

| 方法 | 说明 |
|------|------|
| `pkginfo.name()` | 包名 |
| `pkginfo.version()` | 当前安装的版本 |
| `pkginfo.install_file()` | 下载的文件路径 |
| `pkginfo.install_dir()` | 安装目录 |
| `pkginfo.dep_install_dir(dep_name, dep_version)` | 依赖的安装目录 |

**xvm** (`xim.libxpkg.xvm`)

| 方法 | 说明 |
|------|------|
| `xvm.add(name)` | 注册到xvm (自动检测bindir) |
| `xvm.add(name, { bindir = "...", envs = {...} })` | 注册到xvm (指定bindir，可选环境变量) |
| `xvm.remove(name)` | 从xvm移除当前版本 |
| `xvm.remove(name, version)` | 从xvm移除指定版本 |
| `xvm.setup(name, opt)` | 批量注册程序、库和头文件 |
| `xvm.teardown(name, opt)` | 批量注销程序、库和头文件 |

`xvm.add()` 的 `opt` 参数：

| 字段 | 类型 | 说明 |
|------|------|------|
| `version` | string | 版本号（默认取 `_RUNTIME.version`） |
| `bindir` | string | 可执行文件目录 |
| `alias` | string | 别名 |
| `type` | string | `"program"` (默认) 或 `"lib"` |
| `filename` | string | 文件名 |
| `binding` | string | 绑定关系（如 `"python@3.12.6"`） |
| `envs` | table | 环境变量表（如 `{ HOMEBREW_PREFIX = "/opt/homebrew" }`） |

`xvm.setup()` / `xvm.teardown()` 的 `opt` 参数：

| 字段 | 类型 | 说明 |
|------|------|------|
| `install_dir` | string | 安装根目录（默认 `_RUNTIME.install_dir`） |
| `version` | string | 版本号 |
| `bindir` | string | 程序目录（相对或绝对，默认 `"bin"`） |
| `libdir` | string | 库目录（相对或绝对，可选） |
| `includedir` | string | 头文件目录（相对或绝对，可选） |
| `programs` | list | 程序名列表 |
| `libs` | list | 库文件名列表 |

**system** (`xim.libxpkg.system`)

| 方法 | 说明 |
|------|------|
| `system.exec(cmd, opt)` | 执行命令 (支持重试) |
| `system.subos_sysrootdir()` | 获取sysroot目录 |
| `system.unix_api().append_to_shell_profile(config)` | 配置shell profile |
| `system.rundir()` | 获取运行目录 |

**log** (`xim.libxpkg.log`)

| 方法 | 说明 |
|------|------|
| `log.info(msg, ...)` | 信息日志 |
| `log.warn(msg, ...)` | 警告日志 |
| `log.error(msg, ...)` | 错误日志 |

**pkgmanager** (`xim.libxpkg.pkgmanager`)

| 方法 | 说明 |
|------|------|
| `pkgmanager.install(target)` | 安装子依赖 |
| `pkgmanager.remove(target)` | 卸载子依赖 |

**elfpatch** (`xim.libxpkg.elfpatch`)

| 方法 | 说明 |
|------|------|
| `elfpatch.auto(enable)` | 启用/禁用自动 ELF 补丁（install hook 后自动应用） |
| `elfpatch.auto({ enable = true, shrink = true })` | 启用自动补丁并压缩 RPATH |
| `elfpatch.patch_elf_loader_rpath(target, opts)` | 手动补丁 ELF 的 interpreter 和 RPATH |
| `elfpatch.closure_lib_paths(opt)` | 收集自身+依赖的 lib 路径（用于 RPATH） |

**json** (`xim.libxpkg.json`)

| 方法 | 说明 |
|------|------|
| `json.encode(val, opts)` | 编码 Lua 值为 JSON 字符串 |
| `json.decode(str)` | 解码 JSON 字符串为 Lua 值 |
| `json.loadfile(path)` | 从文件加载 JSON |
| `json.savefile(path, val, opts)` | 将 Lua 值保存为 JSON 文件 |

**base64** (`xim.libxpkg.base64`)

| 方法 | 说明 |
|------|------|
| `base64.encode(data)` | Base64 编码 |
| `base64.decode(data)` | Base64 解码（返回字符串） |

## 包类型说明

### package 类型

标准包, 用于安装可执行程序或库。通常需要 `install`, `config`, `uninstall` 函数。

### script 类型

脚本包, 通过 `xscript` 命令调用。入口函数为 `xpkg_main(...)`:

```lua
package = {
    spec = "1",
    name = "my-script",
    type = "script",
    -- ...
    xpm = {
        linux = { ["0.0.1"] = { } },
    },
}

import("xim.libxpkg.utils")

local __xscript_input = {
    ["--option1"] = false,
    ["--option2"] = false,
}

function xpkg_main(action, ...)
    local cmds = utils.input_args_process(__xscript_input, { ... })
    -- 脚本逻辑...
end
```

### config 类型

配置包, 用于系统配置操作, 无需下载资源文件。

## 完整示例

### 示例1: 标准包 (mdbook)

```lua
package = {
    spec = "1",
    -- base info
    name = "mdbook",
    description = "Create book from markdown files. Like Gitbook but implemented in Rust",

    authors = {"Mathieu David", "Michael-F-Bryan", "Matt Ickstadt"},
    contributors = "https://github.com/rust-lang/mdBook/graphs/contributors",
    licenses = {"MPL-2.0"},
    repo = "https://github.com/rust-lang/mdBook",
    docs = "https://rust-lang.github.io/mdBook",

    -- xim pkg info
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"book", "markdown"},
    keywords = {"book", "gitbook", "rustbook", "markdown"},

    xvm_enable = true,

    xpm = {
        windows = {
            ["latest"] = { ref = "0.4.40" },
            ["0.4.43"] = {
                url = "https://github.com/rust-lang/mdBook/releases/download/v0.4.43/mdbook-v0.4.43-x86_64-pc-windows-msvc.zip",
                sha256 = nil
            },
            ["0.4.40"] = {
                url = "https://gitee.com/sunrisepeak/xlings-pkg/releases/download/mdbook/mdbook-v0.4.40-x86_64-pc-windows-msvc.zip",
                sha256 = nil
            },
        },
        linux = {
            ["latest"] = { ref = "0.4.43" },
            ["0.4.43"] = "XLINGS_RES",
            ["0.4.40"] = {
                url = "https://github.com/rust-lang/mdBook/releases/download/v0.4.40/mdbook-v0.4.40-x86_64-unknown-linux-gnu.tar.gz",
                sha256 = "9ef07fd288ba58ff3b99d1c94e6d414d431c9a61fdb20348e5beb74b823d546b"
            },
        },
        macosx = {
            ["latest"] = { ref = "0.4.43" },
            ["0.4.43"] = "XLINGS_RES",
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

local mdbook_file = {
    windows = "mdbook.exe",
    linux = "mdbook",
    macosx = "mdbook"
}

function install()
    return os.trymv(mdbook_file[os.host()], pkginfo.install_dir())
end

function config()
    xvm.add("mdbook")
    return true
end

function uninstall()
    xvm.remove("mdbook")
    return true
end
```

### 示例2: 带依赖的包 (gcc)

```lua
package = {
    spec = "1",
    name = "gcc",
    description = "GCC, the GNU Compiler Collection",
    type = "package",

    authors = {"GNU"},
    licenses = {"GPL"},
    repo = "https://github.com/gcc-mirror/gcc",

    archs = { "x86_64" },
    status = "stable",
    categories = { "compiler", "gnu", "language" },
    keywords = { "compiler", "gnu", "gcc", "language", "c", "c++" },

    programs = {
        "gcc", "g++", "c++", "cpp",
        "gcc-ar", "gcc-nm", "gcc-ranlib",
    },

    xvm_enable = true,

    xpm = {
        linux = {
            deps = { "glibc@2.39", "binutils@2.42", "linux-headers@5.11.1" },
            ["latest"] = { ref = "15.1.0" },
            ["15.1.0"] = "XLINGS_RES",
            ["13.3.0"] = "XLINGS_RES",
        },
    },
}
```

### 示例3: 引用包 (node -> nodejs)  - 废弃

```lua
package = { spec = "1", type = "package", ref = "nodejs" }
```

### 示例4: 脚本包 (script)

```lua
package = {
    spec = "1",
    name = "my-tool",
    description = "XScript: My Tool",
    type = "script",

    authors = {"author"},
    licenses = {"Apache-2.0"},

    status = "stable",
    categories = {"tools"},

    xpm = {
        linux = { ["0.0.1"] = { } },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.utils")

local __xscript_input = {
    ["--flag1"] = false,
    ["--flag2"] = false,
}

function xpkg_main(action, ...)
    local cmds = utils.input_args_process(__xscript_input, { ... })
    -- 脚本逻辑
    log.info("Running my-tool with action: %s", action)
end

function uninstall()
    log.info("Uninstalling my-tool...")
    return true
end
```
