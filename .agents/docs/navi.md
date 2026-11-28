# navi

navi 是交互式命令速查表工具。稳定包 `xim:navi` 提供 `navi` 命令，支持 Linux 和 Windows x86_64。

## 来源与平台

- 使用 [denisidoro/navi 官方发布](https://github.com/denisidoro/navi/releases/tag/v2.24.0)，许可证为 Apache-2.0。
- GLOBAL 使用上游原始归档。此版本没有发布校验文件，GitHub 资产也没有摘要。两次独立下载每份归档所得 SHA256 相同。
- 自动更新核对两个平台的发布物。配方声明 `ci.mirror = true`，尚无已核实的 CN 地址。
- 上游此版本未发布 macOS 二进制。Linux ARM64 的归档使用 UPX 封装；解包后可见解释器 `ld-linux-aarch64.so.1`，以及 `libgcc_s.so.1`、`libpthread.so.0`、`libdl.so.2`、`libc.so.6`。此外，当前 `xim:fzf` 的 Linux 资源均为 amd64，因此配方只声明 x86_64。

## 运行依赖

用 UPX 展开副本后检查内层程序。Linux x86_64 musl ELF 没有 `PT_INTERP` 或 `DT_NEEDED`。Windows PE 的常规导入均为系统 DLL，延迟导入表为空。安装始终保留上游原始二进制。

两平台的默认检索器来自 `xim:fzf`。导入速查表仓库用 `xim:git`。Linux 的默认命令解释器来自 `xim:bash`，预览中的 `cat` 和非交互终端尺寸探测的 `stty` 来自 `xim:coreutils`。Windows 的 Git 发行包自带这三个程序，navi 的 xvm 注册仅为其子进程添加 Git 的 `usr/bin`。

## 安装和验证

钩子将单文件归档解压到包目录，检查可执行文件，再注册 navi。卸载移除该注册，载荷由 xlings 清理。钩子不启用 shell widget，也不写用户速查表或 navi 配置。

Linux x86_64 使用 CI 固定版本 xlings 2026.11.23.1，在独立 HOME 和 XLINGS_HOME 注册、搜索、安装和重复安装。仅通过测试子系统查找 fzf，以 `--path`、`--query`、`--best-match`、`--print` 从本地文件选择并打印指定命令。卸载后检查载荷、shim 和注册均已清理，再次卸载并移除覆盖配方。Windows 已核对归档、PE 导入及 Git 载荷，本地没有 Windows 执行环境。

## 修订记录

- 2026-11-28 — 初次加入 2.24.0。
