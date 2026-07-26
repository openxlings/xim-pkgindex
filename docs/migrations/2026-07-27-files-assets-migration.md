# `type = "files"` 资产声明 —— 迁移规范

**日期**: 2026-07-27
**状态**: **能力已可用，索引尚不可迁移** —— 见 §2 的兼容性闸门
**依赖**: libxpkg 0.0.47（[openxlings/libxpkg#31](https://github.com/openxlings/libxpkg/pull/31)）、
xlings 2026.7.27.0（[openxlings/xlings#410](https://github.com/openxlings/xlings/pull/410)）
**设计**: xlings `.agents/docs/2026-07-27-sysroot-files-model-design.md`

---

## 0. 一句话

**recipe 现在可以声明"这个文件放到 subos 的这个位置"，由 xlings 统一物化、随版本切换、随卸载清理。**
在此之前只有 `includedir`（"这一个目录变成 sysroot 的 include"），表达不了其它任何东西，
于是索引长出了七种各自为政的写文件方式。

---

## 1. 新能力

```lua
xvm.add("openssl.files.1", {
    type    = "files",
    bindir  = pkginfo.install_dir(),   -- 解析 src 的基准
    src     = "include/openssl",       -- 相对 payload 根
    dst     = "usr/include/openssl",   -- 相对 subos 根
    binding = binding_tag,             -- 归属哪个发布
})

-- 语法糖，自动派生 target 名，适合一个包声明多份
xvm.files({ src = "lib64/pkgconfig", dst = "usr/lib/pkgconfig" })
```

### 两端必须相对 —— 这是硬约束，不是风格

payload **跨 subos 共享且有引用计数**。把绝对目标路径记在 payload 上，
只对安装它的那个 subos 正确，对其余全错。

xlings 侧会拒绝：

| 被拒绝的 dst | 原因 |
|---|---|
| `/usr/include/x` | 绝对路径 |
| `../../etc/passwd`、`usr/../../x` | 逃出 subos |
| `bin/gcc` | `bin/` 是 shim 的地盘 |
| `lib/libx.so` | 库请用 `type = "lib"`，它有 soname 语义 |

允许的根：**`usr/` / `etc/` / `share/`**。

被拒绝时报错会指名字段（`/nodes/N/dst`），不会静默放到别处。

### 卸载不再需要手写

`type = "files"` 的条目登记在版本库里，卸载时由 xlings 按声明反推删除。
recipe 里那些硬编码文件名的 `os.tryrm` 可以一并删掉。

---

## 2. ⛔ 兼容性闸门：**现在还不能迁移共享索引**

**这是本文最重要的一条。**

索引由**所有版本的 xlings 客户端共用**。旧客户端读到 `type = "files"` 会**硬失败**：

```
error: unsupported registration node kind 'files'
       code:     xvm-node-payload-invalid
       field:    /nodes/3/kind
       nothing was changed
```

已实测（用 2026.7.27.0 之前的二进制跑一个声明了 `files` 的 fixture）。

而且 **`xim-pkgindex` 没有客户端版本下限机制** —— 没有 `min_xlings`，
无法给老客户端发老 recipe。所以：

> **今天把任何一个 recipe 迁到 `type = "files"`，等于让每一个还没升级的用户装不上这个包。**

### 放行条件

满足**全部**三条才可以开始迁移：

1. xlings ≥ 2026.7.27.0 已发布，且**已经过一个采纳周期**
2. `xim-pkgindex` 引入客户端版本下限（`min_xlings`），或明确接受"低于该版本不再支持"
3. 迁移按包逐个进行，每个包迁完在隔离 HOME 里实测安装 / 切换 / 卸载

在此之前，**新写的 recipe 也不要用 `files`** —— 它同样会被老客户端拒绝。

---

## 3. 迁移对象分类（放行后按此顺序）

索引里 118 个 recipe，**28 个**碰 sysroot 或改 payload，其余 90 个不用动。

| 类 | 例子 | 现状 | 迁移 | 风险 |
|---|---|---|---|---|
| **A 纯 program** | 90 个 | `xvm.add` | **不动** | — |
| **B 独占目录** | openssl、libxml2 | `sysroot.install_headers` / `os.cp` | 一条 `files` 声明 | **低，先行** |
| **C 散落文件** | zlib(`zlib.h`+`zconf.h`)、libffi、expat | `os.cp` 两个文件 | 每个文件一条声明 | 低 |
| **D 大批量摊开** | glibc(130 项)、musl-gcc(108)、linux-headers、binutils | Lua skip-if-exists | 需要先定跨包冲突策略 | **中高** |
| **E 改 payload** | gcc(`specs`)、llvm(`clang.cfg`) | `config()` 里生成 | 需要 `use()` hook（未实现） | **高** |
| **F elfpatch RPATH** | 10+ | 改 payload 内 ELF | **不动** —— 指向 payload 是 Catalog 引用，正确 | — |
| **G subos 外** | code(desktop entry)、字体、fontconfig、pmwrapper | recipe 自管 | **不动**，见 §4 | — |

### D 类的特别提醒：glibc

glibc 往 `usr/include/` 摊 **130 个顶层条目**，用的是 **skip-if-exists**。

一度以为这是为了"host 头文件优先"，**查证后该说法不成立**：
`sysroot.install_headers` 的目标是 `<subos>/usr/include`，而 sandbox 把 host 的 `/usr`
挂在 `/usr` —— 两个不同的目录，host 从不往前者放东西；且 gcc 注入 `--sysroot=<subos>`
后只看 `<subos>/usr/include`。

真正起作用的是**包与包之间**的碰撞（同一条注释的第二点：pkg-A 已经放了 `scsi/`，pkg-B 也有）。
所以迁移 glibc 前必须先定**跨包 dst 冲突策略**（报错？显式优先级？），否则语义会从"跳过"
变成"覆盖"，可能弄坏用户的构建环境。

---

## 4. 明确不管的：subos 之外

写到 `$HOME`、系统目录、或经系统包管理器安装的东西，**xlings 不接管**：

- desktop entry（`code.lua` 等 4 个，用 `.xvm.desktop` 版本戳文件名，自己删）
- 字体（`jetbrainsmono-nerd-font`）、`fontconfig-user-moyingji`
- `pmwrapper`（apt / pacman / winget）—— host 包管理器有自己的数据库，再记一份必然对不上

这些**不参与版本切换、不被 `doctor` 检查、不随卸载自动清理**，由 recipe 自负。
现状它们已经在自管且管得对，本条是追认而非新规。

---

## 5. 迁移示例（openssl，B 类）

```diff
 function config()
     ...
-    log.debug("Linking headers into subos sysroot ...")
-    if os.isdir(includedir) then
-        sysroot.install_headers(includedir, get_sys_usr_includedir())
-    end
+    xvm.add(package.name .. ".files.1", {
+        type    = "files",
+        bindir  = pkginfo.install_dir(),
+        src     = "include/openssl",
+        dst     = "usr/include/openssl",
+        binding = binding_tree_version_tag,
+    })
     xvm.add(package.name, { binding = binding_tree_version_tag })
 end

 function uninstall()
     ...
-    local includedir = path.join(pkginfo.install_dir(), "include")
-    if os.isdir(includedir) then
-        local sys_includedir = get_sys_usr_includedir()
-        local subdirs = os.dirs(path.join(includedir, "*"))
-        for _, subdir in ipairs(subdirs) do
-            os.tryrm(path.join(sys_includedir, path.filename(subdir)))
-        end
-        for _, file in ipairs(list_files(path.join(includedir, "*.h"))) do
-            os.tryrm(path.join(sys_includedir, path.filename(file)))
-        end
-    end
 end
```

迁移后 openssl 的头文件**第一次变得可切换** —— 此前装了两个版本，
库在后装的那个、头文件停在先装的那个，`xlings use` 两个方向都修不回来。

---

## 6. 相关变化（xlings 2026.7.27.0）

不需要 recipe 配合，但会改变行为：

| 变化 | 之前 |
|---|---|
| **库真正随发布版本切换** | `xlings use` 对库是**静默 no-op**（规划器读的字段无人写入） |
| 安装非激活版本不再覆盖激活版本的库 | 覆盖了，而头文件没动 → sysroot 同时持有两个版本 |
| `use` 与 install 写同一个 sysroot lib 目录 | 不一致（`usr/lib` vs `lib`） |
| `doctor` 不再把 release 锚点报成 broken payload | 库-only 包的锚点被当成缺失的可执行文件 |
| **版本号改日期式** `2026.7.27.0` | `x.y.z` 停用；日期不补零 |
