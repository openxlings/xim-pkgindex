package = {
    spec = "2",
    homepage = "https://www.haiku-os.org/",
    name = "x86_64-haiku-sysroot",
    description = "Haiku base system sysroot for x86_64-haiku for compiling and linking: libroot and the system's libraries, Haiku's headers and start files, GCC's run-time and libstdc++",

    maintainers = {"https://github.com/xlings-res/x86_64-haiku-sysroot"},
    licenses = {"MIT", "GPL-3.0-or-later WITH GCC-exception-3.1"},
    repo = "https://github.com/xlings-res/x86_64-haiku-sysroot",
    docs = "https://github.com/openxlings/xim-pkgindex/blob/main/.agents/tools/build-haiku-sysroot.py",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"library", "sysroot", "libc"},
    keywords = {"haiku", "sysroot", "libroot", "libstdc++", "cross"},

    xvm_enable = true,

    -- A BASE PACKAGE: the package root is the sysroot, and its `mcpp.toml` states what it
    -- provides. Assembled from Haiku's own packages (the system's and HaikuPorts' GCC run-time),
    -- each held to its digest and read by `hpkg.py` (PROVENANCE.md in the archive lists them);
    -- the version is the system's revision. It is laid out as a running system (boot/system),
    -- which is where a compiler for Haiku looks beneath a sysroot.
    -- It is data for a compiler on any host: nothing in it is run.
    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/x86_64-haiku-sysroot/releases/download/${version}/x86_64-haiku-sysroot-${version}.tar.xz",
            CN = "https://gitcode.com/xlings-res/x86_64-haiku-sysroot/releases/download/${version}/x86_64-haiku-sysroot-${version}.tar.xz",
        },
        linux = {
            -- Target libraries, which no host loads: exported to no consumer
            -- and outside what rule M judges (libxpkg 0.0.68 reads {} as none).
            exports = { runtime = { libdirs = {} } },
            ["latest"] = { ref = "hrev60431" },
            ["hrev60431"] = {
                -- r1: the std module (GCC's sources, libstdc++'s include directories), libstdc++
                -- linked by name, and <fenv.h>'s seven functions with external linkage in C++
                -- (PROVENANCE.md). An r0 payload has no std module: floor 1.
                revision = 1,
                floor = 1,
                url = {
                    GLOBAL = "https://github.com/xlings-res/x86_64-haiku-sysroot/releases/download/hrev60431-r1/x86_64-haiku-sysroot-hrev60431-r1.tar.xz",
                    CN = "https://gitcode.com/xlings-res/x86_64-haiku-sysroot/releases/download/hrev60431-r1/x86_64-haiku-sysroot-hrev60431-r1.tar.xz",
                },
                sha256 = { x86_64 = "4c72ec4137d95cb82e5b8f9d2bf1ef8967dc41f1a72f7e7814f42215bab102e2", aarch64 = "4c72ec4137d95cb82e5b8f9d2bf1ef8967dc41f1a72f7e7814f42215bab102e2" },
            },
        },
        macosx = {
            -- Target libraries, which no host loads: exported to no consumer
            -- and outside what rule M judges (libxpkg 0.0.68 reads {} as none).
            exports = { runtime = { libdirs = {} } },
            ["latest"] = { ref = "hrev60431" },
            ["hrev60431"] = {
                -- r1: the std module (GCC's sources, libstdc++'s include directories), libstdc++
                -- linked by name, and <fenv.h>'s seven functions with external linkage in C++
                -- (PROVENANCE.md). An r0 payload has no std module: floor 1.
                revision = 1,
                floor = 1,
                url = {
                    GLOBAL = "https://github.com/xlings-res/x86_64-haiku-sysroot/releases/download/hrev60431-r1/x86_64-haiku-sysroot-hrev60431-r1.tar.xz",
                    CN = "https://gitcode.com/xlings-res/x86_64-haiku-sysroot/releases/download/hrev60431-r1/x86_64-haiku-sysroot-hrev60431-r1.tar.xz",
                },
                sha256 = "4c72ec4137d95cb82e5b8f9d2bf1ef8967dc41f1a72f7e7814f42215bab102e2",
            },
        },
        windows = {
            -- Target libraries, which no host loads: exported to no consumer
            -- and outside what rule M judges (libxpkg 0.0.68 reads {} as none).
            exports = { runtime = { libdirs = {} } },
            ["latest"] = { ref = "hrev60431" },
            ["hrev60431"] = {
                -- r1: the std module (GCC's sources, libstdc++'s include directories), libstdc++
                -- linked by name, and <fenv.h>'s seven functions with external linkage in C++
                -- (PROVENANCE.md). An r0 payload has no std module: floor 1.
                revision = 1,
                floor = 1,
                url = {
                    GLOBAL = "https://github.com/xlings-res/x86_64-haiku-sysroot/releases/download/hrev60431-r1/x86_64-haiku-sysroot-hrev60431-r1.tar.xz",
                    CN = "https://gitcode.com/xlings-res/x86_64-haiku-sysroot/releases/download/hrev60431-r1/x86_64-haiku-sysroot-hrev60431-r1.tar.xz",
                },
                sha256 = "4c72ec4137d95cb82e5b8f9d2bf1ef8967dc41f1a72f7e7814f42215bab102e2",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

local required = {
    "mcpp.toml", "PROVENANCE.md", "boot/system/develop/headers/posix/stdio.h",
    "boot/system/develop/headers/os/kernel/OS.h", "boot/system/develop/lib/crti.o",
    "boot/system/develop/lib/start_dyn.o", "boot/system/develop/lib/crtbeginS.o",
    "boot/system/develop/lib/libgcc.a", "boot/system/lib/libroot.so", "boot/system/lib/libgcc_s.so.1",
}

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    local extracted = pkginfo.install_file():replace(".tar.xz", "")
    if not os.isdir(extracted) then
        raise("x86_64-haiku-sysroot payload not found at " .. extracted)
    end
    os.mv(extracted, dir)
    for _, f in ipairs(required) do
        if not os.isfile(path.join(dir, f)) then
            raise("x86_64-haiku-sysroot payload is missing " .. f)
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
