package = {
    spec = "1",
    -- base info
    name = "musl-gcc",
    description = "GCC, the GNU Compiler Collection (prebuilt with musl)",

    authors = {"GNU"},
    licenses = {"GPL"},
    repo = "https://github.com/gcc-mirror/gcc",
    docs = "https://gcc.gnu.org/wiki",

    -- xim pkg info
    type = "package",
    -- Native (host == target) musl toolchain. XLINGS_RES picks the
    -- host-matching asset: musl-gcc-<ver>-linux-x86_64 on x86_64,
    -- musl-gcc-<ver>-linux-aarch64 on aarch64. All install/config logic below
    -- is triple-agnostic (detected from the payload), so the same package
    -- serves both arches.
    archs = {"x86_64", "aarch64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"compiler", "gnu", "language"},
    keywords = {"compiler", "gnu", "gcc", "language", "c", "c++"},

    programs = {
        -- "musl-gcc-static", "musl-g++-static",
        "musl-gcc", "musl-g++", "musl-c++", "musl-cpp",
        "musl-addr2line", "musl-ar", "musl-as", "musl-ld", "musl-nm",
        "musl-objcopy", "musl-objdump", "musl-ranlib", "musl-readelf",
        "musl-size", "musl-strings", "musl-strip",
    },

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        linux = {
            -- patchelf is required by __patch_toolchain_dynamic_bins() in
            -- install() — the prebuilt tarball ships every binutils binary
            -- (~16 entries under bin/<triple>-* AND under <triple>/bin/) with
            -- PT_INTERP hardcoded to the canonical
            -- /home/xlings/.xlings_data/lib/ld-musl-<arch>.so.1 path. Without
            -- patchelf the relocation step silently no-ops and the toolchain
            -- only runs where that exact path resolves — breaking non-default
            -- XLINGS_HOME / containers / fresh machines. Declaring the dep
            -- guarantees patchelf is on the install-hook PATH.
            deps = { "xim:patchelf@0.18.0" },

            -- toolchain build based on musl-gcc-static
            ["latest"] = { ref = "15.1.0" },
            -- gcc 16: fixes the GCC-15 module-instantiation link bug
            -- (mcpp remediation doc A2/R5b); stripped ~105MB assets.
            ["16.1.0"] = "XLINGS_RES",
            ["15.1.0"] = "XLINGS_RES", -- deps musl-gcc
            ["13.3.0"] = "XLINGS_RES",
            ["11.5.0"] = "XLINGS_RES",
            ["9.4.0"] = "XLINGS_RES",
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- Detect the toolchain triple (e.g. x86_64-linux-musl / aarch64-linux-musl)
-- from the installed payload's `bin/<triple>-gcc`, so all logic below is
-- arch-agnostic. Native build => triple's arch == host arch.
local function __musl_triple()
    -- Detect from the payload's frontend `bin/<triple>-gcc` via os.isfile —
    -- the most reliable sandbox primitive (os.files is nil here, os.isdir
    -- proved unreliable). aarch64 first so the native aarch64 toolchain wins.
    local bindir = path.join(pkginfo.install_dir(), "bin")
    for _, t in ipairs({"aarch64-linux-musl", "x86_64-linux-musl"}) do
        if os.isfile(path.join(bindir, t .. "-gcc")) then return t end
    end
    return "x86_64-linux-musl"                  -- fallback
end

-- "<triple>-linux-musl" -> "<arch>" (the part before "-linux")
local function __musl_arch(triple)
    return triple:split("-linux")[1]
end

local function __dynamic_bins(triple)
    local tools = {
        "addr2line", "ar", "as", "c++filt", "elfedit", "gprof",
        "ld", "ld.bfd", "nm", "objcopy", "objdump", "ranlib",
        "readelf", "size", "strings", "strip",
    }
    local out = {}
    for _, t in ipairs(tools) do table.insert(out, triple .. "-" .. t) end
    -- target-prefixed copies (live under <triple>/bin/)
    for _, t in ipairs({"ar","as","ld","ld.bfd","nm","objcopy","objdump","ranlib","readelf","strip"}) do
        table.insert(out, t)
    end
    return out
end

local function __patch_toolchain_dynamic_bins()
    local install_dir = pkginfo.install_dir()
    local triple = __musl_triple()
    local musl_lib_dir = path.join(install_dir, triple, "lib")
    local musl_loader = path.join(musl_lib_dir, "libc.so")

    -- Relocation only applies to a musl-DYNAMIC toolchain (bins whose PT_INTERP
    -- points at musl's libc.so). A static toolchain (no libc.so / no INTERP) and
    -- a host without patchelf need no relocation — skip gracefully rather than
    -- failing the install.
    if not os.isfile(musl_loader) then
        log.warn("musl-gcc: no musl libc.so at %s; skipping relocation (static toolchain?)", musl_loader)
        return
    end
    local have_patchelf = try {
        function() os.exec("patchelf --version"); return true end,
        catch = function() return false end
    }
    if not have_patchelf then
        log.warn("musl-gcc: patchelf unavailable; skipping dynamic-bin relocation")
        return
    end

    local bindirs = {
        path.join(install_dir, "bin"),
        path.join(install_dir, triple, "bin"),
    }

    local patched = 0
    for _, bindir in ipairs(bindirs) do
        if os.isdir(bindir) then
            for _, name in ipairs(__dynamic_bins(triple)) do
                local target = path.join(bindir, name)
                if os.isfile(target) then
                    -- only dynamic ELFs have an interpreter; skip static bins.
                    local interp = try {
                        function() return os.iorun("patchelf --print-interpreter " .. target) end,
                        catch = function() return "" end
                    }
                    if interp and interp:trim() ~= "" then
                        os.exec(string.format("patchelf --set-interpreter %q %q", musl_loader, target))
                        os.exec(string.format("patchelf --set-rpath %q %q", musl_lib_dir, target))
                        patched = patched + 1
                    end
                end
            end
        end
    end

    log.info("musl-gcc relocate (%s): patched dynamic tools = %d", triple, patched)
end

-- ─────────────────────────────────────────────────────────────────────
-- gcc-flavor cross-registration
--
-- A musl-gcc install also publishes itself under the standard `gcc` family
-- of program names with version suffix `-musl` (e.g. `15.1.0-musl`):
--   xlings use gcc 15.1.0          # glibc
--   xlings use gcc 15.1.0-musl     # musl (this package, host-native)
--
-- See git history for the rationale on the suffix (sorts alongside 15.1.0),
-- the frontends-only shimming (gcc drives cc1/as/ld internally), and why we
-- inject `-Wl,--dynamic-linker=`/`-rpath` to the toolchain-shipped libc.so
-- (musl: libc.so doubles as the dynamic linker) but NOT `--sysroot`.
-- All names/paths are derived from the detected triple so this works for any
-- host arch (x86_64, aarch64, ...).
-- ─────────────────────────────────────────────────────────────────────

local function __gcc_flavor_progs(triple)
    return {
        ["gcc"] = triple .. "-gcc",
        ["g++"] = triple .. "-g++",
        ["c++"] = triple .. "-c++",
        ["cpp"] = triple .. "-cpp",
        ["cc"]  = triple .. "-gcc",
    }
end

local function __gcc_flavor_version()
    return pkginfo.version() .. "-musl"
end

local function __gcc_flavor_root_name()
    return "xim-musl-gnu-gcc"
end

local function __gcc_flavor_alias_args()
    local musl_lib_dir = path.join(
        pkginfo.install_dir(), __musl_triple(), "lib"
    )
    local musl_loader = path.join(musl_lib_dir, "libc.so")
    return string.format(
        " -Wl,--dynamic-linker=%s -Wl,-rpath,%s",
        musl_loader, musl_lib_dir
    )
end

local function __register_as_gcc_flavor()
    local gcc_bindir = path.join(pkginfo.install_dir(), "bin")
    local flavor_ver = __gcc_flavor_version()
    local alias_args = __gcc_flavor_alias_args()
    local root_name = __gcc_flavor_root_name()
    local flavor_root = string.format("%s@%s", root_name, flavor_ver)

    log.info("registering musl-gcc as gcc flavor %s (root: %s) ...",
             flavor_ver, flavor_root)

    -- Anchor a virtual root node for this flavor's subtree.
    xvm.add(root_name)

    for prog, target in pairs(__gcc_flavor_progs(__musl_triple())) do
        xvm.add(prog, {
            bindir  = gcc_bindir,
            alias   = target .. alias_args,
            version = flavor_ver,
            binding = flavor_root,
        })
    end
end

local function __unregister_gcc_flavor()
    local flavor_ver = __gcc_flavor_version()
    for prog, _ in pairs(__gcc_flavor_progs(__musl_triple())) do
        xvm.remove(prog, flavor_ver)
    end
    -- Drop the virtual root only if no other musl-gcc version still hangs
    -- registrations off it (xvm.remove on an empty target is a no-op there).
    xvm.remove(__gcc_flavor_root_name())
end

local function __remove_specs()
    local install_dir = pkginfo.install_dir()
    local specs_file = path.join(
        install_dir,
        "lib", "gcc", __musl_triple(), pkginfo.version(), "specs"
    )

    if not os.isfile(specs_file) then
        log.info("musl-gcc: specs file not found, skip remove: %s", specs_file)
        return
    end

    os.tryrm(specs_file)
    log.info("musl-gcc: removed specs file: %s", specs_file)
end

function install()
    local gccdir = pkginfo.install_file()
        :replace(".tar.gz", "")
        :replace(".zip", "")
    os.tryrm(pkginfo.install_dir())
    os.mv(gccdir, pkginfo.install_dir())
    __patch_toolchain_dynamic_bins()
    __remove_specs()
    return true
end

function config()
    local gcc_bindir = path.join(pkginfo.install_dir(), "bin")
    local triple = __musl_triple()
    local arch_prefix = __musl_arch(triple) .. "-linux-"  -- e.g. "aarch64-linux-"

    -- binding tree - root node
    local binding_tree_root = "musl-gcc@" .. pkginfo.version()
    xvm.add("musl-gcc", {
        bindir = gcc_bindir,
        alias = triple .. "-gcc",
    })

    local __binding_tree_root = triple .. "-gcc@" .. pkginfo.version()
    xvm.add(triple .. "-gcc", { bindir = gcc_bindir })

    for _, prog in ipairs(package.programs) do
        if prog ~= "musl-gcc" then
            xvm.add(prog, {
                bindir = gcc_bindir,
                alias = arch_prefix .. prog,
                binding = binding_tree_root,
            })
            -- full-name (e.g. aarch64-linux-musl-ar)
            xvm.add(arch_prefix .. prog, {
                bindir = gcc_bindir,
                binding = __binding_tree_root,
            })
        end
    end

-- runtime lib path (used by musl-ldd / musl-loader only)
    local musl_lib_dir = path.join(
        pkginfo.install_dir(), triple, "lib"
    )

-- special commands: musl-ldd and musl-loader invoke libc.so (the musl
-- dynamic linker) via an alias wrapper, so RPATH cannot apply.  Setting
-- LD_LIBRARY_PATH directly is a deliberate, documented exception.
    xvm.add("musl-ldd", {
        version = "musl-gcc-" .. pkginfo.version(),
        bindir = musl_lib_dir,
        alias = "libc.so --list",
        envs = {
            LD_LIBRARY_PATH = musl_lib_dir,
        },
        binding = binding_tree_root,
    })

    xvm.add("musl-loader", {
        version = "musl-gcc-" .. pkginfo.version(),
        bindir = musl_lib_dir,
        alias = "libc.so",
        envs = {
            LD_LIBRARY_PATH = musl_lib_dir,
        },
        binding = binding_tree_root,
    })

    log.info("add static wrapper for musl-gcc ...")
    xvm.add("musl-gcc-static", { alias = "musl-gcc -static", binding = binding_tree_root })
    xvm.add("musl-g++-static", { alias = "musl-g++ -static", binding = binding_tree_root })

    __register_as_gcc_flavor()

    return true
end

function uninstall()
    local arch_prefix = __musl_arch(__musl_triple()) .. "-linux-"
    __unregister_gcc_flavor()
    for _, prog in ipairs(package.programs) do
        xvm.remove(prog)
        xvm.remove(arch_prefix .. prog)
    end
    -- special commands
    xvm.remove("musl-ldd", "musl-gcc-" .. pkginfo.version())
    xvm.remove("musl-loader", "musl-gcc-" .. pkginfo.version())
    xvm.remove("musl-gcc-static")
    xvm.remove("musl-g++-static")
    return true
end
