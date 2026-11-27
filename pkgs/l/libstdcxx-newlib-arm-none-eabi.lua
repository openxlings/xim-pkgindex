-- libstdcxx-newlib-arm-none-eabi: libstdc++ and libsupc++ of GCC 14.2.0 (full and
-- nano) for every multilib of ZheFeng7110:arm-none-eabi-gcc 14.2.0, built against
-- newlib-arm-none-eabi 4.5.0.20241231 -- IN A COMPLETE SYSROOT THAT CARRIES THAT
-- NEWLIB, selected with `--sysroot=<this package>/arm-none-eabi`. The payload is
-- what `xlings install fromsource:libstdcxx-newlib-arm-none-eabi@14.2.0` builds,
-- exported by tools/fromsource.sh of
-- https://github.com/ZheFeng7110/xlings-arm-none-eabi-gcc (README.provenance names
-- the recipe commit, the xlings client and the factory image).
--
--   arm-none-eabi/                       newlib-arm-none-eabi 4.5.0.20241231, whole, plus
--   arm-none-eabi/include/c++/14.2.0/    the C++ headers (per multilib: arm-none-eabi/<multilib>/bits)
--   arm-none-eabi/lib/<multilib>/        libstdc++.a libsupc++.a ... libstdc++_nano.a libsupc++_nano.a
--
-- ⭐ C AND C++ IN ONE SYSROOT. A compiler takes one --sysroot, and the C++ headers
-- and libraries must be in the same one as the C library's: this package is the
-- newlib sysroot with libstdc++ added, not an add-on to newlib-arm-none-eabi (which
-- it does not need). The names are Arm GNU Toolchain's: `--specs=nano.specs`
-- (STM32CubeMX) maps -lstdc++ to -lstdc++_nano, built as Arm builds it: -Os,
-- -fno-exceptions, against newlib-nano.
--
-- ⚠️ IT NEEDS arm-none-eabi-gcc 14.2.0 REVISION 1 OR LATER: from that revision the
-- compiler looks for its C++ headers in the sysroot (--with-gxx-include-dir under
-- it). Revision 0 looks in its own prefix and does not find these.
--
-- ⭐ NOT A CLONE OF ARM'S: std::filesystem WORKS when the project provides the POSIX
-- functions it calls (mkdir, getcwd, chdir, chmod, ... -- under those names, e.g.
-- over FatFs or littlefs; newlib has none of them on arm). Arm GNU Toolchain's
-- libstdc++ is built without them: there every such operation returns "Function
-- not implemented". The other side of it: an operation used without its function
-- is a link error here, not a run-time one (a stub that sets errno = ENOSYS and
-- returns -1 gives Arm's behaviour). With -Wl,--gc-sections (CubeMX) only what is
-- used is needed: create_directory needs mkdir, current_path getcwd and pathconf. std::random_device uses no entropy syscall,
-- as in Arm's (std::runtime_error reaches it; nothing defines _getentropy).
--
-- ⚠️ ONE GCC VERSION: libstdc++ is part of GCC; this version is the compiler's.
--
-- ⚠️ A target sysroot, not a host library: nothing enters the SubOS's include or lib
-- path. Target code: ONE archive (one sha256) serves every host.
--
-- ⭐ NAMESPACE ZheFeng7110: built from the upstream sources by the repository above and
-- hosted on its releases, so this is a personal packaging (AGENTS.md). The id is
--
--   ZheFeng7110:libstdcxx-newlib-arm-none-eabi@14.2.0
--
-- and loses the prefix if a maintainer moves the payloads to xlings-res (the bytes,
-- and so the hashes, stay the same).
local versions = {
    ["latest"] = { ref = "14.2.0" },
    -- The release libstdcxx-newlib-arm-none-eabi-14.2.0 (build run 45975474963 of 3fa7932).
    ["14.2.0"] = { sha256 = "ead19549a73a9c6f27bbaed61db0464eccf9c99d21d3088bb00450d76688aae4" },
}

package = {
    spec = "2",
    homepage = "https://gcc.gnu.org/onlinedocs/libstdc++/",
    name = "libstdcxx-newlib-arm-none-eabi",
    namespace = "ZheFeng7110",
    description = "libstdc++ (full and nano) for arm-none-eabi-gcc 14.2.0's Cortex-M/R multilibs, in a sysroot with newlib and newlib-nano",
    authors = {"GNU", "Red Hat", "newlib contributors"},
    maintainers = {"https://gcc.gnu.org/"},
    licenses = {"GPL-3.0-or-later WITH GCC-exception-3.1", "BSD-3-Clause", "BSD-2-Clause", "MIT"},
    repo = "https://gcc.gnu.org/git/gcc.git",
    docs = "https://gcc.gnu.org/onlinedocs/libstdc++/",
    type = "package",
    -- Host arches, not target ones: the payload is target code.
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"library", "embedded", "arm", "cortex-m", "c++"},
    keywords = {"libstdc++", "newlib", "newlib-nano", "arm-none-eabi", "cortex-m", "stm32", "baremetal"},
    -- No programs: a sysroot. config() registers only the umbrella node.
    xvm_enable = true,

    -- On the building repository's releases; CI copies the GLOBAL payload to
    -- xlings-res after merge (no well-known CN mirror carries it).
    ci = { mirror = true },

    xpm = {
        source = "https://github.com/ZheFeng7110/xlings-arm-none-eabi-gcc/releases/download/${name}-${version}/${name}-${version}.tar.gz",
        linux = versions,
        macosx = versions,
        windows = versions,
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- arm-none-eabi-gcc's `-print-multi-lib` (--with-multilib-list=rmprofile), in its order.
local multilibs = {
    ".",
    "arm/v5te/softfp",
    "arm/v5te/hard",
    "thumb/nofp",
    "thumb/v7/nofp",
    "thumb/v7+fp/softfp",
    "thumb/v7+fp/hard",
    "thumb/v7-r+fp.sp/softfp",
    "thumb/v7-r+fp.sp/hard",
    "thumb/v6-m/nofp",
    "thumb/v7-m/nofp",
    "thumb/v7e-m/nofp",
    "thumb/v7e-m+fp/softfp",
    "thumb/v7e-m+fp/hard",
    "thumb/v7e-m+dp/softfp",
    "thumb/v7e-m+dp/hard",
    "thumb/v8-m.base/nofp",
    "thumb/v8-m.main/nofp",
    "thumb/v8-m.main+fp/softfp",
    "thumb/v8-m.main+fp/hard",
    "thumb/v8-m.main+dp/softfp",
    "thumb/v8-m.main+dp/hard",
    "thumb/v8.1-m.main+mve/hard",
    "thumb/v8.1-m.main+pacbti/bp/nofp",
    "thumb/v8.1-m.main+pacbti+fp/bp/softfp",
    "thumb/v8.1-m.main+pacbti+fp/bp/hard",
    "thumb/v8.1-m.main+pacbti+dp/bp/softfp",
    "thumb/v8.1-m.main+pacbti+dp/bp/hard",
    "thumb/v8.1-m.main+pacbti+mve/bp/hard",
}

-- newlib's and libstdc++'s, per multilib row.
local required = {
    "libc.a", "libm.a", "libg.a", "libnosys.a", "librdimon.a", "crt0.o", "rdimon-crt0.o",
    "libc_nano.a", "libg_nano.a", "librdimon_nano.a",
    "libstdc++.a", "libsupc++.a", "libstdc++_nano.a", "libsupc++_nano.a",
}

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    local extracted = pkginfo.install_file():replace(".tar.gz", "")
    if not os.isdir(extracted) then
        raise("libstdcxx-newlib-arm-none-eabi payload not found at " .. extracted)
    end
    os.mv(extracted, dir)

    local root = path.join(dir, "arm-none-eabi")
    local cxx = path.join("include", "c++", pkginfo.version())
    for _, m in ipairs(multilibs) do
        for _, f in ipairs(required) do
            if not os.isfile(path.join(root, "lib", m, f)) then
                raise("libstdcxx-newlib-arm-none-eabi payload is missing lib/" .. m .. "/" .. f)
            end
        end
        local bits = m == "." and path.join(cxx, "arm-none-eabi", "bits")
                     or path.join(cxx, "arm-none-eabi", m, "bits")
        if not os.isfile(path.join(root, bits, "c++config.h")) then
            raise("libstdcxx-newlib-arm-none-eabi payload is missing " .. bits .. "/c++config.h")
        end
    end
    for _, f in ipairs({"lib/nano.specs", "lib/nosys.specs", "lib/rdimon.specs",
                        "include/stdio.h", "include/newlib-nano/newlib.h",
                        path.join(cxx, "vector"), path.join(cxx, "iostream")}) do
        if not os.isfile(path.join(root, f)) then
            raise("libstdcxx-newlib-arm-none-eabi payload is missing " .. f)
        end
    end
    return true
end

function config()
    -- Umbrella node only: target headers and libraries, selected with --sysroot;
    -- on the host include path they would shadow the host's.
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
