# xim-pkgindex 贡献指南

> 编写日期: 2026-07-12 | 版本: 0.0.63

## 1. 贡献范围

`xim-pkgindex` 是 xlings 官方 xpkg 配方和索引发布仓库。包配方位于
`pkgs/<首字母>/<name>.lua`，测试位于对应的 `tests/<首字母>/` 目录。

包作者只维护声明式 `package` 元数据、`xpm` 资源矩阵和必要的 lifecycle hook。
资源解析、compat 和模板归一化由 xlings 使用的 libxpkg 提供；不要在配方或测试中复制
一套平台判断、资源服务器 URL 拼接或模板解析逻辑。

## 2. 资源表达选择

保持原有 `platform -> version` 模型，按下面顺序选择：

| 场景 | 推荐表达 |
|---|---|
| 官方 xlings-res，URL 遵循默认命名 | `xpm.source = "xlings-res"` + 版本项 per-arch `sha256` |
| GitHub/第三方 release，URL 规则统一 | `xpm.source = "https://.../${version}/...${arch}..."` + per-arch `sha256` |
| 各架构 URL 不规则 | 版本项 per-arch resource map，每项 `{url, sha256}` |
| 单个历史资源或特殊版本 | 版本项显式 `url`/mirror，覆盖默认 `source` |
| 历史配方 | `"XLINGS_RES"`、`res = true`、单 URL、`ref` 和旧单 hash 继续兼容 |

官方资源的最佳范例：

```lua
package = {
    spec = "2",
    name = "demo",
    description = "demo binary",
    type = "package",
    archs = { "x86_64", "aarch64" },
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
}
```

没有权威 hash 时可以暂时保留旧表达，但不能把它作为新的官方二进制版本发布；应先
补齐制品和 sidecar，再提交索引迁移。

## 2.1 CI 扩展

需要加入官方自动镜像或自动更新时，只在包元数据中声明意图：

```lua
ci = {
    mirror = true,
    update = true,
}
```

周期、cron、限流和重试统一由仓库 `.github/xpkg-ci.yml` 管理，包文件不写 `1d`、`3d`
等周期。`mirror` 处理已声明版本；`update` 只负责发现版本并创建 PR。完整工具和
workflow 边界见 [CI 镜像与自动更新设计](../.agents/docs/2026-07-12-xpkg-ci-mirror-update-design.md)。

## 3. xlings-res 发布流程

1. 从权威上游 release 或同一次构建取得所有平台/架构制品。
2. 按 `xlings-res` 命名约定发布 GitHub RES 与 GitCode RES 的同版本 tag/release。
3. 为每个归档生成同名 `.sha256` sidecar，并检查文件大小和 SHA256。
4. 从权威上游、GitHub RES、GitCode RES 各下载一次，逐字节比较并记录结果。
5. 更新配方的 `source`/`sha256`，运行版本检查器；缺失平台、架构、sidecar 或 hash 时
   让检查器 fail closed。
6. 只在全部资源验证完成后提交一个 PR。补发旧版本不能让 `latest` 回退。
7. 已发布版本需要重建或重新打包（补丁、前缀、布局）时，不新增版本键，也不替换
   已发布资产：以 `<version>-r<N>` 为 release tag 和资产名发布新资产，版本项改用新
   `url`/`sha256`，并把 `revision` 增为 N（见 V2 规范的
   [`revision`](V2/xpackage-spec.md#revision--a-packaging-change-under-an-unchanged-version)
   一节）。`.github/scripts/check-revision.lua` 拒绝资源变化而 `revision` 未增加的
   改动；改变安装结果的 hook 修改（包括 config 的效果，见 §5.4）同样需要增加
   `revision`，由 review 判断。

`xim-index` 索引工件属于独立发布链：它使用版本化 tarball、pointer 和 SHA256，不能
把索引工件放进软件包的 `xlings-res/<package>` 目录，也不能把二进制资源当成索引工件。

## 4. 本地验证

```bash
# 配方静态检查与完整测试
python3 .github/scripts/version-check.py --workspace .
pytest -q

# 针对一个包的测试
pytest -q tests/<letter>/test_<package>.py
```

安装行为必须使用隔离 home，不得修改开发者真实环境：

```bash
TMP_HOME="$(mktemp -d)"
XLINGS_HOME="$TMP_HOME" xlings update
XLINGS_HOME="$TMP_HOME" xlings install <package>@<version> -y
XLINGS_HOME="$TMP_HOME" xlings -y remove <package>
rm -rf "$TMP_HOME"
```

涉及多架构资源时，至少检查 x86_64 和 aarch64 的解析结果；涉及 mirror 时，检查
GLOBAL/CN URL 的实际响应和 SHA256。涉及坏缓存时，预置一个错误大小的缓存，确认 xlings
驱逐并重新下载，而不是把非空文件当作命中。

## 5. 测试要求

- 新包必须有对应测试；资源表达变更必须覆盖 `source`、显式 URL、`ref`、mirror 和
  per-arch hash。
- hook 只能使用标准 Lua 和 `xim.libxpkg.*` API，不依赖 xmake 私有 runtime。
- 配置型包将写配置的动作放在 `config()`，保留用户已有配置并避免输出 token。
- 旧配方变更必须确认旧客户端仍能解析；不能仅凭静态字段推断兼容。

### 5.1 自带共享库的载荷：`deps` 与 `$ORIGIN`

有些上游预编译包把自己的共享库一并放进归档，并靠自身的
`DT_RPATH=$ORIGIN/../<dir>` 找到它们（xPack、部分 Electron/Bun 应用）。
**这类载荷不要声明提供 loader 的依赖（`xim:glibc` 等）。**

声明了，xlings 的谓词驱动 elfpatch 就有了可 key 的 loader 提供者，而它
**整条替换 `DT_RPATH`，不是前置追加**。实测（2026-08-19，`qemu-riscv`）：

```
上游:   [$ORIGIN/../libexec]
装完:   [<install>/lib:<glibc>/lib64:<subos farm>/lib]
```

自带的库全部失联，**而 install 仍然报成功** —— 文件一个不少，所有存在性检查
都过，只有第一次真运行才会炸（`libpixman-1.so.0: cannot open shared object
file`）。所以：

- 判断依据是**实测的 DT_NEEDED 闭包**，不是清单；用
  `LD_TRACE_LOADED_OBJECTS=1 <bin>` 分清哪些来自载荷内部、哪些跨出边界。
- 跨出边界的只有核心 glibc 时，空 `deps` 是正确答案（参考 `claude.lua`、
  `aarch64-linux-musl-gcc.lua`，从另外两个方向得到同一结论）。
- 载荷里如果还捆了 `libresolv`/`libssp` 这类 glibc 组件，即使 elfpatch 保留
  `$ORIGIN` 也不该声明私有 glibc —— 那会让两个 glibc 进同一个进程。
- 这类包的 `verify` 测试必须**真跑一次**，不能只问 `--version`：上面那个断裂
  对 `--version` 完全不可见。

### 5.2 目标 sysroot:与宿主库的三条区别

交叉/裸机 sysroot 包(`picolibc-riscv` 是第一个)与普通宿主库包在三处相反:

1. **头文件绝不进 subos sysroot。** 宿主库把头拷进 `usr/include`(见 `zlib.lua`)
   是对的;`riscv*-none-elf` 的**目标**头这么做,会让每个普通构建的宿主 libc 被
   遮住。这类包的 `config()` 只注册 umbrella 节点,消费者自己把 `--sysroot` /
   `-isystem` 指到它的安装目录。
2. **载荷与宿主无关 ⇒ 一个 sha256 服务全平台。** 目标代码在哪台机器上都是同一份
   字节,所以三个平台写同一个哈希、不写 per-arch 表 —— per-arch 表会让镜像工具
   把它当成有架构区分的资产,去抓第二个并不存在的 URL。
3. **自建产物不设 `ci`。** `mirror = true` 会让镜像镜像它自己(GLOBAL 已经是
   xlings-res);`update = true` 会把 `latest` 指向一个还没构建出来的 URL。版本
   升级 = 跑构建脚本 → 发布 → 改配方,是人的动作。

自建产物必须在 `.agents/tools/` 留一份**可复现**的构建脚本(固定 tar 的
owner/mtime 与成员序,同输入同字节),并在配方里指向它。

### 5.3 编译器的运行时不进库载荷

**库包的载荷不携带编译器的 C++ 运行时。** Windows 上即 MSVC C++ 运行时集合:
`vcruntime140*.dll`、`msvcp140*.dll`、`concrt140.dll`、`vccorlib140.dll`,以及它们所在的
`Microsoft.VC*.CRT` redistributable 目录。唯一的例外是工具集包本身(`msvc`),它的
redistributable 目录就是编译器的运行时。

理由:程序的 C++ 运行时必须不旧于构建其任一映像的最新工具集。链接程序的那次构建知道这个
工具集,库载荷不知道,它的副本是配方钉住的那个版本。`xim:qt-base` 6.11.1 曾在 `bin/` 中携带
14.44 的副本,mcpp 把它放到用更新工具集构建的程序旁(2026-09-28 生态评审 §2.1)。mcpp
2026.9.28.2 起放置工具集的集合,并把依赖包的副本作为打包缺陷说明一次;载荷自己的宿主工具
(Qt 的 `moc.exe`)由引擎放在每个 action `PATH` 最前面的工具集运行时启动。

`tests/test_no_compiler_runtime_in_payloads.py` 检查配方源码:注释以外的代码行不得出现上述
名字或 redistributable 归档。去掉运行时副本的配方同时提高 `revision`,使已安装的旧载荷在下次
使用时被替换;`installed()` 也不得再断言这些文件存在。

### 5.4 config 的效果与 `revision`（xlings 2026.9.29.1 起）

payload 由整个 home 共享，config 却是每个 scope（subos 或项目）各跑一次。xlings 在每个 scope
的 `.xlings.json` 里记录 `configured`（包 → 配置时的 `revision`）；一个包已安装、且本 scope
按当前 `revision` 配置过时，`xlings install` 不会再跑它的 config（`--reconfig` 强制重跑）。
由此有两条规则：

1. **改变 config 效果的修改必须增加 `revision`**（注册的命令、sysroot 链接、`subos.env`
   声明、写出的文件）。这是唯一能让每个 scope 在下一次安装时各自重新配置的信号；只改
   hook 不加 revision，已配置过的 scope 永远看不到新 config。
2. **config 不能把 scope 相关的数据写进共享 payload**（例如用 `system.subos_sysrootdir()`
   的路径改写 payload 里的文件）。两个 scope 会互相覆盖，而且有了上面的记录之后，谁也
   不会再改写回来。需要 scope 路径的内容写进 scope 自己（sysroot、`subos.env`），或者像
   gcc 的 specs 那样写 payload 直达路径、在执行时再展开 scope。

`installed()` 不是"已安装的 payload 是否最新"的信号：xlings 对已安装的 payload 只看
`revision`。用 `installed()` 判定布局过期的配方（例如 qt 的 `runtime` 标记）同时要增加
`revision`，旧 payload 才会被替换。

## 6. PR 清单

PR 描述至少包含：

- 包用途、支持的平台和架构；
- 资源来源、版本、镜像 release/tag 和 SHA256；
- install/config/uninstall 是否修改用户环境；
- 本地命令、pytest、静态检查和隔离安装结果；
- 若更新 `latest`，说明它指向的已验证版本。

提交遵循 `<type>(<scope>): <description>`，例如 `feat(pkg): add foo 1.2.0` 或
`fix(index): add missing aarch64 checksums`。PR 通过 Linux、macOS、Windows 以及索引
发布相关检查后再合并。

## 7. 与 xlings 的职责边界

`xlings`/libxpkg 是唯一的 xpkg 解析、compat 和资源归一化入口；`xim-pkgindex` 只声明
数据和 hook。xlings 仓库自身使用 mcpp 构建，`xlings install` 不会隐式安装 xmake；这
不影响用户显式安装 xmake 包或使用既有 `xmake xim` 兼容入口。
