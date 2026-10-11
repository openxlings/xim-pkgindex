# CI：镜像与自动更新

[English](../13-ci-mirror-and-update.md) | **简体中文**

一个包可以让索引的自动化镜像它已声明的版本，并提出新版本。这只是索引维护：xlings 忽略
它，它也从不改变包的解析方式。

## 加入

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
                sha256 = { x86_64 = "<sha256>", aarch64 = "<sha256>" },
            },
        },
    },
}
```

| 字段 | 默认 | 含义 |
|---|---|---|
| `ci.mirror` | `false` | 已声明的版本校验通过后，CI 可以创建它的 `xlings-res` 镜像 release |
| `ci.update` | `false` | 加入周期扫描；上游有新版本时生成一个 PR |

周期由仓库统一配置在 `.github/xpkg-ci.yml`，不写进配方：

```yaml
version: 1
update:
  enabled: true
  interval: 3d
  wakeup_cron: "17 2 * * *"
  max_packages_per_run: 50
  request_budget: 500
```

workflow 每天唤醒一次；一个包到期后才被扫描。

## 各自做什么

```text
ci.mirror = true  ->  the versions already declared -> download, verify -> an xlings-res release
ci.update = true  ->  a newer upstream version -> its resource matrix and sha256s -> a pull request
```

两者互相独立：`mirror` 从不发现新版本，`update` 从不绕过 PR 修改索引。两者都开启时，
顺序是：发现、计算 hash、PR、PR 的 CI、合入，然后才是镜像 release。

- `update` 需要包含 `${version}` 的 URL 模板；固定 URL 无法跟踪。
- `source = "xlings-res"` 时再设 `mirror` 是冲突（它已经是官方镜像），直接失败。
- 镜像 release 本身不改变用户的下载来源：让安装走镜像是另一个需要 review 的索引改动。
- 自建资源（目标 sysroot、`tools/res/` 构建的一切）不设 `ci`：镜像会镜像它自己，更新会
  把 `latest` 指向一个还没人构建的 URL。

## 工具

`tools/xpkg_ci.py` 完成每一步，可以在本地运行：

| 命令 | 做什么 | 网络 | 写入 |
|---|---|---|---|
| `inspect` | 读取每个配方的 `ci`、source 和资源矩阵 | 否 | 报告 |
| `scan` | 查询上游、展开模板、下载、计算 hash | 是 | 报告与缓存 |
| `verify <manifest>` | 检查一份 manifest 的矩阵和 hash | 是 | 无 |
| `mirror <manifest> --execute` | 在 GitHub 和 GitCode 上创建 release，三方校验 | 是 | release |
| `propose --apply` | 为 PR 写出最小的配方改动 | 否 | 配方 |

已存在且内容完全相同的 release 视为成功；任何不同都失败，release 从不被覆盖。

## 旧机制：`url_template` 与 `res_versioned`

较早的配方用每个平台上的 `url_template`（`{version}` 占位符）加入自动更新，写作
`"XLINGS_RES"` 的条目用 `res_versioned = true`。两者仍然有效；新配方用 `xpm.source`。
约定见 [url-template](../specs/url-template.md)。

## 每周轮转

`ci-test.yml` 只安装一次推送改动到的包。`ci-sweep.yml` 每周按 ISO 周次安装所有配方中的
一片，使没有人改过的钩子也定期运行；手动触发可以重跑某一片。
