package = {
    spec = "2",
    homepage = "https://www.netbsd.org/",

    name = "x86_64-netbsd-sysroot",
    description = "NetBSD base system sysroot for x86_64-netbsd (amd64) for compiling and linking, with GCC's libstdc++",

    maintainers = {"https://github.com/xlings-res/x86_64-netbsd-sysroot"},
    licenses = {"BSD-2-Clause", "BSD-3-Clause", "GPL-3.0-or-later WITH GCC-exception-3.1"},
    repo = "https://github.com/xlings-res/x86_64-netbsd-sysroot",
    docs = "https://github.com/mcpp-community/mcpp-platforms",

    type = "package",
    -- Host arches, not target ones: the payload is target code and one archive
    -- serves every host.
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"library", "sysroot", "libc"},
    keywords = {"netbsd", "sysroot", "libc", "libstdc++", "cross"},

    -- No programs: a sysroot, not a tool. `config()` registers only the
    -- umbrella node.
    xvm_enable = true,

    -- From the official `base.tar.xz` and `comp.tar.xz` sets of NetBSD 10.2 for amd64
    -- (cdn.netbsd.org, checked against the release's SHA512); one package per
    -- identity, and the package root is the sysroot of <arch>-netbsd: `usr/include`,
    -- the shared libraries of `lib/` and `usr/lib/`, `libexec/ld.elf_so`, crt objects
    -- and the static archives of the C library, the C++ run-time (GCC's libstdc++,
    -- which ships no module sources: the base states no `std-module`) and the
    -- compiler run-time. Assembled by `.agents/tools/build-netbsd-sysroot.py`;
    -- `mcpp.toml` at the root is the package manifest mcpp reads.
    -- The version is NetBSD's. No `ci` block: a version bump re-runs the
    -- assembly script against a new upstream release, which is a human step.

    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/x86_64-netbsd-sysroot/releases/download/${version}/x86_64-netbsd-sysroot-${version}.tar.xz",
            CN = "https://gitcode.com/xlings-res/x86_64-netbsd-sysroot/releases/download/${version}/x86_64-netbsd-sysroot-${version}.tar.xz",
        },
        linux = {
            -- Target libraries, which no host loads: exported to no consumer
            -- and outside what rule M judges (libxpkg 0.0.68 reads {} as none).
            exports = { runtime = { libdirs = {} } },
            ["latest"] = { ref = "10.2" },
            ["10.2"] = { sha256 = { x86_64 = "fb61ee3f84a88ba001f5515ec37771c585b12ca8e312141dad65dd84a26bb799", aarch64 = "fb61ee3f84a88ba001f5515ec37771c585b12ca8e312141dad65dd84a26bb799" } },
        },
        macosx = {
            -- Target libraries, which no host loads: exported to no consumer
            -- and outside what rule M judges (libxpkg 0.0.68 reads {} as none).
            exports = { runtime = { libdirs = {} } },
            ["latest"] = { ref = "10.2" },
            ["10.2"] = { sha256 = "fb61ee3f84a88ba001f5515ec37771c585b12ca8e312141dad65dd84a26bb799" },
        },
        windows = {
            -- Target libraries, which no host loads: exported to no consumer
            -- and outside what rule M judges (libxpkg 0.0.68 reads {} as none).
            exports = { runtime = { libdirs = {} } },
            ["latest"] = { ref = "10.2" },
            ["10.2"] = { sha256 = "fb61ee3f84a88ba001f5515ec37771c585b12ca8e312141dad65dd84a26bb799" },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- Files whose absence makes the base unusable, relative to the package root.
local required = {
    "mcpp.toml", "PROVENANCE.md", "usr/include/stdio.h", "usr/lib/crt0.o", "lib/libc.so.12", "usr/lib/libc.a", "usr/lib/libstdc++.so", "usr/lib/libgcc_s.so", "libexec/ld.elf_so",
}

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    local extracted = pkginfo.install_file():replace(".tar.xz", "")
    if not os.isdir(extracted) then
        raise("x86_64-netbsd-sysroot payload not found at " .. extracted)
    end
    os.mv(extracted, dir)
    for _, f in ipairs(required) do
        if not os.isfile(path.join(dir, f)) then
            raise("x86_64-netbsd-sysroot payload is missing " .. f)
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
