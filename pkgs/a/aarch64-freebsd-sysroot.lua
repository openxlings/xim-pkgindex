package = {
    spec = "2",
    homepage = "https://www.freebsd.org/",

    name = "aarch64-freebsd-sysroot",
    description = "FreeBSD base system sysroot for aarch64-freebsd (arm64) for compiling and linking, with libc++'s std module sources",

    maintainers = {"https://github.com/xlings-res/aarch64-freebsd-sysroot"},
    licenses = {"BSD-2-Clause", "BSD-3-Clause", "Apache-2.0 WITH LLVM-exception"},
    repo = "https://github.com/xlings-res/aarch64-freebsd-sysroot",
    docs = "https://github.com/mcpp-community/mcpp/blob/main/docs/22-target-side.md",

    type = "package",
    -- Host arches, not target ones: the payload is target code and one archive
    -- serves every host.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"library", "sysroot", "libc"},
    keywords = {"freebsd", "sysroot", "libc", "libc++", "cross"},

    -- No programs: a sysroot, not a tool. `config()` registers only the
    -- umbrella node so `xlings use freebsd-sysroot@<ver>` works.
    xvm_enable = true,

    -- From the official `base.txz` set of FreeBSD <version>-RELEASE for arm64
    -- (download.freebsd.org); one package per identity, and the package root is
    -- the sysroot of aarch64-freebsd: `usr/include`, the shared libraries,
    -- `libexec/ld-elf.so.1`, crt objects and the static archives of the C
    -- library, the C++ run-time and the compiler run-time; without FreeBSD's own
    -- toolchain (`usr/lib/clang`, `libprivate*`). FreeBSD installs no std.cppm,
    -- so libc++'s module sources are generated from the official libcxx source
    -- release of the base's libc++ version. Assembled by
    -- `.agents/tools/build-freebsd-sysroot.py`; `mcpp.toml` at the root is the
    -- package manifest mcpp reads (provides, [build]). The version is FreeBSD's.
    -- No `ci` block: `mirror` would point the mirror at xlings-res itself, and a
    -- version bump re-runs the assembly script against a new upstream release,
    -- which is a human step.
    --
    -- Revision 2 (same version key, new asset, the same release): the crt
    -- objects and static archives of `usr/lib` have their debug sections
    -- decompressed. FreeBSD compresses them with zlib, and a linker built
    -- without zlib reads no such section: every link against this base on a
    -- Windows host stopped at `crtend.o` ("is compressed with
    -- ELFCOMPRESS_ZLIB, but lld is not built with zlib support"). The
    -- sections' contents are those of the release; PROVENANCE.md states it.
    --
    -- Revision 3 (same version key, new asset): the release's link inputs
    -- again. The Windows link that stopped at `crtend.o` ran the ld.lld of
    -- the host's PATH, since the llvm payload for Windows shipped none; the
    -- payload's own lld reads zlib (llvm 23.1.3 revision 4 ships ld.lld.exe).
    -- The archive is revision 1's, its directory renamed, with a
    -- README.provenance (tools/res/build.sh, `aarch64-freebsd-sysroot
    -- 14.5-r3`).

    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/aarch64-freebsd-sysroot/releases/download/${version}/aarch64-freebsd-sysroot-${version}.tar.xz",
            CN = "https://gitcode.com/xlings-res/aarch64-freebsd-sysroot/releases/download/${version}/aarch64-freebsd-sysroot-${version}.tar.xz",
        },
        linux = {
            -- Target libraries, which no host loads: exported to no consumer
            -- and outside what rule M judges (libxpkg 0.0.68 reads {} as none).
            exports = { runtime = { libdirs = {} } },
            ["latest"] = { ref = "14.5" },
            ["14.5"] = {
                revision = 3,
                url = {
                    GLOBAL = "https://github.com/xlings-res/aarch64-freebsd-sysroot/releases/download/14.5-r3/aarch64-freebsd-sysroot-14.5-r3.tar.xz",
                    CN = "https://gitcode.com/xlings-res/aarch64-freebsd-sysroot/releases/download/14.5-r3/aarch64-freebsd-sysroot-14.5-r3.tar.xz",
                },
                sha256 = { x86_64 = "b73f2f0f9b9569c162674b141babc427292b9cdbeb8041dfb882261e60484115", aarch64 = "b73f2f0f9b9569c162674b141babc427292b9cdbeb8041dfb882261e60484115" },
            },
        },
        macosx = {
            -- Target libraries, which no host loads: exported to no consumer
            -- and outside what rule M judges (libxpkg 0.0.68 reads {} as none).
            exports = { runtime = { libdirs = {} } },
            ["latest"] = { ref = "14.5" },
            ["14.5"] = {
                revision = 3,
                url = {
                    GLOBAL = "https://github.com/xlings-res/aarch64-freebsd-sysroot/releases/download/14.5-r3/aarch64-freebsd-sysroot-14.5-r3.tar.xz",
                    CN = "https://gitcode.com/xlings-res/aarch64-freebsd-sysroot/releases/download/14.5-r3/aarch64-freebsd-sysroot-14.5-r3.tar.xz",
                },
                sha256 = "b73f2f0f9b9569c162674b141babc427292b9cdbeb8041dfb882261e60484115",
            },
        },
        windows = {
            -- Target libraries, which no host loads: exported to no consumer
            -- and outside what rule M judges (libxpkg 0.0.68 reads {} as none).
            exports = { runtime = { libdirs = {} } },
            ["latest"] = { ref = "14.5" },
            ["14.5"] = {
                revision = 3,
                url = {
                    GLOBAL = "https://github.com/xlings-res/aarch64-freebsd-sysroot/releases/download/14.5-r3/aarch64-freebsd-sysroot-14.5-r3.tar.xz",
                    CN = "https://gitcode.com/xlings-res/aarch64-freebsd-sysroot/releases/download/14.5-r3/aarch64-freebsd-sysroot-14.5-r3.tar.xz",
                },
                sha256 = "b73f2f0f9b9569c162674b141babc427292b9cdbeb8041dfb882261e60484115",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- Files whose absence makes the base unusable, relative to the package root.
local required = {
    "mcpp.toml", "PROVENANCE.md",
    "usr/include/stdio.h", "usr/lib/crt1.o", "lib/libc.so.7", "usr/lib/libc.a",
    "usr/lib/libc++.a", "usr/lib/libcxxrt.a", "libexec/ld-elf.so.1",
    "usr/share/libc++/v1/std.cppm",
}

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    local extracted = pkginfo.install_file():replace(".tar.xz", "")
    if not os.isdir(extracted) then
        raise("freebsd-sysroot payload not found at " .. extracted)
    end
    os.mv(extracted, dir)
    for _, f in ipairs(required) do
        if not os.isfile(path.join(dir, f)) then
            raise("freebsd-sysroot payload is missing " .. f)
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
