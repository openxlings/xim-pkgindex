package = {
    spec = "2",
    homepage = "https://keithp.com/picolibc/",

    name = "picolibc-aarch64",
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
    categories = {"library", "embedded", "aarch64", "libc"},
    keywords = {"picolibc", "aarch64", "baremetal", "freestanding", "libc"},

    -- No programs: this is a sysroot, not a tool. `config()` registers only the
    -- umbrella node so `xlings use picolibc-aarch64@<ver>` works.
    xvm_enable = true,

    -- ⭐ The payload is TARGET code (aarch64 static archives, object files and
    -- linker scripts), so it is host-independent: ONE archive serves
    -- linux/macosx/windows on every arch. Hence one URL and one sha256 rather
    -- than a per-arch table -- which is also what tells the mirror tooling to
    -- treat it as an arch-independent asset.
    --
    -- ⚠️ UPSTREAM DOES PUBLISH AN aarch64-none-elf PREBUILT, so unlike
    -- `picolibc-riscv` the reason to build is not absence. It is CONTENT: this
    -- archive carries picolibc AND the compiler-rt builtins that link it, both
    -- produced by the index's own llvm payload. A picolibc built by a different
    -- compiler is not wrong, but the builtins that come with it are that
    -- compiler's, and mixing them is a class of link failure nobody should have
    -- to debug.
    --
    -- Built by `.agents/tools/build-baremetal-sysroot.sh --family aarch64`. The
    -- script is the reproduction: same inputs, same bytes (fixed tar
    -- owner/mtime and sorted member order).
    --
    -- ⚠️ No `ci` block, deliberately. `mirror` would point the mirror at
    -- xlings-res, i.e. at itself. `update` would bump `latest` to a new
    -- picolibc release and re-download a URL that does not exist yet -- this
    -- artifact has to be REBUILT for a version bump, and that is a human step:
    -- run the script, publish, then edit this file.
    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/picolibc-aarch64/releases/download/${version}/picolibc-aarch64-${version}.tar.gz",
            CN = "https://gitcode.com/xlings-res/picolibc-aarch64/releases/download/${version}/picolibc-aarch64-${version}.tar.gz",
        },
        linux = {
            ["latest"] = { ref = "1.8.12" },
            ["1.8.12"] = { sha256 = "e42b24b9a74a0d0b1593cfb3e9df2de61db9a0a54b1efdc7cdad11882d022315" },
        },
        macosx = {
            ["latest"] = { ref = "1.8.12" },
            ["1.8.12"] = { sha256 = "e42b24b9a74a0d0b1593cfb3e9df2de61db9a0a54b1efdc7cdad11882d022315" },
        },
        windows = {
            ["latest"] = { ref = "1.8.12" },
            ["1.8.12"] = { sha256 = "e42b24b9a74a0d0b1593cfb3e9df2de61db9a0a54b1efdc7cdad11882d022315" },
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
    {march = "armv8-a", mabi = "aapcs", arch = "aarch64"},
}

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)

    -- One fixed archive name, so unlike a per-host package there is nothing to
    -- derive from the platform here.
    local extracted = pkginfo.install_file():replace(".tar.gz", "")
    if not os.isdir(extracted) then
        raise("picolibc-aarch64 payload not found at " .. extracted)
    end
    os.mv(extracted, dir)

    -- Assert the payload per profile rather than trusting the archive.
    -- ⚠️ THE 128-BIT SHIFT CHECK THE RISCV PACKAGE MAKES IS NOT REPEATED HERE,
    -- AND THAT IS MEASURED RATHER THAN ASSUMED. rv64 has no 128-bit shift
    -- instruction, so picolibc's ryu float formatting leaves __ashlti3 /
    -- __lshrti3 undefined and the first bare-metal printf fails at LINK time.
    -- aarch64 has the instructions and its builtins legitimately do not export
    -- those symbols; asserting them here would reject a library that is right.
    --
    -- Verified end to end instead, which is the stronger claim: a `printf`
    -- image built against this payload links AND runs under qemu `virt`
    -- (`picolibc aarch64 ok 42`), on the default 128 MB of RAM.
    for _, p in ipairs(profiles) do
        local libdir = path.join(dir, "lib", p.march, p.mabi)
        local incdir = path.join(dir, "include", p.march, p.mabi)
        local required = {
            "libc.a", "libm.a", "libsemihost.a",
            "crt0-semihost.o", "picolibc.ld", "picolibcpp.ld",
            "libclang_rt.builtins-" .. p.arch .. ".a",
        }
        for _, f in ipairs(required) do
            if not os.isfile(path.join(libdir, f)) then
                raise("picolibc-aarch64 payload is missing lib/"
                      .. p.march .. "/" .. p.mabi .. "/" .. f)
            end
        end
        if not os.isfile(path.join(incdir, "stdio.h")) then
            raise("picolibc-aarch64 payload is missing include/"
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
    -- usr/include). They are `aarch64-none-elf` TARGET headers: putting them
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
