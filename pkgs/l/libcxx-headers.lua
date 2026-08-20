package = {
    spec = "2",
    homepage = "https://libcxx.llvm.org/",

    name = "libcxx-headers",
    description = "libc++ headers and export tables - for cross-compiling from a host whose LLVM payload ships none",

    maintainers = {"https://github.com/llvm/llvm-project/graphs/contributors"},
    licenses = {"Apache-2.0 WITH LLVM-exception"},
    repo = "https://github.com/llvm/llvm-project",
    docs = "https://libcxx.llvm.org/",

    type = "package",
    -- Host arches. See the source note: the payload is text and one archive
    -- serves every host on every arch.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"library", "toolchain", "c++"},
    keywords = {"libc++", "libcxx", "headers", "freestanding", "cross", "llvm"},

    -- No programs: this is a set of headers, not a tool.
    xvm_enable = true,

    -- ⭐ THE PAYLOAD IS TEXT, SO ONE ARCHIVE SERVES EVERY HOST.
    --
    -- libc++'s headers are ordinary, host-independent source. The same clang
    -- cross-compiling to `riscv64-none-elf` reads them identically on linux,
    -- darwin and win32 -- nothing about a CROSS build depends on the host's own
    -- standard library. Hence one URL and one sha256 rather than a per-platform
    -- table, which is also what tells the mirror tooling to treat it as an
    -- arch-independent asset. `picolibc-riscv` is the same shape for the same
    -- reason.
    --
    -- ⚠️ THIS PACKAGE EXISTS BECAUSE A PAYLOAD OMITS THEM, NOT BECAUSE A
    -- PLATFORM CANNOT DO FREESTANDING.
    --
    -- The Windows LLVM payload builds clang against the MSVC standard library
    -- for Windows-hosted work and ships no libc++ at all -- which also takes
    -- libc++ away from every cross-compilation that payload could otherwise
    -- serve. Measured on that payload: `#include <algorithm>` for a bare-metal
    -- target reports `'algorithm' file not found`.
    --
    -- ⚠️ AND SWITCHING IMPLEMENTATIONS DOES NOT SOLVE IT. Measured on the same
    -- 40 C++23/26 freestanding-mandated headers with libstdc++ 16.1.0 and
    -- `-D_GLIBCXX_HOSTED=0`, changing only the target:
    --
    --     x86_64-linux-gnu   40 / 40 compile
    --     riscv64-none-elf    0 / 40, all at
    --         bits/c++config.h -> bits/os_defines.h -> 'features.h' not found
    --
    -- The difference is not which implementation; it is whether that
    -- implementation was CONFIGURED for the target. libc++'s per-target
    -- configuration is one flat macro file (`__config_site`) and can be
    -- synthesised; libstdc++'s is a configure output that pulls in the host C
    -- library.
    --
    -- ⚠️ `__config_site` IS NOT IN THIS ARCHIVE, and that is not an omission.
    -- It exists only under the payload's own host triple and is absent for
    -- every cross target, so shipping one here would ship a configuration for
    -- somebody else's target. `mcpplibs/std-freestanding` synthesises it, and
    -- that is the one thing it adds on top of these files.
    --
    -- ⚠️ No `ci` block, deliberately, for the same reasons `picolibc-riscv` has
    -- none: `mirror` would point the mirror at xlings-res, i.e. at itself, and
    -- `update` would bump `latest` to a new LLVM release and re-download a URL
    -- that does not exist yet -- this artifact has to be REPACKAGED from a new
    -- llvm payload, which is a human step.
    --
    -- The release also carries a `.zip` of the same tree for anyone who prefers
    -- it. This descriptor does not reference it: one archive is the honest
    -- shape for a host-independent payload, and `llvm.lua` already establishes
    -- that xim extracts `.tar.xz` on win32.
    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/libcxx-headers/releases/download/${version}/libcxx-headers-${version}.tar.xz",
            CN = "https://gitcode.com/xlings-res/libcxx-headers/releases/download/${version}/libcxx-headers-${version}.tar.xz",
        },
        linux = {
            ["latest"] = { ref = "22.1.8" },
            ["22.1.8"] = { sha256 = "e3e33e3d8b991810f0645221241a6ae55023bd8da10bb5febcd98098cc8d8982" },
        },
        macosx = {
            ["latest"] = { ref = "22.1.8" },
            ["22.1.8"] = { sha256 = "e3e33e3d8b991810f0645221241a6ae55023bd8da10bb5febcd98098cc8d8982" },
        },
        windows = {
            ["latest"] = { ref = "22.1.8" },
            ["22.1.8"] = { sha256 = "e3e33e3d8b991810f0645221241a6ae55023bd8da10bb5febcd98098cc8d8982" },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)

    -- One fixed archive name, so unlike a per-host package there is nothing to
    -- derive from the platform here.
    local extracted = pkginfo.install_file():replace(".tar.xz", "")
    if not os.isdir(extracted) then
        raise("libcxx-headers payload not found at " .. extracted)
    end
    os.mv(extracted, dir)

    -- ⚠️ ASSERT THE TWO HALVES SEPARATELY, BECAUSE A CONSUMER NEEDS BOTH AND
    -- THE SECOND IS EASY TO LEAVE OUT WHEN REPACKAGING.
    --
    -- `include/c++/v1` is the headers. `share/libc++/v1/std/<h>.inc` is the
    -- per-header export table libc++ maintains, and a module that re-exports
    -- the standard library reads it rather than writing its own -- an export
    -- table naming absent declarations is an error in the module interface, not
    -- in the consumer.
    if not os.isfile(path.join(dir, "include", "c++", "v1", "algorithm")) then
        raise("libcxx-headers payload is missing include/c++/v1/algorithm")
    end
    if not os.isfile(path.join(dir, "share", "libc++", "v1", "std", "array.inc")) then
        raise("libcxx-headers payload is missing share/libc++/v1/std/array.inc")
    end

    return true
end

function config()
    -- Umbrella node only.
    --
    -- ⚠️ These headers must NOT be published into the subos sysroot the way a
    -- host library's are. They are a SECOND copy of the C++ standard library:
    -- putting them on the host include path would shadow whichever one the
    -- host's own toolchain ships, for every ordinary build. A consumer points
    -- `-isystem` at this package's install dir for the cross target that needs
    -- it -- which is what `mcpplibs/std-freestanding` does, and only when its
    -- toolchain payload carries none.
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
