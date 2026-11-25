# julia

High-level, high-performance dynamic programming language for technical computing (`julia` CLI and runtime, status: stable).

- Upstream: https://julialang.org / https://github.com/JuliaLang/julia (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64` portable zip; no upstream Windows ARM64 build exists)

## Source

- Tier: official upstream release (`julialang-s3.julialang.org` indexed by `https://julialang-s3.julialang.org/bin/versions.json`)
- GLOBAL:
  - `linux`: `https://julialang-s3.julialang.org/bin/linux/${arch_alias}/1.13/julia-${version}-linux-${arch}.tar.gz` (`x64` / `aarch64`)
  - `macosx`: `https://julialang-s3.julialang.org/bin/mac/${arch_alias}.tar.gz` (`x64/1.13/julia-1.13.4-mac64` / `aarch64/1.13/julia-1.13.4-macaarch64`)
  - `windows`: `https://julialang-s3.julialang.org/bin/winnt/${arch_alias}/1.13/julia-${version}-win64.zip` (`x64`)
- CN: none yet (`ci = { mirror = true }` mirrors GLOBAL archives to `xlings-res` after merge)
- Checksums: taken from `https://julialang-s3.julialang.org/bin/versions.json` and independently verified by downloading and hashing all 5 archives (`1.13.4`)
- Auto-update: no — `JuliaLang/julia` GitHub releases attach only source tarballs, and the S3 prebuilt binary URLs embed `<major>.<minor>` (`/1.13/`) which the pinned `xpkgindex-update` expander does not support (`${version:minor}` is rejected as an unknown placeholder)

## Linking

- Linux (`x86_64` 164 ELFs, `aarch64` 163 ELFs): `bin/julia`, `lib/libjulia.so.1.13.4`, `lib/julia/*.so*`, and `libexec/julia/*` bundle `libstdc++.so.6`, `libgcc_s.so.1`, `libLLVM.so.20.1jl`, `libunwind.so.8`, etc. via `$ORIGIN` RUNPATHs. External `DT_NEEDED` entries are exclusively core glibc (`ld-linux-*`, `libc.so.6`, `libdl.so.2`, `libm.so.6`, `libpthread.so.0`, `librt.so.1`). Declaring `xim:glibc` triggers `elfpatch`, which replaces `DT_RUNPATH` and breaks `$ORIGIN` resolution (`libunwind.so.8` not found); per `SKILL.md` §2, no `deps` are declared on Linux so `$ORIGIN` RUNPATHs stay intact against host glibc.
- Windows (`win64.zip`): MinGW-w64 build bundling `libgcc_s_seh-1.dll`, `libstdc++-6.dll`, and `libwinpthread-1.dll` in `bin/`, importing only Windows OS DLLs (`KERNEL32.dll`, `msvcrt.dll`, etc.; no MSVC CRT dependency).

## What the hooks do

- `install`: unpacks `julia-<version>/` into `pkginfo.install_dir()` via `payload.unpack` (and `System32\tar.exe --strip-components=1` for `.zip` on Windows), then verifies `bin/julia` (or `bin/julia.exe`), `etc/julia/startup.jl`, and `share/julia/base.cache`.
- `config`: registers `julia` with `xvm.add("julia", { bindir = pkginfo.install_dir() .. "/bin", ... })` (adding `alias = "julia.exe"` when `bin/julia.exe` is present).
- `uninstall`: calls `xvm.remove("julia")`.
- System impact: none outside `pkginfo.install_dir()` and the subos `julia` shim.

## Verification

- Verified locally on Linux `x86_64` in an isolated `XLINGS_HOME`: `xlings config --add-xpkg`, `xlings search julia`, `xlings install julia@1.13.4 -y`, `julia --version`, `julia -e 'println(1+1)'`, `dep-closure-check.sh`, idempotent reinstall, `xlings remove julia -y`, repeat remove, and `xlings config --remove-xpkg julia`.
- Not run locally: `linux/aarch64`, `macosx/x86_64`, `macosx/aarch64`, `windows/x86_64` (archives downloaded and checksums/layouts/PE imports verified on Linux `x86_64`; native execution left to CI runners).

## Revision log

- 2026-11-25 — added at 1.13.4: Linux (`x86_64`, `aarch64`), macOS (`x86_64`, `aarch64`), Windows (`x86_64` portable zip).
