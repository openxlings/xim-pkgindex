# xpkgindex-update 多模式统一设计

日期：2026-10-23。状态：方案待 review，以下新增字段不是当前可直接使用的 API。
目标：同一工具从简单 GitHub 包覆盖到官方软件源、平台独立发布、现成 CN 镜像和镜像生产；
每个包按自己的发布模型选择组合。xim 当前的启用范围与工具能力分别管理。

## 1. 当前支持情况与需要修正的边界

核对上游 main `6c0bee2941e36132bc2ac3d1f7edbef8b5790320` 及工具 PR #3：

| 能力 | 当前 main | PR #3 | 本方案 |
|---|---|---|---|
| 通用 HTTPS URL 模板、版本占位符 | 已有 | 保留 | 保留为最简资源声明 |
| 平台 URL、现成 GLOBAL/CN 双地址 | 已有 | 增加平台/架构矩阵 | 继续支持，镜像消费和生产分开 |
| 发现 GitHub Releases/tags | 已有 | 显式 upstream | 作为 discovery provider 之一 |
| xim latest 前移/保持、完整架构原子追加 | 未完整实现 | 已实现 | 归入统一 policy/adapter |
| JSON、appcast、APT、手工指定版本 | 未实现完整流程 | 未实现 | 注册式 discovery providers |
| 平台独立候选版本/latest | 不支持 | 不支持 | 显式 platform_policy |
| 下载并验证已存在的 CN 镜像 | 已有基础能力 | 完整架构/sidecar 校验 | 与 discovery 任意组合 |
| 在统一工具中上传/发布 CN 镜像 | 不支持 | 不支持 | 独立 publisher 阶段 |

GitHub-only 是 xim 本轮的 rollout policy，不是 URL 模板或工具的普遍限制。
工具已有双地址消费能力，不应表述为“完全不支持 CN”；尚缺的是通用版本发现、
平台独立策略以及统一工具中的镜像生产等能力。

## 2. 用组合覆盖场景，避免一个巨大的 mode 开关

包内仍只有 `extensions.autoupdate` 一个入口，分为五个正交部分：

| 部分 | 负责 | 不能替代 |
|---|---|---|
| discovery | 找到候选版本及来源证据，可提供真实资源 URL/hash | 资源模板不能自己发现版本 |
| url / resources | 用模板或 discovery 返回的资产定位资源 | 镜像位置不能充当版本权威源 |
| verify | 下载 hash、上游 checksum、sidecar 或签名核验 | 不能把仅计算本地 hash 宣称为上游签名验证 |
| platform_policy / latest | 同版联动或平台独立；前移或保持 latest | 上游缺资产不能自动缩小支持矩阵 |
| mirrors | 消费现成镜像，或显式生产镜像 | 上传成功不能替代镜像下载复核 |

最简包只写现有 upstream/tag/latest/url；复杂包才声明 discovery、平台策略和镜像生产。
所有模式最终进入同一个 plan、资源验证器、adapter 编辑器和 PR/CI 流程，不增加第二套扫描器。

## 3. 简单场景：保留短声明

GitHub 发布与固定资源命名直接使用现有原生写法：

```lua
autoupdate = {
    upstream = "acme/foo",
    tag = "v${version}",
    latest = "advance",
    url = "https://github.com/acme/foo/archive/refs/tags/${tag}.tar.gz",
}
```

内部将 upstream/tag 规范化为 GitHub discovery。平台 URL、平台 → 架构 URL、
现成 GLOBAL/CN 双地址继续可用，不要求每个包填写大型 provider 对象。
这是统一声明的短写，不恢复旧 ci.update、url_template 或旧 CLI 兼容层。

高级写法使用 `discovery = { type = ... }`，与短写的 upstream/tag 互斥；
两者同时出现报错，避免隐含覆盖顺序。已有 mcpp 的短写和 adapter 规则继续验证。

## 4. 版本发现模式

| provider | 输入 | 输出/权威绑定 | 实现重点 |
|---|---|---|---|
| github | repo、releases/tags 策略、tag 模板、channel | version、tag、commit、assets | 保留当前稳定版过滤及去歧义规则 |
| json | HTTPS feed、有限 JSON Pointer 字段映射 | version、选中项及文档摘要，可带 URL/hash | 不执行 jq、JS、Lua 或 shell |
| appcast | HTTPS Sparkle feed、平台筛选、版本字段策略 | version、enclosure、长度/签名等元数据 | 区分内部 build 与展示版本，只选完整适配归档 |
| apt | 仓库、suite、component、包名、架构、信任 key | package version、Filename、SHA256、签名索引证据 | 验证 Release/InRelease → Packages → 资源的链路 |
| manual | 命令显式指定版本，配方声明资源映射 | 人工请求身份、版本及已验证资产 | 无显式版本的定时运行返回 manual-required |

JSON 类型可供大量普通厂商使用，避免每个域名新增专用 provider；有稳定协议的
APT/appcast 使用正式实现，不要求包作者用正则重新实现协议。
其他平台如 GitLab/GitCode 的发布 API 可以增加注册 provider，不改变 plan/编辑器。
自定义协议通过受维护工具代码扩展，不执行包配方中的任意更新脚本。

示例：JSON 中提供版本、资源仍按通用模板命名：

```lua
autoupdate = {
    discovery = {
        type = "json",
        url = "https://vendor.example/releases.json",
        items = "/releases",
        version = "/version",
    },
    latest = "advance",
    url = "https://vendor.example/downloads/foo-${version}.tar.gz",
}
```

这里只是拟定接口，example 域名不是真实服务。字段映射只从数据中提取值；
排序、channel、版本映射使用声明式、可测试规则。Debian version 使用 Debian 排序，
不能直接套 SemVer；源版本与索引版本不相同时必须显式映射。映射碰撞报错，
不能用相同索引版本静默替换已发布资源。

manual 模式拟增加 `check --package ... --version ...`，必要时限定 platform。
当前 CLI 没有这一能力，不能把现在的 apply 当作任意版本发现的替代品。

## 5. 资源模式：模板与 feed 返回资产均可选择

- `url = "https://.../${version}/..."`：固定命名，模板展开。
- 现有平台/架构 URL 矩阵：逐目标显式映射。
- 拟新增 `url = { from = "discovery.asset" }` 资源叶子：文件名或签名 URL 无法稳定推导时，
  使用 provider 返回的选中资产；仍须绑定平台、架构、hash 和来源。
- 现成 `{ GLOBAL = "...", CN = "..." }`：验证两份实际字节，全部满足才 ready。

资源选择只允许明确且唯一的目标。未知架构、多个匹配资产、缺失平台或区域都不猜测。
模板和 feed URL 都进入同一个 HTTPS 下载器、重试/字节预算、归档检查和摘要验证流程。

## 6. 平台策略与 ChatGPT

默认 `platform_policy = "atomic"` 保持当前语义：所有目标平台同一个候选版本，
完整平台/架构矩阵一起追加。增加 `platform_policy = "independent"` 才允许平台独立发布。

independent 下每个平台是一个原子组：平台内架构必须齐全，latest 只与本平台历史比较。
一个平台缺资源不会阻止其他已就绪平台形成提案，也不会让该平台假装升级成功。
每包仍只保留一个开放更新 PR，在该 PR 中列出每个原子组的独立结果。
默认 latest 字符串作用于所有组，高级场景可显式按平台覆盖；禁止平台策略隐式切换。

ChatGPT 的目标模型示意：

```lua
autoupdate = {
    platform_policy = "independent",
    latest = "advance",
    discovery = {
        linux = {
            type = "apt",
            -- repository/suite/component/key 必须先从官方源核实，不能猜 URL
            package = "chatgpt",
            arch = "amd64",
        },
        macosx = {
            type = "appcast",
            url = "https://persistent.oaistatic.com/codex-app-prod/appcast.xml",
        },
    },
    url = {
        linux = { x86_64 = { from = "discovery.asset" } },
        macosx = { aarch64 = { from = "discovery.asset" } },
    },
}
```

该片段有意未补齐尚未核实的 Linux 仓库信息，不能直接投入生产。
只覆盖配方现有 Linux x86_64、macOS ARM64，不因为上游有资源就自动添加其他平台。
现有 deb()/mac() 等表达式需适配静态分析边界，不能为发现版本而执行 Lua。
实现时保留历史块；平台候选、资源选择和 latest 变更由新 plan 清晰表达。

## 7. CN mirror 分两种模式

### 7.1 consume：使用已经发布的镜像

GitHub 发现版本，包内 url 声明 GLOBAL/CN，工具下载并验证一致性。
此能力已有；平台/架构矩阵和 sidecar 支持在 PR #3 中补齐。
CN 尚未就绪返回 waiting-assets；不把镜像伪装为版本发现源，不写入不可用 CN 地址。

### 7.2 publish：先生产镜像，再生成 ready plan

为有需求的包增加显式 mirrors 配置，拟定形式：

```lua
mirrors = {
    mode = "publish",
    required = { "GLOBAL", "CN" },
    targets = {
        GLOBAL = { type = "github", repo = "xlings-res/foo" },
        CN = { type = "gitcode", repo = "xlings-res/foo" },
    },
}
```

原始资源来自 discovery/url；publisher 接收已冻结的候选和 hash，复制相同字节，
发布对应 sidecar，再从目标区域下载比对。已有同名同 hash 资产可幂等复用；
同名不同 hash 拒绝覆盖。发布能力默认关闭，包作者显式选择，凭据由仓库工作流提供。

统一工具持有可注册 publisher，xim 不维护另一套版本发现或配方编辑器。
scan、镜像写入、PR 写入分别使用对应权限；PR 安装测试不获得镜像发布凭据。
仅校验现成 CN 地址与向 GitCode 上传资源不能混成一个含糊的 mirror=true 开关。

## 8. 通用内部模型与 plan

目前 plan 的 repo/tag/upstream_commit 是 GitHub 特有模型。下一版应使用：

- Declaration：解析并规范化包的模式组合，不执行 Lua。
- CandidateGroup：一个 atomic 组，或 independent 的单个平台组。
- AuthorityEvidence：provider 类型、选中版本/项、来源快照和内容身份。
- Resource：platform/arch/region、固定 URL、大小、hash、校验结果。
- MirrorReceipt：选定来源 hash、发布目标、目标资产身份和复核结果。
- Adapter：把已验证 CandidateGroup 追加到具体索引，保护历史/latest/hooks。

GitHub evidence 绑定 tag/commit；APT evidence 绑定签名索引和包 checksum；
appcast/JSON evidence 绑定选中项及资源身份。不能为厂商源虚构 GitHub repo 或 commit。
复核选中候选不重新挑最新版；feed 增加其他版本不应改变本次选中候选。

新结构使用明确的新 plan format（拟 format 3），执行器拒绝未知格式。
同一代短写/高级声明规范化后只走一个执行流程，不双写计划。

```text
无镜像生产：check → ready plan → propose → candidate CI
有镜像生产：check → candidate plan → publish --plan → verify → ready plan → propose
```

candidate/ready plan 明确 stage。镜像阶段只补充绑定原始候选的回执，记录 parent digest，
不能重新发现版本或更换资源。propose 仅接受 ready，复核来源、资源和配方后原子写入。
新增镜像不改历史版本；修改已发布版本仍走独立人工 revision 流程。

## 9. 每包选择，仓库控制上线范围

包作者选择 discovery、资源、校验、平台和镜像模式。仓库配置只负责预算、凭据映射和
已准入 capability，不在工具代码中硬编码“所有源都必须 GitHub”。

xim 当前 24 个 GitHub 包是首批 rollout，不代表工具只支持这一类。
后续把临时 github_only 筛选改为声明式 capability policy：先开放 GitHub，再逐包开放
JSON/appcast/APT、独立平台、现成镜像及 publisher。模式已实现但仓库未启用时报告
policy-disabled；模式未实现时报告 unsupported-provider，不能静默降级为 GitHub。

检查/更新周期属于仓库调度，与单包模式正交。目前实际扫描/提案每 3 天执行一次。
包不能靠选择 provider 绕过统一预算、固定 plan、历史保护或人工合并。

## 10. 分阶段实现与验收

1. 抽出共享 HTTP transport、discovery registry、AuthorityEvidence 和规范化声明；
   GitHub 行为及 mcpp/xim 当前测试保持通过。增加 manual 和 JSON，让通用模板可用于非 GitHub 源。
2. 增加 appcast/APT、provider 对应版本排序/证据复核和 independent CandidateGroup；
   核实 ChatGPT 官方源后接入，完成两平台真实安装和运行验收。
3. 整理现成 GLOBAL/CN 消费、sidecar 和 capability policy，受控接入代表性包。
4. 增加 GitHub/GitCode publisher、candidate → ready plan 回执链和失败恢复；
   只有实际镜像发布/下载复核通过后才启用对应包。

每阶段在同一上游工具实现，独立 review/CI；本方案不宣称新模式已完成。
必须覆盖：最简包、模板/动态资产、签名与hash冲突、feed刷新但选中项不变、平台独立缺资源、
镜像已存在/缺失/冲突、推分支后建PR恢复、各来源预算和跨模式历史保护。

## 11. 协议参考

- [Sparkle appcast 发布格式与签名](https://sparkle-project.org/documentation/publishing/)：
  需区分内部版本和展示版本，处理 enclosure 和签名元数据；不能把任意 RSS 当成安装资源。
- [Debian apt-secure](https://manpages.debian.org/trixie/apt/apt-secure.8.en.html)：
  仓库签名、索引 checksum 与包 checksum 属于同一验证链，不能仅抓取网页中的版本字符串。
- [工具 PR #3](https://github.com/openxlings/xpkgindex-update/pull/3)
- [xim 接入 PR #1027](https://github.com/openxlings/xim-pkgindex/pull/1027)
