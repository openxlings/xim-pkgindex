package = {
    spec = "2",
    homepage = "https://www.debian.org/ports/hurd/",
    name = "x86_64-hurd-sysroot",
    description = "Debian GNU/Hurd base system sysroot for x86_64-hurd (hurd-amd64) for compiling and linking: glibc on the Hurd, the Hurd's and GNU Mach's headers, GCC's run-time and libstdc++",

    maintainers = {"https://github.com/xlings-res/x86_64-hurd-sysroot"},
    licenses = {"LGPL-2.1-or-later", "GPL-2.0-or-later", "GPL-3.0-or-later WITH GCC-exception-3.1"},
    repo = "https://github.com/xlings-res/x86_64-hurd-sysroot",
    docs = "https://github.com/openxlings/xim-pkgindex/blob/main/.agents/tools/build-hurd-sysroot.py",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"library", "sysroot", "libc"},
    keywords = {"hurd", "gnu", "sysroot", "glibc", "libstdc++", "cross"},

    xvm_enable = true,

    -- A BASE PACKAGE: the package root is the sysroot, and its `mcpp.toml` states what it
    -- provides. Assembled from the packages of Debian's `hurd-amd64` port, each held to its
    -- digest (PROVENANCE.md in the archive lists them); the version is the day they were taken.
    -- It is data for a compiler on any host: nothing in it is run. 20260314 is taken at the
    -- versions Debian's pre-installed image of that day has (hurd-disk-image@20260314), from the
    -- archive's snapshot: a program is built against the libraries it runs with, and states GCC's
    -- std module. 20261118 (sid of its day) has a libstdc++ newer than that image's.
    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/x86_64-hurd-sysroot/releases/download/${version}/x86_64-hurd-sysroot-${version}.tar.xz",
            CN = "https://gitcode.com/xlings-res/x86_64-hurd-sysroot/releases/download/${version}/x86_64-hurd-sysroot-${version}.tar.xz",
        },
        linux = {
            -- Target libraries, which no host loads: exported to no consumer
            -- and outside what rule M judges (libxpkg 0.0.68 reads {} as none).
            exports = { runtime = { libdirs = {} } },
            ["latest"] = { ref = "20260314" },
            ["20260314"] = { sha256 = { x86_64 = "2ed3688e7b6c8f8a49a868e8c1c618f52b10ed522505a6274a5dc516963d49da", aarch64 = "2ed3688e7b6c8f8a49a868e8c1c618f52b10ed522505a6274a5dc516963d49da" } },
            ["20261118"] = { sha256 = { x86_64 = "69263c78c58498723fbf232b7ec52eb22d8dd9f9eb2c8ab181d5cd875db54b6f", aarch64 = "69263c78c58498723fbf232b7ec52eb22d8dd9f9eb2c8ab181d5cd875db54b6f" } },
        },
        macosx = {
            -- Target libraries, which no host loads: exported to no consumer
            -- and outside what rule M judges (libxpkg 0.0.68 reads {} as none).
            exports = { runtime = { libdirs = {} } },
            ["latest"] = { ref = "20260314" },
            ["20260314"] = { sha256 = "2ed3688e7b6c8f8a49a868e8c1c618f52b10ed522505a6274a5dc516963d49da" },
            ["20261118"] = { sha256 = "69263c78c58498723fbf232b7ec52eb22d8dd9f9eb2c8ab181d5cd875db54b6f" },
        },
        windows = {
            -- Target libraries, which no host loads: exported to no consumer
            -- and outside what rule M judges (libxpkg 0.0.68 reads {} as none).
            exports = { runtime = { libdirs = {} } },
            ["latest"] = { ref = "20260314" },
            ["20260314"] = { sha256 = "2ed3688e7b6c8f8a49a868e8c1c618f52b10ed522505a6274a5dc516963d49da" },
            ["20261118"] = { sha256 = "69263c78c58498723fbf232b7ec52eb22d8dd9f9eb2c8ab181d5cd875db54b6f" },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

local required = {
    "mcpp.toml", "PROVENANCE.md", "usr/include/stdio.h", "usr/include/hurd.h", "usr/include/mach.h",
    "usr/lib/x86_64-gnu/crt1.o", "usr/lib/x86_64-gnu/libc.so", "usr/lib/x86_64-gnu/libc.so.0.3",
    "usr/lib/x86_64-gnu/ld-x86-64.so.1",
}

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    local extracted = pkginfo.install_file():replace(".tar.xz", "")
    if not os.isdir(extracted) then
        raise("x86_64-hurd-sysroot payload not found at " .. extracted)
    end
    os.mv(extracted, dir)
    for _, f in ipairs(required) do
        if not os.isfile(path.join(dir, f)) then
            raise("x86_64-hurd-sysroot payload is missing " .. f)
        end
    end
    -- GCC's run-time, of the release the version took (16 in 20261118, 15 in 20260314).
    if not (os.isfile(path.join(dir, "usr/lib/gcc/x86_64-gnu/15/libgcc.a"))
            or os.isfile(path.join(dir, "usr/lib/gcc/x86_64-gnu/16/libgcc.a"))) then
        raise("x86_64-hurd-sysroot payload is missing usr/lib/gcc/x86_64-gnu/<15|16>/libgcc.a")
    end
    return true
end

function config()
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
