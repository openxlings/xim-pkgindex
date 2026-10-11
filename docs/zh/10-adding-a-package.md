# 添加一个包

[English](../10-adding-a-package.md) | **简体中文**

从一个配方到合入的 PR。精确规则见 [XPackage V2](../specs/xpackage-v2.md)；本章是路径。

## 流程

1. 创建一个 [Add XPackage](https://github.com/openxlings/xim-pkgindex/issues/new/choose)
   issue：包名、一句话介绍、主页、许可证。
2. 把[模板](../specs/xpackage-template.lua)复制为 `pkgs/<首字母>/<name>.lua`。
3. 填写 `package` 表和钩子（见下文）。
4. 添加 `tests/<首字母>/test_<name>.py`（[测试](20-testing.md)）。
5. 在隔离的 home 中安装它，覆盖它声明的每个平台和架构。
6. 发起 PR，并在 issue 中链接它。

## `package` 表

```lua
package = {
    spec = "2",
    name = "demo",
    description = "One sentence on what it is",
    type = "package",
    licenses = {"MIT"},
    repo = "https://github.com/acme/demo",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    programs = {"demo"},
    xvm_enable = true,

    xpm = {
        source = "https://github.com/acme/demo/releases/download/v${version}/demo-${os}-${arch_alias}.${ext}",
        linux = {
            ["latest"] = { ref = "1.0.0" },
            ["1.0.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = { x86_64 = "<amd64-sha256>", aarch64 = "<arm64-sha256>" },
            },
        },
    },
}
```

- `archs` 会与宿主比对，不匹配即失败：只声明测试过的架构。
- `programs` 列出包放到 PATH 上的每个命令；站点和路由表都读取它。
- `latest` 用 `ref` 指向一个真实版本，并且只向前移动。
- 没有网络资源的版本（脚本、配置）写空表：`["0.0.1"] = {}`。

### 资源的写法

保持 `platform -> version` 模型，按顺序选第一个适用的：

| 情形 | 写法 |
|---|---|
| xlings-res 上的官方资源 | `xpm.source = "xlings-res"`，加每个架构的 `sha256` |
| URL 规则统一的第三方 release | `xpm.source = "<含 ${version} 的模板>"`，加每个架构的 `sha256` |
| 各架构 URL 不规则 | 按架构分别写资源表，每项 `{ url, sha256 }` |
| 单个特殊或历史版本 | 在该版本项写显式 `url` / 镜像表，覆盖 `source` |
| 旧配方 | `"XLINGS_RES"`、`res = true`、单个 URL、单个 hash —— 仍然兼容 |

每个架构都要有 sha256。没有权威 hash 时，先保留旧写法，等资源和它的 sidecar 都存在后
再迁移；不能发布没有 hash 的新官方二进制版本。

## 钩子

```lua
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    os.tryrm(pkginfo.install_dir())
    os.mv(pkginfo.install_file():replace(".tar.gz", ""), pkginfo.install_dir())
    return true
end

function config()
    xvm.add("demo", { bindir = path.join(pkginfo.install_dir(), "bin") })
    return true
end

function uninstall()
    xvm.remove("demo")
    return true
end
```

- `install()` 放置文件；没有它时，安装目录恰好是归档中的条目。
- `config()` 注册命令、链接进 sysroot、声明环境变量 —— 每个 scope 运行一次，按
  revision 记录。
- 钩子只使用标准 Lua 和 `xim.libxpkg.*`：不调用宿主的包管理器，不改 `.bashrc`，不直接
  改 `PATH`（隔离测试会让这些失败）。
- 配置类的包在 `config()` 中写配置，保留用户已有的配置，不输出 token。

## 依赖

```lua
deps = {
    runtime = { "xim:glibc", "xim:gtk3" },
    build   = { "xim:7zip@26.02" },
}
```

- `runtime` 会激活到用户的 workspace 并进入 RPATH 闭包；`build` 只在 `install()` 运行时
  存在，不在 PATH 上。
- 只在 `install()` 里用的工具（7zip、patchelf、cmake）是 `build` 依赖；用
  `pkginfo.build_dep("7zip")` 获取 —— **裸名**。
- 获取 runtime 依赖时，用声明时的坐标：`pkginfo.dep_install_dir("xim:glibc")`。不要自己
  拼载荷路径。
- 用分离的写法；不要在位置列表中混写 `build`（`tests/test_deps_shape.py`）。
- 自带共享库、靠 `$ORIGIN` 找到它们的载荷（xPack、部分 Electron 和 Bun 应用）**不要**
  声明 loader 依赖：声明了 `xim:glibc`，elfpatch 就会替换它的 `DT_RPATH`，自带的库全部
  失联，而安装仍然报告成功。依据实测的 `DT_NEEDED` 闭包判断
  （`LD_TRACE_LOADED_OBJECTS=1 <bin>`），并在测试中真正运行一次程序 —— `--version` 看不出来。

## 保证包正确的规则

- **库载荷不携带编译器的运行时。** 在 Windows 上即 `vcruntime140*.dll`、`msvcp140*.dll`、
  `concrt140.dll`、`vccorlib140.dll` 及 `Microsoft.VC*.CRT` 目录；只有工具集包（`msvc`）带它们
  （`tests/test_no_compiler_runtime_in_payloads.py`）。
- **目标 sysroot 不是宿主库。** 交叉或裸机 sysroot（`picolibc-riscv`）的头文件绝不进 SubOS 的
  `usr/include`，所有平台用同一个 sha256（它的字节与宿主无关），并且不设 `ci`。
- **config 的效果由 `revision` 标识。** 改变 `config()` 注册、链接、声明或写出的内容时，
  提高版本项的 `revision`，否则已经配置过的 scope 永远看不到变化。`config()` 不把 scope
  相关的数据写进共享的载荷。
- **载荷中不能有硬链接。** xlings 用 `link(2)` 解出硬链接，Android 应用沙箱和 FAT 会拒绝
  （`payload-hard-links.yml`）。打包时用 `tar --hard-dereference`。
- **钩子不从环境猜测架构**：2026.10.8.1 之前的客户端在钩子中没有 `os.arch()`，要从载荷
  内容判断（对它带的 loader 用 `os.isfile`）。

## 在本地测试

```bash
python3 .github/scripts/version-check.py --workspace .
pytest tests/<letter>/test_<name>.py -m "static or isolation"
```

安装使用隔离的 home，不用你自己的：

```bash
TMP_HOME="$(mktemp -d)"
XLINGS_HOME="$TMP_HOME" xlings config --add-xpkg pkgs/<letter>/<name>.lua
XLINGS_HOME="$TMP_HOME" xlings install <name>@<version> -y
XLINGS_HOME="$TMP_HOME" xlings remove <name> -y
```

涉及多个架构时，检查 x86_64 和 aarch64 上的解析结果；涉及镜像时，检查 GLOBAL 和 CN 的
实际响应及其 sha256。

## PR

描述中写明：

- 包是什么，支持的平台和架构；
- 资源：来源、版本、镜像 release、sha256；
- install、config、uninstall 是否改变用户环境；
- 运行了什么：命令、pytest、隔离安装；
- `latest` 移动时，它指向的已验证版本。

提交遵循 `<type>(<scope>): <description>` —— `feat(pkg): add foo 1.2.0`、
`fix(index): add missing aarch64 checksums`。Linux、macOS、Windows 和索引检查都通过后合入。

## 职责边界

xlings 与 libxpkg 是配方、兼容规则和资源解析的唯一实现；本索引只声明数据和钩子。
配方不重新实现平台判断、资源服务器 URL 或模板展开。
