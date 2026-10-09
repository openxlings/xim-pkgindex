> **Superseded (2026-10-10).** This PR was reworked to the ecosystem design in
> xlings `.agents/docs/2026-10-09-luban-os-and-agent-private-design.md` (§C9):
> editions with date versions and fixed manifests (luban-nano, tiny without a
> kernel in the root, core without claude, luban-agent-workspace), the policies
> agent-private and agent-confined, and no owner-side script -- a template
> declares its policy and `luban new <n> agent-workspace --proxy <url>` makes
> the workspace private when it is made. What follows is the first iteration,
> kept for the record.

# Luban 与 Agent 私有环境 xpkg 设计方案

状态：待 review；本文件记录 review 设计及实施时确认的接口调整；实际验证证据见实施文档与 PR。
日期：2026-10-09。
范围：第一阶段 Linux x86_64、共享宿主内核的 rootfs；后续扩展其他架构与独立启动。
文档位于 `.agents/docs`。

## 1. 目标与设计决策

Luban 是由 xlings 生态组成、以 xlings 为默认包管理器的用户态。xlings 是必备基础设施，不是用户进入环境后另行安装的可选工具。

三类声明分开管理：

| 声明 | xpkg 类型 | 职责 |
| --- | --- | --- |
| luban-tiny | subos | 最小 rootfs 的包组成、factory 配置 |
| luban-core | subos | 继承 tiny，提供日常开发工具默认组合 |
| agent-workspace-private | config | 安装 owner 侧配置入口；由入口应用安全策略并在 rootfs 内配置用户数据 |
| agent-private | subos-policy | 可锁定、可升级、由 xlings 强制执行的安全策略 |

`agent-workspace-private` 不另造发行版，不重复安装 core 工具，不用 shell 代理变量替代网络隔离。
策略包与配置包分开，使隔离策略可以独立审查和升级。上述新包名是本提案建议。

## 2. Luban 默认组成

### luban-tiny

- 静态 xlings 管理入口，由 rootfs 构造流程保证存在并能分发命令。
- xlings 生态的 BusyBox、glibc、CA 证书及其必要闭包。
- 最小 passwd/group、hosts、nsswitch、shell、目录布局和 DNS 配置。
- 能进入 shell、验证 HTTPS、通过环境内 xlings 安装和配置工具。
- 不默认包含内核、完整服务管理器、桌面服务或开发工具链。当前 tiny 配方包含内核，此处是拟调整目标。
- patchelf 等构造工具是否进入运行根，由构造与运行依赖区分决定，不因构造过程使用过就默认保留。

### luban-core

最低默认集合：bash、fish、vim、nvim、git、mcpp、g++、glibc。

- glibc 继承 tiny；g++ 由 xlings 的 gcc 包及其工具链闭包提供，不假设存在独立的 g++ 包。
- 补充必要 GNU 基础工具、binutils、make、证书及运行库。具体包名和闭包在实现时核对。
- 延续前次讨论，claude 也列入默认集合；安装 CLI，不携带登录状态或个人凭据。
- vim 与 nvim 同时提供，bash 与 fish 同时提供，不把它们视为互斥替代品。
- 默认 shell 建议 bash，fish 可由用户在实例内选择；不修改宿主 shell。
- Node/Python 等按项目需要安装，只有明确依赖时进入默认闭包。
- 声明版本组合，发布时生成完整解析锁定记录；已发布模板不因 latest 移动而改变组成。

这一定义扩展现有 luban-core 配方；现有配方尚不包含全部上述工具。

## 3. 在线模板与离线 rootfs

在线 xpkg 是小型声明包，`install()` 生成模板，不捆绑所有工具二进制。
`subos new --rootfs --from ...` 根据模板的继承链和 packages 声明准备工具、闭包与根投影。
用户进入后继续使用 xlings install/use/remove；private 实例中的写操作经 broker 按策略执行。

模板包的 `xpm.deps` 与实例的 `packages` 不混用：前者是安装模板自身需要的依赖，后者描述目标 rootfs 的组成。
不要为了准备目标环境，在宿主当前作用域激活整套 core 工具。需验证客户端创建流程确实将工具配置到目标实例。

离线版本是同一份锁定声明的物化产物，包含根目录、xlings、完整 payload 闭包以及必要元数据。
不能只归档链接树而遗漏链接目标。导出后在无网络、无原始 XLINGS_HOME 的环境中验证可运行与管理。

离线产物至少记录：模板版本、客户端版本、目标架构、全部包版本与校验值、闭包清单、根代标识。
离线包的签名/来源真实性校验遵循资源分发机制；SHA256 用于完整性校验，本身不证明来源真实性。
离线更新若未携带新资源，应明确失败，不能宣称支持无资源离线安装。

在线和离线共享配置、包集合与验收要求，不维护两套不同发行版。

## 4. rootfs、状态与启动

沿用 SubOS Part 2 的根投影和 generation 模型：

- 包和运行库组成 /usr 的代；安装、切换、卸载生成新代。
- /etc 使用 factory 配置只补缺；home、workspace、var、凭据不随代回滚。
- 应用程序使用根内的 loader 和库，不挂入宿主 /usr 或默认使用宿主 ld.so.cache。
- 必须核对程序 INTERP、RUNPATH、动态库和附加资源闭包。Claude 原生 ELF 保留字节，不能通过盲目 patchelf 破坏附加载荷。
- 前缀域遵循客户端现有模型，保持逻辑安装路径可达；不由 recipe 自行搬移 payload 或改写共享 store。
- 第一阶段不启动完整机器 init。会话生命周期和网络接入由 SubOS 会话层处理。
- 可启动离线版本另加入内核、init 和启动声明；共享内核与独立启动是同一用户态的不同交付形态。

## 5. Agent private 配置与策略

### config 包

安装阶段只生成不含实例数据或秘密的固定入口脚本，config 阶段仅用 xvm 注册入口。
owner 显式执行 `agent-workspace-private <instance> <socks5h endpoint> [policy ref]`：先通过正式客户端选择并锁定策略，再在实例内部初始化私有目录与配置。凭据留在实例，不写共享 payload。

实际验证发现声明 private 后 recipe hook 会隔离并过滤环境，不能可靠地执行 owner 策略变更；因此最终实现不从 hook 修改策略。重复应用也经 owner 入口，不放宽 hook 权限。
新 mcpp 用户配置复用 Luban xlings home，通过已存在 GCC payload 的 path toolchain 构建；core 补 Ninja。已有 mcpp/Claude 配置保留。

### subos-policy 包

以已有 private 预设为基础，明确升级为受控代理网络。private 预设的 NAT 本身仍使用宿主出口。

| 领域 | 默认要求 |
| --- | --- |
| 文件 | 根来自 Luban；只暴露经校验的闭包和本实例数据，宿主 home、其他实例不可见 |
| 进程 | PID/IPC/UTS 隔离，禁止嵌套 userns，能力不足拒绝进入 |
| 设备与 socket | 摄像头、音频、GPU、display、dbus、ssh-agent 默认不授权 |
| 网络 | proxy 模式，无外部直连路由；受控代理解析 DNS；阻断宿主 loopback、未授权局域网和 IPv6 旁路 |
| 身份 | 中性用户名和主机名、独立 Git 身份；默认 UTC 与明确 locale，可配置但不以出口时区匹配证明匿名性 |
| 环境 | 白名单继承；清除宿主凭据、运行时 socket 和识别性变量 |
| 获取包 | 默认 ask；owner 可按可信来源与包集合配置规则，写操作经 broker |
| 观察 | 提供实际能力报告和审计；日志有权限和保留策略，不记录秘密 |

代理 endpoint 属于部署配置，不写死到可分发模板；认证秘密通过私有通道提供。
代理失效必须停止相关联网操作，不回退直连。应用程序不支持代理时应报告联网不可用，不能自动放宽网络策略。

共享宿主内核仍可能暴露内核/CPU/资源特征，账号、Git 身份和应用请求也可能关联用户。
本方案减少宿主信息暴露与网络旁路，不承诺完全匿名；需要独立内核边界时复用 Luban 用户态进入 VM。

## 6. xpkg 描述示意

以下表达设计意图，不是可直接提交的完整 recipe；版本、API 和 schema 在实现前核对。

```lua
package = {
    spec = "2",
    name = "luban-core",
    namespace = "subos",
    type = "subos",
    -- linux 的版本条目为空资源；install 生成模板
}
```

生成的模板沿用现有字段：

```json
{
  "subos_kind": "rootfs",
  "from": "subos:luban-tiny@<release>",
  "packages": [
    "xim:bash@<version>", "xim:fish@<version>",
    "xim:vim@<version>", "xim:nvim@<version>",
    "xim:git@<version>", "xim:mcpp@<version>",
    "xim:gcc@<version>", "xim:claude@<version>"
  ],
  "workspace": {}
}
```

glibc 从 tiny 继承，必要工具和库由经验证的声明及依赖闭包补齐。
策略 payload 为客户端支持的 policy.json；配置 recipe 只使用规范 Lua 和必要 libxpkg API。
不把尚未确认的 policy 字段或 hook API 写成已实现接口。

## 7. 生命周期与验收

- 模板安装与卸载不创建或删除用户实例。
- 配置升级保留代码、凭据、用户设置；策略升级显示差异并显式应用。
- 卸载 config 不自动放宽现有安全策略，不删除 workspace 或凭据。
- 删除实例是独立用户操作，遵循客户端确认机制。

实现验收至少包含：

1. tiny 在无宿主用户态挂载时启动，DNS/HTTPS 与 xlings 管理入口可用。
2. core 的 bash/fish/vim/nvim/git/mcpp/g++/claude 均实际运行；g++ 编译链接并运行 C++ 程序，mcpp 完成真实构建。
3. 在根内安装新增工具，刷新后立即可用，未改动宿主或其他实例。
4. 无网络、无原始 store 的离线 rootfs 能运行默认工具；闭包校验通过。
5. 宿主哨兵、其他实例数据和凭据不可见；未授权设备/socket 不可访问。
6. 直接 TCP/UDP、DNS、IPv6、宿主 localhost 的旁路尝试被阻断；代理出口正确，代理停机不直连。
7. 策略能力不足、客户端过旧和未知字段拒绝进入；doctor 报告请求与实际能力。
8. 升级、回滚、重复配置、卸载保留用户数据；策略更新不静默降低安全要求。

代码实施按仓库 PR/CI 流程执行；本设计阶段不修改 pkgs、tests 或 scripts。

## 8. Review 核心点

1. tiny = xlings + BusyBox + glibc + CA，第一阶段不包含内核；独立启动组合后续提供。
2. core 至少 bash/fish/vim/nvim/git/mcpp/g++/glibc，延续默认 claude；工具都由 xlings 管理。
3. 在线 xpkg 分发声明，离线 rootfs 分发相同锁定声明的完整闭包。
4. agent-workspace-private 用 config 包提供 owner 配置入口，安全规则独立为 subos-policy 包。
5. private 使用强制代理网络和 fail closed，明确共享内核的指纹与安全边界。
6. 第一阶段 Linux x86_64；默认 shell 建议 bash；不默认安装 Node/Python 或桌面服务。
