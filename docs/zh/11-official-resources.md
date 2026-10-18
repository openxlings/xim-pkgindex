# 官方资源

[English](../11-official-resources.md) | **简体中文**

本索引从自己的服务器安装的二进制：它们在哪里、怎样构建，以及配方引用它们之前要通过
的门禁。

## 在哪里

`xpm.source = "xlings-res"` 解析到官方资源服务器：一个组织、两个主机，内容逐字节相同：

| 区域 | 服务器 |
|---|---|
| `GLOBAL` | `https://github.com/xlings-res` |
| `CN` | `https://gitcode.com/xlings-res` |

一个资源是 `xlings-res/<package>`，每个版本一个 release，资产名为
`<name>-<version>-<os>-<arch>.<ext>`，旁边有 `.sha256` sidecar。客户端先试自己的区域，
另一个作为后备；接受与否由配方中的 sha256 决定，所以滞后的镜像会被拒绝，而不是被信任。

索引工件（`xlings-res/xim-index`）是另一类资源，有自己的指针；包的二进制不放在那里，
索引也不放进包的 release。

## 镜像的还是构建的

| 类别 | 例子 | 怎样到那里 |
|---|---|---|
| 镜像 | 设了 `ci.mirror = true` 的第三方 release | 镜像 workflow 校验后复制（[CI](13-ci-mirror-and-update.md)） |
| 在这里构建 | bwrap、pasta、e2fsprogs、limine、qemu-system、aarch64 的 gcc | 资源工厂 `tools/res/` |

## 资源工厂

`tools/res/build.sh <what> <version> <out>` 在目标架构上构建一个资源。`res-build` workflow
在 `ubuntu-24.04` 和 `ubuntu-24.04-arm` 上运行它：

- 它需要的一切都在**按 digest 固定**的容器中运行（静态 musl 构建用 Alpine，链接 glibc 的
  用 Debian）；runner 只需要 docker；
- 每个上游输入都按 `tools/res/inputs.txt` 中的 digest 校验；
- 每次构建在成为 artifact 之前检查产物 —— 能运行、声称静态的确实是静态、链接 glibc 的只
  依赖 glibc、没有硬链接；
- 每个载荷带一份 `README.provenance`：输入、它们的 digest、容器，以及容器内安装的包。

```bash
gh workflow run res-build.yml --ref <branch> -f only=qemu-system
gh workflow run res-build.yml --ref <branch> -f publish_runs="<run-id>" -f execute=true
```

前者在一个分支上构建一个资源；后者在受保护的 `xlings-res-publish` 环境中发布已有运行的
artifact。

**自举是方向，还不是现状。** 在工厂的容器里，构建工具来自发行版的包管理器（Alpine 的
`apk`、Debian 的 `apt`）。目标是工厂所用的工具本身也由 xlings 从本索引安装，使每个资源都
只由本生态发布的东西构建；在那之前，容器 digest 和 `README.provenance` 精确记录了用到的
东西。

## 门禁

配方只有在以下各项都成立后才引用一个资源：

1. **它声明的每个平台和架构**都有资产，GitHub 和 GitCode 上同名。
2. **以一次构建为准**：sha256 从它计算，然后分别从上游、GitHub、GitCode 下载并逐字节比较。
   GitCode 用 GET 而不是 HEAD 验证（它对 HEAD 返回 401）。
3. **每个资产都有 `.sha256` sidecar**；缺少某个受支持架构的 hash 时，
   `version-check.py --apply` 失败且不做任何修改。
4. **`latest` 只移到已验证的版本**，补发旧版本时绝不后退。
5. **已发布的资源永不改变。** 重新构建（补丁、前缀、布局修正、去掉硬链接）以新的 tag 和
   资产名 `<version>-r<N>` 发布，版本项的 `revision` 改为 N。旧资产原样保留：缓存了索引的
   客户端仍持有它的 hash。`.github/scripts/check-revision.lua` 拒绝资源变化而 revision 未提高
   的改动。重新构建修复的是所有已装载荷都有的缺陷时，同时把版本项的 `floor` 提到 N；不是这种
   情况（去掉硬链接、只为某个平台调整布局）时不动它，已装的载荷继续可用
   （[`floor`](../specs/xpackage-v2.md#floor--the-oldest-installed-revision-still-usable)）。

## xlings 的发布

xlings 的新版本在 `pkgs/x/xlings.lua` 引用它之后才可安装：每个平台都有新版本的条目和
sha256，`latest` 移到它。release 的资产先在 GitHub 和 GitCode 上就位（GitCode 的副本从
国内的机器推送）；两边都验证过之后，索引的改动才合入。
