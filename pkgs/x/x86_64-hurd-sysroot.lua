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
    -- It is data for a compiler on any host: nothing in it is run.
    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/x86_64-hurd-sysroot/releases/download/${version}/x86_64-hurd-sysroot-${version}.tar.xz",
            CN = "https://gitcode.com/xlings-res/x86_64-hurd-sysroot/releases/download/${version}/x86_64-hurd-sysroot-${version}.tar.xz",
        },
        linux = {
            ["latest"] = { ref = "20261118" },
            ["20261118"] = { sha256 = "69263c78c58498723fbf232b7ec52eb22d8dd9f9eb2c8ab181d5cd875db54b6f" },
        },
        macosx = {
            ["latest"] = { ref = "20261118" },
            ["20261118"] = { sha256 = "69263c78c58498723fbf232b7ec52eb22d8dd9f9eb2c8ab181d5cd875db54b6f" },
        },
        windows = {
            ["latest"] = { ref = "20261118" },
            ["20261118"] = { sha256 = "69263c78c58498723fbf232b7ec52eb22d8dd9f9eb2c8ab181d5cd875db54b6f" },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

local required = {
    "mcpp.toml", "PROVENANCE.md", "usr/include/stdio.h", "usr/include/hurd.h", "usr/include/mach.h",
    "usr/lib/x86_64-gnu/crt1.o", "usr/lib/x86_64-gnu/libc.so", "usr/lib/x86_64-gnu/libc.so.0.3",
    "usr/lib/x86_64-gnu/ld-x86-64.so.1", "usr/lib/gcc/x86_64-gnu/16/libgcc.a",
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
