# 如何添加一个 XPackage 到包索引仓库 (xim-pkgindex)?

> 本文档基于 XPackage Spec V1 (`spec = "1"`)

## 第一步 - 创建 Issue

在 [xim-pkgindex](https://github.com/openxlings/xim-pkgindex) 仓库创建一个 [Add XPackage](https://github.com/openxlings/xim-pkgindex/issues/new/choose) Issue, 填写包的基础信息:

- 包名
- 包的简短描述
- 主页 / 仓库
- 开源 or 闭源
- 协议
- ...

## 第二步: 复制包模板文件

复制一份 [包模板文件](xpackage-template.lua)。一个包文件由两大部分组成: **package 域** + **hooks 域**, 包文件的语法对应 Lua 语言的基础语法 (**不需要特殊学习 Lua, 参考已有包的用法即可**)。

## 第三步: 填写 package 域

### 基础信息

基础信息用来描述和记录包的相关信息, 在安装时会进行显示, 但不影响实际安装过程。至少需要包含 `spec`、`name`、`description`、`type`、`keywords` 字段:

```lua
package = {
    spec = "1",

    -- 基础信息
    name = "mdbook",
    description = "Create book from markdown files. Like Gitbook but implemented in Rust",

    authors = {"Mathieu David", "Michael-F-Bryan", "Matt Ickstadt"},
    contributors = "https://github.com/rust-lang/mdBook/graphs/contributors",
    licenses = {"MPL-2.0"},
    repo = "https://github.com/rust-lang/mdBook",
    docs = "https://rust-lang.github.io/mdBook",

    -- xim 包信息
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"book", "markdown"},
    keywords = {"book", "gitbook", "rustbook", "markdown"},

    -- xvm 版本管理
    xvm_enable = true,
}
```

### 平台 & 依赖 & 资源 - xpm

`xpm` 字段描述包支持的平台、依赖和网络资源。**没有描述的平台/系统和版本不会添加到本地索引数据库中, 即不可查询和安装。**

- 系统名是 `xpm` 的 key, 表示支持的平台 (`windows`, `linux`, `macosx`, `ubuntu`, ...)
- `deps` 是可选项, 描述该平台下的依赖 (这些依赖需要已在索引仓库中), 支持指定版本如 `dep@1.0.0`
- 版本值支持三种格式:
  - `{ url = "...", sha256 = "..." }` - 完整URL + 可选sha256校验
  - `"XLINGS_RES"` - 自动从 xlings 镜像生成 URL
  - `{ ref = "x.x.x" }` - 引用另一个版本
- 平台支持引用: `ubuntu = { ref = "linux" }` 表示 ubuntu 继承 linux 的配置

```lua
package = {
    -- ...
    xpm = {
        windows = {
            ["latest"] = { ref = "0.4.40" },
            ["0.4.40"] = {
                url = "https://gitee.com/xxx/mdbook-v0.4.40-x86_64-pc-windows-msvc.zip",
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
```

> **注:**
>
> 1. `latest` 版本一般使用 `ref` 引用到一个具体版本上
>
> 2. 如果没有网络资源时 (例如 script/config 类型包) 可以填写空表: `["0.0.1"] = { }`
>
> 3. `"XLINGS_RES"` 会自动从 xlings 镜像源生成下载 URL

## 第四步: 编写 hooks 函数

### 导入辅助模块

V1 规范使用新的模块导入方式:

```lua
import("xim.libxpkg.pkginfo")   -- 包信息 (安装路径、版本等)
import("xim.libxpkg.xvm")       -- xvm 版本管理
import("xim.libxpkg.system")    -- 系统操作 (可选)
import("xim.libxpkg.log")       -- 日志 (可选)
```

### install 函数

- `pkginfo.install_file()` 返回下载的文件路径 (压缩包已由框架自动解压)
- `pkginfo.install_dir()` 返回安装目标目录
- 所有 hooks 运行在与下载资源同级的目录

```lua
function install()
    return os.trymv("mdbook", pkginfo.install_dir())
end
```

对于解压后是目录的情况:

```lua
function install()
    local dir = pkginfo.install_file()
        :replace(".zip", "")
        :replace(".tar.gz", "")
    os.tryrm(pkginfo.install_dir())
    os.mv(dir, pkginfo.install_dir())
    return true
end
```

> **预构建二进制（ELF）可重定位**：若包为 Linux 预构建且解释器/RPATH 写死构建机路径，需在 install 中做 patchelf 等修正，使任意用户/路径下可用。详见 xlings 文档 [ELF 可重定位与多 subos 设计](https://github.com/openxlings/xlings/blob/main/docs/mcpp-version/elf-relocation-and-subos-design.md)。

### config 函数

通常用于注册到 xvm:

```lua
function config()
    xvm.add("mdbook")
    return true
end
```

如果可执行文件不在安装目录根下, 可以指定 bindir:

```lua
function config()
    xvm.add("cmake", {
        bindir = path.join(pkginfo.install_dir(), "bin")
    })
    return true
end
```

### uninstall 函数

```lua
function uninstall()
    xvm.remove("mdbook")
    return true
end
```

### installed 函数 (可选)

用于检测包是否已安装, 返回 `true/false` 或包含版本号的字符串:

```lua
function installed()
    return os.iorun("mdbook --version")
end
```

### mdbook 完整示例

```lua
package = {
    spec = "1",
    name = "mdbook",
    description = "Create book from markdown files. Like Gitbook but implemented in Rust",

    authors = {"Mathieu David", "Michael-F-Bryan", "Matt Ickstadt"},
    contributors = "https://github.com/rust-lang/mdBook/graphs/contributors",
    licenses = {"MPL-2.0"},
    repo = "https://github.com/rust-lang/mdBook",
    docs = "https://rust-lang.github.io/mdBook",

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

## 第五步: 测试包

### 添加包到索引数据库

```bash
xlings install --add-xpkg yourLocalPath/mdbook.lua
```

示例:

```bash
speak@speak-pc:~$ xlings install --add-xpkg mdbook.lua
[xlings]: convert xpkg-file to runtime path - mdbook.lua
[xlings]: add xpkg - /home/speak/mdbook.lua
[xlings]: update index database
```

### 搜索测试

```bash
xlings search mdbook
```

示例:

```bash
speak@speak-pc:~$ xlings search mdbook
[xlings]: search for *mdbook* ...

{ 
  "mdbook@0.4.40" = { },
  "mdbook@0.4.43" = { 
    "mdbook",
    "mdbook@latest" 
  } 
}
```

### 安装测试

```bash
xlings install mdbook
```

安装会依次执行: `installed` -> `download` -> `build`(可选) -> `install` -> `config`(可选)

安装完成后, 重新打开终端刷新环境, 再次运行安装命令检测是否重复安装。

### 安装列表测试

```bash
xlings list mdbook
```

```bash
speak@speak-pc:~$ xlings list mdbook
-> mdbook@0.4.43 (mdbook@latest, mdbook)
```

### 卸载测试

```bash
xlings remove mdbook
```

卸载后可再次执行卸载命令, 检测是否能正确识别包已卸载。

## 第六步: 补充测试信息到 Issue

把第五步中测试的 log 或截图补充到第一步创建的 Issue 里。

## 第七步: Fork 仓库并放置包文件

Fork [xim-pkgindex](https://github.com/openxlings/xim-pkgindex) 仓库, 把包文件放到 `pkgs` 目录下对应首字母目录中。

索引仓库按文件名首字母分类。

## 第八步: 发起 Pull Request

- 提交文件到自己 fork 的仓库
- 发起 Pull Request
- 把 PR 地址补充到 Issue 里
- 在评论区 @ 项目维护人员

## 第九步: 合入仓库

交流讨论 & reviewer 本地验证通过后合入仓库。

## 第十步: 更新本地索引

```bash
xlings update
```

> xlings 会自动同步最新的包索引数据库到本地
