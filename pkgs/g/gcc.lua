package = {

    -- Platform version sets differ ON PURPOSE:
    -- windows tracks its own `latest` (15.1.0) and does not carry the linux lineage's newer builds; the Windows toolchain is served by mingw-w64.
    -- Declared so `tests/check_platform_version_parity.lua` can tell this
    -- apart from a bump that landed in one section and was forgotten in the
    -- others -- which reads as `<pkg>@<ver> not found` on the platforms that
    -- lack it, against a file that contains the version string.
    platform_versions_diverge = true,
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
                "xim:glibc@>=2.39", "xim:binutils@2.42",
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
        __prune_stale_fixincludes()
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
        -- Delegated, like install(). This package registers no xvm version of
        -- its own on Windows -- every shim under `gcc`, `g++`, `c++` belongs to
        -- mingw-w64 -- so removal has nothing of its own to select, and it used
        -- to fail with `exact removal version is not registered`
        -- (openxlings/xlings#506).
        --
        -- xlings 2026.8.10.1 answered that on its side: removal decides
        -- ownership by the provider whose uninstall hook is running, so another
        -- provider's version under the same target neither blocks this hook nor
        -- enters its removal set. The tolerance that used to skip this case in
        -- windows-test.ps1 is removed in the same change as this comment.
        --
        -- Which means the shim cleanup below is now asserted rather than
        -- skipped: `programs` above IS the mingw-w64-provided set, so this
        -- delegation is what has to take those shims away.
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

-- Drop the headers fixincludes froze at gcc-build time.
--
-- When gcc is built, `fixincludes` copies system headers it judges broken into
-- `lib/gcc/<triple>/<ver>/include-fixed/` and patches them. That directory
-- precedes the sysroot in the search order, so the copies WIN over the live
-- headers -- which is the whole point when the sysroot never moves, and exactly
-- wrong for a relocatable toolchain whose sysroot is a package we upgrade.
--
-- Measured on the 15.1.0 payload, 2026-08-08 (openxlings/xim-pkgindex#560):
--
--   include-fixed/pthread.h  was frozen from
--       /home/xlings/.xlings_data/subos/linux/usr/include/pthread.h
--   i.e. from OUR OWN sysroot as it stood at gcc build time -- glibc 2.39. The
--   sysroot is now glibc 2.44, and 2.44 changed the layout of pthread_cond_t:
--
--     2.39  #define PTHREAD_COND_INITIALIZER { { {0}, {0}, {0,0}, {0,0}, 0, 0, {0,0} } }
--     2.44  #define PTHREAD_COND_INITIALIZER { { {0}, {0}, {0,0}, 0, 0, {0,0}, 0, 0 } }
--
--   The frozen macro is fed to the live type, so libstdc++'s own
--   `ext/concurrence.h:257` stops compiling:
--
--     cannot convert '<brace-enclosed initializer list>' to 'unsigned int'
--
--   Any C++ translation unit reaching that header fails, which is most of them.
--   It took down an LLVM build at 13/4049 with an error naming neither gcc nor
--   the header that shadowed. With the file removed, `-H` shows the sysroot's
--   pthread.h winning and the same unit compiles clean.
--
-- So this is not host leakage -- it is VERSION SKEW against our own glibc, and
-- it recurs on every glibc bump for any gcc that ships an include-fixed copy.
--
-- The discriminator is the fixincludes banner, not a filename list. gcc also
-- puts genuinely-generated headers here (`limits.h`, `syslimits.h`) which carry
-- no banner and must stay; a filename allowlist would need editing every time
-- fixincludes decides to freeze something new, and the failure mode of guessing
-- wrong is silent. 16.1.0's include-fixed holds only README, so this is a no-op
-- there -- which is the shape to want: the fix is not conditioned on a version.
function __prune_stale_fixincludes()
    local banner = "auto-edited by fixincludes"
    local root = path.join(pkginfo.install_dir(), "lib", "gcc")
    if not os.isdir(root) then return end

    -- Found with `grep -rl`, not with a Lua directory walk.
    --
    -- This took three wrong primitives to get right, and all three failed the
    -- same way -- an install hook dying on "attempt to call a nil value":
    --
    --   os.files     nil in the recipe sandbox (already recorded in
    --                pkgs/m/musl-gcc.lua, and written here anyway)
    --   os.exists    nil
    --   os.filedirs  nil -- despite pkgs/i/interposer-stub.lua:86 calling it,
    --                which means that error path has never run either
    --
    -- os.dirs works but lists only directories, and this needs FILES, recursively
    -- (fixincludes nests into bits/, sys/). `os.iorun` is attested by 36 recipes,
    -- and grep does the recursion and the file discrimination in one call -- so
    -- there is nothing left to get wrong about the traversal.
    --
    -- `|| true` because grep exits 1 when it matches nothing, which is the
    -- healthy case here, and os.iorun raises on a non-zero exit.
    local out = os.iorun(string.format(
        "sh -c 'grep -rlF %s %s 2>/dev/null || true'",
        __shq(banner), __shq(root)))

    local pruned = 0
    for _, line in ipairs((out or ""):split("\n", { plain = true })) do
        local f = line:trim()
        -- Only under an include-fixed directory. grep is pointed at lib/gcc, and
        -- narrowing here rather than in the pattern keeps the check readable and
        -- refuses to delete anything outside the one directory this is about.
        if f ~= "" and f:find("include-fixed", 1, true) and os.isfile(f) then
            os.tryrm(f)
            pruned = pruned + 1
            log.info("gcc: pruned frozen fixincludes header " .. path.filename(f)
                     .. " (see #560) -- the sysroot's own copy now wins")
        end
    end

    -- Deliberately not an error when zero: a payload built with a fixincludes
    -- that found nothing to fix is the healthy case, not a missing fix. 16.1.0 is
    -- exactly that -- its include-fixed holds only README.
    if pruned > 0 then
        log.warn("gcc: removed " .. pruned .. " header(s) frozen against an older "
                 .. "sysroot; C++ threading headers would not have compiled")
    end
end

-- Single-quote for `sh -c`. The paths here are ours and the banner is a literal,
-- so this is belt-and-braces rather than a live injection concern -- but a build
-- path containing a quote would otherwise turn a prune into an unparseable
-- command, and the recipe would report success having pruned nothing.
function __shq(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

function __config_linux()
    local gcc_bindir = path.join(pkginfo.install_dir(), "bin")

    -- LINK axis (loader + rpath): baked into the SPECS, pointing directly at
    -- this package's own dep payloads — the glibc payload's loader/lib plus
    -- gcc's own lib64 (libstdc++/libgcc_s at run time). Payload-direct, no
    -- subos indirection: the specs govern every invocation style (xvm shim,
    -- direct <install_dir>/bin/gcc, and downstream tools), so they must not
    -- depend on an environment directory that may be absent or belong to a
    -- different home. Mirrors llvm.lua's payload-direct cfg.
    local glibc_lib, dynamic_linker = __find_glibc_runtime()
    if glibc_lib then
        local rpath = glibc_lib .. ":" .. path.join(pkginfo.install_dir(), "lib64")
        -- Propagate the failure. This used to be called for effect with its
        -- result discarded, so a rewrite that did not take hold still reported
        -- a successful install.
        if not __rewrite_specs_linux(rpath, dynamic_linker) then
            return false
        end
    else
        -- Fail, do not warn and continue.
        --
        -- Without the rewrite the binary keeps the ELF interpreter baked in
        -- on the build machine -- a path that does not exist here -- so what
        -- gets installed cannot run at all. Reporting that as a successful
        -- install hands the user a broken toolchain and a warning they have
        -- already scrolled past; the failure shows up later as
        -- "No such file or directory" on a binary that is plainly present.
        --
        -- glibc is a declared dependency of this package on linux, so
        -- reaching here means the dependency did not get installed. That is
        -- worth stopping for. See openxlings/xlings#415.
        log.error("glibc payload not found, but gcc needs it to rewrite its"
            .. " ELF interpreter away from the build machine's path.")
        log.error("  without it the installed gcc cannot run at all.")
        log.error("  install it first: xlings install xim:glibc@2.39")
        return false
    end

    -- HEADER axis: injected only on the xvm shim aliases. gcc's header
    -- search (include-fixed, #include_next) needs an FHS-shaped tree, which
    -- individual payloads are not — the subos is exactly xlings' FHS
    -- composite view for this purpose. Consumers that bypass the shim
    -- (e.g. mcpp) supply their own header flags.
    --
    -- Written as the marker `${XLINGS_DYNAMIC_SUBOS_DIR}`, not as whichever
    -- subos happens to be active while this hook runs.
    --
    -- The xvm database is shared by every subos in the home, so a path naming
    -- one of them is right for the subos that installed gcc and wrong for all
    -- the others: the user switches subos and their g++ keeps compiling
    -- against the old one's headers, with nothing saying so.
    --
    -- xlings expands the marker at execution time, against whichever subos the
    -- calling process resolved to -- global selection, XLINGS_ACTIVE_SUBOS, or
    -- a project subos. No filesystem path can follow an environment variable,
    -- which is why the answer cannot be stored at all.
    --
    -- The marker is xlings's, the `--sysroot=` spelling is ours. That split is
    -- deliberate: xlings owns a dictionary of runtime FACTS a recipe can name,
    -- and a recipe owns the syntax its tool wants them in. A toolchain needing
    -- `-isysroot` or `--gcc-toolchain=` writes that here and needs no xlings
    -- change.
    --
    -- Older xlings (< 2026.7.31.2) does not expand it. Those clients keep
    -- working through the exec-time path normalization they already have --
    -- but it only sees CONCRETE paths, so on them this alias reaches gcc with
    -- the marker literal. Land this only once the expanding release is what
    -- `latest` resolves to.
    local alias_args = ' --sysroot=${XLINGS_DYNAMIC_SUBOS_DIR}'

    -- Root of the release's binding group. `type = "group"` because it names
    -- no artifact: no bindir, no alias, nothing under it to exec. As the
    -- default `program` it got a shim at `bin/xim-gnu-gcc` that answered
    -- `executable 'xim-gnu-gcc' not found` -- and, on any home where the name
    -- had no active version, `self doctor` called it an orphan shim
    -- (openxlings/xlings#452). Version stays the default: the children below
    -- bind to `xim-gnu-gcc@<pkginfo.version()>`.
    xvm.add("xim-gnu-gcc", { type = "group" }) -- root

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
-- Does the rewritten specs name an ELF interpreter that EXISTS on this machine?
--
-- That is the postcondition the rewrite exists for, checked directly instead of
-- inferred from "the command exited 0".
--
-- Deliberately NOT "compile a probe and run it". That was the first version and
-- CI rejected it, correctly: at config() time the sysroot is not necessarily
-- assembled, so a full link can fail
--
--   collect2: error: ld returned 1 exit status
--
-- while the specs are perfectly correct. RPATH is a RUNTIME search path;
-- linking needs -L. Conflating "are the specs right" with "can this toolchain
-- link right now" fails every fresh install -- which is exactly what it did.
--
-- Reading the interpreter out of the specs needs neither a linker nor a
-- sysroot, and it is precisely the thing that goes wrong: a loader path that is
-- valid on the packaging machine and absent here. `execve` then reports ENOENT
-- against the BINARY rather than the missing loader, which is why that failure
-- is so consistently misread -- openxlings/xlings#509 spent 16 CI runs and four
-- wrong fixes on it.
--
-- Returns ok, reason.
function __specs_interp_exists(gcc_bin, dynamic_linker)
    if not dynamic_linker or dynamic_linker == "" then
        return true, nil     -- nothing was asked for; nothing to verify
    end

    -- The loader must exist. This is the whole failure mode: a path that is
    -- valid where the payload was built and absent here.
    if not os.isfile(dynamic_linker) then
        return false, "the requested ELF interpreter does not exist: "
            .. dynamic_linker
    end

    local libgcc = os.iorun(gcc_bin .. " -print-libgcc-file-name")
    if not libgcc or libgcc:trim() == "" then
        -- Cannot locate the specs. Do not invent a failure out of not knowing.
        return true, nil
    end
    local specs_file = path.join(path.directory(libgcc:trim()), "specs")
    if not os.isfile(specs_file) then
        return false, "no specs file at " .. specs_file
    end

    -- Is OUR loader actually in there? Checked by exact string, not by scanning
    -- for any `ld-*` path.
    --
    -- Scanning was the first attempt and it is WRONG: gcc's specs legitimately
    -- carry alternates for other targets --
    --
    --   /lib/ld-musl-i386.so.1   /lib/ld-musl-x32.so.1   /libx32/ld-linux-x32.so.2
    --
    -- which are selected by -m32/-mx32/-mmusl and are absent on a perfectly
    -- healthy machine. Asserting "every ld-* path exists" fails a good
    -- toolchain, which is worse than the bug it was meant to catch.
    --
    -- `grep -a`: a specs file carries escape bytes; without it grep calls the
    -- file binary and prints nothing -- a silent empty result reading as "fine".
    local hit = os.iorun("grep -acF -- '" .. dynamic_linker .. "' '"
        .. specs_file .. "'")
    if not hit or hit:trim() == "" or hit:trim() == "0" then
        return false, "the specs do not name the requested interpreter ("
            .. dynamic_linker .. "), so the rewrite did not land"
    end
    return true, nil
end

function __rewrite_specs_linux(rpath, dynamic_linker)
    -- The "-payload" suffix versions the specs SCHEMA: pre-existing installs
    -- carry the old subos-form stamp, which no longer matches, so the next
    -- config() re-fire converges them to the payload-direct form.
    local stamp = path.join(
        pkginfo.install_dir(),
        ".specs-rewritten-" .. pkginfo.version() .. "-payload.stamp"
    )
    local gcc_bin = path.join(pkginfo.install_dir(), "bin/gcc")

    -- The stamp is a cache, NOT the decision.
    --
    -- It used to be the decision -- "have we run?" -- and that is a different
    -- question from "is the result correct". A specs file corrupted by any
    -- means (an interrupted run, a hand edit, or another home writing into a
    -- payload this one shares) was then frozen that way forever, because the
    -- stamp said the work was done. Observed: PT_INTERP stuck on glibc 2.39
    -- while the rpath had moved to 2.44, surfacing as
    --
    --   libc.so.6: undefined symbol: __pointer_chk_guard, version GLIBC_PRIVATE
    --
    -- which names nothing relevant. So a present stamp still has to survive the
    -- probe; if it does not, we rewrite and repair.
    if os.isfile(stamp) then
        local ok = __specs_interp_exists(gcc_bin, dynamic_linker)
        if ok then
            log.debug("gcc specs already rewritten and verified, skipping.")
            return true
        end
        log.warn("gcc specs stamp is present but this gcc cannot produce a "
            .. "runnable binary -- rewriting to repair it.")
    end

    local specs_config_bin = path.join(system.bindir(), "gcc-specs-config")

    log.info("Rewriting gcc specs to payload-direct paths via gcc-specs-config...")
    system.exec(string.format(
        "%s %s --dynamic-linker %s --rpath %s --linker-type gnu",
        specs_config_bin, gcc_bin, dynamic_linker, rpath
    ))

    -- Fail, do not warn and continue -- the same reasoning as the missing-glibc
    -- branch in __config_linux. A gcc that installs "successfully" and cannot
    -- produce a runnable binary hands the user a toolchain whose failures point
    -- at the wrong file entirely.
    local ok, why = __specs_interp_exists(gcc_bin, dynamic_linker)
    if not ok then
        log.error("gcc specs rewrite did not take effect: %s", why)
        log.error("  dynamic-linker: %s", dynamic_linker)
        log.error("  rpath:          %s", rpath)
        log.error("  the installed gcc cannot produce a working binary.")
        return false
    end

    -- Only now. A stamp written on an unverified rewrite is how the failure
    -- above became permanent in the first place.
    io.writefile(stamp, pkginfo.version())
    return true
end

-- Locate the glibc payload runtime (this package's own dep, xim:glibc) via
-- pkginfo.dep_install_dir, and discover the loader NAME from the payload
-- contents (any `ld-*.so*`) — no architecture hardcodes, no directory
-- layout assumptions. Same helper shape as llvm.lua's.
function __find_glibc_runtime()
    local glibc_dir = pkginfo.dep_install_dir("glibc")
    if not glibc_dir then return nil, nil end

    for _, libname in ipairs({"lib64", "lib"}) do
        local libdir = path.join(glibc_dir, libname)
        local g = io.popen('ls -1 "' .. libdir .. '" 2>/dev/null')
        if g then
            for line in g:lines() do
                local name = line:gsub("[\r\n]+$", "")
                if name:match("^ld%-") and name:find(".so", 1, true) then
                    g:close()
                    return libdir, path.join(libdir, name)
                end
            end
            g:close()
        end
    end
    return nil, nil
end
