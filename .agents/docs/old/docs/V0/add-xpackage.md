> **⚠️ 本文档已废弃。** 请使用 [V1 规范](../V1/add-xpackage.md)。V0 使用的 `xim` 命令和 `xim.base.runtime` API 已被移除。

# [已废弃] 如何添加一个XPackage到包索引仓库(xim-pkgindex)?

## 第一步 - 创建一个[Add XPackage](https://github.com/openxlings/xim-pkgindex/issues/new/choose)

在`xim-pkgindex`的issues创建选择界面选择`Add XPackage`模板并先填写包的基础信息

- 包名
- 包的简短描述
- 主页
- 开源 or 闭源
- 仓库
- 协议
- ...

## 第二步: 复制一份[包模板文件](docs/xpackage-template.lua)

复制一份包模板文件。一个包文件有两大部分组成: package + hooks/actions, 并且包文件的语法对应的就是lua语言的基础语法(**并不需要特殊学习lua, 只要参考已有的包里的用法即可**)

### package域

**基础信息描述部分**

基础信息部分主要是要来描述和记录这个包的相关信息的。**这些信息会在安装的时候进行显示, 但是他们不会实质的影响安装的过程。**但为了包的完整度应该尽可能的填写相关字段(至少包含`name`、`description`、`type`、`keywords`)。具体格式如下:

```lua
package = {
    -- base info
    homepage = "https://example.com",

    name = "package-name",
    description = "Package description",

    authors = "Author Name",
    maintainers = "Maintainer Name or url",
    contributors = "Contributor Name or url",
    licenses = "MIT",
    repo = "https://example.com/repo",
    docs = "https://example.com/docs",

    -- xim pkg info
    type = "package", -- package, config
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"category1", "category2"},
    keywords = {"keyword1", "keyword2"},
    date = "2024-12-01",
    --...
}
```

**平台&依赖&资源描述部分 - xpm**

xpm字段描述了这个包支持的具体的平台, 以及每个平台上安装这个包需要的依赖和网络资源。这个部分会实质性的影响安装过程且**没有描述的平台/系统和版本将不会添加到用户的本地索引数据库中, 即不可查询和安装**

- 系统名是xpm的中的key, 表示要支持的系统/平台
- 系统key对应的值包含:
  - deps是可选项, 用来描述这个包在对应平台下需要的依赖(这些依赖需要已经在索引仓库中)
  - 版本项也是kv结构 `["key"] = {"url", "sha256"}`
    - 它的key的格式一般为`x.x.x`其中x是数字, 也可以用`latest`描述(用户默认安装的版本)
    - 它的值的格式为一对字符串, 第一个是网络资源url, 第二个为这个资源对应的sha256校验码(为可选项, xim会自动的下载资源并校验, 路径会存在pkginfo.install_file中)
- 在xpm的中系统字段和版本字段支持同级引用, 如: `["latest"] = { ref = "1.0.1"}` latest对应的值将会是`1.0.1`里的值

```lua
package = {
    -- ...
    xpm = {
        windows = {
            deps = {"dep1", "dep2"},
            ["1.0.1"] = {"url", "sha256"},
            ["1.0.0"] = {"url", "sha256"},
        },
        ubuntu = {
            deps = {"dep3", "dep4"},
            ["latest"] = { ref = "1.0.1"},
            ["1.0.1"] = {"url", "sha256"},
            ["1.0.0"] = {"url", "sha256"},
        },
    },
}
```

> **注:**
>
>    1.latest版本一般会使用ref引用到一个具体的版本上
>
>    2.如果没有网络资源时(例如是config包)可以填写一个空列表。如: `["1.0.1"] = { },`
>

### hooks/actions域

hooks域主要是安装或卸载时实际对应的lua函数, 最少要包含: `installed`、`install`、`uninstall` 这三个函数, 他们描述了包对应动作下的具体行为。

**installed**

用来检测对应版本是否被安装, 支持返回true/false或直接返回包含版本的字符串, 框架中会自动的检测字符串是否包含对应的版本号, 常用的实现是直接返回 `os.iorun("program --version")`。对于无法直接获取版本号的包/软件, 可以通过代码自行判断并和当前要执行的版本号进行对比, 然后返回true或false

```lua
function installed()
    -- ...
end
```

**install/uninstall**

install和uninstall主要是对应的安装和卸载, 可以使用lua代码对资源文件进行操作。通常使用os.exec函数等同与命令行

> **注:** 所有的hooks都运行在和所下载资源的同级目录

## 第三步: 修改文件名和包内容 - mdbook包文件示例

把[包模板文件](docs/xpackage-template.lua)重命令为`mdbook.lua`并修改文件内容

**mdbook安装的核心逻辑是, 把解压出来的执行文件复制到系统的bin目录或其他已经添加到path环境变量中的路径里**

### 添加mdbook基础信息

```lua
package = {
    -- base info
    name = "mdbook",
    description = "Create book from markdown files. Like Gitbook but implemented in Rust",

    authors = "Mathieu David, Michael-F-Bryan, Matt Ickstadt",
    contributors = "https://github.com/rust-lang/mdBook/graphs/contributors",
    licenses = "MPL-2.0",
    repo = "https://github.com/rust-lang/mdBook",
    docs = "https://rust-lang.github.io/mdBook",

    -- xim pkg info
    type = "package",
    categories = {"book", "markdown"},
    keywords = {"book", "gitbook", "rustbook", "markdown"},
}
```

### 添加xpm基础信息

- 主要支持平台为: windows, linux(ubuntu, debian, archlinux)
- mdbook没有依赖, 所以不需要deps字段
- 把mdbook的不同平台的二进制执行文件包的url添加到对应版本的value中
- windows支持0.4.40, debain支持0.4.40, 0.4.43版本
- 设置每个平台下的latest版本对应的具体版本, windows上ref到`0.4.40`, debain上ref到`0.4.43`
- 由于mdbook支持所有linux系统, 所以`ubuntu, archlinux`可以直接ref到debian

```lua
package = {
    -- ...
    xpm = {
        windows = {
            ["latest"] = { ref = "0.4.40" },
            ["0.4.40"] = {
                url = "https://gitee.com/sunrisepeak/xlings-pkg/releases/download/mdbook/mdbook-v0.4.40-x86_64-pc-windows-msvc.zip",
                sha256 = nil
            }
        },
        debain = {
            ["latest"] = { ref = "0.4.43" },
            ["0.4.43"] = {
                url = "https://github.com/rust-lang/mdBook/releases/download/v0.4.43/mdbook-v0.4.43-x86_64-unknown-linux-gnu.tar.gz",
                sha256 = "d20c2f20eb1c117dc5ebeec120e2d2f6455c90fe8b4f21b7466625d8b67b9e60"
            },
            ["0.4.40"] = {
                url = "https://github.com/rust-lang/mdBook/releases/download/v0.4.40/mdbook-v0.4.40-x86_64-unknown-linux-gnu.tar.gz",
                sha256 = "9ef07fd288ba58ff3b99d1c94e6d414d431c9a61fdb20348e5beb74b823d546b"
            },
        },
        archlinux = { ref = "debain" },
        ubuntu = { ref = "debain" },
    },
}
```

### 编写mdbook的hooks函数

- 使用import语法导入xim的platform模块, 用于获取系统的bin目录
- 由于mdbook的压缩包解压出来就是一个mdbook的可执行文件, windows上为`mdbook.exe`, linux上为`mdbook`。所以使用lua语法定义局部变量mdbook_file用于表示不同平台下的对应的文件名
- 实现`installed`函数: mdbook本身可以用`mdbook --version`查询当前版本, 所以这里就执行返回`os.iorun("mdbook --version")`这个命令运行后的字符串就可以了
- 实现`install`函数: 并且xim的框架会自动的解压下载的压缩包, 所以实际的安装就是复制这个可执行文件到bin目录
- 实现`uninstall`函数: 同理卸载mdbook, 就是直接把这个文件删除

```lua
-- package...

import("platform")

local bindir = platform.get_config_info().bindir

local mdbook_file = {
    windows = "mdbook.exe",
    linux = "mdbook",
}

function installed()
    return os.iorun("mdbook --version")
end

function install()
    os.cp(mdbook_file[os.host()], bindir)
    return true
end

function uninstall()
    os.tryrm(path.join(bindir, mdbook_file[os.host()]))
    return true
end
```

> **注:** 更多复杂的包文件实现, 可以参考[索引仓库](https://github.com/openxlings/xim-pkgindex)中的其他包文件

## 第四步: 对包内容进行测试

> 通过把包文件添加到索引数据库进行相关操作的测试和验证

### 添加包到索引数据库

```lua
xim --add-xpkg yourLocalPath/mdbook.lua
```

**示例**

```bash
speak@speak-pc:~$ xim --add-xpkg mdbook.lua
[xlings:xim]: convert xpkg-file to runtime path - mdbook.lua
[xlings:xim]: add xpkg - /home/speak/mdbook.lua
[xlings:xim]: update index database
```

### 搜索测试

> 检测是是否能正常显示包可安装的版本

```lua
xim -s mdbook
```

**示例**

```bash
speak@speak-pc:~$ xim -s mdbook
[xlings:xim]: search for *mdbook* ...

{ 
  "mdbook@0.4.40" = { },
  "mdbook@0.4.43" = { 
    "mdbook",
    "mdbook@latest" 
  } 
}
```

### 安装测试

> 执行包的安装命令测试资源和hooks函数是否正常执行

```lua
xim -i mdbook
```

**示例**

```bash
speak@speak-pc:~$ xim -i mdbook
[xlings:xim]: create pm executor for mdbook ... 

--- [package] info

name: mdbook
version: 0.4.43
authors: Mathieu David, Michael-F-Bryan, Matt Ickstadt
contributors: https://github.com/rust-lang/mdBook/graphs/contributors
license: MPL-2.0
repo: https://github.com/rust-lang/mdBook
docs: https://rust-lang.github.io/mdBook

	Create book from markdown files. Like Gitbook but implemented in Rust

-> install mdbook? (y/n)
```

命令会执行如下动作

- installed
- download - 不需要实现
- build - 可选
- install
- config - 可选

安装完成后可以, 重新打开一个窗口(刷新环境), 再次运行安装看是否会重复安装


### 安装列表测试

> 执行list命令, 查看被安装的版本是否正确

```lua
xim -l mdbook
```

```bash
speak@speak-pc:~$ xim -l mdbook
-> mdbook@0.4.43 (mdbook@latest, mdbook)
```

### 卸载测试

> 测试卸载功能

```lua
xim -r mdbook
```

示例

```lua
speak@speak-pc:~$ xim -r mdbook
[xlings:xim]: create pm executor for mdbook ... 

--- [package] info

name: mdbook
version: 0.4.43
authors: Mathieu David, Michael-F-Bryan, Matt Ickstadt
contributors: https://github.com/rust-lang/mdBook/graphs/contributors
license: MPL-2.0
repo: https://github.com/rust-lang/mdBook
docs: https://rust-lang.github.io/mdBook

	Create book from markdown files. Like Gitbook but implemented in Rust

-> uninstall/remove mdbook? (y/n)
y
xxx
[xlings:xim]: mdbook - removed

	     反馈 & 交流 | Feedback & Discourse
	(if encounter any problem, please report it)

	https://forum.d2learn.org/category/9/xlings
	https://github.com/openxlings/xlings/issues

[xlings:xim]: update index database
```

同理, 卸载后可以在此执行卸载命令进行测试是否能检测到包已经被卸载


## 第五步: 把测试信息补充到第一步中创建的问题里

把第四步中测试的log或则截图补充到第一步创建的issue里

## 第六步: 索引仓库和包文件位置

fork包索引仓库[xim-pkgindex](https://github.com/openxlings/xim-pkgindex), 并把包文件放到`pkgs`目录下的对应字母目录

索引仓库是按文件名的首字母进行分类的

## 第七步: 发起合入请求

- 先把添加的文件提交到自己fork的仓库
- 发起合入的Pull-Request
- 把PR地址补充到问题里
- 在评论区@项目维护人员

## 第八步: TODO (reviewer本地验证&approval)

交流讨论 & 验证通过后合入仓库

## 第九步: 更新本地索引数据库

> xim会自动同步最新的包索引数据库到本地, 然后就可以对该包进行管理了 

```bash
xim --update index
```