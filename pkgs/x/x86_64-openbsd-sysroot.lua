package = {
    spec = "2",
    homepage = "https://www.openbsd.org/",

    name = "x86_64-openbsd-sysroot",
    description = "OpenBSD base system sysroot for x86_64-openbsd (amd64) for compiling and linking, with libc++'s std module sources",

    maintainers = {"https://github.com/xlings-res/x86_64-openbsd-sysroot"},
    licenses = {"ISC", "BSD-2-Clause", "BSD-3-Clause", "Apache-2.0 WITH LLVM-exception"},
    repo = "https://github.com/xlings-res/x86_64-openbsd-sysroot",
    docs = "https://github.com/mcpp-community/mcpp-platforms",

    type = "package",
    -- Host arches, not target ones: the payload is target code and one archive
    -- serves every host.
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"library", "sysroot", "libc"},
    keywords = {"openbsd", "sysroot", "libc", "libc++", "cross"},

    -- No programs: a sysroot, not a tool. `config()` registers only the
    -- umbrella node.
    xvm_enable = true,

    -- From the official `base80.tgz` and `comp80.tgz` sets of OpenBSD 8.0 for amd64
    -- (cdn.openbsd.org, checked against the release's signed SHA256); one package
    -- per identity, and the package root is the sysroot of <arch>-openbsd:
    -- `usr/include`, the shared libraries and crt objects of `usr/lib`,
    -- `usr/libexec/ld.so`, and the static archives of the C library, the C++
    -- run-time and the compiler run-time. Two additions: each library's link name
    -- (`libc.so -> libc.so.104.0`), which OpenBSD's own linker does without and
    -- upstream lld needs, and libc++'s module sources, generated from the
    -- llvm-project release of the base's libc++ version. Assembled by
    -- `.agents/tools/build-openbsd-sysroot.py`; `mcpp.toml` at the root is the
    -- package manifest mcpp reads.
    -- The version is OpenBSD's. No `ci` block: a version bump re-runs the
    -- assembly script against a new upstream release, which is a human step.

    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/x86_64-openbsd-sysroot/releases/download/${version}/x86_64-openbsd-sysroot-${version}.tar.xz",
            CN = "https://gitcode.com/xlings-res/x86_64-openbsd-sysroot/releases/download/${version}/x86_64-openbsd-sysroot-${version}.tar.xz",
        },
        linux = {
            -- Target libraries, which no host loads: exported to no consumer
            -- and outside what rule M judges (libxpkg 0.0.68 reads {} as none).
            exports = { runtime = { libdirs = {} } },
            ["latest"] = { ref = "8.0" },
            ["8.0"] = { sha256 = { x86_64 = "1f9d125aadb8ec9ac1334e1616120307ab8517699981030d9b77283483d4454c", aarch64 = "1f9d125aadb8ec9ac1334e1616120307ab8517699981030d9b77283483d4454c" } },
        },
        macosx = {
            -- Target libraries, which no host loads: exported to no consumer
            -- and outside what rule M judges (libxpkg 0.0.68 reads {} as none).
            exports = { runtime = { libdirs = {} } },
            ["latest"] = { ref = "8.0" },
            ["8.0"] = { sha256 = "1f9d125aadb8ec9ac1334e1616120307ab8517699981030d9b77283483d4454c" },
        },
        windows = {
            -- Target libraries, which no host loads: exported to no consumer
            -- and outside what rule M judges (libxpkg 0.0.68 reads {} as none).
            exports = { runtime = { libdirs = {} } },
            ["latest"] = { ref = "8.0" },
            ["8.0"] = { sha256 = "1f9d125aadb8ec9ac1334e1616120307ab8517699981030d9b77283483d4454c" },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- Files whose absence makes the base unusable, relative to the package root.
local required = {
    "mcpp.toml", "PROVENANCE.md", "usr/include/stdio.h", "usr/lib/crt0.o", "usr/lib/libc.so", "usr/lib/libc.a", "usr/lib/libc++.so", "usr/lib/libc++abi.so", "usr/libexec/ld.so", "usr/share/libc++/v1/std.cppm",
}

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    local extracted = pkginfo.install_file():replace(".tar.xz", "")
    if not os.isdir(extracted) then
        raise("x86_64-openbsd-sysroot payload not found at " .. extracted)
    end
    os.mv(extracted, dir)
    for _, f in ipairs(required) do
        if not os.isfile(path.join(dir, f)) then
            raise("x86_64-openbsd-sysroot payload is missing " .. f)
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
