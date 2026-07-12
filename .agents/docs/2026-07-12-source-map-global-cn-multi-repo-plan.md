# xpm source GLOBAL/CN 多仓库镜像与自动更新方案

> 日期：2026-07-12  
> 状态：设计方案，尚未实现  
> 范围：libxpkg、mcpp-index、xlings、xim-pkgindex、xlings-res 发布链
> 兼容约束：xlings 包本身暂不迁移到新规范

## 1. 背景与目标

当前 xpkg 已支持：

- 版本项 url = { GLOBAL = ..., CN = ... } 镜像表；
- 版本扫描器使用的旧 xpm.<platform>.url_template；
- V2 的单字符串 xpm.source 模板。

目标是让 source 支持地区模板，避免每个版本重复写 URL：

    xpm = {
        source = {
            GLOBAL = "https://github.com/neovim/neovim/releases/download/v${version}/nvim-${os}-${arch_alias}.tar.gz",
            CN = "https://gitcode.com/xlings-res/nvim/releases/download/${version}/nvim-${os}-${arch_alias}.tar.gz",
        },
        linux = {
            ["latest"] = { ref = "0.12.4" },
            ["0.12.4"] = {
                sha256 = { x86_64 = "<sha256>" },
            },
        },
    }

最终应满足：

1. GLOBAL 是权威上游，CN 是已校验的 xlings-res 镜像。
2. xlings 按地区选择 URL，失败、404 或 hash mismatch 时安全回退。
3. 所有候选使用同一 per-arch SHA256。
4. CI 能发现上游版本、生成 manifest、发布镜像并创建索引 PR。
5. 旧客户端继续解析字符串 source、显式 url 和 XLINGS_RES。
6. xlings 包本身不迁移，继续保证安装和自升级兼容。

## 2. 协议设计

### 2.1 source 输入形状

保留三种形状：

    -- 兼容旧写法
    source = "https://example.com/${version}/tool-${arch}.tar.gz"

    -- 新写法
    source = {
        GLOBAL = "https://github.com/acme/tool/releases/download/${version}/tool-${arch_alias}.tar.gz",
        CN = "https://gitcode.com/xlings-res/tool/releases/download/${version}/tool-${arch_alias}.tar.gz",
    }

    -- 官方资源特殊值
    source = "xlings-res"

支持 root xpm.source 和 platform-level source；platform-level 覆盖 root-level。
模板变量为 name、version、os、arch、arch_alias、ext。

地区 map 约束：

- 至少有 GLOBAL 或一个可解析候选；
- 值必须是 HTTPS 模板；
- CN 缺失时回退 GLOBAL；
- GLOBAL 缺失时不能静默选择任意 map 项作为权威源；
- 地区候选只改变传输位置，不改变版本、归档、架构和 hash。
- CN 模板只有在镜像资产文件名、tag 和目录布局与模板一致时才能自动生成；不规则
  镜像必须由 manifest 生成版本级 url map，不能猜测文件名。

### 2.2 资源归一化优先级

1. per-arch 版本项：version.arch = { url, sha256 }；
2. 版本项显式 url / url = { GLOBAL, CN }；
3. platform source；
4. root source；
5. source = "xlings-res"；
6. V1 兼容路径。

先完成资源归一化，再按 preferred mirror 排序候选，最后进入统一下载、校验和
fallback 流程。

### 2.3 url_template 弃用

url_template 标记为 deprecated：

- 旧包继续解析；
- 新包和迁移包只使用 source；
- inspect/scan 输出弃用警告；
- 文档明确它只服务旧 CI 更新流程，不参与 xlings runtime 资源解析；
- source-map 支持发布一个稳定 xlings 版本后，不再接受新增 url_template。

ci.update 应消费归一化后的 source 模板，而不是依赖字段名 url_template。

## 3. 多仓库职责与实施项

### 3.1 openxlings/libxpkg

职责：Lua 配方解析、source map 数据模型和资源归一化。

修改范围：

- src/xpkg.cppm
  - 增加 source template 单字符串/map 模型；
  - PlatformMatrix 保存 root/platform source；
  - 保持 PlatformResource.mirrors 兼容。
- src/xpkg-loader.cppm
  - 解析 xpm.source 字符串或 {GLOBAL,CN}；
  - 解析 platform/root 覆盖；
  - 非字符串、空 map、坏 URL fail closed。
- resolve_resource
  - 展开模板；
  - 生成首选 URL 与 fallback URLs；
  - 绑定同一版本和 per-arch SHA256。

测试必须覆盖字符串 source、GLOBAL/CN map、root/platform 覆盖、CN 缺失回退、
显式版本 URL 覆盖 source、坏 map 和旧 V1/V2 fixture。

### 3.2 mcpp-community/mcpp-index

- 在 libxpkg tag/release 完成后注册新的 `mcpplibs.xpkg` 版本。
- `mcpp-index` 的 GLOBAL 归档、CN mirror、SHA256 必须指向同一份 release
  字节；该注册 PR 是 xlings 使用新 xpkg 版本的依赖，不应省略。
- 依赖顺序：libxpkg PR merge → tag/release → mcpp-index 注册并 merge →
  xlings 依赖升级 PR CI。

### 3.3 openxlings/xlings

职责：安装器选择地区、尝试 fallback、校验缓存和输出诊断。

重点文件：

- src/core/xim/installer.cppm
  - 使用 libxpkg 归一化结果；
  - preferred CN/GLOBAL 先尝试；
  - 404、超时、下载失败、hash mismatch 进入候选 fallback；
  - 保持 XLINGS_RES 自动资源服务器 fallback。
- src/core/xim/libxpkg/types/type.cppm
  - 必要时补 resolved candidate/source kind 类型。
- tests/unit、tests/e2e
  - fake GLOBAL/CN server；
  - CN 404 回退 GLOBAL；
  - GLOBAL 超时回退 CN；
  - hash mismatch 拒绝错误资产；
  - source map、显式 mirror map、XLINGS_RES 三种路径兼容。

### 3.4 openxlings/xim-pkgindex

职责：规范、CI、manifest、索引配方和迁移。

修改范围：

- docs/V2/xpackage-spec.md：source map、fallback、优先级和 hash 规范；
- docs/contributing.md：新模板、mirror 前置条件和验证命令；
- docs/spec/url-template.md：deprecated 标记和迁移说明；
- .github/scripts/version-check.py
  - 只从 GLOBAL 模板查询上游；
  - 同时识别字符串 source 与 source map；
  - 生成完整 per-platform/per-arch update manifest；
  - 不在 CN release 尚未验证时生成 CN 路由；
- tools/xpkg_ci.py
  - inspect 输出 source map；
  - materialize 使用 GLOBAL/权威源；
  - verify 检查候选、归档、sidecar、hash；
  - mirror 发布同名 GitHub/GitCode 资产；
  - 增加 source-map fixture 和 dry-run 测试。

### 3.5 xlings-res 发布面

每个 package/version 必须同时具备：

- GitHub xlings-res/<pkg> 同名 tag/release；
- GitCode xlings-res/<pkg> 同名 tag/release；
- 全部平台/架构归档；
- 同名 .sha256 sidecar；
- manifest.json；
- 权威 GLOBAL、GitHub RES、GitCode RES 三方 hash 一致。

GitCode release asset 不覆盖、不删除；历史 release 不回写 latest。

## 4. CI 状态机

    ci.update=true
      → 读取 GLOBAL source template
      → 查询上游 latest release
      → 下载全部平台/架构并计算 hash
      → 生成 immutable update manifest
      → 创建 update PR

    ci.mirror=true
      → 消费同一 manifest
      → 发布 GitHub RES + GitCode RES
      → 三方 hash、大小、文件名核验
      → 生成 mirror-ready 证明
      → 生成带 GLOBAL/CN source route 的索引 PR

manifest 是唯一事实源；update 和 mirror 不得各自重新下载并计算 hash。
merge 前不允许把不存在的 CN release 写入索引。

source map 的 CN 候选不能只因为 URL 形式合法就进入索引；route generator 必须先
读取 mirror manifest，确认对应 tag、文件名和 sidecar 已经存在，再生成 CN 模板或
版本级覆盖。对于不同于 GLOBAL 文件名的资源，优先生成版本级 per-arch map。

## 5. 迁移批次

### Batch 0：单架构、低风险

先迁移已有 PR #360 涉及的：

- fish
- griddycode
- nvim
- pnpm

要求：spec = "2"、ci opt-in、source map、per-arch hash、mirror manifest 和跨平台
install/config/uninstall 验证。

### Batch 1：需要架构校正

- ripgrep
- fzf
- zoxide
- sing-box
- cc-connect
- cc-switch

迁移前确认每个平台 x86_64/aarch64 资产存在，补 arch_alias 或改成 per-arch map；
不能继续用一条 amd64 URL 支撑多架构声明。

### Batch 2：已有镜像或复杂安装布局

- yazi
- github-gh
- xmake
- patchelf
- proot

先验证归档内部目录、可执行文件路径和 xvm hook，再切换 source map。

暂缓：

- xlings：保持 res_versioned/旧兼容路径；
- go：上游 release 检查当前返回 404；
- 没有完整平台资产或稳定 release 的包。

## 6. 交付顺序

1. libxpkg 实现 source map 数据模型、解析和单测。
2. xlings 接入归一化结果、地区选择和 fallback。
3. xim-pkgindex 更新规范、CI parser、manifest 和 route PR。
4. 用 fixture 验证 GLOBAL、CN、缺失 CN、hash mismatch 和旧格式。
5. 发布支持 source map 的 xlings/libxpkg 版本。
6. 迁移 Batch 0，先 mirror，再提交 CN route PR。
7. 迁移 Batch 1/2，每批独立 PR 和多平台验证。
8. 所有包迁移完成后，停止新增 url_template，保留至少一个稳定版本周期的兼容解析。

## 7. 验收清单

- [ ] source 字符串和 GLOBAL/CN map 均能被 libxpkg 解析。
- [ ] root/platform 覆盖关系有测试。
- [ ] preferred mirror 失败按 hash 安全回退。
- [ ] source map 不允许无 hash 资源进入安装。
- [ ] update 只从 GLOBAL 查版本，CN 只作为已验证镜像。
- [ ] 两端 release、sidecar、manifest 和三方 hash 一致。
- [ ] route PR 只在 mirror-ready 后生成。
- [ ] url_template 文档标记 deprecated，旧包仍可用。
- [ ] Batch 0 安装/卸载和跨平台 CI 通过。
- [ ] xlings 包没有被 source-map 迁移改动。
