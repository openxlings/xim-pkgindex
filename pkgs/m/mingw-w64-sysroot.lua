package = {
    spec = "2",
    homepage = "https://github.com/mstorsjo/llvm-mingw",

    name = "mingw-w64-sysroot",
    description = "MinGW-w64 (UCRT) sysroot with libc++, libunwind and compiler-rt, from llvm-mingw, for x86_64 and aarch64 Windows",

    maintainers = {"https://github.com/xlings-res/mingw-w64-sysroot"},
    licenses = {"ZPL-2.1", "Apache-2.0 WITH LLVM-exception", "MIT"},
    repo = "https://github.com/xlings-res/mingw-w64-sysroot",
    docs = "https://github.com/mcpp-community/mcpp/blob/main/docs/22-target-side.md",

    type = "package",
    -- Host arches, not target ones: the payload is target code and one archive
    -- serves every host.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"library", "sysroot", "libc"},
    keywords = {"mingw-w64", "windows", "ucrt", "libc++", "compiler-rt", "sysroot", "llvm-mingw"},

    -- No programs: a sysroot, not a tool. `config()` registers only the
    -- umbrella node so `xlings use mingw-w64-sysroot@<ver>` works.
    xvm_enable = true,

    -- The target side of llvm-mingw (Martin Storsjö; the maintainer of MinGW
    -- support in LLVM), UCRT variant: `generic-w64-mingw32/include` as `include`,
    -- `<arch>-w64-mingw32/{lib,bin}`, the compiler-rt runtime as
    -- `compiler-rt/lib/windows` and libc++'s std module sources as
    -- `share/libc++/v1`, taken without modification by
    -- `.agents/tools/build-mingw-w64-sysroot.py`. The package root is the sysroot
    -- of x86_64-windows-gnu and aarch64-windows-gnu; `mcpp.toml` at the root is
    -- the package manifest mcpp reads (provides, [build]).
    --
    -- Named `-sysroot` because `mingw-w64` is the winlibs toolchain on Windows
    -- hosts. The version is llvm-mingw's; `-<n>` is a packaging revision.
    -- No `ci` block: `mirror` would point the mirror at xlings-res itself, and a
    -- version bump re-runs the assembly script against a new upstream release,
    -- which is a human step.

    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/mingw-w64-sysroot/releases/download/${version}/mingw-w64-sysroot-${version}.tar.xz",
            CN = "https://gitcode.com/xlings-res/mingw-w64-sysroot/releases/download/${version}/mingw-w64-sysroot-${version}.tar.xz",
        },
        linux = {
            ["latest"] = { ref = "20261104-2" },
            ["20261104-2"] = { sha256 = "7bafe4815bb7b0dfd31f9d82d36f92fe5c5e0658eb58f48bf0a1f80c273ff065" },
            ["20261104-1"] = { sha256 = "9fe4af80676911cc8e23a612a0e3c449bda710a17e2c6424b05a8ee02d561d8f" },
            -- An earlier manifest form no mcpp release reads; kept as published.
            ["20261104"] = { sha256 = "66ca0c7c0f65a44e13ab7a28f6741dea5408250869adb02eaf92a01e96244f05" },
        },
        macosx = {
            ["latest"] = { ref = "20261104-2" },
            ["20261104-2"] = { sha256 = "7bafe4815bb7b0dfd31f9d82d36f92fe5c5e0658eb58f48bf0a1f80c273ff065" },
            ["20261104-1"] = { sha256 = "9fe4af80676911cc8e23a612a0e3c449bda710a17e2c6424b05a8ee02d561d8f" },
            -- An earlier manifest form no mcpp release reads; kept as published.
            ["20261104"] = { sha256 = "66ca0c7c0f65a44e13ab7a28f6741dea5408250869adb02eaf92a01e96244f05" },
        },
        windows = {
            ["latest"] = { ref = "20261104-2" },
            ["20261104-2"] = { sha256 = "7bafe4815bb7b0dfd31f9d82d36f92fe5c5e0658eb58f48bf0a1f80c273ff065" },
            ["20261104-1"] = { sha256 = "9fe4af80676911cc8e23a612a0e3c449bda710a17e2c6424b05a8ee02d561d8f" },
            -- An earlier manifest form no mcpp release reads; kept as published.
            ["20261104"] = { sha256 = "66ca0c7c0f65a44e13ab7a28f6741dea5408250869adb02eaf92a01e96244f05" },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- Files whose absence makes the base unusable, relative to the package root.
local required = {
    "mcpp.toml",
    "include/stdio.h", "include/windows.h", "include/c++/v1/__config_site",
    "x86_64-w64-mingw32/lib/crt2.o", "x86_64-w64-mingw32/lib/libc++.a",
    "x86_64-w64-mingw32/lib/libunwind.a", "x86_64-w64-mingw32/lib/libucrt.a",
    "aarch64-w64-mingw32/lib/crt2.o", "aarch64-w64-mingw32/lib/libc++.a",
    "compiler-rt/lib/windows/libclang_rt.builtins-x86_64.a",
    "compiler-rt/lib/windows/libclang_rt.builtins-aarch64.a",
    "share/libc++/v1/std.cppm",
}

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    local extracted = pkginfo.install_file():replace(".tar.xz", "")
    if not os.isdir(extracted) then
        raise("mingw-w64-sysroot payload not found at " .. extracted)
    end
    os.mv(extracted, dir)
    for _, f in ipairs(required) do
        if not os.isfile(path.join(dir, f)) then
            raise("mingw-w64-sysroot payload is missing " .. f)
        end
    end
    return true
end

function config()
    -- Umbrella node only. These are TARGET headers and libraries: published
    -- into the subos sysroot they would shadow the host's C library. A consumer
    -- (mcpp, as the sysroot a manifest at its root describes) names this directory.
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
