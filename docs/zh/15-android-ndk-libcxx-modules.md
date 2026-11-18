# Android NDK 的 libc++ 模块源

[English](../15-android-ndk-libcxx-modules.md) | **简体中文**

`import std;` 预编译的是 libc++ 的模块源：`share/libc++/v1` 下的 `std.cppm`、
`std.compat.cppm` 及其 `std/*.inc`、`std.compat/*.inc` 分区。Google 的 Linux 与
macOS NDK 压缩包带有这些文件，Windows 压缩包没有。`xim:android-ndk-libcxx-modules`
在 Windows 上把它们提供给 `xim:android-ndk`。

## 缺了什么（实测）

逐个读取 NDK r30（`30.0.16248370`）压缩包：

| 压缩包 | 预编译主机 | `share/libc++/v1` | libc++ 头文件 | clang |
|---|---|---|---|---|
| `android-ndk-r30-linux.zip` | `linux-x86_64` | 133 个文件 | 1665 | 21.0.0, r574158c |
| `android-ndk-r30-darwin.zip` | `darwin-x86_64` | 133 个文件 | 1665 | 21.0.0, r574158c |
| `android-ndk-r30-windows.zip` | `windows-x86_64` | 缺失 | 1665 | 21.0.0, r574158c |

Linux 与 Windows 压缩包的 libc++ 头文件（`sysroot/usr/include/c++/v1`）逐字节相同。

## Windows 压缩包为什么没有

libc++ 把模块源和它所构建的 libc++ 一起安装到该安装位置的 `share/libc++/v1`。
NDK 的 Linux 与 macOS clang 工具链构建时带有主机 libc++（工具链自己的 `lib/`
里就有），所以模块源落在工具链前缀下。Windows 工具链是为 Windows 交叉构建的，
没有主机 libc++，因此那里不会安装模块源。Android 目标的 libc++ 另外打包在
sysroot 中，sysroot 只有头文件和库，从来不含模块源。这一解释是从压缩包的布局
推断的，并非 NDK 维护者的说明。

模块源描述的是目标的 libc++，而不是主机的。同一个版本、同一个 clang 修订、
头文件完全相同，Linux 压缩包里的模块源正是 Windows 工具链所缺的那一份。

## 这个包怎样制作

```bash
python3 tools/res/android-ndk/libcxx_modules.py probe \
    https://dl.google.com/android/repository/android-ndk-r30-linux.zip \
    https://dl.google.com/android/repository/android-ndk-r30-windows.zip
bash tools/res/build.sh android-ndk-libcxx-modules 30.0.16248370 out
```

`probe` 用 HTTP Range 请求读取每个压缩包的中央目录，输出上面的表格，无需下载
就能评估一个新版本。`build.sh` 下载两个压缩包，按 `tools/res/inputs.txt` 中的
摘要校验，然后运行 `libcxx_modules.py extract`：只有两个压缩包都是所要求的
`Pkg.Revision`、clang 修订相同、libc++ 头文件逐字节相同、且只有第一个带模块源时
才会继续；它还用 Range 请求读取 darwin 压缩包的中央目录，其模块源必须是相同的
文件（CRC-32 与大小一致）。产物是 Linux 压缩包的 `share/libc++/v1`（原样），加上 `MANIFEST`
（每个文件一行 `<sha256>  <路径>`）、该版本的 `NOTICE.toolchain` 和
`README.provenance`。它按数据资源打包：排序、属主 0、mtime 0，因此重新构建得到
相同的字节。`res-build` 工作流像构建和发布其他资源一样构建和发布它
（[官方资源](11-official-resources.md)）。

## `xim:android-ndk` 怎样使用它

`xim:android-ndk` 的 `windows` 条目把 `xim:android-ndk-libcxx-modules@<同一版本>`
声明为构建依赖。`install()` 逐行读取 `MANIFEST`，把每个文件安装到
`toolchains/llvm/prebuilt/windows-x86_64/share/libc++/v1`，并与源文件比对。
`linux` 与 `macosx` 条目使用压缩包自带的文件；已有的版本条目保持发布时的形式，
而派生过程已经核对过这些文件就是本包的内容。

随后安装自检在每个主机上都为 `aarch64-linux-android24` 预编译 `std.cppm`。

## 新的 NDK 版本

1. 对新版本的压缩包运行 `probe`。如果 Windows 压缩包带有 `share/libc++/v1`，
   新的 `windows` 条目就不需要模块源依赖。
2. 否则把版本名加入 `tools/res/build.sh` 的 `android-ndk-libcxx-modules` 分支，
   把两个压缩包的摘要加入 `tools/res/inputs.txt`，把版本加入
   `.github/res-build-matrix.json`，然后构建并发布。
3. 在同一次改动中把版本加入两个配方，依赖只加在新的 `windows` 条目上；
   `tests/a/test_android_ndk_libcxx_modules.py` 检查二者一致。
