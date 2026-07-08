package = {
    spec = "1",
    -- base info
    name = "aarch64-linux-musl-gcc",
    description = "Cross GCC toolchain: host -> aarch64-linux-musl (musl, static-capable)",

    authors = {"GNU"},
    licenses = {"GPL"},
    repo = "https://github.com/gcc-mirror/gcc",
    docs = "https://gcc.gnu.org/wiki",

    -- xim pkg info
    type = "package",
    -- Host architectures this CROSS toolchain runs on. The TARGET is always
    -- aarch64-linux-musl (baked into the name). Distinct from `musl-gcc`,
    -- which is the host==target NATIVE toolchain. Built via musl-cross-make
    -- (Canadian-cross step A: build=x86_64, host=x86_64, target=aarch64).
    archs = {"x86_64", "aarch64"},
    status = "dev", -- dev, stable, deprecated
    categories = {"compiler", "gnu", "language", "cross"},
    keywords = {"compiler", "gnu", "gcc", "cross", "aarch64", "arm64", "musl"},

    -- The prebuilt cross tools are host (x86_64) ELFs. The target sysroot under
    -- <root>/aarch64-linux-musl/{include,lib} holds aarch64 objects; libxpkg's
    -- predicate-driven elfpatch only rewrites host-arch ELFs, so the aarch64
    -- sysroot is left untouched.
    programs = {
        "aarch64-linux-musl-gcc", "aarch64-linux-musl-g++",
        "aarch64-linux-musl-c++", "aarch64-linux-musl-cpp",
        "aarch64-linux-musl-ar", "aarch64-linux-musl-as",
        "aarch64-linux-musl-ld", "aarch64-linux-musl-nm",
        "aarch64-linux-musl-objcopy", "aarch64-linux-musl-objdump",
        "aarch64-linux-musl-ranlib", "aarch64-linux-musl-readelf",
        "aarch64-linux-musl-strip", "aarch64-linux-musl-addr2line",
        "aarch64-linux-musl-c++filt", "aarch64-linux-musl-size",
        "aarch64-linux-musl-strings",
    },

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        linux = {
            -- No deps: a fully self-contained toolchain. BOTH host assets are
            -- musl-static — their host ELFs (gcc/g++/cc1plus/as/ld/...) have no
            -- PT_INTERP and no NEEDED libs, so they need neither a libc loader
            -- in the sandbox (no xim:glibc) nor elfpatch relocation; the install
            -- hook just unpacks. Built via musl-cross-make with the musl host
            -- compiler and `-static --static` (the double flag pierces binutils'
            -- libtool so even as-new/ld come out static) + `-g0 -Os`/`LDFLAGS=-s`
            -- to strip. This is what keeps xlings hermetic: the toolchain leans
            -- on neither host nor sandbox glibc.
            --   (History: an earlier x86_64 asset was glibc-DYNAMIC with a baked
            --    sandbox INTERP; on a cold sandbox its g++ died with exit 127.
            --    Rebuilt musl-static so "no deps" is now actually true.)
            -- XLINGS_RES picks the host-matching asset:
            -- aarch64-linux-musl-gcc-<ver>-linux-{x86_64,aarch64}.tar.gz
            ["latest"] = { ref = "15.1.0" },
            -- gcc 16: fixes the GCC-15 module-instantiation link bug that
            -- forced an anchor workaround in mcpp (remediation doc A2).
            ["16.1.0"] = "XLINGS_RES",
            ["15.1.0"] = "XLINGS_RES",
        },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- ─────────────────────────────────────────────────────────────────────
-- gcc-flavor cross-registration (mirrors musl-gcc.lua)
--
-- Besides its own long-name programs (aarch64-linux-musl-gcc / -g++ / ...),
-- this toolchain also publishes itself under the unified `gcc` family with a
-- version TAG identifying it as the aarch64 musl cross compiler, so:
--   xlings use gcc 15.1.0                 # x86_64 glibc
--   xlings use gcc 15.1.0-musl            # x86_64 musl (native)
--   xlings use gcc 15.1.0-aarch64-musl    # aarch64 musl (cross)  <-- this pkg
--
-- Unlike native musl-gcc we do NOT inject `-Wl,--dynamic-linker=`: this is a
-- cross compiler, its output is aarch64 (not runnable on the x86_64 host), and
-- musl-cross-make already bakes the target loader `/lib/ld-musl-aarch64.so.1`
-- into the cross gcc specs.
-- ─────────────────────────────────────────────────────────────────────

local __gcc_flavor_progs = {
    ["gcc"] = "aarch64-linux-musl-gcc",
    ["g++"] = "aarch64-linux-musl-g++",
    ["c++"] = "aarch64-linux-musl-c++",
    ["cpp"] = "aarch64-linux-musl-cpp",
    ["cc"]  = "aarch64-linux-musl-gcc",
}

local function __gcc_flavor_version()
    return pkginfo.version() .. "-aarch64-musl"
end

local function __gcc_flavor_root_name()
    return "xim-aarch64-musl-gnu-gcc"
end

local function __register_as_gcc_flavor()
    local gcc_bindir = path.join(pkginfo.install_dir(), "bin")
    local flavor_ver = __gcc_flavor_version()
    local root_name  = __gcc_flavor_root_name()
    local flavor_root = string.format("%s@%s", root_name, flavor_ver)

    log.info("registering aarch64-linux-musl-gcc as gcc flavor %s ...", flavor_ver)

    xvm.add(root_name)
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
    xvm.remove(__gcc_flavor_root_name())
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
    local root = "aarch64-linux-musl-gcc@" .. pkginfo.version()
    xvm.add("aarch64-linux-musl-gcc", { bindir = bindir })
    for _, prog in ipairs(package.programs) do
        if prog ~= "aarch64-linux-musl-gcc" then
            xvm.add(prog, { bindir = bindir, binding = root })
        end
    end

    -- (2) Unified gcc family, version-tagged as the aarch64 musl cross flavor.
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
