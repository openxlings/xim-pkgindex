# ChatGPT 自动更新评估

> 2026-10-23 更新：本文旧的 upstream/url 和 GitHub-only 描述已被 [source/resources 当前设计](2026-10-23-xpkgindex-update-multi-mode-design.md) 取代；以当前设计、覆盖审计和 PR 最新提交为准。

## 现有声明来自哪里

`extensions.autoupdate`、tag/version 占位符及平台 URL 映射原本已由
`xpkgindex-update` 提供。显式 `upstream`、`latest = "advance"/"keep"`、
平台内架构矩阵和 xim format-2 plan 是本轮在上游 PR #3 中增加的能力。

当前上游 main 仍为 `6c0bee2941e36132bc2ac3d1f7edbef8b5790320`，只接受
`{tag, url}`；xim PR #1027 固定使用扩展提交。不是 xim 私有更新脚本，
但在工具 PR 合入前，也不能称为已发布 main 的既有能力。

## 通用 URL 模板与版本发现

通用 URL 模板支持任意合规 HTTPS 下载源，不限定 GitHub 域名。例如已知版本
`26.1016.61520` 时，现有展开函数可以直接处理：

```text
https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_amd64.deb
https://persistent.oaistatic.com/codex-app-prod/ChatGPT-darwin-arm64-${version}.zip
```

`${version}` 是模板输入；模板不会发现最新版本。当前 main 和 PR #3 都通过
GitHub Releases/tags 发现候选，并绑定上游 tag commit；CLI 也没有可直接替代
发现流程的通用 `--version` 参数。尚无 Debian/appcast/feed provider。

GitHub-only 是 xim 本期准入策略，不是工具 HTTPS 下载器的域名能力限制。

## ChatGPT 能否接入

技术上可以扩展支持；当前 GitHub-only 范围不包含它：

- `pkgs/c/chatgpt.lua` 使用 OpenAI 官方 `persistent.oaistatic.com` 资源，
  没有可用于当前准入的 GitHub upstream/star 数据。
- 配方通过 `deb()` / `mac()` helper 生成资源，需要适配静态分析/编辑边界，
  不能运行任意 Lua 来完成版本发现。
- Linux 与 macOS 允许独立发布，配方显式声明 `platform_versions_diverge`；
  当前“全部平台同一 candidate 一起推进”的策略不能直接套用。

若批准官方源例外，应在统一工具上游实现正式 provider：Linux 从官方软件源
元数据发现固定版本 URL/SHA256，macOS 从官方 appcast 发现资源并校验下载；
平台候选和 latest 独立，保留全部历史块，并跑现有安装、签名/版本和运行测试。
具体 feed、校验链和资源形态须另行验证，不能仅猜版本号拼 URL。
本轮未自动放宽 GitHub-only，也未添加不可执行的 ChatGPT 自动更新声明。

## 通用能力方向

后续采用 [多模式统一设计](2026-10-23-xpkgindex-update-multi-mode-design.md)，
让每个包选择版本发现、资源、校验、平台与镜像策略。GitHub-only 只属于首批仓库启用策略；
通用工具覆盖官方源、现成 CN 镜像以及未来的镜像发布能力，不为 ChatGPT 发明私有更新脚本。

## 调度调整

扫描/提案每 3 天运行一次。GitHub Actions 每日 02:17 UTC 检查轻量门禁，
按 2026-10-23 UTC 起始日期计算三天周期；不使用月末不等间隔的 `*/3` 日期 cron。
非到期日跳过更新任务，PR 检查和人工触发正常运行。
