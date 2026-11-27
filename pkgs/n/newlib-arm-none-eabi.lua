-- newlib-arm-none-eabi: newlib 4.5.0.20241231 and newlib-nano for every multilib of
-- ZheFeng7110:arm-none-eabi-gcc, as the sysroot that compiler selects with
-- `--sysroot=<this package>/arm-none-eabi`. The payload is what
-- `xlings install fromsource:newlib-arm-none-eabi@4.5.0.20241231` builds (with
-- fromsource:arm-none-eabi-gcc 14.2.0, the compiler of ZheFeng7110:arm-none-eabi-gcc),
-- exported by tools/fromsource.sh of
-- https://github.com/ZheFeng7110/xlings-arm-none-eabi-gcc (README.provenance in the
-- payload names the recipe commit, the xlings client and the factory image).
--
-- ⭐ THE NAMES ARE ARM GNU TOOLCHAIN'S, so a project generated for it links unchanged
-- (STM32CubeMX: `--specs=nano.specs --specs=nosys.specs`); so are the two configures:
--
--   arm-none-eabi/include/               newlib's headers
--   arm-none-eabi/include/newlib-nano/   nano's newlib.h (nano.specs puts it first)
--   arm-none-eabi/lib/{nano,nosys,rdimon,...}.specs
--   arm-none-eabi/lib/<multilib>/        libc.a libm.a libg.a libnosys.a librdimon.a crt0.o ...
--                                        libc_nano.a libg_nano.a librdimon_nano.a
--
-- C only. For C++ install libstdcxx-newlib-arm-none-eabi instead: its sysroot is
-- this newlib with libstdc++ (full and nano) added -- a compiler takes one --sysroot.
--
-- ⚠️ USE IT WITH arm-none-eabi-gcc 14.2.0 REVISION 1 OR LATER. Revision 0's limits.h
-- never includes the C library's (no PATH_MAX, and MB_LEN_MAX 1 instead of 8).
--
-- ⚠️ THE MULTILIB DIRECTORIES ARE THE COMPILER'S, `rmprofile`. A library in the wrong
-- directory links cleanly and is wrong only at run time, so the factory checks
-- which archive a CubeMX-style link takes (cortex-m0, m3, m4 soft/hard, m33) and
-- runs programs under qemu mps2-an385/an386; install() asserts every row.
--
-- ⚠️ A target sysroot, not a host library: nothing enters the SubOS's include or lib
-- path. The payload is target code, so ONE archive (one sha256) serves every host;
-- a version bump is a factory rebuild.
--
-- ⭐ NAMESPACE ZheFeng7110: built from the upstream sources by the repository above and
-- hosted on its releases, so this is a personal packaging (AGENTS.md). The id is
--
--   ZheFeng7110:newlib-arm-none-eabi@4.5.0.20241231
--
-- and loses the prefix if a maintainer moves the payloads to xlings-res (the bytes,
-- and so the hashes, stay the same).
local versions = {
    ["latest"] = { ref = "4.5.0.20241231" },
    -- The release newlib-arm-none-eabi-4.5.0.20241231 (build run 45975474963 of 3fa7932).
    ["4.5.0.20241231"] = { sha256 = "dc5fb47392f89fdd5afa6d734c352cbe1a1d7628ce745e3208d7718e2ec3bc19" },
}

package = {
    spec = "2",
    homepage = "https://sourceware.org/newlib/",
    name = "newlib-arm-none-eabi",
    namespace = "ZheFeng7110",
    description = "newlib and newlib-nano for arm-none-eabi-gcc's Cortex-M/R multilibs (nano.specs, nosys.specs, rdimon.specs)",
    authors = {"Red Hat", "newlib contributors"},
    maintainers = {"https://sourceware.org/newlib/"},
    -- newlib is a collection of permissive licenses; COPYING.NEWLIB and
    -- COPYING.LIBGLOSS in the payload are the authoritative list.
    licenses = {"BSD-3-Clause", "BSD-2-Clause", "MIT"},
    repo = "https://sourceware.org/git/newlib-cygwin.git",
    docs = "https://sourceware.org/newlib/docs.html",
    type = "package",
    -- Host arches, not target ones: the payload is target code.
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"library", "embedded", "arm", "cortex-m", "libc"},
    keywords = {"newlib", "newlib-nano", "arm-none-eabi", "cortex-m", "stm32", "baremetal", "libc"},
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

local required = {
    "libc.a", "libm.a", "libg.a", "libnosys.a", "librdimon.a", "crt0.o", "rdimon-crt0.o",
    "libc_nano.a", "libg_nano.a", "librdimon_nano.a",
}

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    -- One fixed archive name for every host; its one directory is the prefix.
    local extracted = pkginfo.install_file():replace(".tar.gz", "")
    if not os.isdir(extracted) then
        raise("newlib-arm-none-eabi payload not found at " .. extracted)
    end
    os.mv(extracted, dir)

    -- Every row, not only the ones the factory links: a payload that lost one
    -- multilib installs cleanly and fails only for whoever targets that row.
    local root = path.join(dir, "arm-none-eabi")
    for _, m in ipairs(multilibs) do
        for _, f in ipairs(required) do
            if not os.isfile(path.join(root, "lib", m, f)) then
                raise("newlib-arm-none-eabi payload is missing lib/" .. m .. "/" .. f)
            end
        end
    end
    for _, f in ipairs({"lib/nano.specs", "lib/nosys.specs", "lib/rdimon.specs",
                        "include/stdio.h", "include/newlib-nano/newlib.h"}) do
        if not os.isfile(path.join(root, f)) then
            raise("newlib-arm-none-eabi payload is missing " .. f)
        end
    end
    return true
end

function config()
    -- Umbrella node only. These are arm-none-eabi TARGET headers and libraries:
    -- on the host include path they would shadow the host libc for every
    -- ordinary build. The compiler is pointed at them with --sysroot.
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
