# xim-pkgindex 统一自动更新设计

> 2026-10-23 更新：本文旧的 upstream/url 和 GitHub-only 描述已被 [source/resources 当前设计](2026-10-23-xpkgindex-update-multi-mode-design.md) 取代；以当前设计、覆盖审计和 PR 最新提交为准。

日期：2026-10-22  
状态：实现与 CI 验证中，等待 review；交付为草稿 PR。  
范围：上游版本发现、资源验证、配方追加、更新 PR、候选版本 CI、旧自动更新链路退役。

2026-10-22 范围修订：按用户最新要求，自动更新每 3 天触发一次；本期仅接入纯 GitHub 来源。
配方含 CN 镜像、`XLINGS_RES` 或 `xpm.source = "xlings-res"` 隐式多镜像的包不接入；候选 URL
必须为 HTTPS `github.com`，厂商接口和外部 registry 均不接入。下文通用工具的区域矩阵能力不代表
本期启用双镜像包。工作流每日 `17 2 * * *` 检查日期门禁，以 2026-10-23 UTC 为锚点，仅每 3 天执行扫描/提案（02:17 UTC / 11:17 JST）；移除测试分支 push 提案入口。

## 1. 设计决策

统一使用 `openxlings/xpkgindex-update`，不保留 xim 旧自动更新协议的兼容层。

- 唯一更新声明为 `package.extensions.autoupdate`。
- 删除自动更新对 `ci.update`、`url_template`、`res_versioned` 的识别与执行路径；不建立字段翻译、双读或旧 CLI 转发。
- `xpm.source` 是运行时资源声明，可以继续存在，但不隐式开启自动更新，也不充当更新配置的后备来源。
- `ci.mirror` 属于独立镜像发布能力，本次不迁移其协议；删除 `ci.update` 时保留仍有用途的 `ci` 字段。
- xim 所需的通用能力在 `xpkgindex-update` 上游实现。xim 仓库不维护私有 fork、补丁副本或第二套版本比较/配方编辑器。
- 每 3 天一次扫描，生成固定 plan；同一次运行的 propose 消费该 plan，不重新发现版本。
- 默认每包只更新到最新可接受稳定版本，不在正常升级中自动补历史。
- 完整平台与架构资源验证通过后，原子追加新版本并推进 `latest.ref`；历史版本保持原样。
- 只创建 PR，经候选版本 CI 和人工 review 后合并；本方案不引入自动合并。

“不兼容旧协议”针对自动更新输入与入口，不意味着删除历史版本、重写安装逻辑或取消旧版本安装。

## 2. 现状与能力边界

调查基线：`xpkgindex-update` 远端 main 为 `6c0bee2941e36132bc2ac3d1f7edbef8b5790320`。
实施时先复核最新上游，再固定一个包含所需能力、通过验证的提交；禁止生产工作流跟随浮动 `@main`。

| 内容 | 当前已有 | 本方案要求新增/调整 |
|---|---|---|
| 更新声明 | `extensions.autoupdate = { tag, url }` | xim 策略、显式上游、平台/架构 URL 矩阵 |
| 发现 | GitHub Releases，必要时回退 tags；数字/日期等版本排序 | 显式上游与资源仓库解耦；不支持的编号策略明确停止 |
| 计划与写入 | 配方摘要、上游 commit、资源 hash、apply 复核、原子写入 | 按架构记录资源；记录预期 latest 与最终 latest |
| adapter | xim 文件仅重导出 mcpp append | 真正的 adapter 分发，覆盖 check/apply/propose/guard |
| latest | 检测到已有 latest 时拒绝追加 | xim 明确允许的前移/保持策略 |
| 平台版本 | 要求历史平台版本集合一致 | 允许历史差异；新候选必须覆盖声明矩阵 |
| PR | 每包去重、识别人工 PR、孤立 worktree、恢复未建 PR 的分支 | 按包隔离失败、结构化汇总，落实一致的 CI 触发方式 |
| 下载 | 缓存、重试、hash、基础归档识别；512 MiB/资源、4 GiB/运行 | 中央可配置预算，支持大型工具链，完善 tar.xz 等资源检查 |

现有 xim 的离线复现已确认：共享扫描状态会跳过后续扫描、错误仍写检查时间并返回成功、平台版本取并集会漏报缺失。
现有 version-check 单元脚本和 14 项 backfill 测试通过，不能据此认为这些边界已被覆盖。

参考：

- [工具说明（调查基线）](https://github.com/openxlings/xpkgindex-update/blob/6c0bee2941e36132bc2ac3d1f7edbef8b5790320/docs/usage.md)
- [xim adapter（调查基线）](https://github.com/openxlings/xpkgindex-update/blob/6c0bee2941e36132bc2ac3d1f7edbef8b5790320/src/xpkgindex_update/adapters/xim_pkgindex.py)
- [mcpp-index 集成](https://github.com/mcpplibs/mcpp-index/blob/main/.github/workflows/xpkgindex-update.yml)
- [现有 xim CI/镜像设计](2026-07-12-xpkg-ci-mirror-update-design.md)
- [现有 V2 资源形态](../../docs/V2/xpackage-spec.md)

## 3. 职责划分

| 所在位置 | 职责 |
|---|---|
| `xpkgindex-update` | 解析声明、发现版本、比较版本、展开矩阵、下载校验、生成与复核 plan、编辑配方、保护历史、管理更新 PR |
| xim 包文件 | 声明更新意图、固定 tag/URL 映射、支持的资源矩阵和 latest 策略；保留实际安装/配置逻辑 |
| xim 中央配置 | adapter、请求/下载预算、每次 PR 上限 |
| xim workflow/薄 CI helper | 调度、传递 artifact、选择测试、安装候选、收集证据、汇总门禁 |
| 既有资源生产/镜像工作流 | 构建、重打包、发布 GitHub/GitCode 资源及 sidecar |
| maintainer | 审查变更、决定平台增减、特殊编号、历史修复和合并 |

CI helper 不实现版本比较、资源 URL 展开或 Lua 源码改写。需要这些操作时调用统一工具。
工具不得执行包内自定义更新脚本或任意 Lua，以绕过声明模型。

## 4. 统一声明

### 4.1 现有标准写法

单个共享源码资源继续使用工具已有的声明：

```lua
extensions = {
    autoupdate = {
        tag = "v${version}",
        url = "https://github.com/acme/foo/archive/refs/tags/${tag}.tar.gz",
    },
},
```

### 4.2 xim 统一写法

以下字段由统一工具上游 PR 实现；xim 固定使用通过 CI 的提交。本期只接入纯 GitHub 资源和不含 CN 的包。

```lua
extensions = {
    autoupdate = {
        upstream = "acme/foo", -- 发现版本的 GitHub 仓库，与资源仓库独立
        tag = "v${version}",
        latest = "advance",
        url = {
            linux = {
                x86_64 = "https://github.com/acme/foo/releases/download/${tag}/foo-${version}-linux-amd64.tar.gz",
                aarch64 = "https://github.com/acme/foo/releases/download/${tag}/foo-${version}-linux-arm64.tar.gz",
            },
            macosx = {
                aarch64 = "https://github.com/acme/foo/releases/download/${tag}/foo-${version}-darwin-arm64.tar.gz",
            },
            windows = {
                x86_64 = "https://github.com/acme/foo/releases/download/${tag}/foo-${version}-windows-amd64.zip",
            },
        },
    },
},
```

字段约束：

- `tag`：沿用工具的 `${version}` / `${version:dash}` 映射。拒绝模糊映射或隐式删除发行后缀。
- `upstream`：xim 自动更新包必须显式填写，避免把 xlings-res 或 fork 下载仓库误当版本来源。
- `latest`：xim 必填，枚举为 `advance` / `keep`。`advance` 才允许移动已有 latest；`keep` 只追加。
- `url`：使用字符串、平台映射或平台 → 架构映射；本期每个资源叶子必须是 HTTPS `github.com` 地址。通用工具的 GLOBAL/CN 矩阵能力不在本期 xim 准入范围内。
- URL 只使用已声明的占位符。新矩阵使用规范架构名 `x86_64` / `aarch64`；文件名差异显式写在 URL 中，不从旧版本继承 alias。
- 可选 `verify = "sha256-sidecar"`：上游新增能力；对每个声明的资源验证 `<url>.sha256`，文件名和实际 hash 必须匹配。未声明时仍下载计算 hash。
- 未声明 `autoupdate` 的包不扫描；声明不完整则报配置错误，不静默转入旧逻辑。

平台映射和区域映射按键空间判定，禁止同层混用平台/架构/区域。未知键、非规范架构、空矩阵和重复资源身份均报错。
工具已有 mcpp 的 `{ tag, url }` 写法继续有效；xim 的必填约束由 xim adapter 校验，不强加给 mcpp。

### 4.3 新版本的运行时输出

多架构二进制统一生成 V2 已支持的 Shape B，具体 URL/hash 一一对应：

```lua
["1.2.3"] = {
    x86_64 = { url = "https://.../foo-1.2.3-linux-amd64.tar.gz", sha256 = "<verified>" },
    aarch64 = { url = "https://.../foo-1.2.3-linux-arm64.tar.gz", sha256 = "<verified>" },
},
```

单架构/共享源码维持简单 `{ url, sha256 }`，相同资源可以复用工具已有的共享表机制。
已有 Shape C、source、sentinel、alias 与历史版本块不重写；新 Shape B 用显式资源，不依赖历史 alias 或 source 的隐式继承。
采用 Shape B 的包需在迁移时满足并标注仓库现有客户端能力/最低版本要求，不能假定所有旧客户端都理解新形态。

## 5. latest 与完整矩阵

1. 从新声明和当前 latest 解析结果建立平台/架构覆盖表；迁移 PR 明确确认实际支持集合，不能把顶层 `archs` 的并集直接复制到所有平台。
2. 所有声明的平台必须存在于 xpm；现有平台必须在更新声明中被明确覆盖。暂不支持隐式忽略某个平台。
3. 每个平台的新资源集合必须保持当前 latest 的实际架构集合。增减架构/平台单独人工 PR，不能由上游缺资产触发。
4. 历史版本允许平台不同，但当前 latest 在各目标平台必须一致；不一致时返回 `policy-required`，不自动对齐。
5. `advance` 的候选必须高于当前 latest 和各目标平台已存在的可比较版本。不能把一个低于现存版本的候选写成 latest。
6. `keep` 追加候选后不改 latest；它同样不承担低版本补录。
7. 候选只存在于部分平台时返回 `existing-version-conflict`；普通更新不修复、覆盖或重复插入。
8. 原子写入前验证全部资源及输出解析结果。任一失败，整个包文件保持原样。

历史保护允许改变已声明策略下的 `latest.ref`，不放宽历史资源块保护；`guard` 按 adapter 验证允许的指针前移和候选完整性。
自动更新不得改动历史 URL/hash、资源共享表旧值、revision、依赖或安装函数。guard 仅作为自动更新范围的严格门禁；人工 revision 变更继续遵循既有 revision 流程。

## 6. 固定计划与执行

```text
每 3 天/手动调度
  → inspect + 声明审计
  → check：发现候选、展开完整矩阵、下载校验
  → 固定 plan artifact
  → propose --plan：复核、每包隔离追加、创建/恢复 PR
  → PR CI：静态检查 + 实际候选安装/运行
  → maintainer review / merge
```

计划包含 schema 版本、adapter、索引 base commit、包身份/路径/配方摘要、旧/新 latest、策略摘要、tag 与上游 commit，
以及每个 `(platform, arch, region)` 的 URL、大小、SHA256 和 sidecar 校验结果。
新矩阵使用新 plan schema 版本；旧执行器必须拒绝新格式，不能忽略架构字段继续写入。

- propose 必须消费 scan 的 artifact；不使用当前 composite `mode: propose`，因为它会自行重新 check。
- apply/propose 都复核 base、配方摘要、上游 tag commit、矩阵和资源内容；资源缓存限本次验证生命周期，缓存不能替代跨运行复核。
- base 变化后本轮报告 `stale-plan`，下次重新扫描；不在旧 plan 上自动 rebase 后继续执行。
- plan 只能来自同次受信任默认分支运行，不能从 PR 工作区提交或任意外部 artifact 获取后进入写权限 job。
- 新增/变动 tag、缺资源、镜像不一致都不允许降级到“猜一个 URL 继续”。

## 7. 调度、状态与 PR

唯一入口建议为 `.github/workflows/xpkgindex-update.yml`，默认每 3 天运行，可手动按包执行。
删除三天检查时间缓存；预算不足时保留待处理清单，失败不写“已成功”状态。

中央 `.github/xpkgindex-update.yml` 初始保留工具现有字段 `version: 1`、`adapter: xim-pkgindex`、`max_prs: 3`。
请求数、下载字节数、单资源大小和包扫描上限在工具上游增加正式配置；拟定初值为 500 次 API 请求、每轮 50 包、
每资源 4 GiB、每轮 16 GiB。预算在请求/下载之前及流式读取中执行，重试也计费；大资源按包去重下载。
预算截止状态与下一次起点需要持久化，否则持续重扫前 50 包会饿死后续包；状态只保存游标和结果索引，不用于推迟失败重试。
工作流串行化，恢复状态失败可重扫，但不得永久漏包。

| 状态 | 行为 |
|---|---|
| `up-to-date` | 正常完成 |
| `update-ready` | 允许 propose |
| `waiting-assets` | 上游 404/410 等资源尚未齐备，下一次重试，不创建 PR |
| `pending` | 已有自动或人工 PR 修改该包，不重复创建 |
| `pinned-*` / `policy-required` | 明确展示原因，需要人工修订声明 |
| `budget-deferred` / `stale-plan` | 保存原因，下一次优先重新处理 |
| `error` / `existing-version-conflict` | 当前包失败，其他包继续；最终汇总失败 |

`waiting-assets` 连续 7 天仍未就绪时纳入失败汇总，防止永久等待被当作健康。
按包隔离可用部分 plan 中的 update-ready 记录继续 propose；汇总 job 在最后统一报告错误，不能靠 scan job 失败把全部候选静默跳过。

每包最多一个开放更新 PR；人工包修改 PR 同样阻止重复提案。已关闭且未合并的同一候选不自动重开。
已有分支但没有 PR 时，复核分支内容与计划一致后恢复建 PR；不覆盖不一致的分支。
PR 描述列出旧/新 latest、完整资源矩阵、tag commit、plan 来源和待完成 CI。

## 8. CI 与权限

- scan/候选安装测试只读；propose 才有内容、PR 和显式 CI dispatch 的写权限，且只允许默认分支定时/手动入口。
- 使用内置 `GITHUB_TOKEN`。用户已开启 Actions 创建 PR；REST 权限和真实机器人建 PR 均已验证，不依赖旧 `XPKG_BOT_TOKEN`。
- 显式 CI dispatch 验证机器人 PR、仓库、基础分支和 head SHA，按工作流/head 幂等补触发；不假定 token 创建的 PR 会自动触发普通 PR CI。
- checkout 使用 `persist-credentials: false`，工具固定通过 CI 的不可变提交，不使用浮动 `@main`。
- 移除集成分支 push 自动提案入口；自动升级只按每 3 天的调度执行，仍保留人工触发和 PR 候选验证。

PR CI 从 diff 选择所有新增 `(package, version)`，不扫描未来上游版本；即使 latest 未变也要测试新增版本。
自动更新必跑：Lua/元数据校验、历史保护、完整矩阵资源校验、索引注册、受支持 runner 上的安装/功能/卸载检查。
测试显式安装候选版本，确认候选配方来自 PR checkout，并记录安装元数据与程序实际版本，避免缓存或已发布索引掩盖错误。
资源校验覆盖完整矩阵；运行测试按可用原生 runner 或已验证的模拟环境逐项覆盖。缺执行环境的矩阵项必须阻止该包自动更新上线，先人工维护。
硬件类工具可做无硬件 CLI smoke test；不能把无探针环境的失败解释成候选成功，也不要求 CI 操作真实硬件。

## 9. GitHub 接入范围与独立镜像

统一 updater 只发现、验证和提交；本期只支持 GitHub Releases/tags 和 HTTPS `github.com` 资源。

- 按包筛选：任何历史运行时资源声明含 `CN`，或直接使用 GitCode 地址，则整包不接入。
- `XLINGS_RES`、`xpm.source = "xlings-res"` 会隐式启用多镜像，也不接入；不通过删除老镜像来让包满足准入。
- 外部 registry、厂商下载地址和厂商 discovery provider 不接入；Go 等包维持人工维护。
- 候选资源必须全部位于 GitHub 声明地址，完整架构的 URL 和 SHA256 验证通过后才提 PR；缺资源则等待。
- 既有版本的 URL/hash、运行时镜像与 `ci.mirror` 独立发布行为保持原样；本期不由 updater 构建、上传或补录资源。
- 本地证据目录不加入 PR；可复核证据通过 Actions artifact 和工作流链接提供。

## 10. 历史补录与特殊版本

正常升级只提最新可接受稳定版。历史补录是未来统一工具的独立显式操作，需指定版本范围/数量、生成 plan、通过同样矩阵门禁，且保持 latest。
首轮不实现自动 backfill，也不保留旧脚本作为 backfill 入口；确需补录时先实现统一工具能力或人工 PR。
commit snapshot、包版本与源码版本不一致、重新编号、发行后缀无法无歧义映射的包先人工维护。
Go 等需要厂商接口的包，在统一工具实现正式 discovery provider 前不能假定 GitHub Releases 可替代官方版本接口。

## 11. 迁移与退役

### A. 上游工具完成能力

在 `xpkgindex-update` 提 PR 实现：adapter 真分发、xim 身份默认命名空间、latest 策略、多架构矩阵、新 plan schema、sidecar、
历史差异处理、预算/游标、结构化状态、PR 故障恢复与 guard。保持 mcpp 现有用法及测试通过。
必须覆盖真实 xim 配方的静态语法与安装函数尾部；解析器不支持时明确拒绝，不能执行 Lua 或退回正则改写。
先合并并验证工具提交，再让 xim 固定使用该提交。

### B. 迁移清单与试运行

静态盘点必须按语法结构读取，不能用全文搜索的 `update = true` 匹配注释。
逐包输出：旧意图、资源形态、实际矩阵、发现源、mirror 就绪方式、测试环境、迁移/人工维护结论和原因。
以符合本期 GitHub-only 准入的 uv/fd 等包验证普通资源、架构矩阵和三平台候选安装；CN/隐式多镜像包不作为接入试点。
在测试分支验证 check/apply 与候选测试；显式测试环境中可建 draft PR，生产 propose 仍关闭。
若只做部分包试点，先停用旧定时更新器，其余包暂人工维护；不允许旧新扫描器同时生产更新 PR。

### C. 切换 PR

同一切换 PR 完成：

1. 添加中央配置、新 workflow 和调用统一工具的 CI helper。
2. 将批准接入的包改为 `extensions.autoupdate`；尚不具备条件的包登记人工维护。
3. 移除全部旧 `ci.update` / `url_template` / `res_versioned` 自动更新声明；保留 runtime source、ci.mirror 和历史资源。
4. 删除 `version-check.yml`、`version-bump.yml`、`version-check.py` 及仅服务旧链路的测试/说明。
5. 删除 `tools/xpkg_ci.py` 的 scan/propose、旧策略读取与 `load_vcheck` 依赖；保留 inspect/verify/materialize/mirror 中镜像仍需的逻辑，明确其仅消费镜像元数据。
6. 删除 `.github/xpkg-ci.yml` 中失去用途的更新策略和旧扫描缓存路径，更新文档、贡献规范和包创建 skill。
7. 审计已有自动 bump PR 与孤立分支，登记接管/关闭方案；不能未经核实批量关闭人工工作。

用户 review 设计后再实施。所有工具代码、包、测试和 workflow 修改分别走 PR 与 CI，本次文档不触发生产切换。

### D. 上线验收与回退

启用后至少观察 7 次生产调度和一次真实自动更新 PR 的完整安装测试闭环；当前 GitHub-only 范围需有受控资源验证和实际候选安装证据。
异常时停用新的 propose，保留报告与人工更新；回退不恢复旧扫描器，不自动删除已追加版本。

## 12. 验收清单

- 生产只有一个 updater 和一个更新声明入口，无旧字段读取、转发或第二套编辑器。
- 同次 scan 的 plan 被 propose 原样消费；base、配方、tag 或资源变化会拒绝应用。
- 历史平台差异不阻止合法新版本；新版本任一平台/架构缺资源时整个包不写入。
- latest 不倒退；keep 不移动；平台指针不一致和部分候选冲突可见且不自动修复。
- 原有版本、镜像、hash、注释、顺序及共享引用内容保持不变。
- 注释内的旧开关不被当成有效配置；运行时 source 不会隐式开启更新。
- 网络/校验错误不产生成功状态；其他包能继续，最终汇总准确失败。
- 预算真正限制请求/下载；重试计费；后续包不会永久饥饿。
- 重跑不重复建 PR，人工 PR 可阻止重复，推分支后建 PR 失败可以恢复。
- 每项候选测试证明实际安装的是 PR 中的新版本；写权限 job 不执行候选安装逻辑。
- 接入包不存在 CN 或隐式多镜像源；GitHub 完整资源未就绪时不创建升级 PR。
- 上游 mcpp-index 功能与跨平台测试继续通过；xim 接入不会改变 mcpp 的 latest 规则。

## 13. 本轮 review 需要确认的核心决策

1. 自动更新协议整体切换，无旧字段/CLI 兼容；未迁移的包明确人工维护。
2. 扩展能力统一进入上游工具，生产固定经过验证的最新提交。
3. xim 显式声明 upstream、latest 和资源矩阵；多架构新版本统一输出 Shape B。
4. 正常升级只追最新稳定版，历史补录独立；完整矩阵原子提交。
5. 本期只接入纯 GitHub、无 CN 的包；既有镜像生产独立，不由 updater 发布资源。
6. 每 3 天扫描、固定 plan、每轮最多 3 个 PR、内置 GITHUB_TOKEN 与显式 CI dispatch、候选版本 CI、人工合并。
