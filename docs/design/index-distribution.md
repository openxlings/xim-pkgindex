# xlings 索引机制（index mechanism）

> **来源校准**：本文是从 `openxlings/xlings` 仓库的 `docs/`、`.agents/docs/`
> 与源码确认后，同步到本仓库的「最新索引机制」摘要。
> **对应 xlings 版本**：v0.4.55（2026-06-23）。索引即资源（index-as-resource）
> 特性在 v0.4.52 → v0.4.55 连续发布中落地（#327/#328/#329/#331）。
>
> 权威来源（以 xlings 仓库为准，本文如与其冲突以 xlings 为准）：
> - `docs/design/index-distribution.md` — 分发/镜像设计（最权威）
> - `docs/design/package-index-ecosystem.md` — 三层模型、命名空间、解析
> - `docs/spec/xpkg-manifest-v1.md`、`docs/spec/xlings-json-schema.md`
> - `.agents/docs/2026-06-21-pkgindex-redesign-proposal.md`（决策 §7.7/§7.10）
> - `.agents/docs/2026-06-22-index-as-resource-impl-plan.md`（实现状态）
> - 代码：`src/core/config.cppm`、`src/core/xim/{indexfetch,repo,catalog,index,commands}.cppm`

本仓库（`openxlings/xim-pkgindex`）就是 xlings 的**官方包索引**。理解索引机制能帮助
维护者明白：写在 recipe 里的 `XLINGS_RES`/镜像表如何被消费、本仓库如何被分发到用户机器、
以及发版时需要协同改哪个文件。

---

## 1. 索引模型（三层）

xlings 的索引是去中心化的：每个索引仓库都是一个普通 Git 仓库，里面是
`pkgs/<首字母>/<name>.lua` 形式的 recipe。三层来源：

| 层级 | 说明 | 备注 |
|------|------|------|
| **官方索引（`xim`）** | 本仓库 `openxlings/xim-pkgindex` | 始终存在，名字固定为 `xim`，本地目录名 `xim-pkgindex` |
| **第三方/子索引** | 通过主索引的 `xim-indexrepos.lua` 发现，或用户自配 | 默认子索引：`awesome` / `scode` / `d2x` |
| **自建/私有** | `file://`、本地绝对/相对路径（软链不 clone）、私有 Git URL | 始终走 git/symlink |

- **官方索引默认值**（硬编码于 `config.cppm:91-97`）：
  - `GLOBAL` → `https://github.com/openxlings/xim-pkgindex.git`
  - `CN` → `https://gitee.com/sunrisepeak/xim-pkgindex.git`（git 回退镜像）
  - 默认索引名 `xim`，本地目录 `xim-pkgindex`。
- **官方索引常驻保证**（`config.cppm:499-516`）：即使用户在
  `.xlings.json` 的 `index_repos` 里只写了自定义索引而漏掉 `xim`，xlings 也会
  把官方索引**插到列表最前面**。用户配置是**追加**而非替换。
- **子索引发现**：主索引根目录的 `xim-indexrepos.lua`（格式
  `["name"] = {["GLOBAL"]="url", ["CN"]="url"}`）由一个手写状态机解析（不是跑 Lua
  解释器，`repo.cppm:73-144`）。镜像选择：优先当前地区 key 的 URL，缺失回退 `GLOBAL`。

### 1.1 命名空间解析

目标语法 `[namespace:]name[@version]`（`ns:name` 与 `ns::name` 都接受，`catalog.cppm`）。
解析优先级（`collect_matches_`）：

1. **项目级索引 > 全局级索引**
2. **主索引 > 子索引**

规则细节：

- **裸名字**（不带命名空间）：只要任一**主索引**命中，就**不再查子索引**。
- **显式命名空间**：搜索所有索引（含子索引）。
- 多个主索引对同一裸名字都命中 → 报歧义错误，要求用 `ns:name` 消歧。
- 省略命名空间时，默认用该仓库的 `defaultNamespace`（= 仓库名；官方索引即 `xim`）。

### 1.2 解析缓存

每个索引目录有 `.xlings-index-cache.json`（format version 1，`index.cppm`），以
**仓库头哈希**为 key：

- git 仓库 → git HEAD
- **制品（artifact）管理的仓库** → `"artifact:" + <.xlings-index-version>`

后者（v0.4.55 修复）让命令不再每次都全量重建索引。

---

## 2. 索引即资源（index-as-resource / Y-asset）—— 当前分发模型

这是最近最核心的改动，**已完全落地**。要点：官方索引在 `auto` 模式下**不再在运行时
git clone**，而是作为一个**带版本号、sha256 锁定的 tar.gz 制品**，**走与软件包二进制
相同的 HTTP 资源服务路径**拉取，从而复用 0.4.49 的自适应延迟排序与卡死看门狗。

### 2.1 资源服务器（固定的发现锚点）

`config.cppm:99-104`：

| 地区 key | 资源服务器 |
|----------|-----------|
| `GLOBAL` | `https://github.com/xlings-res` |
| `CN` | `https://gitcode.com/xlings-res` |

> ⚠️ 两个「镜像」概念要分清：
> - **地区 key**（`GLOBAL`/`CN`，`Config::mirror()`）→ 选上游主机。
> - **代理改写**（`mirror::` 命名空间，jsdelivr/ghproxy…）→ 改写 github URL。
>   **索引拉取刻意不使用 github 代理**（见 §2.4）。

候选选择：项目配置 → 全局配置 → 内置默认 → `GLOBAL` 兜底。多个候选时做延迟探测，
取最快者（≤100ms 立即采用），进程内记忆。

### 2.2 制品契约

发布到 `xlings-res/xim-index`（**GitHub 与 GitCode 双发**），滚动 `latest` tag +
归档 `v<ver>` tag：

- `xim-index[-<sub>]-<ver>.tar.gz` — 索引树（`pkgs/`、`.xpkgindex.json`、
  `xim-indexrepos.lua`），已剥离 `.git`。
- `manifest.json`（每个索引一份）：`format_version:1`、`index_version`、`index_name`、
  `generated_at`、`source_commit`、`artifact{name,sha256,size}`、`signature:null`。

### 2.3 合并指针（0.4.54 定稿）

最关键的分发细节：指针是 `xlings-res/xim-index` 仓库里的**单个文件**
`xim-index-pointers.json`（**不是 release 资产**），commit 进仓库后用 raw 方式读取：

```json
{"format_version":1,"indexes":{"xim":{...},"awesome":{...},"scode":{...},"d2x":{...}}}
```

- **为什么用仓库文件**：GitCode 的 release 资产不能覆盖/删除；仓库文件可以 git push 覆盖。
- **为什么合并**：一次 raw 拉取覆盖所有索引 → 规避 GitCode raw 的限流（逐索引拉会触发 403）。
- raw URL 形式（`indexfetch.cppm`）：
  - GitHub → `raw.githubusercontent.com/<org>/xim-index/main/<file>`
  - GitCode → `raw.gitcode.com/<org>/xim-index/raw/main/<file>`（必须用 `/raw/main/`，
    `/main/` 会返回 HTML）

### 2.4 运行时拉取流程

`indexfetch.cppm` `fetch_index_artifact`：

1. 读合并指针 `xim-index-pointers.json`（每进程缓存一次）。
2. 查到该索引的 manifest 条目，要求 `format_version==1`。
3. 构造候选 URL：选中的（延迟探测过的）服务器优先 → 所有地区服务器 →
   **总是追加 GLOBAL/GitHub**。形如 `{server}/xim-index/releases/download/latest/<file>`。
4. 逐候选下载，**对任何失败（包括 HTTP 404）都继续 fall-through**（这是 CN 关键修复：
   底层 http 库会把 404 当致命错误）；对卡死/超时/坏字节的主机降权，但 **404/401 不降权**。
5. 按 manifest 校验 sha256 → 解压到 staging → 检查 `pkgs/` 存在 → 写
   `.xlings-index-version` 标记 → 原子 rename 到 `data/xim-pkgindex`（带回滚备份）。

**CN 专属决策**：索引**不做 github 代理扩展**（ghfast/ghproxy/kkgithub）——它们 TCP
可达但常常不真正提供资产，排在前面会导致每个 ~30s 超时（就是「fetching package index」卡住
的根因）。索引只用 **gitcode（原生）+ github 直连**（按地区排序），gitcode 没命中就 github。
sha256 来自指针，即使某个镜像 tar 落后也保证正确性。

### 2.5 来源选择门（git vs artifact）

`repo.cppm` `sync_all_repos`，环境变量 `XLINGS_INDEX_SOURCE=git|artifact|auto`（默认 `auto`）：

- **auto** 仅在以下条件用 artifact：主索引是**官方远端**（URL 含 `openxlings/xim-pkgindex`
  或 `sunrisepeak/xim-pkgindex`，且非本地源）**且**（已是 artifact 管理 **或** 全新安装）。
- 已存在的 **git** 索引保持 git（兼容老 checkout/测试夹具）。
- 本地/自定义/fork 源始终 git/symlink。
- **默认子索引**在「名字是 lua 默认 + URL 仍等于 lua 默认 + 非本地」时走 artifact；
  用户自加的第三方子索引仍按其声明 URL 走 git。
- artifact 管理的目录带 `.xlings-index-version`，不会再被 git clone。

### 2.6 自建/离线

- **自建索引服务**：环境变量 `XLINGS_INDEX_BASE_URL` 或 `.xlings.json` 的
  `xim.index-base`（字符串或 `{GLOBAL,CN}` 对象）。只需把
  `xim-index-pointers.json` + `xim-index[-sub]-<ver>.tar.gz` 作为静态文件提供即可。
  其它覆盖：`XLINGS_INDEX_REPO`（默认 `xim-index`）、`XLINGS_INDEX_TAG`（默认 `latest`）。
- **离线/首启**：release 包内置 `data/xim-pkgindex` 即为 **artifact 管理**态（剥离 `.git`
  并写好 `.xlings-index-version`），新装即在 artifact 路径上。

### 2.7 git 回退路径（保留）

`sync_repo`：首次 `git clone --depth 1`（带 `mirror::` 代理候选）；更新
`git pull --ff-only` → 失败回退 `fetch + reset --hard`；**7 天节流**（`.xlings-sync-stamp`）；
本地源软链。`xlings update` → `cmd_update` 调 `sync_all_repos(true)` 再 `catalog.rebuild(true)`。

---

## 3. 与本仓库 recipe / 发版的关系

### 3.1 recipe 里的资源解析

recipe 版本值用的 `XLINGS_RES` 哨兵、以及 `url = {GLOBAL=..., CN=...}` 镜像表，
解析的是**软件包二进制**，走的也是 §2.1 的资源服务器
（`GLOBAL` = `github.com/xlings-res`，`CN` = `gitcode.com/xlings-res`）。
这与「索引本身的分发」是同一套资源服务路径，但两者是不同的资产，不要混淆：

- recipe 的 `XLINGS_RES` → 拉 `<pkg>` 的二进制 tar/zip。
- 索引即资源 → 拉 `xim-index` 的索引树 tar.gz（用户一般无感知）。

> `XLINGS_RES` 发布前置要求见 `xpkg-creater` skill §1.2.1（GitHub RES 与 GitCode RES
> 必须双发、资产一致、sha256 字节一致）。

### 3.2 发版协同触点（本仓库）

xlings 发新版时，本仓库的协同点是 **`pkgs/x/xlings.lua`**：

1. xlings 侧 bump `VERSION` + `mcpp.toml`。
2. 本仓库 `pkgs/x/xlings.lua`：把各平台 `["latest"].ref` 指到新版，并新增
   `["<ver>"] = "XLINGS_RES"`。
3. xlings 的 `release.yml` 会从**更新后的 pkgindex** 构建二进制 + 跑 `publish-index`
   任务（因此 `latest` 一次性写对），再把二进制镜像到 `xlings-res/xlings`。

> 注意「索引发布只能在内容定稿后发一次」——GitCode 不能覆盖同名 release 资产
> （指针文件用仓库文件正是为绕开这一点）。

---

## 4. 已实现 vs 计划中

**已实现（当前）**

- 索引即资源 Y-asset 获取（制品 + manifest + sha256 锁定、原子替换、git 回退）。
- 合并仓库文件指针（gitcode + github raw）、404 fall-through、坏主机降权。
- CN 地区路由、索引不走 github 代理、版本标记缓存 key。
- artifact 管理的 release 内置索引；`XLINGS_INDEX_SOURCE` / `XLINGS_INDEX_BASE_URL` /
  `XLINGS_INDEX_REPO` / `XLINGS_INDEX_TAG` 环境变量；`xim.index-base` 配置。
- 默认子索引制品化。

**计划中 / 未做**（`signature:null` 等已为其预留）

- 指针的 **minisign 签名**（X-full 模型）。
- **ETag / If-Modified-Since 304** 条件请求。
- **`xlings.lock`** 可复现锁（借鉴 mcpp.lock）。
- recipe 级 **sha256 覆盖率 8% → ~100%** + CI lint。
- 稀疏/X-full 索引（仅当包数量增长到 MB 级才需要）。

---

## 5. 一个待修的上游文档不一致（备忘）

xlings 的 `docs/quick-start/custom-index.md` 仍把索引仓库布局写成
`packages/<tool>/xpkg.lua`，而真实/官方布局是 `pkgs/<首字母>/<name>.lua`；该文也尚未
提及 artifact/指针分发模型。引用自建索引文档时以本文 §1 / §2 为准。
