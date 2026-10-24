# CI：镜像与自动更新

[English](../13-ci-mirror-and-update.md) | **简体中文**

版本自动更新统一使用固定提交的上游 [xpkgindex-update](https://github.com/openxlings/xpkgindex-update)。
唯一声明入口是 `package.extensions.autoupdate`；`xpm.source` 只负责运行时资源解析。

```lua
extensions = {
    autoupdate = {
        source = "https://github.com/acme/foo/releases",
        resources = {
            GLOBAL = "https://github.com/acme/foo/releases/download/${tag}/foo-${version}.zip",
            -- When a verified mirror exists, both targets are required by default:
            -- CN = "https://verified-mirror.example/foo/${tag}/foo-${version}.zip",
        },
    },
},
```

新建包可将上面的固定模板放入 `package` 表，按需接入自动更新。
**建议上游 GitHub 仓库至少有 50 stars**；这是贡献者建议，不是 CI 或工具的硬门槛，
star 数也不能替代资源完整性和镜像可用性验证。
将示例仓库和资产路径替换为已核实的真实值。各平台共用同一产物时使用字符串简写，
否则展开平台/架构 URL 矩阵，覆盖包声明支持的全部组合。
`${tag}` 为原始 release 标签，`${version}` 为提取后的版本，普通数字或 `v` 前缀无需额外配置。
自动更新模板独立于 `xpm.source`，不会隐式展开运行时的 `${os}`、`${arch_alias}`、`${ext}` 等占位符。

没有已验证镜像时只声明 GLOBAL；增加 CN 前核实真实项目路径、完整候选资产及两侧 SHA256 一致性。
目标默认必需；若镜像可选，经 review 显式设置 `required = false`，至少保留一个必需目标。
LTS 或固定默认版本使用 `latest = "keep"`。提交 PR 前用下方固定版本工具运行 `inspect` 和指定包的
`check` 并检查 plan。配置只维护在配方自身；人工维护的原因写入配方注释或 PR 说明。
首次建包走常规建包 CI，updater 候选检查用于已有配方的新增版本。
CI 直接校验当前配方，自动生成 `coverage.json` 并上传 Actions artifact；生成的审计快照不进入 PR。

默认 `latest = "advance"`，每个目标默认 `required = true`；`latest = "keep"` 保留既有指针。
复杂目标可写 `{ required = true, url = { linux = { x86_64 = "..." } } }`。
版本来源识别 GitHub releases/tags 和以 `.xml` 结尾的公开 HTTPS Sparkle RSS appcast，下载模板可使用任意公开 HTTPS。
候选从新到旧检查，取所有必需目标完整平台/架构资源的真实版本交集，并下载校验字节一致。
包可通过配方声明的 review 显式选择可选目标；本轮接入的 GLOBAL/CN 均默认配置为必需。

官方 appcast 可直接配置 `source = "https://vendor.example/appcast.xml"`，下载模板使用 `${version}`，
不需要 GitHub 仓库或 `tag` 声明。版本来自 Sparkle 的数字短版本号，排除增量包及带 channel 的发布项。
至少一个必需模板必须匹配完整 enclosure 的 URL 和长度；所有必需平台资源就绪后才推进 latest。
ChatGPT 使用此模式，消费官方 Linux x86_64 DEB 和 macOS ARM64 ZIP；只有 macOS 发布时等待 Linux，
不删平台或改写历史 helper 条目，新版本生成显式 URL/SHA256 表。暂不支持各平台独立推进。
官方厂商来源不需要虚构 GitHub star 数。计划绑定所选清单项的元数据摘要与资源 hash，
所选项变化则拒绝应用，清单新增其他版本不影响原计划。
updater 不验 Sparkle 签名；ChatGPT 安装时仍保留 macOS 包版本及 codesign 检查。

只有 GLOBAL 的包保留单资源。已有 xlings-res 双腿继续消费，合适的大学镜像经项目路径与产物核实后采用。
CN 跳回 GitHub 不算镜像就绪。当前使用 xlings-res 的包，也可为后续版本采用更新的上游原版资产和已验证的机构镜像。
同时将 `source` 指向真实上游版本目录，避免旧资源仓库限制发现范围；重打包/拆分包先验证布局和安装契约。
只新增候选，保留历史资源、手工条目、注释与 hooks。

实际扫描/提案每 3 天执行一次，时间为 02:17 UTC / 11:17 JST。每日轻量调度按 UTC 日期门禁，
以 2026-10-23 为锚点（10 月 23/26/29 日、11 月 1 日等），非到期日跳过扫描/提案，跨月和跨年保持等间隔。
PR 检查和人工触发不受该门禁限制。到期运行连续扫描多个批次，propose 消费同一份固定 plan，不重新发现版本。配方、base、tag commit
或资源字节变化会拒绝应用。更新不执行 Lua、不改写历史版本、不自动修复冲突、不构建载荷、不自动合并。
候选版本必须通过相应 runner 上的真实安装、功能验证和卸载。

中央策略位于 `.github/xpkgindex-update.yml`。`max_packages: 50` 是每批扫描数量，
每轮最多连续扫描 20 批，共用 500 次请求和 16 GiB 下载预算。每个包另有 50 次请求、8 GiB
下载配额；单包配额用尽时延后该包并推进游标，避免阻塞其他包。整轮预算耗尽时，
未完成的包在下轮优先重试。

已验证的候选进入独立于扫描顺序的持久 FIFO 队列。`max_prs: 20` 限制每轮提案尝试次数，
包括创建和刷新 PR；剩余候选继续排队，不必重新发现。更高候选版本替换记录但保留排队位置，
失败项移到队尾并退避 1～24 小时。配方变更使旧候选失效，提案时重新校验上游身份和资源字节。
单包错误仍在最终结果中报告，其他已验证的候选可以继续处理。

游标和队列保存在独立的运行状态分支 `auto/update-state`。首次接入可以迁移旧 Actions 缓存，
之后以持久状态为准。最终持久化任务通过版本比较保存提案后的状态；提案失败时保留最新可用检查点。
并发写入会被拒绝，不能覆盖更新的进度。状态分支不发布包变更，也不会自动合入。

每个候选工作流最多并发 4 个平台任务，每轮最多分发 20 次新工作流。
相同 head 已成功或仍在运行的 CI（包括普通 PR 触发）不会重复分发；刷新 head 后重新验证，
重新确认 PR head 未变化后才取消旧任务。显式使用 `autoupdate-dispatch.py --retry-failed`
可重试未变化的失败 head，仍保留 bot、仓库和 base 校验。部分提案失败时，成功项仍会分发 CI，
最终门禁仍保留失败状态。

人工触发 `xpkgindex-update.yml` 时，可指定 `max_batches`（1..20）、可选的 `package`，
以及 `dry_run: true`。试运行检查真实上游资源并上传 `unified-update-plan`，不创建 PR、不分发候选 CI。
试运行、单包扫描和功能分支扫描均不读取或保存生产游标；仅默认分支允许创建提案。
例如，发布前验证接入分支：

```sh
gh workflow run xpkgindex-update.yml --ref fix/autoupdate-batching-ci -f dry_run=true -f max_batches=20
```

候选安装脚本从固定的 xlings release tag 获取。原生安装任务仅覆盖 Linux x86_64/ARM64、
macOS ARM64 和 Windows x86_64。macOS Intel 和 Windows ARM64 仅校验资源：新增资源仍全部校验，
但不创建安装任务。任务摘要和 `coverage.json` 明确报告此边界，资源校验不算安装验证。
未知平台仍会被准入检查拒绝。DPCPP 的 RUNPATH 校验仍是真实升级门禁。

预算和轮转游标约束扫描，不用多天节流掩盖失败。正常升级只追最新稳定版，
历史补录独立处理且尚未启用。工具安装后可以运行：

```sh
xpkgindex-update inspect
xpkgindex-update check --package xim:foo --output plan.json
xpkgindex-update apply --plan plan.json --package xim:foo
```

`propose --plan plan.json` 使用有写权限的凭据创建或刷新每包 PR。
分支固定为例如 `auto/bump-xim-nvim`；更高候选版本更新同一个 bot PR，包括标题和资源证据。
普通追加提交替换未发布的候选变更，保留所有已发布版本；人工修改、并发更新会被拒绝，不使用强推。
旧版带版本号的 bot PR 仅在固定分支的替代 PR 创建成功后关闭；已有人工包 PR 仍阻止自动提案。
推分支成功但建 PR 失败可以恢复；base、配方、tag commit 或资源字节变化会拒绝应用。

## 镜像发布

`ci = { mirror = true }` 继续独立控制已声明资源的镜像发布。
`tools/xpkg_ci.py` 仅保留 `inspect`、`materialize`、`verify`、`ensure-repo`、`mirror`。
镜像发布不能成为同一个更新 PR 合并后才可满足的资源前置条件。
自建/重打包载荷由独立工作流生产，updater 只消费已就绪资源；已发布资源变更仍走人工 revision 流程。

旧自动更新字段和工作流已移除，不提供旧协议回退。CI 每次从配方生成全量包清单，不读取提交到仓库的审计快照。
