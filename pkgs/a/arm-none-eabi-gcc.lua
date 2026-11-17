-- arm-none-eabi-gcc: GCC 14.2.0 (C, C++) and binutils 2.43.1 for bare-metal Arm
-- (Cortex-M/R), WITHOUT a C library -- as Homebrew's arm-none-eabi-gcc, built here
-- from source by tools/res/build.sh arm-none-eabi-gcc (tools/res/arm-none-eabi/gcc.sh).
--
-- ⭐ THE C LIBRARY IS A PACKAGE OF ITS OWN, AND SO IS libstdc++.
--
--   newlib-arm-none-eabi              newlib + newlib-nano, Arm GNU Toolchain's names
--   picolibc-arm-none-eabi            (planned)
--   libstdcxx-<libc>-arm-none-eabi    (planned) libstdc++ built against that libc's
--                                     headers by THIS gcc, so its version is this
--                                     package's version: libstdcxx-newlib-arm-none-eabi@14.2.0
--
-- A C library is a sysroot this compiler selects with `--sysroot=<it>/arm-none-eabi`;
-- its specs files then do the rest (`--specs=nano.specs --specs=nosys.specs`, as
-- STM32CubeMX generates). The compiler's own sysroot, `<prefix>/arm-none-eabi`, is
-- relocatable and holds no C library, so without one only freestanding code links
-- (`-nostdlib ... -lgcc`).
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
-- Linux only for now: the resource factory runs on Linux runners (x86_64, aarch64).
-- The host programs are built in Debian 12 and need glibc alone (the build checks
-- it); elfpatch puts them on xim:glibc at install time.
package = {
    spec = "2",
    homepage = "https://gcc.gnu.org/",
    name = "arm-none-eabi-gcc",
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

    -- Built, not mirrored: a version bump is a factory build and a publication,
    -- then an edit here. No `ci` block.
    xpm = {
        source = "xlings-res",
        linux = {
            deps = {
                runtime = { "xim:glibc@>=2.39" },
                build = { "xim:patchelf@0.18.0" },
            },
            ["latest"] = { ref = "14.2.0" },
            -- PENDING PUBLICATION: the hashes are res-build's artifacts' (the
            -- `.sha256` sidecars), filled in once xlings-res/arm-none-eabi-gcc
            -- 14.2.0 is published on GitHub and GitCode.
            ["14.2.0"] = {
                sha256 = {
                    x86_64 = "PENDING-res-build-arm-none-eabi-gcc-14.2.0-linux-x86_64",
                    aarch64 = "PENDING-res-build-arm-none-eabi-gcc-14.2.0-linux-aarch64",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    -- The archive's one directory, arm-none-eabi-gcc-<version>-linux-<arch>, is the prefix.
    local top = pkginfo.install_file():replace(".tar.gz", "")
    if not os.isdir(top) then
        raise("arm-none-eabi-gcc payload not found at " .. top)
    end
    os.tryrm(pkginfo.install_dir())
    os.mv(top, pkginfo.install_dir())
    -- The compiler finds as/ld in <prefix>/arm-none-eabi/bin and cc1 under
    -- libexec, relative to itself; a payload missing either installs cleanly
    -- and fails at the first compile.
    local libexec = "libexec/gcc/arm-none-eabi/" .. pkginfo.version()
    for _, f in ipairs({
        "bin/arm-none-eabi-gcc", "arm-none-eabi/bin/as", "arm-none-eabi/bin/ld",
        libexec .. "/cc1", libexec .. "/cc1plus",
    }) do
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
