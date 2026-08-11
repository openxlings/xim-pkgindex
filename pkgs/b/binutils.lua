package = {
    spec = "1",
    homepage = "https://www.gnu.org/software/binutils",
    -- base info
    name = "binutils",
    description = "The GNU Binutils are a collection of binary tools",

    authors = {"GNU"},
    licenses = {"GPL"},
    docs = "https://sourceware.org/binutils/wiki/HomePage",

    -- xim pkg info
    type = "package",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"binutils", "gnu"},
    keywords = {"binutils", "gnu"},

    -- xvm: xlings version management
    xvm_enable = true,

    programs = {
        "ld", "as", "gold",
        "addr2line", "ar", "c++filt", "dlltool", "elfedit",
        "gprof", "nlmconv", "nm", "objcopy",
        "objdump", "ranlib", "readelf", "size", "strings", "strip",
        "windres", "windmc",
        -- "gprofng", TODO: fix cannot find -lrt: No such file or directory
    },

    xpm = {
        linux = {
            deps = { "xim:glibc@>=2.39" },
            ["latest"] = { ref = "2.42.1" },
            -- SAME ARTIFACT, NEW KEY. The bytes are identical to 2.42 -- the
            -- sha256 below is the 2.42 tarball's -- and the only thing that
            -- changed is this recipe's config(), which now installs the `ld`
            -- wrapper below.
            --
            -- config() runs only when a package INSTALLS. A home that already
            -- has 2.42 would keep an `ld` that cannot see the subos library
            -- farm, with nothing to say so; the fix would ship and those users
            -- would never get it. A new key under the same artifact makes
            -- `latest` pull it and the hook re-run. Same move as libglvnd
            -- 1.7.0.1 and fontconfig 2.15.0.1.
            --
            -- Written as an explicit url rather than the XLINGS_RES sentinel
            -- because that sentinel derives the filename from the VERSION, and
            -- there is no `binutils-2.42.1-*` artifact -- there is no new
            -- artifact at all. The install hook derives the extracted
            -- directory from the downloaded FILENAME, so it still finds
            -- `binutils-2.42-linux-x86_64/`.
            ["2.42.1"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/binutils/releases/download/2.42/binutils-2.42-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/binutils/releases/download/2.42/binutils-2.42-linux-x86_64.tar.gz",
                },
                sha256 = "32ec131327cd10624f70741fc553ad369f8f53ee4b79276a44f572c6d8190fd7",
            },
            ["2.42"] = "XLINGS_RES",
        },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.fs")
-- elfpatch import removed: predicate-driven auto-patch (post 2026-05-02
-- design) reads glibc.lua's exports.runtime.loader and rewrites our
-- INTERP / RPATH automatically. No install-hook elfpatch call needed.

function install()

    local glibcdir = pkginfo.install_file():replace(".tar.gz", "")

    os.tryrm(pkginfo.install_dir())
    os.cp(glibcdir, pkginfo.install_dir(), {
        force = true, symlink = true
    })

    return true
end

-- Where the `ld` wrapper lives. NOT `bin/` -- see write_ld_wrapper.
local WRAPPER_SUBDIR = "xlings-wrappers"

-- Single-quote for `sh`. NOT `string.format("%q")`, which is LUA quoting: it
-- produces a double-quoted string, and a shell expands `$` and backticks
-- inside those. libglvnd.lua records what that costs -- `$ORIGIN` went through
-- `%q` into `os.exec`, the shell expanded it as an unset variable, and the
-- resulting RPATH was a bare `/glx-vendor` that exists nowhere.
function __shq(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- Teach `ld` where this subos keeps its libraries.
--
-- THE PROBLEM (openxlings/xlings#532). A subos publishes every installed
-- library into `<subos>/lib` and puts that on the compiler's search path, so
-- `gcc t.c -lGL` finds `libGL.so`. But `libGL.so` has DT_NEEDED on
-- `libGLdispatch.so.0` and `libGLX.so.0`, and `ld` does NOT search `-L`
-- directories for a dependency's dependencies -- that is what `-rpath-link` is
-- for. Measured, verbatim:
--
--   ld: warning: libGLdispatch.so.0, needed by <subos>/lib/libGL.so, not found
--       (try using -rpath or -rpath-link)
--   ld: <subos>/lib/libGL.so: undefined reference to `__glDispatchInit'
--
-- Both libraries are in the same directory as libGL.so. The linker's own
-- message names the fix.
--
-- WHY HERE AND NOT IN EACH COMPILER'S ALIAS. Putting `-Wl,-rpath-link=...` in
-- gcc's alias works and would need repeating for g++, clang, musl-gcc and
-- every driver added later -- N answers to one question, which is the defect
-- class this ecosystem keeps paying for. The linker is where the knowledge
-- belongs: one place, and it also covers a direct `ld` call.
--
-- WHY NOT A SEPARATE PACKAGE. `binutils` already registers `ld` exclusively;
-- a second package claiming that name meets the contested-name veto
-- (2026.8.1.1), and it would need to re-derive where the real `ld` lives --
-- a second answerer to that question too.
--
-- WHY `xlings-wrappers/` AND NOT `bin/ld`. Replacing the ELF at `bin/ld` with
-- a shell script would put a non-ELF where the install-time ELF passes
-- (elfpatch auto, closure_check rule E) expect a linker, and it would leave
-- the real `ld` needing a new name that something else has to know. Instead
-- `bin/` is untouched and only the xvm REGISTRATION moves: the shim for `ld`
-- resolves here, and this file execs the untouched binary next door. A build
-- that hardcodes `<payload>/bin/ld` behaves exactly as it does today.
--
-- WHY IT READS AN ENVIRONMENT VARIABLE. `XLINGS_SUBOS_LIB` (E2a, xlings
-- 2026.8.11.1) is declared by whichever layer knows which subos this process
-- is in -- the shell profile, `subos spawn`, `--sandbox`, and since
-- 2026.8.11.2 the shim itself. So this file contains no home path, no subos
-- path and no version: it is the same bytes in every home, `xlings use
-- binutils <ver>` needs no rewrite, and there is no shared mutable state.
--
-- WHY THE VALUE IS TESTED AND NOT INTERPOLATED. An unset variable expands to
-- the empty string, and `-rpath-link ""` is not "no option" -- it is an option
-- naming the current directory. That exact confusion (empty vs absent) is what
-- produced `--sysroot=` and cost this project five days. If there is no value,
-- the flag does not appear at all.
--
-- POSIX ONLY, and that is not a gap: this recipe declares `xpm.linux` and
-- nothing else, so there is no Windows payload for a `#!/bin/sh` file to be
-- wrong on.
function write_ld_wrapper()
    local dir = path.join(pkginfo.install_dir(), WRAPPER_SUBDIR)
    fs.mkdir_p(dir)
    local wrapper = path.join(dir, "ld")
    local real = path.join(pkginfo.install_dir(), "bin", "ld")

    -- `$0` first, absolute second. The shim execs this by absolute path, so
    -- `$0` is normally this file and the relative hop is correct even if the
    -- home is moved or copied. The absolute fallback covers the case where it
    -- is reached through something that rewrites `$0` -- belt and braces, two
    -- lines, and the failure it prevents is "the linker vanished".
    io.writefile(wrapper, table.concat({
        "#!/bin/sh",
        "# Generated by xlings: xim-pkgindex/pkgs/b/binutils.lua",
        "# Adds the active subos library farm to the linker's",
        "# dependency-of-a-dependency search path. See openxlings/xlings#532.",
        'real="$(dirname "$0")/../bin/ld"',
        '[ -x "$real" ] || real=' .. __shq(real),
        'if [ -n "$XLINGS_SUBOS_LIB" ] && [ -d "$XLINGS_SUBOS_LIB" ]; then',
        '    exec "$real" -rpath-link "$XLINGS_SUBOS_LIB" "$@"',
        'fi',
        'exec "$real" "$@"',
        "",
    }, "\n"))
    os.exec("chmod +x " .. __shq(wrapper))

    -- Assert, do not assume. A wrapper that was not written is
    -- indistinguishable from one that works until someone tries to link a
    -- library with cross-payload dependencies -- and then the error names
    -- undefined symbols, not this file.
    if not os.isfile(wrapper) then
        log.error("could not write the ld wrapper at %s; `-l<lib in the subos "
                  .. "farm>` will fail to link with undefined references",
                  wrapper)
        return nil
    end
    return dir
end

function config()
    xvm.add("binutils")

    local binutils_root_binding = "binutils@" .. pkginfo.version()

    local binutils_bindir = path.join(pkginfo.install_dir(), "bin")
    local ld_bindir = write_ld_wrapper() or binutils_bindir

    for _, program in ipairs(package.programs) do
        xvm.add(program, {
            -- `ld` alone resolves through the wrapper. Everything else in this
            -- payload is registered exactly as before: `as` and `gold` do not
            -- resolve a dependency's dependencies, so there is nothing for the
            -- flag to fix there and no reason to add a process to their path.
            bindir = (program == "ld") and ld_bindir or binutils_bindir,
            binding = binutils_root_binding,
        })
    end

    return true
end

function uninstall()
    xvm.remove("binutils")
    for _, program in ipairs(package.programs) do
        xvm.remove(program)
    end
    return true
end