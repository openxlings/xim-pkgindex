# Android NDK libc++ Module Sources

**English** | [简体中文](zh/15-android-ndk-libcxx-modules.md)

`import std;` precompiles libc++'s module sources: `std.cppm`,
`std.compat.cppm` and their `std/*.inc`, `std.compat/*.inc` partitions, under
`share/libc++/v1`. Google's Linux and macOS NDK archives carry them; the
Windows archive does not. `xim:android-ndk-libcxx-modules` supplies them to
`xim:android-ndk` on Windows.

## What is missing, measured

Read from each NDK r30 (`30.0.16248370`) archive:

| Archive | Prebuilt host | `share/libc++/v1` | libc++ headers | clang |
|---|---|---|---|---|
| `android-ndk-r30-linux.zip` | `linux-x86_64` | 133 files | 1665 | 21.0.0, r574158c |
| `android-ndk-r30-darwin.zip` | `darwin-x86_64` | 133 files | 1665 | 21.0.0, r574158c |
| `android-ndk-r30-windows.zip` | `windows-x86_64` | absent | 1665 | 21.0.0, r574158c |

The libc++ headers (`sysroot/usr/include/c++/v1`) of the Linux and Windows
archives are byte-identical.

## Why the Windows archive lacks them

libc++ installs its module sources together with the libc++ it builds, under
that installation's `share/libc++/v1`. The NDK's Linux and macOS clang
toolchains are built with a host libc++ (the toolchain's own `lib/` holds it),
so the sources land in the toolchain prefix. The Windows toolchain is
cross-built for Windows without a host libc++, so no sources are installed
there. The Android target's libc++ is packaged separately in the sysroot,
which holds headers and libraries and never held the module sources. This
explanation is inferred from the archives' layout, not from a statement by
the NDK's maintainers.

The sources describe the target's libc++, not the host's. With one release,
one clang revision and identical headers, the Linux archive's sources are the
ones the Windows toolchain needs.

## How the package is made

```bash
python3 tools/res/android-ndk/libcxx_modules.py probe \
    https://dl.google.com/android/repository/android-ndk-r30-linux.zip \
    https://dl.google.com/android/repository/android-ndk-r30-windows.zip
bash tools/res/build.sh android-ndk-libcxx-modules 30.0.16248370 out
```

`probe` reads each archive's central directory with HTTP range requests and
reports the table above, so a new release is assessed without downloading
it. `build.sh` downloads both archives, checks them against the digests in
`tools/res/inputs.txt`, and runs `libcxx_modules.py extract`, which refuses
unless both archives are the requested `Pkg.Revision`, share one clang
revision, have byte-identical libc++ headers, and only the first has module
sources; it also reads the darwin archive's central directory with range
requests and refuses unless its module sources are the same files (CRC-32 and
size). The payload is the Linux archive's `share/libc++/v1`, unmodified, plus
`MANIFEST` (`<sha256>  <path>` per file), the release's `NOTICE.toolchain` and
`README.provenance`. It is packed as a data resource: sorted, owner 0, mtime 0,
so a rebuild produces the same bytes. The `res-build` workflow builds and
publishes it like every other resource ([Official Resources](11-official-resources.md)).

## How `xim:android-ndk` uses it

The `windows` entry of `xim:android-ndk` declares
`xim:android-ndk-libcxx-modules@<the same version>` as a build dependency.
`install()` walks `MANIFEST`, installs each file into
`toolchains/llvm/prebuilt/windows-x86_64/share/libc++/v1`, and compares it with
its source. The `linux` and `macosx` entries use the files their archives ship;
an existing version entry keeps its published form, and the derivation has
already checked that those files are the payload's.

The install's self-test then precompiles `std.cppm` for
`aarch64-linux-android24` on every host.

## A new NDK release

1. Run `probe` on the new release's archives. If the Windows archive carries
   `share/libc++/v1`, the new `windows` entry needs no module-sources
   dependency.
2. Otherwise add the release name to the `android-ndk-libcxx-modules` case of
   `tools/res/build.sh`, the two archive digests to `tools/res/inputs.txt` and
   the version to `.github/res-build-matrix.json`, then build and publish.
3. Add the version to both recipes in one change, the dependency on the new
   `windows` entry only;
   `tests/a/test_android_ndk_libcxx_modules.py` checks that they agree.
