# asciinema

稳定版 3.2.1 提供终端录制、回放及格式转换。命名空间为 `xim`。

- 上游及许可证：https://github.com/asciinema/asciinema ，GPL-3.0。
- Linux 和 macOS 均提供 x86_64、aarch64 官方独立程序。上游没有 Windows 程序。
- GLOBAL 取自官方 Release。四个程序各下载两次，SHA256 均与 GitHub 资产摘要一致。配方声明自动更新和 CI 镜像复制。
- Linux x86_64 选用 musl 静态程序。ARM64 GNU 版本需要 glibc 和 libgcc_s，因此 Linux 平台声明两项运行依赖。
- 安装钩子复制程序并设置执行权限，配置钩子注册 asciinema。卸载交由 xlings 清理程序及路由，用户录制文件独立保存。
- Linux x86_64 在隔离 HOME 中完成安装、重复安装、录制、转换和卸载，包测试共五项通过。其他架构和 macOS 的原生运行由 CI 覆盖其可用 runner。

## 修订记录

- 2026-11-28 新增官方 3.2.1。
