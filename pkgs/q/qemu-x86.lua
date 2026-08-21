package = {
    spec = "2",
    homepage = "https://www.qemu.org/",

    name = "qemu-x86",
    description = "qemu-system-x86_64 - the x86_64 system emulator, built from source for five hosts",

    maintainers = {"https://github.com/mcpplibs/qemu-x86/graphs/contributors"},
    licenses = {"GPL-2.0-only"},
    repo = "https://github.com/mcpplibs/qemu-x86",
    docs = "https://www.qemu.org/docs/master/",

    programs = {"qemu-system-x86_64"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"emulator", "virtualization", "baremetal"},
    keywords = {"qemu", "x86_64", "emulator", "baremetal", "freestanding"},

    xvm_enable = true,

    -- ⭐ THIS PACKAGE IS BUILT RATHER THAN REPACKAGED, AND THAT IS WHY IT
    -- EXISTS AT ALL.
    --
    -- `qemu-arm` and `qemu-riscv` repackage xPack's prebuilt archives. xPack
    -- publishes no x86_64 build, so there was nothing to repackage: the
    -- artifacts here are configured with `--target-list=x86_64-softmmu` and
    -- built by `mcpplibs/qemu-x86`'s own workflow on five hosts. GLOBAL
    -- therefore points at that project the way `qemu-arm`'s points at
    -- xpack-dev-tools -- in both cases, at whoever produced the bytes.
    --
    -- ⚠️ SINGLE TARGET, SINGLE PROGRAM. `--target-list=x86_64-softmmu` is the
    -- whole reason a 27 MB archive can serve a job that would otherwise pull
    -- a multi-hundred-megabyte all-targets build. It also means `programs`
    -- names exactly one emulator, unlike `qemu-arm`, which ships two.
    xpm = {
        linux = {
            -- ⚠️ `deps` IS DELIBERATELY EMPTY, AND THE MEASUREMENT BEHIND THAT
            -- IS THIS PAYLOAD'S OWN.
            --
            -- Measured resolution of bin/qemu-system-x86_64 through the
            -- loader itself, not through `ldd` (2026-08-21). Fifteen objects
            -- resolve; twelve come out of the payload's own `lib/` by way of
            -- `RUNPATH=$ORIGIN/../lib`:
            --
            --     libblkid  libffi  libgio-2.0  libglib-2.0  libgmodule-2.0
            --     libgobject-2.0  libmount  libpcre2-8  libpixman-1
            --     libselinux  libz  libzstd
            --
            -- Exactly two cross the payload boundary, and both are core glibc:
            --
            --     libm.so.6  libc.so.6
            --
            -- Declaring `xim:glibc@...` would hand xlings' predicate-driven
            -- elfpatch a loader provider to key off, and elfpatch REPLACES the
            -- runtime search tag rather than prepending to it -- so all twelve
            -- bundled libraries would go out of reach while the install still
            -- reported success, the break surfacing only on first run. With no
            -- dep the predicate never fires, the binary keeps its own INTERP
            -- and `$ORIGIN/../lib`, and it runs against the host glibc.
            --
            -- ⚠️ The `ldd` on a subos PATH is a shell script that fails to
            -- parse under some shells, and it fails on STDERR. A closure check
            -- written as `ldd ... 2>/dev/null | grep -v <payload>` therefore
            -- prints nothing and reads exactly like "nothing escapes". The
            -- numbers above come from `LD_TRACE_LOADED_OBJECTS=1` invoked on
            -- the loader directly.
            source = {
                GLOBAL = "https://github.com/mcpplibs/qemu-x86/releases/download/${version}/qemu-x86-${version}-linux-${arch_alias}.tar.gz",
                CN = "https://gitcode.com/xlings-res/qemu-x86/releases/download/${version}/qemu-x86-${version}-linux-${arch_alias}.tar.gz",
            },
            ["latest"] = { ref = "9.2.4-1" },
            ["9.2.4-1"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64  = "f4deefc7a010884855c2a8f79d7e972829ee973fdf73fdf1aa4e3cce08b621ae",
                    aarch64 = "53d66136db6bc0aea662fe4f1ec1294bcc41713f766b63c8ec6e35e1bff081a2",
                },
            },
        },
        macosx = {
            -- Same shape, measured with `otool -L` rather than the loader:
            -- eighteen libraries are bundled under `lib/` and reached through
            -- `@loader_path/../lib`, and every Homebrew absolute path was
            -- rewritten at build time. What remains outside is `/System/...`
            -- and `/usr/lib`, which no package provides and none should.
            --
            -- ⚠️ The rewritten binaries are re-signed ad-hoc as part of the
            -- build: `install_name_tool` invalidates the signature, and macOS
            -- kills an invalidly-signed binary rather than reporting a load
            -- error. Nothing here has to redo that; it is noted because a
            -- future repackaging that edits install names MUST.
            source = {
                GLOBAL = "https://github.com/mcpplibs/qemu-x86/releases/download/${version}/qemu-x86-${version}-darwin-${arch_alias}.tar.gz",
                CN = "https://gitcode.com/xlings-res/qemu-x86/releases/download/${version}/qemu-x86-${version}-darwin-${arch_alias}.tar.gz",
            },
            ["latest"] = { ref = "9.2.4-1" },
            ["9.2.4-1"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64  = "9c6335c6c2901b397302131cb02df8f729547d957010da12a26a5902ecf1c21e",
                    aarch64 = "4fa9c1110401a6f55b121e15139629a88f9e81e1aea739c7d25b6fa4796f625b",
                },
            },
        },
        windows = {
            -- PE has no runtime search path, so the thirteen MSYS2 DLLs sit in
            -- `bin/` beside the executable, which is where the loader looks
            -- first. The archive is a `.zip` rather than a `.tar.gz` for the
            -- same reason every other windows asset here is.
            source = {
                GLOBAL = "https://github.com/mcpplibs/qemu-x86/releases/download/${version}/qemu-x86-${version}-win32-${arch_alias}.zip",
                CN = "https://gitcode.com/xlings-res/qemu-x86/releases/download/${version}/qemu-x86-${version}-win32-${arch_alias}.zip",
            },
            ["latest"] = { ref = "9.2.4-1" },
            ["9.2.4-1"] = {
                arch_alias = { x86_64 = "x64" },
                sha256 = {
                    x86_64 = "8e5c32903908c1f8daaf9b0da88fb064d0b26a91438a8328bf2327892060ac01",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- ⚠️ THE ARCHIVES HAVE NO WRAP DIRECTORY -- `bin/` and `share/` are at the
-- root -- so unlike `qemu-arm` there is no upstream-chosen name to look for.
-- What xim hands us is the extraction directory named after the archive, and
-- that directory IS the payload root. The fallback exists for a repackaged
-- mirror asset whose name does not match.
local function payload_root()
    local named = pkginfo.install_file()
        :replace(".tar.gz", "")
        :replace(".zip", "")
    local exe = is_host("windows") and "qemu-system-x86_64.exe" or "qemu-system-x86_64"

    if os.isfile(path.join(named, "bin", exe)) then
        return named
    end

    local base = path.directory(pkginfo.install_file())
    for _, d in ipairs(os.dirs(path.join(base, "*"))) do
        if os.isfile(path.join(d, "bin", exe)) then
            return d
        end
    end

    raise("cannot find the qemu-x86 payload under '" .. base
          .. "': no directory contains bin/" .. exe)
end

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv(payload_root(), dir)

    local exe = is_host("windows") and "qemu-system-x86_64.exe" or "qemu-system-x86_64"
    if not os.isfile(path.join(dir, "bin", exe)) then
        raise("qemu-x86 payload is missing bin/" .. exe)
    end

    -- ⚠️ ASSERT THE FIRMWARE, NOT JUST THE EXECUTABLE, AND ASSERT IT HERE.
    --
    -- qemu resolves its datadir relative to the executable, so an extraction
    -- that produced `bin/` and dropped `share/` yields an emulator that
    -- answers `--version` and then fails to boot anything. `-kernel <elf>`
    -- needs no BIOS, but the default machine does, and a payload that can only
    -- serve the first is a payload whose fault surfaces in somebody else's
    -- project. `bios-256k.bin` is the default x86 firmware and is present in
    -- all five archives (verified 2026-08-21).
    --
    -- Unlike qemu-arm this needs no per-platform candidate list: this build
    -- puts share/qemu at the same place on all three platforms, because the
    -- same workflow assembles all three.
    local bios = path.join(dir, "share", "qemu", "bios-256k.bin")
    if not os.isfile(bios) then
        raise("qemu-x86 payload has no share/qemu/bios-256k.bin -- the "
              .. "emulator would answer --version and then fail to boot")
    end

    return true
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")

    -- Umbrella node for the package name itself, plus the one program. Nobody
    -- types `qemu-x86`, but `xlings use qemu-x86@<ver>` and Spec D1 key off it.
    xvm.add(package.name)
    xvm.add("qemu-system-x86_64", { bindir = bindir })
    return true
end

function uninstall()
    xvm.remove("qemu-system-x86_64")
    xvm.remove(package.name)
    return true
end
