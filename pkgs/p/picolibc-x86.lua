package = {
    spec = "2",
    homepage = "https://keithp.com/picolibc/",

    name = "picolibc-x86",
    description = "Freestanding RISC-V sysroot - picolibc + the compiler-rt builtins needed to link it",

    maintainers = {"https://github.com/picolibc/picolibc/graphs/contributors"},
    -- picolibc is BSD-3-Clause/BSD-2-Clause (it carries newlib and AVR libc
    -- heritage; COPYING.picolibc in the payload is the authoritative list).
    -- The compiler-rt builtins are Apache-2.0 WITH LLVM-exception.
    licenses = {"BSD-3-Clause", "BSD-2-Clause", "Apache-2.0 WITH LLVM-exception"},
    repo = "https://github.com/picolibc/picolibc",
    docs = "https://github.com/picolibc/picolibc/blob/main/doc/using.md",

    type = "package",
    -- Host arches, not target ones. See the source note: the payload is target
    -- code and one archive serves every host.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"library", "embedded", "x86", "libc"},
    keywords = {"picolibc", "x86_64", "baremetal", "freestanding", "libc"},

    -- No programs: this is a sysroot, not a tool. `config()` registers only the
    -- umbrella node so `xlings use picolibc-x86@<ver>` works.
    xvm_enable = true,

    -- ⭐ The payload is TARGET code (x86_64 static archives, object files and
    -- linker scripts), so it is host-independent: ONE archive serves
    -- linux/macosx/windows on every arch. Hence one URL and one sha256 rather
    -- than a per-arch table -- which is also what tells the mirror tooling to
    -- treat it as an arch-independent asset.
    --
    -- Built from source by `.agents/tools/build-baremetal-sysroot.sh --family
    -- x86` with the index's own llvm payload, because no upstream publishes a
    -- picolibc binary for `x86_64-none-elf` at all.
    --
    -- ⚠️ AND THE BUILD NEEDS A LINK WRAPPER, WHICH IS A TOOLCHAIN FACT RATHER
    -- THAN A PICOLIBC ONE. clang ships a BareMetal toolchain for arm, aarch64
    -- and riscv but not for x86_64; on this triple it hands the link to the
    -- host gcc/collect2, which cannot link a bare ELF, so meson cannot even
    -- configure. `.agents/tools/bare-link-wrapper.sh` takes the link away from
    -- the driver and calls `ld.lld -m elf_x86_64` directly, exactly as mcpp's
    -- own engine does for this target. Nothing in the shipped payload depends
    -- on the wrapper.
    --
    -- ⚠️ `-fuse-ld=lld` APPEARS to solve it and does not: measured, with an
    -- `lld` on PATH the probe passes and with PATH reduced to coreutils both
    -- the bare name and `-B<llvm>/bin` fall through to `collect2 ... [cannot
    -- find ld]`. The pass was ambient state.
    --
    -- ⚠️ No `ci` block, deliberately. `mirror` would point the mirror at
    -- xlings-res, i.e. at itself. `update` would bump `latest` to a new
    -- picolibc release and re-download a URL that does not exist yet -- this
    -- artifact has to be REBUILT for a version bump, and that is a human step:
    -- run the script, publish, then edit this file.
    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/picolibc-x86/releases/download/${version}/picolibc-x86-${version}.tar.gz",
            CN = "https://gitcode.com/xlings-res/picolibc-x86/releases/download/${version}/picolibc-x86-${version}.tar.gz",
        },
        linux = {
            ["latest"] = { ref = "1.8.12" },
            ["1.8.12"] = { sha256 = "b25d6a5f4a2768fda4027f296b9e904f31aa809bd94eee32d6cc99ee227ce6de" },
        },
        macosx = {
            ["latest"] = { ref = "1.8.12" },
            ["1.8.12"] = { sha256 = "b25d6a5f4a2768fda4027f296b9e904f31aa809bd94eee32d6cc99ee227ce6de" },
        },
        windows = {
            ["latest"] = { ref = "1.8.12" },
            ["1.8.12"] = { sha256 = "b25d6a5f4a2768fda4027f296b9e904f31aa809bd94eee32d6cc99ee227ce6de" },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- Profiles the payload carries, as `<march>/<mabi>`. picolibc's own multilib
-- convention, so adding a profile later moves no existing file.
-- `arch` is carried rather than derived from `march`: the recipe sandbox has no
-- `string.startswith` (it is an xmake extension, absent here -- a derived form
-- aborted the install with "attempt to call a nil value").
local profiles = {
    {march = "x86-64", mabi = "sysv", arch = "x86_64"},
}

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)

    -- One fixed archive name, so unlike a per-host package there is nothing to
    -- derive from the platform here.
    local extracted = pkginfo.install_file():replace(".tar.gz", "")
    if not os.isdir(extracted) then
        raise("picolibc-x86 payload not found at " .. extracted)
    end
    os.mv(extracted, dir)

    -- Assert the payload per profile rather than trusting the archive.
    -- ⚠️ NO libsemihost.a AND NO crt0-semihost.o, AND THE ABSENCE IS THE
    -- ARCHITECTURE'S. Semihosting is a debugger-channel protocol that exists
    -- for arm/aarch64 and riscv; x86 has none. A consumer therefore supplies
    -- its own console -- which is a BOARD package's job -- or links
    -- picolibc's `libdummyhost.a` stub, which this payload also carries.
    --
    -- Measured: without one of the two, a `printf` image fails to link with
    -- `undefined symbol: stdout`, which is the correct answer rather than a
    -- packaging defect. With `-ldummyhost` it links at 0x100000, the multiboot
    -- load address this payload's linker scripts default to.
    for _, p in ipairs(profiles) do
        local libdir = path.join(dir, "lib", p.march, p.mabi)
        local incdir = path.join(dir, "include", p.march, p.mabi)
        local required = {
            "libc.a", "libm.a", "picolibc.ld", "picolibcpp.ld",
            "libclang_rt.builtins-" .. p.arch .. ".a",
        }
        for _, f in ipairs(required) do
            if not os.isfile(path.join(libdir, f)) then
                raise("picolibc-x86 payload is missing lib/"
                      .. p.march .. "/" .. p.mabi .. "/" .. f)
            end
        end
        if not os.isfile(path.join(incdir, "stdio.h")) then
            raise("picolibc-x86 payload is missing include/"
                  .. p.march .. "/" .. p.mabi .. "/stdio.h")
        end
    end

    return true
end

function config()
    -- Umbrella node only.
    --
    -- ⚠️ These headers must NOT be published into the subos sysroot the way a
    -- host library's are (compare zlib.lua, which copies zlib.h into
    -- usr/include). They are `x86_64-none-elf` TARGET headers: putting them
    -- on the host include path would shadow the host libc for every ordinary
    -- build. A consumer points its `--sysroot`/`-isystem` at this package's
    -- install dir for the profile it wants.
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
