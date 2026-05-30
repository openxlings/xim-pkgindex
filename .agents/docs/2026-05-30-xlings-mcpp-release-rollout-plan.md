# xim-pkgindex: xlings mcpp Build Rollout Plan

> 状态: in progress
> 分支: `codex/xlings-mcpp-release-rollout`
> 目标: 在 xlings 合入并发布使用官方 mcpp-index 的新版本后，更新 xim-pkgindex 和 xlings-res，使用户可以通过现有包索引安装到打通后的版本。

## 前置条件

- [x] mcpp core PR 合入。
- [x] mcpp `0.0.35` 发布完成。
- [x] mcpp-index 官方依赖包 PR 合入。
- [ ] xlings 迁移 PR 合入。
- [ ] xlings 新版本 GitHub Release / GitCode Release 资产发布完成。

## xim-pkgindex 待办

- [x] 更新 `pkgs/m/mcpp.lua` 到 `0.0.35`,供 xlings CI bootstrap 使用。
- [x] 镜像 `mcpp 0.0.35` 三平台资产到 `xlings-res/mcpp`。
- [x] 本地 smoke test: `local:mcpp@0.0.35` 安装后 `xlings use mcpp@0.0.35`,
  `mcpp --version` = `0.0.35`。
- [ ] 更新 `pkgs/x/xlings.lua` 到新版本。
- [ ] 刷新 `XLINGS_RES` 镜像资产。
- [ ] 确认 Linux/macOS/Windows 三平台 URL、sha256、文件大小。
- [ ] 更新 CI bootstrap 版本变量。
- [ ] 本地 smoke test: `local:xlings@<version>`。
- [ ] 创建 PR 并等待 CI。

## 验证命令

```bash
xim search xlings
xim install local:xlings@<version> -y
xlings --version
```

## Checkpoints

- [ ] 文档 checkpoint commit。
- [x] `mcpp 0.0.35` release 资产确认并镜像。
- [ ] 等 xlings release 资产确认。
- [ ] 更新 package descriptor。
- [ ] 更新 xlings-res 镜像。
- [ ] PR draft 创建。
- [ ] CI 每 120s 检查一次直到完成。
