# xim-pkgindex artifact 发布机制 + 独立发布 CI 设计

**日期**: 2026-06-24
**本仓**: `openxlings/xim-pkgindex`(xlings 的官方包索引)
**目标**: 让"在本仓改了包(`pkgs/**`)→ 自动重发 artifact",不再依赖 xlings 发版。
**配套设计**(分析/背景):xlings 仓 `.agents/docs/2026-06-24-pkgindex-publish-decoupling-ci.md`、
`.agents/docs/2026-06-22-index-as-resource-impl-plan.md`。

---

## 1. 客户端怎么拿索引(双路径)

| 路径 | 说明 |
|---|---|
| **artifact(默认 `XLINGS_INDEX_SOURCE=auto` 优先)** | 拉轻量指针 `xim-index-pointers.json` → 比 sha → 下版本化 tarball,免 git |
| **git(回退)** | clone/pull 本仓(github)或 gitee 镜像(`sunrisepeak/xim-pkgindex`,`gitee-sync.yml`) |

> 默认 auto = artifact 优先、git 回退。所以"让默认客户端拿到改动"= **必须重发 artifact**。

## 2. 资源仓 + 载体(已就绪)

- **资源仓**:`xlings-res/xim-index`(**github GLOBAL + gitcode CN 两端都有**)。
  - **artifact**(`xim-index[-<name>]-<ref>.tar.gz` + `.manifest.json`):作为 **release 资产** 上传。
  - **指针**(合并的 `xim-index-pointers.json`,含 keys `xim`/`awesome`/`scode`/`d2x`):作为
    **仓库文件**提交(GitCode release 资产不可覆盖,故指针走文件 push)。
- **本仓 secrets(已配置)**:`XLINGS_RES_TOKEN`(对 xlings-res 有写权)、`GITCODE_TOKEN`、`GITEE_TOKEN`。

## 3. 发布脚本(standalone,住在 xlings 仓 `tools/`)

| 脚本 | 作用 |
|---|---|
| `build_xim_index_artifact.sh --version <ref> --out <dir> [--name <sub>] [--src <dir>]` | 打包 `pkgs/`+`xim-indexrepos.lua`+`.xpkgindex.json`(去 `.git`)→ 确定性 tarball(`--sort=name --owner=0`)+ manifest(sha256/size/format_version/source_commit/签名槽) |
| `publish_xim_index.sh --version <ref> --dir <dir> [--name <sub>] [--skip-gitcode]` | 把 artifact 传成 release 资产 + 写该 index 的 `*-latest.json` 指针 |
| `push_index_pointers.sh <dir>` | 合并各 `*-latest.json` → `xim-index-pointers.json` → git push 到 `xlings-res/xim-index`(github + gitcode) |

> 这三个脚本**不需要 xlings 构建**,纯打包+发布,完全可在本仓 CI 里独立跑。

## 4. 现状 gap

artifact 目前**只在 xlings release 的 `publish-index` job** 里发,且 artifact 名按 **xlings 版本**
命名。→ 在本仓改了包但不发 xlings,默认(artifact)客户端**拿不到**(指针/artifact 还是上次
release 的)。本仓自带的 `pkgindex-deloy.yml` 只建 GitHub Pages 文档站,**不发 artifact**。

## 5. 方案:本仓加 `publish-artifact.yml`

- **触发**:`push`(paths `pkgs/**`、`xim-indexrepos.lua`、`.xpkgindex.json`)+ `workflow_dispatch`
  + 可选 `schedule`(nightly 兜底)。
- **取脚本**:把 `build_xim_index_artifact.sh`/`publish_xim_index.sh`/`push_index_pointers.sh`
  **vendored 到本仓**(推荐,自洽),或 CI 里 `curl` 拉。
- **artifact 命名改用内容哈希/短 sha**(`xim-index-<gitsha>.tar.gz`),**解绑 xlings 版本** —— 解耦关键。
- **步骤**:build_artifact(`--src .`,主 index;子 index 用 `--name`+各自 URL)→ publish(GH+GitCode)
  → push 合并指针 → 验证两端可下。
- **auth**:用本仓已配的 `XLINGS_RES_TOKEN` + `GITCODE_TOKEN`。
- 子索引(awesome/scode/d2x)同款:各自仓加同 CI,或本仓 CI 一并打包(沿用 release.yml 的
  `--name awesome/scode/d2x` 调法)。

**效果**:改 `pkgs/**` push → CI 自动重发 artifact + 移指针 → 默认客户端下次刷新即拿到,**不必发 xlings**。
xlings release 的 `publish-index` 保留(发版时仍发"已知好"配对),不再是唯一通道。

## 6. 客户端侧配套(见 xlings 仓文档)

`xlings update` 走"指针 sha 比对优先,命中零下载、失败降级本地";子索引不可达即跳过
(0.4.58 `xim/repo.cppm` 已用 `probe_latency` 实现);软 TTL + `--force` 显式刷新。

## 7. 落地

1. **P0**:本仓加 `publish-artifact.yml`(push/dispatch/schedule)+ vendored 脚本 + 内容哈希命名。
2. **P1**:客户端刷新走指针 sha 比对。
3. **P2**:与 `mcpp-community/mcpp-index` 统一(它发到 `xlings-res/mcpp-index`,见 mcpp 仓文档)。
