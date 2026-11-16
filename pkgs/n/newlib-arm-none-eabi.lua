-- newlib-arm-none-eabi: newlib 4.5.0.20241231 and newlib-nano for every multilib of
-- xim:arm-none-eabi-gcc, as the sysroot that compiler selects with
-- `--sysroot=<this package>/arm-none-eabi`. Built by tools/res/build.sh
-- newlib-arm-none-eabi (tools/res/arm-none-eabi/newlib.sh) with the published
-- compiler payload, and Arm GNU Toolchain's configure for each variant.
--
-- ⭐ THE NAMES ARE ARM GNU TOOLCHAIN'S, so a project generated for it links unchanged
-- (STM32CubeMX: `--specs=nano.specs --specs=nosys.specs`):
--
--   arm-none-eabi/include/               newlib's headers
--   arm-none-eabi/include/newlib-nano/   nano's newlib.h (nano.specs puts it first)
--   arm-none-eabi/lib/{nano,nosys,rdimon,...}.specs
--   arm-none-eabi/lib/<multilib>/        libc.a libm.a libg.a libnosys.a librdimon.a crt0.o ...
--                                        libc_nano.a libg_nano.a librdimon_nano.a
--
-- nano.specs also maps -lstdc++ to -lstdc++_nano: libstdc++ is not here, it is
-- libstdcxx-newlib-arm-none-eabi@<gcc version> (planned), which carries both.
--
-- ⚠️ THE MULTILIB DIRECTORIES ARE THE COMPILER'S, `rmprofile`. A library in the wrong
-- directory links cleanly and is wrong only at run time, so the build checks which
-- archive a CubeMX-style link takes for cortex-m0, m3 and m4 hard float, and runs a
-- semihosting program under qemu mps2-an385/an386; install() asserts every row.
--
-- ⚠️ A target sysroot, not a host library: nothing enters the SubOS's include or lib
-- path. The payload is target code, so ONE archive (one sha256) serves every host,
-- and there is no `ci` block -- a version bump is a factory rebuild.
local versions = {
    ["latest"] = { ref = "4.5.0.20241231" },
    -- PENDING PUBLICATION: the hash is res-build's artifact's (the `.sha256`
    -- sidecar), filled in once xlings-res/newlib-arm-none-eabi 4.5.0.20241231 is
    -- published on GitHub and GitCode.
    ["4.5.0.20241231"] = { sha256 = "PENDING-res-build-newlib-arm-none-eabi-4.5.0.20241231" },
}

package = {
    spec = "2",
    homepage = "https://sourceware.org/newlib/",
    name = "newlib-arm-none-eabi",
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

    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/newlib-arm-none-eabi/releases/download/${version}/newlib-arm-none-eabi-${version}.tar.gz",
            CN = "https://gitcode.com/xlings-res/newlib-arm-none-eabi/releases/download/${version}/newlib-arm-none-eabi-${version}.tar.gz",
        },
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
    -- One fixed archive name for every host.
    local extracted = pkginfo.install_file():replace(".tar.gz", "")
    if not os.isdir(extracted) then
        raise("newlib-arm-none-eabi payload not found at " .. extracted)
    end
    os.mv(extracted, dir)

    -- Every row, not only the ones the checks link: a payload that lost one
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
