# 文档索引

贡献者入口：[贡献指南](contributing.md) · [XPackage V2 规范](V2/xpackage-spec.md) ·
[索引分发设计](design/index-distribution.md) · [CI 镜像与自动更新设计](../.agents/docs/2026-07-12-xpkg-ci-mirror-update-design.md)

## 包规范

| 文档 | 说明 |
|------|------|
| [V2/xpackage-spec.md](V2/xpackage-spec.md) | **当前规范** - XPackage Spec V2（多架构、`xpm.source`、per-arch SHA256） |
| [V1/xpackage-spec.md](V1/xpackage-spec.md) | 兼容规范 - XPackage Spec V1 (`spec = "1"`) |
| [V1/add-xpackage.md](V1/add-xpackage.md) | 如何添加包到索引仓库 (V1) |
| [V0/xpackage-spec.md](V0/xpackage-spec.md) | ~~已废弃~~ - V0 规范 |
| [V0/add-xpackage.md](V0/add-xpackage.md) | ~~已废弃~~ - V0 添加流程 |

## 索引机制

| 文档 | 说明 |
|------|------|
| [design/index-distribution.md](design/index-distribution.md) | **索引机制** - 三层模型、命名空间解析、索引即资源(Y-asset)分发与镜像、发版协同（同步自 xlings v0.4.55 源码） |

## 测试

| 文档 | 说明 |
|------|------|
| [test/usage.md](test/usage.md) | 测试使用指南 |
| [test/design.md](test/design.md) | 测试框架设计文档 |
| [test/ci.md](test/ci.md) | CI Workflow 说明 |

## 其他

| 文档 | 说明 |
|------|------|
| [spec/url-template.md](spec/url-template.md) | URL 模板自动版本更新规范 |
| [migrations/](migrations/) | API 迁移文档 |

## Agent 工作文档

| 文档 | 说明 |
|------|------|
| [xpkg CI 镜像与自动更新设计](../.agents/docs/2026-07-12-xpkg-ci-mirror-update-design.md) | `package.ci`、中央调度、镜像 release、自动更新 PR 和安全门禁 |
