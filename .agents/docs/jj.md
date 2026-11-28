# jj

兼容 Git 的版本控制工具，提供 `jj` 命令，当前打包稳定版 0.47.1。

- 上游：https://github.com/jj-vcs/jj （Apache-2.0）
- 命名空间：`xim`
- 平台：Linux x86_64/aarch64、Windows x86_64
- 上游另有 macOS 双架构和 Windows ARM64 二进制，但本索引尚未完整提供这些平台所需的 Git，暂不声明支持

## 来源

- 官方 GitHub Release：`v0.47.1`
- GLOBAL：`https://github.com/jj-vcs/jj/releases/download/v${version}/jj-v${version}-${arch_alias}.${ext}`，各平台后缀固定在配方中
- CN：尚未声明；`ci.mirror = true` 请求合并后复制官方资源，镜像地址由维护者另行审核
- 三份声明归档均实际下载两次，SHA256 一致，且与 GitHub Release 的官方资产摘要一致
- 自动更新：`extensions.autoupdate` 跟踪稳定 Release；只新增版本，不改历史资源

## 链接和依赖

- Linux 两架构使用官方 musl ELF，无动态库依赖
- Windows x86_64 PE 仅导入系统 DLL，不需要额外 MSVC runtime
- 各平台声明 `xim:git@>=2.42.0`，对应上游安装文档的运行要求；不使用宿主 Git 兜底
- macOS 和 Windows ARM64 资源已作下载格式检查，但不能仅凭 jj 二进制存在就承诺完整平台支持

## 钩子行为

- install：将平铺归档重新解压到独立安装目录，验证程序、LICENSE、README.md 三个文件；POSIX 设置执行权限
- config：向 xvm 注册安装目录中的 `jj`
- uninstall：移除 `jj` 注册，由 xlings 清理包载荷
- 不写入用户 Git/jj 配置、Shell 配置或环境变量；依赖包的行为由其独立配方负责

## 验证

- Linux x86_64，临时 HOME、XLINGS_HOME，使用 CI 固定的 xlings 2026.11.23.1
- 注册、搜索、安装、真实文件检查、版本、重复安装、卸载、重复卸载、覆盖项清理通过
- `pytest tests/j/test_jj.py -v`：7 项通过，包含临时仓库创建、记录文件、修改和恢复
- 工作流固定版本 updater 的 inspect/check 通过，状态 up-to-date；资源 hash 另行验证，未将该状态当作下载校验
- 基线全库静态/隔离检查：11427 passed、43 skipped、3 xpassed；既有 packer 隔离测试因 `xlings_home()` 返回字符串却使用路径运算符而失败
- Linux ARM64、Windows 本地未执行，交由 PR 原生 CI 验证；macOS 不在本包声明范围

## 修订记录

- 2026-11-27：新增 0.47.1；首版平台范围受 Git 依赖的索引覆盖限制
