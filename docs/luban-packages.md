# Luban 的包（edition、策略、启动层）

设计：xlings `.agents/docs/2026-10-10-luban-os-design-part2.md` §2。不改 xpkg 规范：这些包都是普通的 recipe，数据写在 recipe 里，写盘只由 `libs/luban.lua` 完成。

| 类别 | type | namespace | 版本 | 写盘 |
|---|---|---|---|---|
| edition | `subos` | `subos` | 发布日期 `YYYY.M.D.N` | `luban.edition({id, variant, versions, files})` |
| 策略 | `subos-policy` | `xim` | 发布日期 | `luban.policy(json)` |
| 启动层 | `package` | `xim` | 发布日期 | `luban.boot(json)` |
| 上游软件（内核、limine、busybox…） | `package` | `xim` | 上游版本，可加 `-rN` | recipe 自己 |

规则：

1. **已发布版本的输出永不修改。** `tests/fixtures/luban-published.json` 记录每个已发布版本写出的每个文件的 sha256 和权限位，`tests/test_luban_published.py` 比对。一个版本合入 main 时，把它加进 fixture：`LUBAN_PUBLISHED_ADD=pkgs/l/<recipe>.lua@<version> pytest -k add_published`。fixture 只增不改。
2. **用到新客户端字段的 edition 写 `min_client`。** 新字段要设计成"旧客户端忽略后仍然安全"（例如 `boot.profile` 被忽略时，退回 `boot.kernel`）。
3. **每个 edition 都 `from` 一个官方层**（nano 除外），并写明 `abi`。
4. **新 edition 只引用 `luban-init`**；`xlings-init` 只为已发布版本保留。
5. **agent 这类更新频繁的工具不带版本。** `subos new` 安装当时的最新版并记录在实例里，`luban upgrade` 再移动它。其余包精确锁定。
6. **preview 的 edition**（`status = "preview"`）在 luban 里没有短名。
