# xpkgindex-update：来源 URL 与必需资源模型

日期：2026-10-23。状态：已在工具 PR #3 实现，索引 PR #1027 接入；以 PR 的当前提交和 CI 为验收依据。
本文取代此前 upstream/tag/latest/url 与五层 discovery/mirrors DSL 提案。新增模式只扩展内部解析器，不要求简单包承担复杂配置。

## 1. 唯一公开模型

```lua
extensions = {
    autoupdate = {
        source = "https://github.com/owner/project/releases",
        resources = {
            GLOBAL = "https://github.com/owner/project/releases/download/${tag}/app-${version}.zip",
        },
    },
}
```

`source` 是版本目录/元数据的地址，`resources` 是资源 URL 模板。下载地址不能独自发现版本。
默认 `latest = "advance"`，每个资源目标默认 `required = true`。
`${tag}` 保留原始标签，`${version}` 是提取后的索引版本；普通数字/v 前缀无需配置。
特殊标签可显式声明 `tag = "release-${version}"`，无需引入第二套版本发现结构。

```lua
autoupdate = {
    source = "https://github.com/owner/project/releases",
    resources = {
        GLOBAL = {
            required = true,
            url = { linux = { x86_64 = "https://github.com/owner/project/releases/download/${tag}/app-linux-x64.tar.gz" } },
        },
        CN = {
            required = true,
            url = { linux = { x86_64 = "https://已核实镜像路径/${tag}/app-linux-x64.tar.gz" } },
        },
    },
}
```

所有目标使用相同的平台/架构矩阵；字符串是只有 url、required 默认为 true 的简写。
当前实现 GLOBAL/CN 两个运行时区域，不引入 mirrors、availability 或任意脚本执行接口。
工具与索引均允许包经 review 显式设置 `required = false`；本轮所有接入且审核过的目标均默认配置 true。
必需性的变更直接 review 配方声明，不能省略至少一个必需目标的约束。
只有 GLOBAL 的包保留 GLOBAL；存在合适 CN 镜像的包同时要求 GLOBAL 和 CN。
没有任一必需目标的配置无效。

新建包通过建包文档、`docs/specs/xpackage-template.lua` 和 xpkg-creater skill 的固定模板接入。
建议上游 GitHub 仓库至少有 50 stars；该建议不构成工具/CI 硬门槛，不影响已有包继续更新。
star 数不能替代来源、完整资源、hash 和原生安装验证。

## 2. 候选版本是必需目标的真实交集

按版本降序检查，选择严格高于所有已有版本、所有必需目标完整可用的第一个候选。
例如 GLOBAL 支持 1.5/1.3、CN 支持 1.4/1.3，结果是 1.3，而非两个最大值的较小值 1.4。

- 404/410，或 CN 下载最终回到 GitHub/已验证的 GLOBAL 下载主机，属于已知资源未就绪，可继续检查较早候选。
- DNS、超时、403、429、服务器异常等不等于版本不存在；必需目标遇到这些错误停止该包选择。
- 必需资源必须完整下载并计算 SHA256；不同区域同一平台/架构必须字节一致。
- 可选目标缺资源、网络失败或与必需目标字节不同，则整体省略该目标并记录原因。
- 预算耗尽返回 budget-deferred，不能凭部分扫描宣布“已是最新”。候选回溯受统一请求/下载预算约束，资源 404、重试与 sidecar 请求都计入预算。
- 全部必需目标未就绪则等待，不回退 latest、不生成半个平台的版本。

“完整”按该目标声明的每个平台/架构检查。CN 某一格失败不能留下部分 CN 地址。
`required` 是发布准入约束，不是强制用户安装时选择该区域。

## 3. 来源识别与模板

当前内置识别 GitHub `/releases` 和 `/tags` 地址；GitHub 不是声明结构中的特殊字段。
资源模板支持公开 HTTPS，域名不必与 source 相同。未知来源明确返回 unsupported-source，
不猜测页面格式，也不把下载 URL 当作版本目录。JSON/appcast/APT 等解析器仍未实现，不宣称 ChatGPT 已接入。

已有 compact、dash/underscore 标签转换继续可用。新增 `${version:base}` / `${version:build}`
处理 `25.0.4+7` 的 `25.0.4_7` 文件名；xim 将数字构建号作为索引版本身份和排序的一部分。
同一版本对应多个等价标签时拒绝歧义。非数字构建元数据不推断发布先后。

## 4. 历史版本与固定计划

check 生成固定 plan，apply/propose 只消费该计划，再次验证源码基线、配置摘要、标签 commit 与每份资源。
持久化最终下载主机以识别跨区回退，不保存临时签名下载 URL，避免重下载时签名改变导致假冲突。
候选 PR 的 verify 只验证 diff 中新增的版本，不再次发现未来版本。

编辑仅插入一个新增版本并按策略推进 latest。已存在条目的字节、相对顺序、注释、手工 helper、hash、
依赖和 hooks 由 guard 保护。若较新手工版本增加了架构，新声明必须包含它，不能按较老 latest 缩减。
历史平台版本集合可以不同，新版本必须原子覆盖所有已声明平台。

默认不补写旧版本的 CN，也不回填当前 latest 的镜像；需要补镜像时走独立 revision/人工审核。
Node 当前 latest 是 LTS 指针，显式配置 keep，只新增后续版本，不把 LTS 变成数值最高的 Current。

## 5. 镜像接入与 xlings-res

全量清单由 CI 从当前包声明生成 `coverage.json` 并上传 artifact；不再提交重复包声明的 JSON 快照。
初始逐包/镜像调研原始数据保留本地，长期维护规则与结论写入文档。镜像站目录不等于完整二进制覆盖。
新增站点及常用包迁移建议见 [机构镜像调研](2026-10-23-autoupdate-institutional-mirrors.md)：
使用 xlings-res 不妨碍后续版本改用更新的可信原版镜像；版本发现也应指向真实上游。
重打包/拆分包先验证布局与安装契约，历史条目保留。

- USTC 的 uv、Temurin 25 已核实项目目录。新版本采用 CN 模板，历史 GitCode/单 GLOBAL 条目保持原样。
- Node 与 rustup 采用官方 GLOBAL、USTC CN；Go 使用官方 GLOBAL、南京大学 CN；Gradle 使用官方 GLOBAL、腾讯 CN。每个包的两边都必须完整且一致。
- 清华 LLVM 发布镜像主要提供源码，不能代替本索引 llvm-tools/llvm-dev 的重打包二进制。
- xlings-res 自建/分包资源继续使用已有 GitHub/GitCode 双腿；以资源仓库的发布版本作为 source，
  不把上游原版 archive 冒充自建包。资源服务 macOS 的 arm64 文件名与 aarch64 键分别处理。
- xlings-res 目标还要求同名 .sha256 sidecar；任一腿或 sidecar 缺失都不能生成版本。
- 已有镜像的历史缺失、最新版本保留策略、网络异常均在审计/验证中分别记录，不能据此改写历史。

镜像目录依据：
[USTC GitHub Release](https://mirrors.ustc.edu.cn/help/github-release.html)、
[清华 GitHub Release](https://mirrors.tuna.tsinghua.edu.cn/help/github-release/)、
[USTC Node](https://mirrors.ustc.edu.cn/help/node.html)、
[USTC Rust](https://mirrors.ustc.edu.cn/help/rust-static.html)。
USTC 的部分项目仅保留最新版本，不能用“历史版本已清理”推断模板无效；每次必须验证具体候选。

## 6. CI 与后续边界

保留每 3 个 UTC 日一次的扫描周期（2026-10-23 锚点），每日轻量门禁；人工/PR 验证不受日期限制。
一次扫描生成同一份 plan，提案阶段不重新发现。每包独立 draft PR，经资源验证与相应平台真实安装、验证、卸载后 review。
资源生产、GitCode 上传、回补历史、平台独立版本、额外来源解析器是后续扩展，不混入当前实现。

`.agents/docs/2026-10-22-autoupdate-evidence/` 不进入 PR 差异。运行产物保留于 Actions artifacts 和本地临时目录。
