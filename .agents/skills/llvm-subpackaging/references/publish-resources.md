# xlings-res 资源发布 SOP（llvm 子包，双镜像）

资产仓库：`xlings-res/llvm`（同一仓库，按 tag=版本号 归档）。
- `GLOBAL` = https://github.com/xlings-res/llvm
- `CN`     = https://gitcode.com/xlings-res/llvm

两镜像**必须含完全相同的资产**，否则不能把配方切到该版本。

## 1. 资产命名约定

```
<pkg>-<version>-<platform>-<arch>.<ext>
```
- `<pkg>`：`llvm` | `llvm-tools`（2 包模型；不再有 core/libcxx）
- `<platform>-<arch>`：`linux-x86_64` | `macosx-arm64` | `windows-x86_64`
- `<ext>`：linux=`tar.gz`+`tar.xz`、macosx=`tar.xz`、windows=`tar.xz`+`zip`（与现网资产对齐；
  同平台同版本两个包扩展名一致）

例：`llvm-22.1.8-macosx-arm64.tar.xz`、`llvm-tools-22.1.8-windows-x86_64.zip`

## 1.5 准入验收（上传前必做,Linux `llvm` 包)

```bash
.agents/tools/verify-toolchain.sh <llvm-*.tar.gz> \
  --loader ~/.xlings/data/xpkgs/xim-x-glibc/2.39/lib64/ld-linux-x86-64.so.2
```

脚本内置 **llvm gate**,不通过一律不上传:
1. **缺件**:`share/libc++/v1/std.cppm`、`libc++.so*`、`libatomic.so.1`
   (历史事故:slim carve 漏 libatomic → 所有产物运行期
   `libatomic.so.1: cannot open`,由用户端发现);
2. **hermetic CRT**:`-###` 干跑断言 `Scrt1.o/crti.o/crtn.o` 全部解析进
   glibc payload(`-B`),不落宿主 `/lib`、不裸名(mcpp issue #195 环境类);
3. **import std 端到端**:std.cppm 预编译 → 编译链接 → 运行。

## 2. 发布命令

### GLOBAL（GitHub，支持覆盖）

```bash
# release 已存在时：
gh release upload <tag> <file>... --clobber --repo xlings-res/llvm
# release 不存在时先建：
gh release create <tag> --repo xlings-res/llvm --title <tag> --notes "llvm <tag> sub-packages"
```

### CN（GitCode）

```bash
# 新 tag 先建 release：
gtc release create xlings-res/llvm --tag <tag> --name "LLVM <tag> (split packages)"
# 上传（新资产名直接传）：
gtc release upload xlings-res/llvm --tag <tag> <file>...
```
> **gtc 不能删资产**，也不能覆盖同名资产。若要替换旧同名资产,**由维护者在 GitCode 网页
> 手动删除**后再 `gtc release upload`。新资产名(如新增平台/新版本)无需删除,直接上传。

`gtc` 位置与配置见 reference 备忘（`/home/speak/.local/bin/gtc`，
token 在 `~/.config/gitcode-tool/config.json`）。
`gtc release create` 可能 HTTP 400，回退用 GitCode API 直接建 release（见备忘）。

## 3. sha256 三方核对（发布后必做）

```bash
sha256sum <file>                                  # carve 产物
curl -sL <GLOBAL_url> | sha256sum                 # GitHub RES
curl -sL <CN_url>     | sha256sum                 # GitCode RES
# 三者必须完全一致
```

URL 形如：
```
https://github.com/xlings-res/llvm/releases/download/<tag>/<asset>
https://gitcode.com/xlings-res/llvm/releases/download/<tag>/<asset>
```

## 4. 发布前/后检查单

- [ ] 三平台每个子包资产都已上传到 **GLOBAL 与 CN**，命名合规。
- [ ] 每个资产 sha256 三方一致（carve / GLOBAL / CN）。
- [ ] 补发旧版本时，两边 `latest` 仍指向应为最新的版本（不倒退）。
- [ ] 配方 `sha256 = nil`，同名替换无需改配方；若某配方 pin 了 sha256，同步更新。
- [ ] PR/汇报中写清 GLOBAL/CN 的 tag 与 sha256 结果（`xpkg-creater` §1.2.1 要求）。

## 5. 与既有机制的关系

- 资产路径与「索引仓库分发（Y-asset）」同一套资源服务，但属不同资产，互不混淆
  （见 `xpkg-creater` §1.2.1 与 `docs/design/index-distribution.md`）。
- 同名替换上线方式与工具链 strip 重打包一致（见
  `.agents/docs/2026-06-22-toolchain-strip-plan.md` 的"上线方式"一节）。
