package = {
    spec = "2",
    homepage = "https://www.freebsd.org/",

    name = "freebsd-sysroot",
    description = "FreeBSD base system sysroot (amd64, arm64) for compiling and linking, with libc++'s std module sources",

    maintainers = {"https://github.com/xlings-res/freebsd-sysroot"},
    licenses = {"BSD-2-Clause", "BSD-3-Clause", "Apache-2.0 WITH LLVM-exception"},
    repo = "https://github.com/xlings-res/freebsd-sysroot",
    docs = "https://github.com/mcpp-community/mcpp/blob/main/docs/22-target-side.md",

    type = "package",
    -- Host arches, not target ones: the payload is target code and one archive
    -- serves every host.
    archs = {"x86_64", "aarch64"},
    -- SUPERSEDED by one package per identity, x86_64-freebsd-sysroot and
    -- aarch64-freebsd-sysroot: this archive carries an earlier manifest form
    -- (a `[base]` table) that no mcpp release reads. Kept, as every published
    -- descriptor is.
    status = "deprecated",
    categories = {"library", "sysroot", "libc"},
    keywords = {"freebsd", "sysroot", "libc", "libc++", "cross"},

    -- No programs: a sysroot, not a tool. `config()` registers only the
    -- umbrella node so `xlings use freebsd-sysroot@<ver>` works.
    xvm_enable = true,

    -- From the official `base.txz` sets of FreeBSD <version>-RELEASE
    -- (download.freebsd.org), one sysroot per architecture (`amd64/`, `arm64/`):
    -- `usr/include`, the shared libraries, `libexec/ld-elf.so.1`, crt objects and
    -- the static archives of the C library, the C++ run-time and the compiler
    -- run-time; without FreeBSD's own toolchain (`usr/lib/clang`, `libprivate*`).
    -- FreeBSD installs no std.cppm, so libc++'s module sources are generated
    -- from the official libcxx source release of the base's libc++ version.
    -- Assembled by `.agents/tools/build-freebsd-sysroot.py`; `mcpp.toml` at the
    -- top is the base statement mcpp reads. The version is FreeBSD's.
    -- No `ci` block: `mirror` would point the mirror at xlings-res itself, and a
    -- version bump re-runs the assembly script against a new upstream release,
    -- which is a human step.

    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/freebsd-sysroot/releases/download/${version}/freebsd-sysroot-${version}.tar.xz",
            CN = "https://gitcode.com/xlings-res/freebsd-sysroot/releases/download/${version}/freebsd-sysroot-${version}.tar.xz",
        },
        linux = {
            ["latest"] = { ref = "14.5" },
            ["14.5"] = { sha256 = "64aea3ebb229e6f27f93397631f5504a2a25868daab604bbf4d8e6ad9c653b8d" },
        },
        macosx = {
            ["latest"] = { ref = "14.5" },
            ["14.5"] = { sha256 = "64aea3ebb229e6f27f93397631f5504a2a25868daab604bbf4d8e6ad9c653b8d" },
        },
        windows = {
            ["latest"] = { ref = "14.5" },
            ["14.5"] = { sha256 = "64aea3ebb229e6f27f93397631f5504a2a25868daab604bbf4d8e6ad9c653b8d" },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- Files whose absence makes the base unusable, relative to the package root.
local required = {
    "mcpp.toml",
    "amd64/usr/include/stdio.h", "amd64/usr/lib/crt1.o", "amd64/lib/libc.so.7",
    "amd64/usr/lib/libc.a", "amd64/usr/lib/libc++.a", "amd64/libexec/ld-elf.so.1",
    "amd64/usr/share/libc++/v1/std.cppm",
    "arm64/usr/include/stdio.h", "arm64/usr/lib/crt1.o", "arm64/lib/libc.so.7",
    "arm64/usr/lib/libc.a", "arm64/usr/lib/libc++.a", "arm64/libexec/ld-elf.so.1",
    "arm64/usr/share/libc++/v1/std.cppm",
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
    -- (mcpp, through the base statement in `mcpp.toml`) names this directory.
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
