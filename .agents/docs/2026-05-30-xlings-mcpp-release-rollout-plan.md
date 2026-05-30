# xim-pkgindex: xlings mcpp Build Rollout Plan

> 状态: complete
> 分支: `codex/xlings-mcpp-release-rollout`
> 目标: 在 xlings 合入并发布使用官方 mcpp-index 的新版本后，更新 xim-pkgindex 和 xlings-res，使用户可以通过现有包索引安装到打通后的版本。

## 前置条件

- [x] mcpp core PR 合入。
- [x] mcpp `0.0.35` 发布完成。
- [x] mcpp-index 官方依赖包 PR 合入。
- [x] xlings 迁移 PR 合入。
- [x] xlings 新版本 GitHub Release / xlings-res 资产发布完成。

## xim-pkgindex 待办

- [x] 更新 `pkgs/m/mcpp.lua` 到 `0.0.35`,供 xlings CI bootstrap 使用。
- [x] 镜像 `mcpp 0.0.35` 三平台资产到 `xlings-res/mcpp`。
- [x] 本地 smoke test: `local:mcpp@0.0.35` 安装后 `xlings use mcpp@0.0.35`,
  `mcpp --version` = `0.0.35`。
- [x] 更新 `pkgs/x/xlings.lua` 到新版本。
- [x] 刷新 `XLINGS_RES` 镜像资产。
- [x] 确认 Linux/macOS/Windows 三平台 URL、sha256、文件大小。
- [x] 更新 CI bootstrap 版本变量。
- [x] 本地 smoke test: `local:xlings@<version>`。
- [x] 创建 PR 并等待 CI。

## 验证命令

```bash
xim search xlings
xim install local:xlings@<version> -y
xlings --version
```

## Checkpoints

- [x] 文档 checkpoint commit。
- [x] `mcpp 0.0.35` release 资产确认并镜像。
- [x] 等 xlings release 资产确认。
- [x] 更新 package descriptor。
- [x] 更新 xlings-res 镜像。
- [x] PR 创建。
- [x] CI 每 120s 检查一次直到完成。

## Final Outcome

- mcpp package update PR: https://github.com/openxlings/xim-pkgindex/pull/259
- xlings package update PR: https://github.com/openxlings/xim-pkgindex/pull/260
- mcpp mirror: https://github.com/xlings-res/mcpp/releases/tag/0.0.35
- xlings mirror: https://github.com/xlings-res/xlings/releases/tag/0.4.46
- xlings release source: https://github.com/openxlings/xlings/releases/tag/v0.4.46
- Final package index commit: `66f8674817a859bc66392ed871485775113762fa`
- CI evidence:
  - PR #260 `pkgindex test`: Linux, macOS install, Windows, Linux install all success.
  - PR #260 `xpkg test`: static/isolation and index-registration success.

## Follow-up: mcpp 0.0.36

Final xlings verification found that older mixed `~/.mcpp/registry/data` caches
could contain xlings index clones but miss the default `mcpplibs` clone. mcpp
`0.0.35` treated that state as fresh and skipped the default-index refresh.

- mcpp PR #89 fixed default `mcpplibs` freshness and was released as `0.0.36`.
- `xlings-res/mcpp` mirrors were published for `0.0.36` on GitHub and GitCode.
- `pkgs/m/mcpp.lua` now points `latest` to `0.0.36` so xlings CI can use the
  corrected bootstrap tool.
