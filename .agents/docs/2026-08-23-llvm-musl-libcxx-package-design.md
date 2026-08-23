# xim:llvm-musl-libcxx 包设计方案

> 状态: **已落地待 review**（配合 mcpp#492 引擎侧 PR）
> 日期: 2026-08-23

## 动机

llvm 家族（clang 前端）不携带任何目标 libc；其 payload 的 `clang.cfg`
还把宿主 glibc 世界钉死在驱动上。`*-linux-musl` 从 llvm 家族服务需要三样
clang 不自带的东西：

1. 为 musl 目标配置的 libc++（宿主 libc++ 的 `__config_site` 描述的是另
   一个 ABI，不可复用）；
2. 基于该 libc++ 的 std/std.compat 模块源（在宿主 libc++ 上预编译的
   std BMI 在 PCM 层就是错的）；
3. crt/libgcc/libc —— musl-gcc 已提供，本包**不**重复：mcpp 引擎经
   `--gcc-toolchain` 指向 musl-gcc payload，这里只出 C++ 运行时。

## 形态

- `type = "package"`，`spec = "2"`，纯数据 payload（头文件 + 静态库 +
  模块源），无 programs，xvm 伞节点（同 `libcxx-headers` 先例：第二份
  C++ 标准库绝不能进宿主 sysroot，会遮蔽宿主自己的 libc++）。
- `archs = {"x86_64", "aarch64"}`：按**目标**架构双资产，每个一份权威
  sha256。资产为 `.tar.xz`，各约 1.5MB。
- 构建来源：llvm-project release/22.x runtimes
  （`LLVM_ENABLE_RUNTIMES=libcxx;libcxxabi;libunwind`），clang 22.1.8
  payload 交叉驱动进各目标 musl sysroot。仅静态（`.a`）：musl 目标是
  全静态 ELF 世界，动态 libc++ 无消费者。
- payload 布局（mcpp 的 llvm-musl 分支按此消费）：
  `include/c++/v1/`、`lib/libc++.a|libc++abi.a|libunwind.a`、
  `share/libc++/v1/std.cppm|std.compat.cppm` 及 `std/`、`std.compat/`
  导出表。

## 资源托管

暂存于贡献者 fork 的 release（`cloud-teahouse/mcpp` tag
`llvm-musl-libcxx-22.1.8`），sha256 已钉死字节；由维护者迁移至
xlings-res（GLOBAL + CN 双镜像）后改指 source 模板。故**未声明 `ci`
块**——`mirror` 会在资产未迁移前指向空仓库，`update` 会 bump 到尚不存在
的版本（资产需从新 llvm payload 逐目标重建，是带构建配方的人工步骤），
与 `libcxx-headers` 不声明 ci 的理由一致。

## 验证

- `pytest tests/ -m 'static or isolation'`：1887 passed（含本包 12 项）。
- 隔离 XLINGS_HOME 下 `config --add-xpkg` + `install` + `remove` 全链路
  实测通过：下载、sha256 校验、install 三断言（algorithm 头 / libc++.a
  / std.cppm）、卸载清理。
- 端到端（配合 mcpp#492）：等效直驱 clang 管线已产出全静态
  x86_64（本机运行）与 aarch64（qemu）二进制验证。

## 关联

- 引擎侧：mcpp-community/mcpp#492（`llvmSysroot` 列消费本包）
- 议题：mcpp-community/mcpp#491
