# XIM Package Index Repository | [xlings](https://github.com/openxlings/xlings)

software, library, environment install/config ...


| [Package Index](https://openxlings.github.io/xim-pkgindex/) - [文档](https://xlings.d2learn.org/documents/xim/intro.html) - [论坛](https://forum.d2learn.org/category/9/xlings) |
| --- |
| [![pkgindex test](https://github.com/openxlings/xim-pkgindex/actions/workflows/ci-test.yml/badge.svg?branch=main)](https://github.com/openxlings/xim-pkgindex/actions/workflows/ci-test.yml) - [![Deploy Static Site - xpkgindex](https://github.com/openxlings/xim-pkgindex/actions/workflows/pkgindex-deloy.yml/badge.svg)](https://github.com/openxlings/xim-pkgindex/actions/workflows/pkgindex-deloy.yml) - [![gitee-sync](https://github.com/openxlings/xim-pkgindex/actions/workflows/gitee-sync.yml/badge.svg)](https://github.com/openxlings/xim-pkgindex/actions/workflows/gitee-sync.yml) |
| **type:** package - app - config - courses - lib - plugin - script |
| **添加你喜欢的 [ 软件、配置组合... ] 到包索引仓库 ➤ [Add XPackage](https://xlings.d2learn.org/documents/community/contribute/add-xpkg.html)** |

---

## 常用命令

```bash
xlings install gcc          # 安装包
xlings search gcc           # 搜索包
xlings remove gcc           # 卸载包
xlings list                 # 列出已安装的包
xlings update               # 更新包索引
```

## 包索引仓库

| 仓库 | 命名空间 | 简介 |
| -- | -- | -- |
| [xim-pkgindex-template](https://github.com/openxlings/xim-pkgindex-template) | xim | 自建/镜像/私有包索引模板仓库 |
| [xim-pkgindex-fromsource](https://github.com/openxlings/xim-pkgindex-fromsource) | fromsource | 从源码构建的包索引仓库 |
| [xim-pkgindex-d2x](https://github.com/d2learn/xim-pkgindex-d2x) | d2x | d2x公开课项目索引仓库（external/d2learn） |


## 如何参与项目贡献?

完整流程见 [`docs/contributing.md`](docs/contributing.md)。简要步骤如下：

1. 阅读 [xpkg V2 资源规范](docs/V2/xpackage-spec.md)，确认包使用的客户端版本。
2. 在 `pkgs/<首字母>/<name>.lua` 修改配方，并为行为添加 `tests/` 测试。
3. 官方二进制优先使用 `xpm.source = "xlings-res"`；每个受支持架构必须有权威 SHA256。
4. 运行静态检查、隔离安装和测试集，再提交 PR。

### 官方资源最小范例

```lua
package = {
    spec = "2",
    name = "demo",
    archs = { "x86_64", "aarch64" },
    xpm = {
        source = "xlings-res",
        linux = {
            ["latest"] = { ref = "1.0.0" },
            ["1.0.0"] = {
                sha256 = {
                    x86_64 = "<linux-x86_64-sha256>",
                    aarch64 = "<linux-aarch64-sha256>",
                },
            },
        },
    },
}
```

`"XLINGS_RES"`、`res = true`、显式 URL、URL template、mirror、`ref` 和旧单 hash
仍受支持，用于兼容历史配方；新配方不应新增无校验的官方二进制版本。

### CI 自动镜像与更新

自动化是可选的 CI 扩展，不影响用户安装规范：

```lua
ci = {
    mirror = true, -- 镜像已声明版本
    update = true, -- 加入仓库统一扫描
}
```

扫描周期统一由仓库 `.github/xpkg-ci.yml` 管理，当前设计默认每 3 天检查一次；包文件不
单独写入周期。自动更新只创建 PR，镜像 release 只在校验、合并和三方 hash 复核后创建。

### 资源发布硬门禁

- GitHub RES 与 GitCode RES 必须存在同版本、同文件名的全部平台资产。
- 资产必须来自同一权威构建；发布后从权威源和两个镜像计算 SHA256 并逐字节核对。
- release 自动生成 `.sha256` sidecar；`version-check.py --apply` 缺少任一受支持架构 hash 时必须失败且不修改配方。
- `latest` 使用 `ref` 指向已验证版本，补发历史版本不得改变 `latest`。
- `xlings-res` 二进制资源和 `xim-index` 索引工件是两类不同资产，不能混用发布目录。

## 社区&交流

- [xlings论坛版块](https://forum.d2learn.org/category/9/xlings)
- 交流群(Q): 167535744
