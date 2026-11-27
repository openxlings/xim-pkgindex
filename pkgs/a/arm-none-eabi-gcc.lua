-- arm-none-eabi-gcc: GCC 14.2.0 (C, C++) and binutils 2.43.1 for bare-metal Arm
-- (Cortex-M/R), WITHOUT a C library -- as Homebrew's arm-none-eabi-gcc. The payload is
-- what `xlings install fromsource:arm-none-eabi-gcc@14.2.0` builds (with
-- fromsource:arm-none-eabi-binutils inside), exported by tools/fromsource.sh of
-- https://github.com/ZheFeng7110/xlings-arm-none-eabi-gcc (README.provenance in the
-- payload names the recipe commit, the xlings client and the factory image).
--
-- ⭐ THE C LIBRARY IS A PACKAGE OF ITS OWN, AND SO IS libstdc++.
--
--   newlib-arm-none-eabi              newlib + newlib-nano, Arm GNU Toolchain's names
--   libstdcxx-newlib-arm-none-eabi    that newlib with libstdc++ (full and nano) built
--                                     by THIS gcc, in one sysroot: its version is this
--                                     package's version (14.2.0)
--   picolibc-arm-none-eabi            (planned)
--
-- A C library is a sysroot this compiler selects with `--sysroot=<it>/arm-none-eabi`;
-- its specs files then do the rest (`--specs=nano.specs --specs=nosys.specs`, as
-- STM32CubeMX generates). The compiler's own sysroot, `<prefix>/arm-none-eabi`, is
-- relocatable and holds no C library, so without one only freestanding code links
-- (`-nostdlib ... -lgcc`).
--
-- ⭐ REVISION 1 (floor 1) is what a C/C++ library package needs: the C++ headers are
-- looked for in the sysroot (--with-gxx-include-dir under it), and limits.h reaches
-- the C library's (PATH_MAX, MB_LEN_MAX 8 with newlib). Revision 0 had neither; its
-- target code (libgcc) is the same bytes as revision 1's.
--
-- ⚠️ libgcc is built with inhibit_libc (there is no C library at build time), so
-- there is no libgcov: `--coverage` does not link.
--
-- ⚠️ THE MULTILIB SET IS PART OF THE ABI WITH ITS C LIBRARY. It is `rmprofile`
-- (thumb/v6-m/nofp ... thumb/v8-m.main+fp/hard), the set Arm's toolchain carries
-- for M/R profiles; newlib-arm-none-eabi is built by this payload from its own
-- `-print-multi-lib`. A compiler with another list is a new version here, never a
-- rebuild of this one.
--
-- Hosts (each payload's README.provenance says how it was made):
--   linux x86_64/aarch64  built by xim:gcc against xim:glibc; the host programs need
--                         glibc alone (the export checks it, and resets INTERP/RPATH);
--                         elfpatch puts them on xim:glibc at install time
--   windows x86_64        cross-built on Linux (fromsource:arm-none-eabi-gcc-mingw-cross),
--                         linked statically: Windows' own DLLs only; a .zip
--   macosx aarch64        built by Xcode's clang: system libraries only, macOS 11+
-- The target code (libgcc) is the same bytes in all of them.
--
-- ⭐ NAMESPACE zhefeng: built from the upstream sources by the repository above and
-- hosted on its releases, so this is a personal packaging (AGENTS.md). The id is
--
--   zhefeng:arm-none-eabi-gcc@14.2.0
--
-- (lowercase letters only: the index's install checks take no other namespace, so it
-- is not the GitHub handle). It loses the prefix if a maintainer moves the payloads
-- to xlings-res (the bytes, and so the hashes, stay the same).
package = {
    spec = "2",
    homepage = "https://gcc.gnu.org/",
    name = "arm-none-eabi-gcc",
    namespace = "zhefeng",
    description = "GCC 14.2.0 and binutils 2.43.1 for bare-metal Arm (arm-none-eabi), without a C library",
    authors = {"GNU"},
    maintainers = {"https://gcc.gnu.org/"},
    licenses = {"GPL-3.0-or-later", "GPL-3.0-or-later WITH GCC-exception-3.1"},
    repo = "https://gcc.gnu.org/git/gcc.git",
    docs = "https://gcc.gnu.org/onlinedocs/gcc/ARM-Options.html",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"compiler", "gnu", "cross", "embedded", "arm", "cortex-m"},
    keywords = {"arm-none-eabi", "gcc", "binutils", "cortex-m", "stm32", "baremetal", "cross"},
    programs = {
        "arm-none-eabi-gcc", "arm-none-eabi-g++", "arm-none-eabi-c++", "arm-none-eabi-cpp",
        "arm-none-eabi-gcc-ar", "arm-none-eabi-gcc-nm", "arm-none-eabi-gcc-ranlib",
        "arm-none-eabi-gcov", "arm-none-eabi-gcov-dump", "arm-none-eabi-gcov-tool",
        "arm-none-eabi-lto-dump",
        "arm-none-eabi-addr2line", "arm-none-eabi-ar", "arm-none-eabi-as",
        "arm-none-eabi-c++filt", "arm-none-eabi-elfedit", "arm-none-eabi-gprof",
        "arm-none-eabi-ld", "arm-none-eabi-ld.bfd", "arm-none-eabi-nm",
        "arm-none-eabi-objcopy", "arm-none-eabi-objdump", "arm-none-eabi-ranlib",
        "arm-none-eabi-readelf", "arm-none-eabi-size", "arm-none-eabi-strings",
        "arm-none-eabi-strip",
    },
    xvm_enable = true,

    -- A version bump is a factory build and a publication in the building
    -- repository, then an edit here. CI copies the GLOBAL payloads to xlings-res
    -- after merge (no well-known CN mirror carries them).
    ci = { mirror = true },

    xpm = {
        linux = {
            source = "https://github.com/ZheFeng7110/xlings-arm-none-eabi-gcc/releases/download/${name}-${version}/${name}-${version}-linux-${arch}.tar.gz",
            deps = {
                runtime = { "xim:glibc@>=2.39" },
                build = { "xim:patchelf@0.18.0" },
            },
            ["latest"] = { ref = "14.2.0" },
            -- 1: 14.2.0-r1, release arm-none-eabi-gcc-14.2.0-r1 (build run 45975474963
            -- of 3fa7932): --with-gxx-include-dir under the sysroot, limits.h that
            -- reaches the C library's. Revision 0 (the release arm-none-eabi-gcc-14.2.0,
            -- runs 44453953062 and 44456719656 of c0b8058) was published only in the
            -- building repository's own index, never here; floor 1: with a C library it
            -- is wrong. An explicit url: `source` names revision 0's.
            ["14.2.0"] = {
                revision = 1,
                floor = 1,
                x86_64 = {
                    url = "https://github.com/ZheFeng7110/xlings-arm-none-eabi-gcc/releases/download/arm-none-eabi-gcc-14.2.0-r1/arm-none-eabi-gcc-14.2.0-r1-linux-x86_64.tar.gz",
                    sha256 = "b50f2f9b7662492addc76b15539a6e79090b88fc839f4a777e7196e64fe42cc1",
                },
                aarch64 = {
                    url = "https://github.com/ZheFeng7110/xlings-arm-none-eabi-gcc/releases/download/arm-none-eabi-gcc-14.2.0-r1/arm-none-eabi-gcc-14.2.0-r1-linux-aarch64.tar.gz",
                    sha256 = "4ba0531c3c9140c1679107a60bafb4467b1f3940460a9b9130d892b1bcbe47b7",
                },
            },
        },
        -- Revision 0: build run 45107607496 of b01941d; revision 1: as on Linux.
        -- ⚠️ Known limitation: the Windows payload does not rebuild to the same bytes
        -- yet (cc1/cc1plus's embedded checksum and an import library's timestamp;
        -- not the code they generate). This hash pins the published one; a fixed
        -- build will be a new revision. See .agents/docs/...-design.md, 8.4 L1.
        windows = {
            source = "https://github.com/ZheFeng7110/xlings-arm-none-eabi-gcc/releases/download/${name}-${version}/${name}-${version}-windows-${arch}.zip",
            ["latest"] = { ref = "14.2.0" },
            ["14.2.0"] = {
                revision = 1,
                floor = 1,
                x86_64 = {
                    url = "https://github.com/ZheFeng7110/xlings-arm-none-eabi-gcc/releases/download/arm-none-eabi-gcc-14.2.0-r1/arm-none-eabi-gcc-14.2.0-r1-windows-x86_64.zip",
                    sha256 = "0e46c7b914d43ad4e9466f930f7fc3b67ca298402234a71eb2cab0428381b830",
                },
            },
        },
        macosx = {
            source = "https://github.com/ZheFeng7110/xlings-arm-none-eabi-gcc/releases/download/${name}-${version}/${name}-${version}-macosx-${arch}.tar.gz",
            ["latest"] = { ref = "14.2.0" },
            ["14.2.0"] = {
                revision = 1,
                floor = 1,
                aarch64 = {
                    url = "https://github.com/ZheFeng7110/xlings-arm-none-eabi-gcc/releases/download/arm-none-eabi-gcc-14.2.0-r1/arm-none-eabi-gcc-14.2.0-r1-macosx-aarch64.tar.gz",
                    sha256 = "5d569219739266262359ce9cf1bb3a88458796d6b91c8eb84d223b957151f8c1",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    -- The archive's one directory, arm-none-eabi-gcc-<version>-<os>-<arch>, is the prefix.
    local top = pkginfo.install_file():replace(".tar.gz", ""):replace(".zip", "")
    if not os.isdir(top) then
        raise("arm-none-eabi-gcc payload not found at " .. top)
    end
    os.tryrm(pkginfo.install_dir())
    os.mv(top, pkginfo.install_dir())
    -- The compiler finds as/ld in <prefix>/arm-none-eabi/bin and cc1 under
    -- libexec, relative to itself; a payload missing either installs cleanly
    -- and fails at the first compile.
    local libexec = "libexec/gcc/arm-none-eabi/" .. pkginfo.version()
    local exe = is_host("windows") and ".exe" or ""
    for _, f in ipairs({
        "bin/arm-none-eabi-gcc", "arm-none-eabi/bin/as", "arm-none-eabi/bin/ld",
        libexec .. "/cc1", libexec .. "/cc1plus",
    }) do
        f = f .. exe
        if not os.isfile(path.join(pkginfo.install_dir(), f)) then
            raise("arm-none-eabi-gcc payload is missing " .. f)
        end
    end
    return true
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    local release = package.name .. "@" .. pkginfo.version()
    -- The package's name is its C compiler; the other programs bind to it.
    xvm.add(package.name, { bindir = bindir })
    for _, prog in ipairs(package.programs) do
        if prog ~= package.name then
            xvm.add(prog, { bindir = bindir, binding = release })
        end
    end
    return true
end

function uninstall()
    for _, prog in ipairs(package.programs) do
        xvm.remove(prog)
    end
    return true
end
