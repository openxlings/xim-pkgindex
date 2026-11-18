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
            ["latest"] = { ref = "hrev60431" },
            ["hrev60431"] = { sha256 = "f418cddd5cf050b30046afe1664c9264a7aa6c4bedc7b04e337ad1afe1a47bb3" },
        },
        macosx = {
            ["latest"] = { ref = "hrev60431" },
            ["hrev60431"] = { sha256 = "f418cddd5cf050b30046afe1664c9264a7aa6c4bedc7b04e337ad1afe1a47bb3" },
        },
        windows = {
            ["latest"] = { ref = "hrev60431" },
            ["hrev60431"] = { sha256 = "f418cddd5cf050b30046afe1664c9264a7aa6c4bedc7b04e337ad1afe1a47bb3" },
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
