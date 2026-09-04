package = {
    spec = "2",
    homepage = "https://keithp.com/picolibc/",

    name = "picolibc-arm",
    description = "Freestanding Cortex-M sysroot - picolibc + the compiler-rt builtins needed to link it, seven multilibs",

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
    categories = {"library", "embedded", "arm", "cortex-m", "libc"},
    keywords = {"picolibc", "cortex-m", "thumb", "baremetal", "freestanding", "libc"},

    -- No programs: this is a sysroot, not a tool. `config()` registers only the
    -- umbrella node so `xlings use picolibc-arm@<ver>` works.
    xvm_enable = true,

    -- ⭐ The payload is TARGET code (thumb static archives, object files and
    -- linker scripts), so it is host-independent: ONE archive serves
    -- linux/macosx/windows on every arch.
    --
    -- ⭐⭐ SEVEN MULTILIBS, AND THAT IS THE FAMILY RATHER THAN A CHOICE.
    -- "Cortex-M" is not an instruction set: an object built for `thumbv7em`
    -- uses instructions a Cortex-M0 does not have, so mcpp's target table
    -- carries seven M-profile rows and a sysroot serving them carries seven.
    --
    -- ⚠️⚠️ KEYED BY TRIPLE, NOT BY `<march>/<mabi>` LIKE ITS THREE SIBLINGS, AND
    -- THE DIFFERENCE IS A SILENT ABI SUBSTITUTION.
    --
    -- On riscv, `mabi` IS the float ABI — `lp64d` and `lp64` are different
    -- values — so `<march>/<mabi>` separates every profile. On ARM `mabi` names
    -- the PROCEDURE CALL STANDARD and is `aapcs` for both variants, while the
    -- float ABI lives in the triple's `eabi`/`eabihf` suffix. Measured: with the
    -- sibling convention the seven profiles collapsed into five directories and
    -- `armv7e-m/aapcs/libc.a` came out carrying `Tag_ABI_HardFP_use` — the
    -- hard-float build, sitting exactly where the soft-float row looks for it.
    -- Nothing failed at build time.
    --
    -- ⚠️ AND THE BUILTINS ARCHIVE IS RENAMED INTO THE PAYLOAD. compiler-rt's
    -- architecture detection does not recognise a `thumb*` triple at all —
    -- configuring with `thumbv6m-none-eabi` produces a build tree with NO
    -- builtins target, cmake succeeds and ninja reports "no work to do" — so it
    -- is built as `armv6m-none-eabi` and emits `libclang_rt.builtins-armv6m.a`.
    -- mcpp asks for `clang_rt.builtins-<arch of the target triple>`, which is
    -- `thumbv6m`, so the file is stored under the name the consumer will ask
    -- for. Leaving compiler-rt's spelling would ship builtins that exist and
    -- cannot be found.
    --
    -- Built by `.agents/tools/build-baremetal-sysroot.sh --family arm`. The
    -- script is the reproduction: same inputs, same bytes (fixed tar
    -- owner/mtime and sorted member order).
    --
    -- ⚠️ No `ci` block, deliberately, for the reason the sibling packages give:
    -- `mirror` would point the mirror at xlings-res, i.e. at itself, and
    -- `update` would bump `latest` to a picolibc release whose artifact does not
    -- exist yet. This payload has to be REBUILT for a version bump, and that is
    -- a human step: run the script, publish, then edit this file.
    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/picolibc-arm/releases/download/${version}/picolibc-arm-${version}.tar.gz",
            CN = "https://gitcode.com/xlings-res/picolibc-arm/releases/download/${version}/picolibc-arm-${version}.tar.gz",
        },
        linux = {
            ["latest"] = { ref = "1.8.12" },
            ["1.8.12"] = { sha256 = "bfd6a510db051f10b6d770df54cdf052dae30c764b38bb64540e8f65a40fad43" },
        },
        macosx = {
            ["latest"] = { ref = "1.8.12" },
            ["1.8.12"] = { sha256 = "bfd6a510db051f10b6d770df54cdf052dae30c764b38bb64540e8f65a40fad43" },
        },
        windows = {
            ["latest"] = { ref = "1.8.12" },
            ["1.8.12"] = { sha256 = "bfd6a510db051f10b6d770df54cdf052dae30c764b38bb64540e8f65a40fad43" },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- The seven profiles the payload carries, each keyed by its TARGET TRIPLE — the
-- same string a consumer writes in `[build] target`, and the same string mcpp
-- records in the `libdir` column of its freestanding table.
--
-- `arch` is carried rather than derived from the triple: the recipe sandbox has
-- no `string.startswith` (an xmake extension, absent here), and a derived form
-- aborted a sibling's install with "attempt to call a nil value".
local profiles = {
    {triple = "thumbv6m-none-eabi",        arch = "thumbv6m"},
    {triple = "thumbv7m-none-eabi",        arch = "thumbv7m"},
    {triple = "thumbv7em-none-eabi",       arch = "thumbv7em"},
    {triple = "thumbv7em-none-eabihf",     arch = "thumbv7em"},
    {triple = "thumbv8m.base-none-eabi",   arch = "thumbv8m.base"},
    {triple = "thumbv8m.main-none-eabi",   arch = "thumbv8m.main"},
    {triple = "thumbv8m.main-none-eabihf", arch = "thumbv8m.main"},
}

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)

    -- One fixed archive name, so unlike a per-host package there is nothing to
    -- derive from the platform here.
    local extracted = pkginfo.install_file():replace(".tar.gz", "")
    if not os.isdir(extracted) then
        raise("picolibc-arm payload not found at " .. extracted)
    end
    os.mv(extracted, dir)

    -- Asserted per profile rather than trusted, and SEVEN of them: an archive
    -- that lost one multilib would install cleanly and fail only for whoever
    -- targets that row.
    --
    -- ⚠️ THE 128-BIT SHIFT CHECK THE RISCV PACKAGE MAKES IS NOT REPEATED HERE.
    -- rv64 has no 128-bit shift instruction, so picolibc's ryu float formatting
    -- leaves `__ashlti3`/`__lshrti3` undefined and the first bare-metal printf
    -- fails at LINK time. That is a riscv fact; asserting it here would reject
    -- a library that is right.
    --
    -- Verified end to end instead, which is the stronger claim: a soft-float
    -- `printf("%.2f")` image built against `thumbv7m-none-eabi` links AND runs
    -- under qemu `mps2-an385`, printing `picolibc: 13.00` and exiting 0.
    for _, p in ipairs(profiles) do
        local libdir = path.join(dir, "lib", p.triple)
        local incdir = path.join(dir, "include", p.triple)
        local required = {
            "libc.a", "libm.a", "libsemihost.a",
            "crt0-semihost.o", "picolibc.ld", "picolibcpp.ld",
            "libclang_rt.builtins-" .. p.arch .. ".a",
        }
        for _, f in ipairs(required) do
            if not os.isfile(path.join(libdir, f)) then
                raise("picolibc-arm payload is missing lib/" .. p.triple .. "/" .. f)
            end
        end
        if not os.isfile(path.join(incdir, "stdio.h")) then
            raise("picolibc-arm payload is missing include/" .. p.triple .. "/stdio.h")
        end
    end

    return true
end

function config()
    -- Umbrella node only.
    --
    -- ⚠️ These headers must NOT be published into the subos sysroot the way a
    -- host library's are. They are `thumb*-none-eabi` TARGET headers: putting
    -- them on the host include path would shadow the host libc for every
    -- ordinary build. A consumer points its `--sysroot`/`-isystem` at this
    -- package's install dir for the profile it wants.
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
