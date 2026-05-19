package = {
    spec = "1",

    -- base info
    name = "gcc",
    description = "GCC, the GNU Compiler Collection",

    authors = {"GNU"},
    licenses = {"GPL"},
    repo = "https://github.com/gcc-mirror/gcc",
    docs = "https://gcc.gnu.org/wiki",

    -- xim pkg info
    type = "package",
    archs = { "x86_64" },
    status = "stable", -- dev, stable, deprecated
    categories = { "compiler", "gnu", "language" },
    keywords = { "compiler", "gnu", "gcc", "language", "c", "c++" },

    -- Cross-platform common-denominator only.
    -- Linux installs additionally register cpp / gcc-ar / gcc-nm / gcc-ranlib /
    -- gcov{,-dump,-tool} / x86_64-linux-gnu-{gcc,g++,c++} via xvm.add inside
    -- the for-loop in __config_linux (see linux_programs below). They are
    -- intentionally NOT in the top-level `programs` so that the windows
    -- declared-program audit (which has no per-platform programs mechanism
    -- yet) doesn't demand mingw-w64 to provide them.
    programs = { "gcc", "g++", "c++" },

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        linux = {
            deps = {
                "xim:glibc@2.39", "xim:binutils@2.42",
                -- fix xmake project --project=.  -k compile_commands
                -- home/xlings/.xlings_data/subos/linux/usr/include/bits/errno.h:26:11: fatal error: linux/errno.h: No such file or directory
                "xim:linux-headers@5.11.1",
                -- gcc-specs-config rewrites gcc's specs at install-time so
                -- the install-machine's xim:glibc loader path / lib64 are
                -- baked in. Without this, direct-invocation of
                -- <install_dir>/bin/gcc (bypassing the xvm shim's flag
                -- injection) emits binaries with INTERP=/lib64/... and
                -- RPATH empty, leaning on system glibc and breaking on
                -- distroless / Alpine / different glibc version.
                "xim:gcc-specs-config@0.0.1",
            },
            ["latest"] = { ref = "16.1.0" },
            ["16.1.0"] = "XLINGS_RES",
            ["15.1.0"] = "XLINGS_RES",
            ["13.3.0"] = "XLINGS_RES",
            ["11.5.0"] = "XLINGS_RES",
            ["9.4.0"] = "XLINGS_RES",
        },
        windows = {
            ["latest"] = { ref = "15.1.0" },
            ["15.1.0"] = {}, -- deps mingw64
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.pkgmanager")
-- elfpatch import removed: predicate-driven auto-patch (post 2026-05-02
-- design) reads glibc.lua's exports.runtime.loader and rewrites our
-- INTERP / RPATH automatically. Default scan = "convention" already
-- covers libexec/ (where cc1 / cc1plus / collect2 live), so the gcc-
-- specific bins = { "bin", "libexec" } is no longer needed.

-- Linux-only program list (registered as xvm shims by __config_linux).
-- Kept separate from package.programs so that the cross-platform declared-
-- program audit (which runs on windows where mingw-w64 only ships gcc/g++/c++)
-- doesn't demand shims that only exist on linux.
local linux_programs = {
    "gcc", "g++", "c++", "cpp",
    "gcc-ar", "gcc-nm", "gcc-ranlib",
    "gcov", "gcov-dump", "gcov-tool",
    "x86_64-linux-gnu-gcc", "x86_64-linux-gnu-g++", "x86_64-linux-gnu-c++",
}

local gcc_tool = {
    ["gcc-ar"] = true, ["gcc-nm"] = true, ["gcc-ranlib"] = true,
    ["gcov"] = true, ["gcov-dump"] = true, ["gcov-tool"] = true,
}

local gcc_lib = {
    -- not include glibc
    "libgcc_s.so", "libgcc_s.so.1",
    "libstdc++.so", "libstdc++.so.6",
    "libatomic.so", "libatomic.so.1",
    -- asan
    "libasan.so", "libasan.so.8",
}

local version_map_gcc2mingw = {
    ["15.1.0"] = "13.0.0",
}

local compiler_entry = {
    ["gcc"] = true,
    ["g++"] = true,
    ["c++"] = true,
    ["x86_64-linux-gnu-gcc"] = true,
    ["x86_64-linux-gnu-g++"] = true,
    ["x86_64-linux-gnu-c++"] = true,
}

function install()
    if os.host() == "windows" then
        pkgmanager.install("mingw-w64@" .. version_map_gcc2mingw[pkginfo.version()])
    else
        local srcdir = pkginfo.install_file():replace(".tar.gz", "")
        os.tryrm(pkginfo.install_dir())
        os.cp(srcdir, pkginfo.install_dir(), {
            symlink = true,
            verbose = true,
        })
    end
    return true
end

function config()
    if os.host() == "windows" then
        -- config in mingw-w64.lua
        return true
    else
        return __config_linux();
    end
end

function uninstall()
    if os.host() == "windows" then
        pkgmanager.uninstall("mingw-w64@" .. version_map_gcc2mingw[pkginfo.version()])
        return true
    end

    local gcc_version = "gcc-" .. pkginfo.version()
    for _, prog in ipairs(linux_programs) do
        if gcc_tool[prog] then
            xvm.remove(prog, gcc_version)
        else
            xvm.remove(prog)
        end
    end

    for _, lib in ipairs(gcc_lib) do
        xvm.remove(lib, gcc_version)
    end

    xvm.remove("xim-gnu-gcc")
    xvm.remove("cc")

    return true
end

-- private

function __config_linux()
    local gcc_bindir = path.join(pkginfo.install_dir(), "bin")
    local sysroot_dir = system.subos_sysrootdir()
    local sysroot_lib = nil
    local dynamic_linker = nil
    local alias_args = ""
    if sysroot_dir and sysroot_dir ~= "" then
        sysroot_lib = path.join(sysroot_dir, "lib")
        dynamic_linker = path.join(sysroot_lib, "ld-linux-x86-64.so.2")
        alias_args = string.format(
            ' --sysroot=%s -Wl,--dynamic-linker=%s -Wl,--enable-new-dtags,-rpath,%s -Wl,-rpath-link,%s',
            sysroot_dir, dynamic_linker, sysroot_lib, sysroot_lib
        )
        __rewrite_specs_linux(sysroot_dir, sysroot_lib, dynamic_linker)
    else
        log.warn("subos dir is empty, skip alias linker/sysroot injection")
    end

    xvm.add("xim-gnu-gcc") -- root

    local config = {
        bindir = gcc_bindir,
        binding = "xim-gnu-gcc@" .. pkginfo.version(),
        envs = {
            --["LD_LIBRARY_PATH"] = ld_lib_path,
            --["LD_RUN_PATH"] = ld_lib_path,
        }
    }

    for _, prog in ipairs(linux_programs) do

        config.alias = prog

        if compiler_entry[prog] then config.alias = prog .. alias_args end

        if gcc_tool[prog] then
            config.version = "gcc-" .. pkginfo.version()
            xvm.add(prog, config)
        else
            config.version = pkginfo.version()
            xvm.add(prog, config)
        end
    end

    -- lib
    log.debug("add gcc libs...")
    local lib_config = {
        type = "lib",
        version = "gcc-" .. pkginfo.version(),
        bindir = path.join(pkginfo.install_dir(), "lib64"),
        binding = "xim-gnu-gcc@" .. pkginfo.version(),
    }

    for _, lib in ipairs(gcc_lib) do
        lib_config.filename = lib -- target file name
        lib_config.alias = lib    -- source file name
        xvm.add(lib, lib_config)
    end

    -- "cc"
    xvm.add("cc", {
        alias = "gcc" .. alias_args,
        version = pkginfo.version(),
        binding = "xim-gnu-gcc@" .. pkginfo.version(),
    })

    return true
end

-- Rewrite gcc's specs file in-place so direct invocation of
-- <install_dir>/bin/gcc (without the xvm shim's flag injection)
-- emits binaries with the correct install-machine INTERP / RPATH.
-- The prebuilt-tarball-baked specs has the build-machine's path,
-- which doesn't exist on the install machine, so this is mandatory.
--
-- Has to live in config() rather than install() because the
-- gcc-specs-config shim only exists in subos/default/bin AFTER its
-- own config() has run — install() of gcc fires before any
-- dependent's config(), so the shim is not yet on disk.
--
-- Gated by a stamp file so that downstream xpkg installs (which
-- re-fire gcc.config()) don't rewrite the specs every time. Same
-- pattern as glibc.lua's __config_header() header-copy gate. The
-- stamp lives inside install_dir and is wiped on `xim reinstall
-- gcc` along with the rest of the payload, so version bumps and
-- forced reinstalls naturally re-rewrite.
function __rewrite_specs_linux(sysroot_dir, sysroot_lib, dynamic_linker)
    local stamp = path.join(
        pkginfo.install_dir(),
        ".specs-rewritten-" .. pkginfo.version() .. ".stamp"
    )
    if os.isfile(stamp) then
        log.debug("gcc specs already rewritten (stamp present), skipping.")
        return
    end

    local gcc_bin = path.join(pkginfo.install_dir(), "bin/gcc")
    local specs_config_bin = path.join(system.bindir(), "gcc-specs-config")

    log.info("Rewriting gcc specs to install-machine paths via gcc-specs-config...")
    system.exec(string.format(
        "%s %s --dynamic-linker %s --rpath %s --linker-type gnu",
        specs_config_bin, gcc_bin, dynamic_linker, sysroot_lib
    ))

    io.writefile(stamp, pkginfo.version())
end
