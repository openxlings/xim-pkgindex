# Luban / Agent private 实施与使用

## 变更

- `subos:luban-tiny@0.2.0`：xlings 管理的 BusyBox/glibc/CA 用户态，默认无内核；保留构造使用的 patchelf。
- `subos:luban-core@0.2.0`：继承 tiny 0.2，加入 bash/fish/vim/nvim/git/mcpp/gcc（含 g++）/claude 及基础工具（含 mcpp 构建所需的 Ninja）。
- 0.1.0 保留原来的包组成；desktop 仍继承 core 0.1.0，不自动扩大 desktop 的工具闭包。
- `xim:agent-private@0.1.0`：严格代理网络策略，未配置代理时不能作为联网环境使用。
- `config:agent-workspace-private@0.1.0`：安装并注册 owner 侧配置入口；入口应用策略后，在目标 rootfs 内配置 `/root` 私有工作目录。

## 创建与配置

合并发布后使用（当前 PR 验证应注册本 PR recipe 并将策略引用改为 local:）：

```bash
xlings subos new agent --rootfs --from subos:luban-core@0.2.0
xlings install config:agent-workspace-private@0.1.0
agent-workspace-private agent socks5h://127.0.0.1:7897
xlings subos status agent --json
xlings subos doctor agent
xlings subos exec agent -- bash
```

第二个位置参数是 owner 侧可达的 SOCKS5h 地址，不接受认证凭据嵌入 URL。目标实例必须已经是 rootfs，不能是 default/current，也不能从沙箱内执行配置。首次策略选择由正式客户端解析并锁定来源及 digest。

重复执行 owner 入口可重新应用策略和检查配置；不通过受隔离的 recipe hook 修改 owner 策略。已有 mcpp 配置保留；新配置使用 Luban 的 xlings home 和既有 GCC payload，不触发私有工具链下载。

该包不继承宿主 Git 身份或 Agent token。Claude 登录和 Git 身份由用户在实例内配置；凭据的传入需显式授权。代理支持与工具的实际行为需由 doctor 和功能测试确认。

## 数据与安全

不覆盖已有 Claude settings，不删除凭据；拒绝通过既有符号链接重定向 owner 写入。卸载保留 workspace、用户设置和实例的安全策略。

配置包安装需要 owner 权限；包获取 ask 的请求由 owner 在外面审批。没有 rootfs/bwrap/proxy 等必要能力时拒绝进入，不降级 proot 或直连。

共享内核和账号请求仍可能暴露指纹。本实现不伪装 CPU/内核或账号，不承诺匿名。标准审计沿用客户端机制，没有增加 token 日志或实现独立日志轮转。

## 在线与离线

模板 recipe 不捆绑工具；创建根时由 xlings 安装锁定版本。离线 rootfs 使用现有 `subos export --tar` 导出完整闭包。此 PR 不新增离线二进制资源镜像，也不发布可启动磁盘镜像；独立启动需另装内核。

## 本地与 CI 证据

最终结果记录在 PR 描述及 review 报告中；不以静态测试代替实际沙箱隔离验证。

当前客户端基础环境白名单仍继承 `LC_*`；LANG 被设为 C.UTF-8，但 LC_ALL 等可能覆盖它。这是已发现的客户端指纹残留，本 PR 不宣称已消除。

完整本地验收：`python3 scripts/test-luban-agent-private.py`；本机 AppArmor 环境可使用 `--busybox`。脚本使用独立临时 home 和本地 SOCKS fixture，保留日志，并停止测试会话。CI 同样执行该验收，要求安装完成、真实 C++23 构建、代理远端域名、直连/DNS/IPv6/本机服务旁路阻断、代理离线、离线闭包和卸载数据保留。
