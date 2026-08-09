package = {
    spec = "2",
    -- base info
    name = "riscv64-linux-musl-gcc",
    description = "Cross GCC toolchain: host -> riscv64-linux-musl (musl, static-capable)",

    authors = {"GNU"},
    licenses = {"GPL"},
    repo = "https://github.com/gcc-mirror/gcc",
    docs = "https://gcc.gnu.org/wiki",

    -- xim pkg info
    type = "package",
    -- Host architectures this CROSS toolchain runs on. The TARGET is always
    -- riscv64-linux-musl (baked into the name). Distinct from `musl-gcc`,
    -- which is the host==target NATIVE toolchain. Built via musl-cross-make
    -- (Canadian-cross step A: build=x86_64, host=x86_64, target=riscv64).
    archs = {"x86_64"},
    status = "dev", -- dev, stable, deprecated
    categories = {"compiler", "gnu", "language", "cross"},
    keywords = {"compiler", "gnu", "gcc", "cross", "riscv64", "musl"},

    -- The prebuilt cross tools are host (x86_64) ELFs. The target sysroot under
    -- <root>/riscv64-linux-musl/{include,lib} holds riscv64 objects; libxpkg's
    -- predicate-driven elfpatch only rewrites host-arch ELFs, so the riscv64
    -- sysroot is left untouched.
    programs = {
        "riscv64-linux-musl-gcc", "riscv64-linux-musl-g++",
        "riscv64-linux-musl-c++", "riscv64-linux-musl-cpp",
        "riscv64-linux-musl-ar", "riscv64-linux-musl-as",
        "riscv64-linux-musl-ld", "riscv64-linux-musl-nm",
        "riscv64-linux-musl-objcopy", "riscv64-linux-musl-objdump",
        "riscv64-linux-musl-ranlib", "riscv64-linux-musl-readelf",
        "riscv64-linux-musl-strip", "riscv64-linux-musl-addr2line",
        "riscv64-linux-musl-c++filt", "riscv64-linux-musl-size",
        "riscv64-linux-musl-strings",
    },

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        linux = {
            -- No deps: a fully self-contained toolchain. The single host asset
            -- (x86_64) is FULLY STATIC — its host ELFs (gcc/g++/cc1plus/as/ld/
            -- ...) have no PT_INTERP and no NEEDED libs, so they need neither a
            -- libc loader in the sandbox (no xim:glibc) nor elfpatch relocation;
            -- the install hook just unpacks. Built via musl-cross-make with
            -- `CC/CXX="gcc -static --static"` (the double flag pierces binutils'
            -- libtool so even as-new/ld come out static).
            --   Unlike aarch64-linux-musl-gcc this one is glibc-static, not
            --   musl-static: the host compiler was the plain glibc gcc. That is
            --   fine here — verified no PT_INTERP/NEEDED and zero libnss_/__nss
            --   references, so nothing dlopens a host libc at runtime. The cost
            --   is size (141MB vs aarch64's 114MB: -O2, not -Os). Switch the
            --   builder to <host>-linux-musl-gcc + `-g0 -Os`/`LDFLAGS=-s` on the
            --   next rebuild to match the other toolchains.
            --   (History on aarch64: an earlier asset was glibc-DYNAMIC with a
            --    baked sandbox INTERP; on a cold sandbox its g++ died with exit
            --    127. Static — either libc — is what makes "no deps" true.)
            -- XLINGS_RES auto-URLs the host-matching asset
            -- <name>-<version>-<os>-<arch>.tar.gz off the res server, i.e.
            -- riscv64-linux-musl-gcc-16.1.0-linux-x86_64.tar.gz.
            -- The spec-2 per-arch `sha256` is what makes that verifiable: a
            -- bare ["ver"] = "XLINGS_RES" entry carries no checksum and would
            -- install this 141MB toolchain unverified.
            ["latest"] = { ref = "16.1.0" },
            -- gcc 16: fixes the GCC-15 module-instantiation link bug that
            -- forced an anchor workaround in mcpp (remediation doc A2).
            ["16.1.0"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "dc85b0a63a6e4582e3122d9f64025d324b1f69c8dc57bb093ceba40a25aae5b2",
                },
            },
        },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- ─────────────────────────────────────────────────────────────────────
-- gcc-flavor cross-registration (mirrors musl-gcc.lua)
--
-- Besides its own long-name programs (riscv64-linux-musl-gcc / -g++ / ...),
-- this toolchain also publishes itself under the unified `gcc` family with a
-- version TAG identifying it as the riscv64 musl cross compiler, so:
--   xlings use gcc 15.1.0                 # x86_64 glibc
--   xlings use gcc 15.1.0-musl            # x86_64 musl (native)
--   xlings use gcc 15.1.0-riscv64-musl    # riscv64 musl (cross)  <-- this pkg
--
-- Unlike native musl-gcc we do NOT inject `-Wl,--dynamic-linker=`: this is a
-- cross compiler, its output is riscv64 (not runnable on the x86_64 host), and
-- musl-cross-make already bakes the target loader `/lib/ld-musl-riscv64.so.1`
-- into the cross gcc specs.
-- ─────────────────────────────────────────────────────────────────────

local __gcc_flavor_progs = {
    ["gcc"] = "riscv64-linux-musl-gcc",
    ["g++"] = "riscv64-linux-musl-g++",
    ["c++"] = "riscv64-linux-musl-c++",
    ["cpp"] = "riscv64-linux-musl-cpp",
    ["cc"]  = "riscv64-linux-musl-gcc",
}

local function __gcc_flavor_version()
    return pkginfo.version() .. "-riscv64-musl"
end

local function __gcc_flavor_root_name()
    return "xim-riscv64-musl-gnu-gcc"
end

local function __register_as_gcc_flavor()
    local gcc_bindir = path.join(pkginfo.install_dir(), "bin")
    local flavor_ver = __gcc_flavor_version()
    local root_name  = __gcc_flavor_root_name()
    local flavor_root = string.format("%s@%s", root_name, flavor_ver)

    log.info("registering riscv64-linux-musl-gcc as gcc flavor %s ...", flavor_ver)

    -- Version is explicit and MUST equal flavor_ver: xvm.add() defaults it to
    -- pkginfo.version(), while every child binds to `<root_name>@<flavor_ver>`
    -- — a different exact node, so the root they name would never exist.
    -- xlings 2026.7.27.1 enforces this and rejects the batch with
    -- `xvm-binding-root-missing`. Same fix as pkgs/m/musl-gcc.lua.
    --
    -- `type = "group"` because this node names no artifact -- see
    -- pkgs/m/musl-gcc.lua for the full note (openxlings/xlings#452).
    xvm.add(root_name, { version = flavor_ver, type = "group" })
    for prog, target in pairs(__gcc_flavor_progs) do
        xvm.add(prog, {
            bindir  = gcc_bindir,
            alias   = target,
            version = flavor_ver,
            binding = flavor_root,
        })
    end
end

local function __unregister_gcc_flavor()
    local flavor_ver = __gcc_flavor_version()
    for prog, _ in pairs(__gcc_flavor_progs) do
        xvm.remove(prog, flavor_ver)
    end
    -- Versioned to match the node __register_as_gcc_flavor actually created.
    xvm.remove(__gcc_flavor_root_name(), flavor_ver)
end

function install()
    -- Tarball extracts to a dir matching the asset stem; relocate to install_dir.
    local srcdir = pkginfo.install_file()
        :replace(".tar.gz", "")
        :replace(".tar.xz", "")
        :replace(".zip", "")

    os.tryrm(pkginfo.install_dir())
    os.cp(srcdir, pkginfo.install_dir(), { force = true, symlink = true })

    return true
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")

    -- (1) Long-name programs form this toolchain's own binding subtree.
    local root = "riscv64-linux-musl-gcc@" .. pkginfo.version()
    xvm.add("riscv64-linux-musl-gcc", { bindir = bindir })
    for _, prog in ipairs(package.programs) do
        if prog ~= "riscv64-linux-musl-gcc" then
            xvm.add(prog, { bindir = bindir, binding = root })
        end
    end

    -- (2) Unified gcc family, version-tagged as the riscv64 musl cross flavor.
    __register_as_gcc_flavor()

    return true
end

function uninstall()
    __unregister_gcc_flavor()
    for _, prog in ipairs(package.programs) do
        xvm.remove(prog)
    end
    return true
end
