# xpkg CI 镜像与自动更新设计方案

> 编写日期: 2026-07-12 | 状态: 已实现，持续验证中 | 适用仓库: `openxlings/xim-pkgindex`

## 1. 摘要

本方案为 xpkg 增加一个独立的 `ci` 扩展字段，用于声明索引维护自动化意图。
`ci` 不属于 xpkg 安装规范，不参与运行时资源解析，不改变 `xpm` 的
`platform -> version` 模型。

仓库级策略统一放在 `.github/xpkg-ci.yml`，例如：

```yaml
version: 1
update:
  enabled: true
  interval: 3d
  wakeup_cron: "17 2 * * *"
  max_packages_per_run: 50
  request_budget: 500
```

`wakeup_cron` 只负责唤醒中央 workflow；`interval` 决定单个包的实际扫描间隔。
这样既可以每天运行一次轻量调度，又不会因为全局 cron 调整而把周期散落到数百个配方。
包配方只声明是否 opt-in，任何频率调整都只改这一份中央配置。

推荐的最小写法：

```lua
package = {
    name = "foo",
    repo = "https://github.com/acme/foo",

    ci = {
        mirror = true,
        update = true,
    },

    xpm = {
        source = "https://github.com/acme/foo/releases/download/${version}/foo-${os}-${arch}.${ext}",
        linux = {
            ["latest"] = { ref = "1.2.0" },
            ["1.2.0"] = {
                sha256 = {
                    x86_64 = "<sha256>",
                    aarch64 = "<sha256>",
                },
            },
        },
    },
}
```

字段语义：

| 字段 | 类型 | 默认值 | 含义 |
|---|---|---|---|
| `ci.mirror` | boolean | `false` | 校验已声明版本后，允许 CI 创建/同步 `xlings-res` 镜像 release |
| `ci.update` | boolean | `false` | 加入仓库统一的定期扫描，发现新版本后创建更新 PR |

扫描周期、cron、限流、重试和每次最多处理的包数量统一配置在仓库级
`.github/xpkg-ci.yml`，不写入单个包。初始中央策略建议 `interval: 3d`、每日唤醒一次
并按到期状态过滤；必要时只改中央配置即可调整全生态频率。不引入 `target`、`strategy`、
`submit` 等包级字段：当前唯一官方目标是 `xlings-res`，更新方式固定为 PR。

## 2. 规范边界

### 2.1 运行时规范与 CI 扩展分离

```text
package metadata + xpm  →  libxpkg  →  xlings install
package.ci              →  trusted GitHub Actions only
```

- libxpkg 可以读取并保留 `ci`，但不得执行 CI 行为。
- xlings 安装器忽略 `package.ci`，用户安装不会触发网络扫描、镜像发布或 PR。
- 普通第三方索引中的 `ci` 默认只作为元数据；只有官方 workflow allowlist 的仓库才执行。
- 旧客户端忽略未知的 `ci` 字段，不应因为 CI 扩展改变资源解析。
- `ci` 不覆盖显式 URL、`ref`、mirror、`source` 和 SHA256 的既有语义。

### 2.2 mirror 与 update 的职责

```text
ci.mirror = true
  → 当前已经声明的版本
  → 下载、完整性验证
  → 创建 xlings-res release

ci.update = true
  → 定期发现上游新版本
  → 创建 xpkg 更新 PR
  → PR 合并后才进入 mirror release 流程
```

两者独立：`mirror=true` 不会发现新版本；`update=true` 不会绕过 PR 直接修改
索引。若 `update` 和 `mirror` 同时启用，顺序必须是：

```text
发现版本 → 生成资源矩阵与 SHA256 → 创建 PR → PR CI → 合并 → 镜像 release
```

### 2.3 source 约束

- `ci.update` 只对包含 `${version}` 的 URL template 生效；固定 URL 无法可靠发现新版本。
- `source = "xlings-res"` 时 `ci.mirror = true` 是冲突配置，因为资源已经是官方镜像；
  CI 应 fail closed 并给出修复提示。
- 普通 URL 没有 `ci.mirror=true` 时，永远不自动复制到 xlings-res。
- 自动镜像不自动改变用户当前安装来源。创建 release 与修改 xpm 资源路由是两个动作；
  若需要让镜像进入安装候选，必须由 bot 创建单独索引 PR，使用已有 URL/mirror 表达并经过
  正常 review。这样不会让一次 CI 运行悄悄改变用户的下载来源。

## 3. 工具分层

不把所有逻辑堆进 `version-check.py`。工具分成可本地运行、可单元测试的命令：

### 3.1 `xpkg-ci inspect`

读取 `pkgs/**/*.lua`，输出规范化 JSON，不访问网络：

```json
{
  "package": "foo",
  "repo": "https://github.com/acme/foo",
  "source": "https://github.com/acme/foo/releases/download/${version}/foo-${os}-${arch}.${ext}",
  "mirror": true,
  "update": true,
  "platforms": ["linux", "macosx"],
  "architectures": ["x86_64", "aarch64"],
  "latest": "1.2.0"
}
```

职责：解析 `package.ci`、验证布尔类型、识别 source/template、检查平台和
架构矩阵。它不执行 release 或修改文件。

### 3.2 `xpkg-ci scan`

消费 `inspect` 输出并访问上游 API，生成扫描报告：

```json
{
  "status": "update-available",
  "package": "foo",
  "current": "1.2.0",
  "upstream": "1.3.0",
  "assets": [
    {
      "os": "linux",
      "arch": "x86_64",
      "url": "...",
      "status": "verified",
      "size": 12628937,
      "sha256": "..."
    }
  ]
}
```

职责：查询 release、展开模板、下载候选资产、计算 SHA256、读取 sidecar、验证归档和
生成完整矩阵。`scan` 只写报告和缓存，不修改配方、不创建 release。

### 3.3 `xpkg-ci mirror`

输入已经通过 `scan` 的 immutable manifest，执行镜像发布：

1. 检查每个平台/架构均为 `verified`。
2. 检查源 URL 为 HTTPS、无认证信息、无私有网段重定向。
3. 检查 release tag 尚不存在，或已有内容与 manifest 完全一致。
4. 创建 `xlings-res/<package>` 的版本 tag/release。
5. 上传归档、同名 `.sha256` 和 `manifest.json`。
6. 上传 GitHub RES 和 GitCode RES。
7. 从权威源、GitHub RES、GitCode RES 各下载并逐字节比较。
8. 写入不可变的镜像结果报告。

同一个版本如果 release 已存在且 hash 完全一致，返回幂等成功；任何内容冲突都失败，
禁止覆盖 release。

### 3.4 `xpkg-ci propose`

输入扫描报告或镜像 manifest，生成最小 xpkg PR：

- 只修改目标包文件；
- 保留已有版本块；
- 新版本写入完整平台/架构 SHA256；
- `latest.ref` 只在全部矩阵通过后更新；
- 不自动将普通 URL 改成 `xlings-res`，除非 PR 明确包含镜像路由变更；
- PR body 附带源 URL、release tag、资产大小、三方 hash 和报告链接。

### 3.5 `xpkg-ci verify`

在 PR 和发布前执行纯验证：

- xpkg Lua 结构和 `ci` 字段类型；
- URL template 占位符和唯一性；
- `ref` 目标和循环；
- 平台/架构完整性；
- SHA256 与 sidecar/manifest 一致；
- GitHub/GitCode release 资产一致；
- 生成的 xpkg 经 libxpkg fixture 解析后结果一致。

## 4. 数据和缓存设计

### 4.1 manifest

每个镜像 release 必须包含 `manifest.json`：

```json
{
  "format": 1,
  "package": "foo",
  "version": "1.2.0",
  "source_repo": "acme/foo",
  "assets": [
    {
      "os": "linux",
      "arch": "x86_64",
      "filename": "foo-1.2.0-linux-x86_64.tar.gz",
      "size": 12628937,
      "sha256": "...",
      "source_url": "..."
    }
  ]
}
```

manifest 是 release 和索引 PR 的共同输入，避免 release 脚本和索引脚本各自猜测文件名
或重新计算不同结果。

### 4.2 缓存

中央扫描 workflow 使用 GitHub Actions cache 或对象存储保存：

- `repo -> latest release tag/etag/checked_at`；
- `package/version/os/arch/source-url -> size/sha256`；
- `package -> next_scan_at`；
- 已创建 PR、release 和 manifest 的幂等键。

缓存只用于降低 API 和下载成本，不能作为发布完整性证据。manifest 和 release 资产才是
发布依据。

### 4.3 调度

不为每个包创建定时 workflow。使用一个每日中央扫描：

```text
每天 1 次 workflow
  → 读取所有 ci.update=true 的包
  → 使用中央 policy.interval 计算 next_scan_at
  → 仅处理 next_scan_at <= now 的包
  → 不为包单独配置周期
```

使用 `concurrency: xpkg-ci-scan` 保证同一仓库只有一个扫描器；单包使用
`concurrency: xpkg-update-<package>`，避免重复 PR。GitHub API 使用 ETag/If-None-Match、
指数退避和全局请求预算。

## 5. Workflow 设计

### 5.1 PR 校验

触发：配方、skill、CI 工具或 manifest 相关 PR。

权限：`contents: read`、不允许 release、不允许写 main。

步骤：

```text
checkout
  → xpkg-ci inspect
  → xpkg-ci verify --offline
  → 对 ci.mirror/update 包执行 scan dry-run
  → libxpkg fixture 解析
  → 上传报告
```

### 5.2 合并后的镜像流程

触发：main 合并、手动 workflow_dispatch。

```text
读取 package.ci.mirror=true 的已声明版本
  → scan 完整矩阵
  → verify
  → mirror GitHub release
  → mirror GitCode release
  → 三方复核
  → 输出 immutable manifest
```

发布 token 只存在于 protected environment；普通 PR 不可访问。

### 5.3 定时更新流程

触发：每天一次中央 scheduler。

```text
读取中央 policy.interval
  → 过滤 ci.update=true 且已到期的包
  → 到期包查询上游 release
  → scan 新版本
  → verify
  → xpkg-ci propose 创建/更新 PR
```

更新 PR 合并后由 5.2 流程发布镜像。已有同包同版本 PR 时只更新报告，不创建第二个 PR。

## 6. 安全和稳定性门禁

### 6.1 默认拒绝

以下任一条件存在时，扫描或发布必须失败：

- URL 不是 HTTPS，含 userinfo，或重定向到 localhost/私有网段；
- 未声明 `package.repo`，或 repo 不在受支持的 release provider；
- URL template 缺少 `${version}` 或生成重复 URL；
- 平台/架构缺失；
- 归档下载失败、大小异常、SHA256 缺失或 sidecar 不一致；
- release 已存在但 manifest/hash 不一致；
- 许可证/再分发政策不允许；
- 上游版本小于当前 `latest`，企图回退。

### 6.2 权限隔离

- PR workflow 只读；
- 扫描 workflow 只允许查询 API 和上传报告；
- mirror workflow 使用最小化 `xlings-res` 发布 token；
- 发布环境要求 protected branch/environment approval；
- `GITHUB_TOKEN` 不得获得任意仓库写权限；GitCode token 只允许目标 release 仓库。
- 更新 PR workflow 使用受保护的 `XPKG_BOT_TOKEN`；未配置时在发现更新后立即失败并给出
  明确配置提示，不使用默认 `GITHUB_TOKEN` 绕过仓库的 PR 创建策略。

### 6.3 可靠性

- 发布资产使用版本唯一文件名和 immutable tag，不覆盖既有版本；
- 每个步骤可重试且幂等；
- GitCode 单文件上传，失败指数退避；
- 半成功 release 记录状态并由 reconcile workflow 补齐，不自动删除已存在的正确资产；
- scanner、mirror、propose 三个阶段通过 manifest 传递，不依赖工作区临时文件；
- 失败只阻塞当前包，不阻塞其他到期包，但最终报告必须为红色并可追踪。

## 7. 与现有工具的迁移

| 现有内容 | 迁移动作 |
|---|---|
| `.github/scripts/version-check.py` | 拆出 inspect/scan/verify；保留兼容 CLI wrapper |
| `.github/workflows/version-check.yml` | 改为中央每日 scheduler + 到期包过滤 |
| `.github/workflows/version-bump.yml` | 改为 `propose`，只创建 PR，不直接承担发布 |
| `tools/mirror_res.sh` | 提取到 `xpkg-ci mirror`，增加 manifest、sidecar、三方复核和幂等检查 |
| `tools/publish_xim_index.sh` | 继续只负责 `xim-index` 工件，不处理软件包 release |
| `.agents/skills/xpkg-creater/SKILL.md` | 增加 `ci` 字段、镜像门禁和更新 PR 流程 |
| `README.md` | 增加普通 URL、自动镜像、自动更新最小范例 |
| `docs/V2/xpackage-spec.md` | 增加独立 CI 扩展章节，明确运行时忽略 `ci` |
| `docs/contributing.md` | 增加 release、权限和失败处理流程 |

旧配方不迁移、不自动镜像、不自动更新。只有明确添加 `package.ci` 的配方进入自动化。

## 8. 分阶段实施

### P0：规范和 dry-run

- 确定 `package.ci` schema；
- 实现 inspect/scan/verify；
- 中央每日 scheduler 只生成报告；
- 为 mcpp、xlings 和一个第三方 URL template 建 fixture。

### P1：镜像 release

- 实现 manifest/sidecar；
- 实现 GitHub/GitCode 幂等 release；
- 加入三方逐字节复核和 protected environment；
- 只对显式 `mirror=true` 的已声明版本启用。

### P2：自动更新 PR

- 实现 `ci.update=true` 和中央 `policy.interval` 到期调度；
- 实现新版本矩阵生成、hash 校验和 propose PR；
- 合并后串联 P1 mirror release；
- 增加 reconcile workflow 处理半成功状态。

## 9. 验收标准

1. 没有 `package.ci` 的普通包行为完全不变。
2. `mirror=true` 只镜像已声明版本，不会发现或升级版本。
3. `ci.update=true` 的包按中央策略统一扫描，初始策略最多每三天扫描一次，并且只创建 PR。
4. 新版本缺平台、架构、hash、sidecar 或归档校验失败时不会创建 release。
5. GitHub/GitCode/权威源三方 hash 不一致时发布失败且不可覆盖旧 release。
6. 重复执行 workflow 不会创建重复 release 或重复 PR。
7. xlings/libxpkg 安装路径不读取或执行 `package.ci`。
8. 旧 V1/V2 配方和旧客户端解析结果保持不变。

## 10. 实现状态与部署决策

- 正式写法已经确定为可选的 `package.ci = { mirror = true, update = true }`；
  两个开关彼此独立，未声明 `ci` 的包保持手工维护。
- 中央策略已经落地到 `.github/xpkg-ci.yml`：当前为 `3d`、每日唤醒，包文件不再散落
  `1d/3d/weekly` 等周期标注。
- 自动更新只创建 PR；PR 合并且 xpkg 测试成功后，受保护的
  `xlings-res-publish` 环境才允许生成不可覆盖的 GitHub/GitCode release。
- 首阶段 provider 仍限定 HTTPS 上游、GitHub Releases 与 GitCode 镜像；普通 URL 和用户
  自有 mirror 不会被隐式发布，必须显式 `mirror=true`。
- 许可证白名单暂不作为阻断条件，后续可在中央策略增加；当前以 HTTPS、完整平台矩阵、
  SHA256、sidecar、归档可读性和不可覆盖 release 作为发布门槛。

## 11. 已完成的真实验证

- `version-check` 与 `tools/xpkg_ci.py scan` 已验证中央策略、3 天状态节流和 `ci.update`
  opt-in；真实扫描发现 `uv 0.11.8 -> 0.11.28`，并已由自动 bump PR 合并。
- `xpkg test` 成功后，`xpkg-mirror-release` 的 post-merge 路径已在 GitHub Actions 成功运行；
  当前没有包声明 `mirror=true`，因此该次运行安全地无发布并完成 changed-package 审计。
- 发布链路仍可通过 `workflow_dispatch` 提交经过 `verify` 的 manifest；重复 GitHub release
  只接受完整同名资产，GitCode 创建幂等且上传带有限重试，不覆盖既有资产。
- 2026-07-13：一次真实的 per-package mirror run（fish/griddycode/nvim/pnpm 四个独立
  matrix job）全部成功；pnpm 三个约 40–50 MB 的 bundled-Node 资产在 GitCode 上传约 14 分钟
  后通过校验，验证了 §6.3 的单文件上传 + 指数退避 + ranged-GET 校验路径。四个包的资产均已
  在 GitHub RES 与 GitCode RES 上以 ranged GET 复核为可下载（206）。
- §3.3 的两处实现缺口已在 `tools/xpkg_ci.py` 补齐：
  - `ensure_mirror_repos`（也暴露为 `ensure-repo` 子命令）在发布前幂等地保证
    `xlings-res/<pkg>` 在 GitHub 与 GitCode 均存在且 `main` 非空——已存在的包只做只读探测，
    不产生写调用，也不需要建仓 token 权限；仅全新的 mirror 包会触发建仓并在 GitCode 播种
    README 以创建 `main`。这消除了「新增 mirror 包需先手工建两个仓库」的前置条件。
  - `verify_mirror_content` 把原先只做「对象存在」的 ranged-GET 探测升级为三方哈希复核：
    发布成功前从 GitHub RES 与 GitCode RES 实际下载每个归档资产并与 manifest（源自权威上游）
    的 sha256 逐一比对，任一不一致即 fail closed。可用 `--no-content-verify` 作为应急旁路。
