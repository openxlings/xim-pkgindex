# Luban 的包

[English](../12-luban-packages.md) | **简体中文**

Luban 的 edition、策略和启动层都是本索引中的普通配方：xpkg 格式不变，数据写在配方里，
只有 `libs/luban.lua` 写盘。Luban 是什么、edition 怎样使用，见
[xlings 的 Luban 文档](https://github.com/openxlings/xlings/tree/main/docs/zh/luban)。

## 类别

| 类别 | `type` | 命名空间 | 版本 | 写盘 |
|---|---|---|---|---|
| edition | `subos` | `subos` | 发布日期 `YYYY.M.D.N` | `luban.edition({id, variant, versions, files})` |
| 策略 | `subos-policy` | `xim` | 发布日期 | `luban.policy(json)` |
| 启动层 | `package` | `xim` | 发布日期 | `luban.boot(json)` |
| 上游软件（内核、limine、busybox 等） | `package` | `xim` | 上游版本，重建时加 `-rN` | 配方自己 |

## 规则

1. **已发布版本的输出永不改变。**
   `tests/fixtures/luban-published.json` 记录每个已发布版本写出的每个文件的 sha256 和权限位，
   `tests/test_luban_published.py` 比对。一个版本合入 `main` 时把它加进去：
   `LUBAN_PUBLISHED_ADD=pkgs/l/<recipe>.lua@<version> pytest -k add_published`。
   fixture 只增不改。
2. **用到新客户端字段的 edition 写 `min_client`。** 新字段设计成旧客户端忽略后仍然安全
   （`boot.profile` 被忽略时退回 `boot.kernel`）。
3. **每个 edition 都 `from` 一个官方层**（nano 除外），并写明 `abi`。
4. **新 edition 只引用 `luban-init`**；`xlings-init` 只为已发布的版本保留。
5. **更新频繁的工具不锁版本**（agent 的 CLI）：`subos new` 安装当时的最新版并记录在实例
   中，`luban upgrade` 再移动它。其余的包精确锁定。
6. **preview 的 edition**（`status = "preview"`）在 luban 中没有短名。
7. **edition 只为它声明的架构构建。** `archs` 只列出启动并测试过的架构；它锁定的每个包在
   这些架构上都存在，`scripts/test-luban-editions.sh` 在 x86_64 和 aarch64 上运行。
