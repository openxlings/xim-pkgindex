# TODO: 本仓库索引制品(index-as-resource)自动发布

> 状态：**待办（未实现）** · 创建：2026-06-23 · 关联：`docs/design/index-distribution.md`

## 背景

xlings v0.4.52+ 引入「索引即资源 / Y-asset」分发：官方索引在 `auto` 模式下不再运行时
git clone，而是作为带版本号、sha256 锁定的 tar.gz 制品，走资源服务器
（`GLOBAL=github.com/xlings-res`、`CN=gitcode.com/xlings-res`）拉取。机制全貌见
`docs/design/index-distribution.md`。

**问题**：当前构建/发布这套制品的工具与 CI 都在 **xlings 仓库**里，且由 **xlings 发版**
触发：

- `tools/build_xim_index_artifact.sh` — 生成 `xim-index[-<sub>]-<ver>.tar.gz` + `manifest.json`
- `tools/publish_xim_index.sh` — 双发到 `xlings-res/xim-index`（GitHub + GitCode），
  滚动 `latest` + 归档 `v<ver>`
- `tools/push_index_pointers.sh` — 把合并指针 `xim-index-pointers.json`（仓库文件）push 到双端
- `release.yml` 的 `publish-index` 任务

而**索引内容**（`pkgs/**`）住在**本仓库**。于是：本仓库 main 合入新包/改动后，
`xlings-res/xim-index` 上已发布的制品会**滞后到下一次 xlings 发版**才刷新。git 回退路径
仍能拉到最新（直接 clone 本仓库 / gitee 镜像），但 artifact 路径上的用户会看到旧索引。

## 目标

让本仓库 **在 main 更新后自行重建并发布索引制品 + 更新合并指针**，使 artifact 路径
始终反映最新 main，与 xlings 发版节奏解耦。

## 待定方案（草案）

新增一个 GitHub Actions workflow（如 `.github/workflows/index-publish.yml`），在 push 到
main（或定时）时：

1. 复用/移植 xlings 的 `build_xim_index_artifact.sh` 逻辑：
   - 主索引 → `xim-index-<ver>.tar.gz` + `manifest.json`
   - 子索引（如本仓库需要负责）→ `xim-index-<sub>-<ver>.tar.gz`
   - 剥离 `.git`，写 `format_version:1` / `index_version` / `source_commit` / `sha256`。
2. 双发到 `xlings-res/xim-index`（GitHub + GitCode），滚动 `latest` + 归档 `v<ver>`。
   - GitCode 侧用 vendored `tools/gtc`（参考 xlings CI；本仓库 memory 有 `gtc` 工具说明）。
   - 注意 GitCode release 资产不可覆盖同名文件 → 版本号要随内容变化。
3. 更新合并指针文件 `xim-index-pointers.json`（仓库文件，可 git push 覆盖）双端。
4. e2e 校验：发布后从 GitHub RES / GitCode RES 各拉一次，比对 sha256 字节一致。

## 待澄清的问题（需 maintainer 决策）

1. **索引版本号怎么定？** 用什么作为 `index_version`——本仓库 commit 短哈希、日期戳、
   还是独立递增号？（影响 GitCode 不可覆盖同名资产的约束。）
2. **职责边界**：索引发布应归 xlings 仓库（发版时）还是本仓库（合入时），还是两者并存？
   若并存，谁是 `latest` 的权威写入方，如何避免互相覆盖/倒退？
3. **子索引（awesome/scode/d2x）** 的制品由谁负责发布？本仓库只发主索引 `xim` 即可吗？
4. **凭证**：本仓库 CI 是否已具备 `XLINGS_RES_TOKEN` / `GITCODE_TOKEN`？还需哪些 secret。
5. **触发策略**：每次 push main 都发，还是合并若干改动后定时/手动发，控制发布频率。
6. 与现有 `pkgindex-deloy.yml`（静态站点）、`gitee-sync.yml`（git 镜像）如何协同。

## 参考

- 本仓库：`docs/design/index-distribution.md`
- xlings：`docs/design/index-distribution.md`、`tools/{build_xim_index_artifact,publish_xim_index,push_index_pointers,package_xim_index}.sh`、`.github/workflows/release.yml`、`src/core/xim/indexfetch.cppm`
- xlings：`.agents/docs/2026-06-22-index-as-resource-impl-plan.md`
