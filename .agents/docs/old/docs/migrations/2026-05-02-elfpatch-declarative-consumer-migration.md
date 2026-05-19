# 任务：迁移剩余 3 个 consumer 到声明式 elfpatch

**Created**: 2026-05-02
**Predecessor**: [#104](https://github.com/openxlings/xim-pkgindex/pull/104) — binutils pilot, merged
**Estimated effort**: 30-60 分钟
**Skill level**: 熟悉 lua + xpkg schema 的人；不需要懂 xlings/libxpkg C++

---

## 背景

### 这个机制是什么

xlings 0.4.11 引入了**声明式 elfpatch**：
- **Provider**（如 glibc）在自己的包描述里声明 `xpm.<platform>.exports.runtime.{loader, abi}`
- **Consumer**（依赖 glibc 的包，如 binutils）的 install hook **不再需要**手算 loader 路径或调 `elfpatch.auto({...})`
- xlings 在 install 后自动扫 consumer 的 runtime deps，找到声明了 loader 的 provider，自动调用 patchelf 修补 INTERP / RPATH

完整设计参见 [openxlings/xlings docs/plans/2026-05-02-elfpatch-exports-design.md](https://github.com/openxlings/xlings/blob/main/docs/plans/2026-05-02-elfpatch-exports-design.md)。

### 现状

已在 main 上：

| 包 | 状态 |
|---|---|
| `pkgs/g/glibc.lua` | ✅ 已加 `exports.runtime.{loader, abi}` |
| `pkgs/b/binutils.lua` | ✅ 已删 install hook 里的 elfpatch.auto 调用（pilot） |
| `pkgs/o/openssl.lua` | ❌ 仍调旧 `elfpatch.auto({...})`，走 deprecation alias 路径 |
| `pkgs/g/gcc.lua` | ❌ 同上 |
| `pkgs/d/d2x.lua` | ❌ 同上 |

deprecation alias 让旧代码继续能跑（行为和 0.4.10 一致），但是：

- 只调 debug log 的兼容路径，**2026-11 后会删除**
- 还在硬编码 glibc 版本号（`pkginfo.dep_install_dir("glibc", "2.39")`）—— glibc 一升级就要每个 consumer 改一遍
- 旧路径不会用到新的 `exports.runtime.libdirs` / `abi` 元数据，多 ABI / 非常规布局支持不到

**这个任务做的就是把这 3 个 consumer 也迁过来**，统一走声明式路径。

---

## 任务范围

### 目标

把 `openssl.lua` / `gcc.lua` / `d2x.lua` 三个 consumer 的 install hook 里 elfpatch.auto 相关代码删掉。**不需要**改其他任何东西。

### 哪些代码要删（每个文件长得很像）

1. `import("xim.libxpkg.elfpatch")` 这一行
2. install hook 里手算 glibc loader 路径的 ~3 行
3. `elfpatch.auto({ enable = true, ... })` 调用块的 ~5 行

### 哪些代码**不要**删

- `import("xim.libxpkg.pkginfo")` / `xvm` / `system` / `log` 这些都保留
- install hook 里的实际 install 逻辑（`os.tryrm`、`os.cp`、`os.mv`、`pkginfo.install_file()`、`__relocate()` 之类）一行不动
- `config()` / `uninstall()` 函数完全不动
- `package = { ... }` 元数据块也不动（**特别**：consumer **不需要**加 exports 字段，那是 provider 才声明的）

---

## 具体操作

### Pilot 参考（binutils 已经做完）

模板对比看 [#104 的 binutils.lua diff](https://github.com/openxlings/xim-pkgindex/pull/104/files)：

```diff
 import("xim.libxpkg.log")
 import("xim.libxpkg.pkginfo")
 import("xim.libxpkg.system")
 import("xim.libxpkg.xvm")
-import("xim.libxpkg.elfpatch")
+-- elfpatch import removed: predicate-driven auto-patch (post 2026-05-02
+-- design) reads glibc.lua's exports.runtime.loader and rewrites our
+-- INTERP / RPATH automatically. No install-hook elfpatch call needed.

 function install()

     local glibcdir = pkginfo.install_file():replace(".tar.gz", "")

     os.tryrm(pkginfo.install_dir())
     os.cp(glibcdir, pkginfo.install_dir(), {
         force = true, symlink = true
     })

-    -- Point interpreter directly to glibc xpkgs
-    local glibc_dir = pkginfo.dep_install_dir("glibc", "2.39")
-    local loader = glibc_dir and path.join(glibc_dir, "lib64", "ld-linux-x86-64.so.2") or nil
-    elfpatch.auto({
-        enable = true,
-        shrink = true,
-        bins = { "bin" },
-        interpreter = loader,
-    })
-
     return true
 end
```

### Per-package 注意事项

#### `pkgs/o/openssl.lua`

直接照抄 binutils 的删法。`elfpatch.auto({...})` 块和上面 3 行 loader resolution 全部删掉，import 也删，加上注释。

#### `pkgs/g/gcc.lua`

**比 binutils 多一点**——gcc 有 `libexec` 子目录（cc1 在那里）。看现有调用：

```lua
elfpatch.auto({
    enable = true,
    shrink = true,
    bins = { "bin", "libexec" },     -- ← 这个 libexec
    libs = { "lib64" },
    interpreter = loader,
})
```

新机制下，xlings 默认 `scan = "convention"` 已经包含 `libexec`，所以**不需要任何特殊处理**。直接全删，跟 binutils 一样的 diff。

如果 review 时担心 libexec 真的被扫到，可以本地装 gcc 后 `find $XLINGS_HOME/data/xpkgs/xim-x-gcc/15.1.0/libexec -type f -name "cc1"` 然后 `readelf -l <path>/cc1 | grep PT_INTERP` 看 INTERP 是否被改过。

#### `pkgs/d/d2x.lua`

跟 binutils 完全一样的 pattern。直接照抄删。

---

## 提交 / PR 流程

### 1. 起一个 PR 同时改 3 个包

```sh
git checkout -b feat/elfpatch-migrate-rest
# 编辑 pkgs/o/openssl.lua
# 编辑 pkgs/g/gcc.lua
# 编辑 pkgs/d/d2x.lua
git add pkgs/o/openssl.lua pkgs/g/gcc.lua pkgs/d/d2x.lua
git commit -m "feat(pkg): migrate openssl/gcc/d2x to declarative elfpatch"
git push -u origin feat/elfpatch-migrate-rest
gh pr create --title "feat(pkg): migrate openssl/gcc/d2x to declarative elfpatch" --body "..."
```

PR body 推荐写成参考 [#104](https://github.com/openxlings/xim-pkgindex/pull/104) 的格式即可。

### 2. CI 验证（自动跑）

xim-pkgindex 仓库的两个 workflow：

| workflow | 触发 | 验证内容 |
|---|---|---|
| **xpkg test** | 每次 push / PR | lua 语法 + index 注册 |
| **pkgindex test** | 改了 `pkgs/**` 才跑 | 在 linux/macos/windows runner 上**真实装**改动的包并验证 shim / 二进制 |

**关键**：**`pkgindex test` 会在 Linux runner 上实地装每个改的包**——`xlings install xim:gcc` 等。CI 失败说明二进制装完跑不起来（很可能 INTERP / RPATH patch 没生效）。这是这次迁移的**端到端验证**：

- 期望 binary 在 CI runner 上跑（`gcc --version` / `openssl version` / `d2x` 之类）
- 期望 `nm` / `readelf -l` 看到 INTERP 指向 xpkgs 里 glibc 的 `lib64/ld-linux-x86-64.so.2`

### 3. 本地手动验证（可选，更彻底）

如果想本地确认：

```sh
# 隔离 XLINGS_HOME
export XLINGS_HOME=/tmp/elfpatch-test
mkdir -p $XLINGS_HOME

# 装 xlings 0.4.11+ 的 bootstrap（如果没装过）
curl -fsSL https://raw.githubusercontent.com/openxlings/xlings/main/tools/other/quick_install.sh | bash
$XLINGS_HOME/bin/xlings --version    # 期望 0.4.11 或更高

# 在你的本地 xim-pkgindex 改动分支上指定 index
$XLINGS_HOME/bin/xlings install gcc -y    # 走改动后的 gcc.lua
$XLINGS_HOME/bin/xlings install openssl -y
$XLINGS_HOME/bin/xlings install d2x -y

# 验 INTERP
readelf -l $XLINGS_HOME/data/xpkgs/xim-x-gcc/*/bin/gcc | grep PT_INTERP
# 期望输出：
#   [Requesting program interpreter: <XLINGS_HOME>/data/xpkgs/xim-x-glibc/2.39/lib64/ld-linux-x86-64.so.2]

# 验 RPATH 闭包
readelf -d $XLINGS_HOME/data/xpkgs/xim-x-gcc/*/bin/gcc | grep RPATH
# 期望包含：xim-x-glibc/2.39/lib64 + 自身的 lib64

# 真跑一下
$XLINGS_HOME/data/xpkgs/xim-x-gcc/*/bin/gcc --version
```

### 4. Merge 条件

- `xpkg test` 全绿
- `pkgindex test` 三平台（linux/macos/windows）全绿——**这是最重要的端到端验证**
- 至少 1 个 review 通过

---

## 出问题怎么排查

### 症状 A：CI `linux-install-test` 红，报 `command not found` / `binary not executable`

**原因**：CI runner 用的 xlings 不是 0.4.11+，没有 predicate-driven trigger。

**验证**：在 CI log 里 grep `xlings 0\.` 看 quick_install 装的是哪个版本。

**修法**：xim-pkgindex CI workflow 用 `quick_install.sh` 不带版本，会自动拉 latest stable。如果 0.4.11 已发但 CI 还在用旧版，可能是 GitHub raw cache 问题——empty commit 重触发。

### 症状 B：CI 报 `multiple loader providers` fail-fast

**原因**：consumer 的 runtime deps 同时声明了 glibc 和 musl。这是设计上的"歧义"场景，xlings 拒绝猜。

**修法**：在 install hook 加：

```lua
import("xim.libxpkg.elfpatch")
function install()
    elfpatch.set({ interp_from = "linux-x86_64-glibc" })   -- 显式选 glibc
    -- ...其他 install 逻辑...
end
```

但这个错只在多 libc 场景下出现，3 个 consumer（openssl/gcc/d2x）当前都只依赖 glibc，**不会**遇到。

### 症状 C：本地装完 binary 跑起来报 `error while loading shared libraries: libc.so.6`

**原因**：RPATH 没指向 glibc 的 lib64。

**验证**：`readelf -d <binary> | grep RPATH` 看是否包含 `xim-x-glibc/<ver>/lib64`。

**修法**：通常说明 elfpatch 没跑——再 grep `xlings 0\.` 确认 xlings 版本是 0.4.11+。

---

## 联系人

- 设计 + 这次实施：会 review 这个 PR 的人
- 全套 spec：[openxlings/xlings docs/plans/2026-05-02-elfpatch-exports-design.md](https://github.com/openxlings/xlings/blob/main/docs/plans/2026-05-02-elfpatch-exports-design.md)
- pilot 模板：[#104](https://github.com/openxlings/xim-pkgindex/pull/104)
- xlings 0.4.11 release notes（讲 elfpatch 重写的部分）：[v0.4.11](https://github.com/openxlings/xlings/releases/tag/v0.4.11)

---

## TL;DR

1. `git checkout -b feat/elfpatch-migrate-rest`
2. 在 `pkgs/o/openssl.lua` / `pkgs/g/gcc.lua` / `pkgs/d/d2x.lua` 各自删除：
   - `import("xim.libxpkg.elfpatch")` 一行
   - install hook 里 `local glibc_dir = pkginfo.dep_install_dir("glibc", ...)` 起到 `elfpatch.auto({...})` 结束的整个块
3. 提 PR，CI 自动跑（关键是 `pkgindex test`）
4. 三平台 CI 全绿 → merge
