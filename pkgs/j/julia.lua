-- Julia is a high-level, high-performance dynamic programming language for
-- technical computing.
--
-- Verified against https://julialang-s3.julialang.org/bin/versions.json and
-- downloaded upstream archives for 1.13.4 (latest stable release):
--   linux    x86_64   julia-1.13.4-linux-x86_64.tar.gz
--   linux    aarch64  julia-1.13.4-linux-aarch64.tar.gz
--   macosx   x86_64   julia-1.13.4-mac64.tar.gz
--   macosx   aarch64  julia-1.13.4-macaarch64.tar.gz
--   windows  x86_64   julia-1.13.4-win64.zip (portable zip; no win64-arm64 upstream build)
--
-- Linking (measured across all 164 linux-x86_64 and 163 linux-aarch64 ELFs):
--   * `bin/julia`, `lib/libjulia.so.*`, `lib/julia/*.so*`, and `libexec/julia/*`
--     bundle `libstdc++.so.6`, `libgcc_s.so.1`, `libLLVM.so.20.1jl`,
--     `libunwind.so.8`, etc. via `$ORIGIN` RUNPATHs (`$ORIGIN/../lib:$ORIGIN/../lib/julia`
--     on `bin/julia`, `$ORIGIN:$ORIGIN/..` on `lib/julia/*.so*`), with max
--     `GLIBC_2.14` symbol requirements on `bin/julia` / `libjulia-internal.so`.
--   * External DT_NEEDED entries are exclusively core glibc libraries
--     (`ld-linux-*`, `libc.so.6`, `libdl.so.2`, `libm.so.6`, `libpthread.so.0`,
--     `librt.so.1`). Declaring `xim:glibc` triggers xlings `elfpatch`, which
--     replaces DT_RUNPATH rather than prepending to it — verified locally to
--     strip `$ORIGIN` and fail on startup with `libunwind.so.8: cannot open
--     shared object file`. Following SKILL.md §2 ("A payload that carries its
--     own libraries via `$ORIGIN` declares no `xim:glibc`"), no `deps` are
--     declared on Linux so `$ORIGIN` RUNPATHs remain intact against host glibc.
--   * Windows `win64.zip` is a MinGW-w64 build bundling `libgcc_s_seh-1.dll`,
--     `libstdc++-6.dll`, and `libwinpthread-1.dll` inside `bin/` and imports
--     only Windows OS DLLs (`KERNEL32.dll`, `msvcrt.dll`, etc.).
--
-- Manual maintenance (no extensions.autoupdate):
--   Official prebuilt binaries are published under
--   `https://julialang-s3.julialang.org/bin/<os>/<arch>/<major>.<minor>/julia-<ver>-...`
--   (JuliaLang/julia GitHub releases attach only source tarballs), and the
--   pinned xpkgindex-update template expander does not support `${version:minor}`.
--   `ci = { mirror = true }` mirrors the declared GLOBAL archives to xlings-res.

package = {
    spec = "2",

    name = "julia",
    description = "High-level, high-performance dynamic programming language for technical computing",
    homepage = "https://julialang.org",
    authors = {"Jeff Bezanson", "Stefan Karpinski", "Viral B. Shah", "Alan Edelman"},
    maintainers = {"https://github.com/JuliaLang/julia/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/JuliaLang/julia",
    docs = "https://docs.julialang.org",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"language", "compiler", "science", "tools"},
    keywords = {"julia", "julialang", "scientific-computing", "numerical", "jit"},

    programs = {"julia"},
    xvm_enable = true,

    xpm = {
        linux = {
            source = "https://julialang-s3.julialang.org/bin/linux/${arch_alias}/1.13/julia-${version}-linux-${arch}.tar.gz",
            ["latest"] = { ref = "1.13.4" },
            ["1.13.4"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "aarch64" },
                sha256 = {
                    x86_64  = "cf1658f13b91facccd57d41464d7125a0e48a1d24f49062d71532d04d4ec4130",
                    aarch64 = "d1814cb51e49a1ecd0c95ff0e4ac267ec5ddaba051f5eed2d866d55e40274de5",
                },
            },
        },
        macosx = {
            source = "https://julialang-s3.julialang.org/bin/mac/${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.13.4" },
            ["1.13.4"] = {
                arch_alias = {
                    x86_64  = "x64/1.13/julia-1.13.4-mac64",
                    aarch64 = "aarch64/1.13/julia-1.13.4-macaarch64",
                },
                sha256 = {
                    x86_64  = "c84de0fcb4268841f296fd56c47c27383d81358033428389b0d1882b110b9bcd",
                    aarch64 = "8e58a1993ecbadb9a762a987eefa4e484b364a8560349609cc05e93287b9a8fe",
                },
            },
        },
        windows = {
            source = "https://julialang-s3.julialang.org/bin/winnt/${arch_alias}/1.13/julia-${version}-win64.zip",
            ["latest"] = { ref = "1.13.4" },
            ["1.13.4"] = {
                arch_alias = { x86_64 = "x64" },
                sha256 = {
                    x86_64 = "ce956aa7c158be0e87be8b0857d950afab3b54e061e1b08f868087731d81417c",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local REQUIRED_COMMON = {
    "etc/julia/startup.jl",
    "share/julia/base.cache",
}

local function required_files(exe)
    local files = { exe }
    for _, rel in ipairs(REQUIRED_COMMON) do
        files[#files + 1] = rel
    end
    return files
end

function installed()
    return payload.present(required_files("bin/julia"))
        or payload.present(required_files("bin/julia.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file()):gsub("\\", "/")
    local exe = (archive:match("win64") or archive:match("%.zip$"))
        and "bin/julia.exe" or "bin/julia"
    payload.unpack{ extracted = "julia-" .. pkginfo.version(), strip = 1 }
    payload.require(required_files(exe))
    return true
end

function config()
    local bindir = pkginfo.install_dir() .. "/bin"
    local cfg = { bindir = bindir }
    if os.isfile(bindir .. "/julia.exe") then
        cfg.alias = "julia.exe"
    end
    xvm.add("julia", cfg)
    return true
end

function uninstall()
    xvm.remove("julia")
    return true
end
