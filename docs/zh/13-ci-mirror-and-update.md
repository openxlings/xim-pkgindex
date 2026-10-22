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

默认 `latest = "advance"`，每个目标默认 `required = true`；`latest = "keep"` 保留既有指针。
复杂目标可写 `{ required = true, url = { linux = { x86_64 = "..." } } }`。
版本来源当前识别 GitHub releases/tags 地址，下载模板可使用任意公开 HTTPS。
候选从新到旧检查，取所有必需目标完整平台/架构资源的真实版本交集，并下载校验字节一致。
工具支持可选目标；本索引对接入且审核过的 GLOBAL/CN 统一要求必需。
只有 GLOBAL 的包保留单资源。已有 xlings-res 双腿继续消费，合适的大学镜像经项目路径与产物核实后采用。
CN 跳回 GitHub 不算镜像就绪。只新增候选，保留历史资源、手工条目、注释与 hooks。

实际扫描/提案每 3 天执行一次，时间为 02:17 UTC / 11:17 JST。每日轻量调度按 UTC 日期门禁，
以 2026-10-23 为锚点（10 月 23/26/29 日、11 月 1 日等），非到期日跳过扫描/提案，跨月和跨年保持等间隔。
PR 检查和人工触发不受该门禁限制。到期运行扫描一次，propose 消费同一份固定 plan，不重新发现版本。配方、base、tag commit
或资源字节变化会拒绝应用。更新不执行 Lua、不改写历史版本、不自动修复冲突、不构建载荷、不自动合并。
候选版本必须通过相应 runner 上的真实安装、功能验证和卸载。

中央策略位于 `.github/xpkgindex-update.yml`；预算和轮转游标约束扫描，不用多天节流掩盖失败。
正常升级只追最新稳定版，历史补录独立处理且尚未启用。工具安装后可以运行：

```sh
xpkgindex-update inspect
xpkgindex-update check --package xim:foo --output plan.json
xpkgindex-update apply --plan plan.json --package xim:foo
```

`propose --plan plan.json` 使用有写权限的凭据创建每包 PR；已有人工包 PR 同样阻止重复提案。
推分支成功但建 PR 失败可以恢复，不覆盖不一致的分支。

## 镜像发布

`ci = { mirror = true }` 继续独立控制已声明资源的镜像发布。
`tools/xpkg_ci.py` 仅保留 `inspect`、`materialize`、`verify`、`ensure-repo`、`mirror`。
镜像发布不能成为同一个更新 PR 合并后才可满足的资源前置条件。
自建/重打包载荷由独立工作流生产，updater 只消费已就绪资源；已发布资源变更仍走人工 revision 流程。

旧自动更新字段和工作流已移除，不提供旧协议回退。迁移 PR 记录全量包清单和每项准入判断。
