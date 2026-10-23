# ChatGPT 自动更新接入

ChatGPT 可以使用统一 `xpkgindex-update` 自动更新，无需 GitHub 镜像或私有脚本。
[工具 PR #4](https://github.com/openxlings/xpkgindex-update/pull/4) 增加通用 Sparkle RSS 解析，索引 PR 固定工具提交并接入现有三天更新任务。
合入顺序为工具 PR、索引 PR；索引不能先使用尚未支持的旧工具提交。

## 配方与策略

完整声明见 `pkgs/c/chatgpt.lua` 的 `extensions.autoupdate`：

- `source`：[官方 appcast](https://persistent.oaistatic.com/codex-app-prod/appcast.xml)。
- GLOBAL 必需，包含 Linux x86_64 DEB 与 macOS ARM64 ZIP 的固定 `${version}` 模板。
- 取所有必需平台都可下载的最新版本交集；不使用持续变化的 latest 下载链接。
- 默认 `latest = "advance"`，不增加 CN，不修改三天调度，不自动合并更新 PR。
- `platform_versions_diverge` 保留：历史手工收录的平台版本集可以不同；本次自动更新只推进共同版本，
  暂不提供各平台独立推进。若未来各平台长期使用不同版本号，需要另扩展明确的平台策略。

2026-10-23 实测：macOS 清单最新为 `26.1016.62342`，对应 Linux DEB 返回 404；
Linux Packages 的当前版本为 `26.1016.61520`，与配方两平台 latest 一致。
因此启用时应报告等待资源，不凭空添加不存在的共同新版本。

## 校验与保留边界

通用解析器读取数字 `shortVersionString`、build、完整 enclosure，排除 channel、预发布和嵌套 delta。
重复或等价版本、多 build/架构歧义、异常清单和资源错误显式失败。
至少一个必需资源必须匹配清单完整 enclosure URL 和长度；其余平台按版本模板完整下载校验。
404/410 才尝试更旧候选；网络、权限、格式或 hash 错误不伪装成镜像未同步。

固定计划绑定配方、基线、所选清单项元数据摘要、完整矩阵及资源 SHA256；
apply/propose 复核所选项及资源字节，不追随新发布版本。所选项消失/变化拒绝写入；
清单新增无关版本不影响原计划。元数据使用无 GitHub 凭据的公开 HTTPS 下载，限制 1 MiB 并共用预算。
元数据摘要包含 Sparkle 签名，但工具不做 Sparkle 密码学验签；macOS 安装继续检查包版本与 codesign。
Linux 保留包内 metadata.version 检查和现有隔离加载器/依赖检查。

旧的 Linux/macOS 版本块、helper、revision、依赖、hooks 及手工补录全部保留，
新版本写显式 URL/SHA256，不执行任意 Lua。生成的计划、网络证据和全量审计 JSON 只留本地或 Actions artifact。

## 复验

使用 workflow 固定的工具运行 `inspect --package xim:chatgpt`、
`check --package xim:chatgpt --output /tmp/chatgpt-plan.json`，检查等待原因和候选矩阵。
工具单测覆盖资源不齐等待/回退、共同版本推进、旧条目保留、计划绑定、清单安全、预算及 PR 重试。
本次元数据接入 PR 执行静态/隔离/注册及工具集成测试，未增加版本，不触发候选原生安装。
后续新增候选时 CI 执行 Linux/macOS 原生安装卸载；GUI 登录及交互需桌面环境另行验收。

其他包可复用 appcast + resources 模板，说明见 `docs/13-ci-mirror-and-update.md`、中文版和建包 skill。
GitHub 上游建议至少 50 stars 是选包建议，官方厂商清单没有 GitHub star 要求。
