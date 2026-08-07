-- Make a payload resolve its own dependencies, instead of the host's.
--
-- Loaded by package hooks via:
--     import("xim.pkgindex.selfcontain")
--
-- THE DEFECT THIS EXISTS TO CLOSE
--
-- Every library recipe in this index declares what it OFFERS:
--
--     exports = { runtime = { libdirs = { "lib" } } }
--
-- and several declare what they need:
--
--     deps = { "xim:libXau@>=1.0", "xim:libXdmcp@>=1.1" }
--
-- but until this module, not one of them CONSUMED the first from the second.
-- `exports` is read by a package's dependents; it does nothing for the package
-- that declares it. The step that turns "my dep exports lib/" into "my ELF can
-- find it" is `elfpatch`, and no recipe in this index -- or in mcpp-index --
-- called it. `elfpatch.closure_lib_paths()` is a public, documented libxpkg API
-- with, before this, zero callers in the entire ecosystem.
--
-- So `libxcb.so.1` shipped with
--
--     DT_NEEDED  libXau.so.6, libXdmcp.so.6, libc.so.6
--     DT_RUNPATH $ORIGIN
--
-- and `libXau.so.6` is in a different payload. It resolved anyway, from the
-- HOST's /etc/ld.so.cache, on every machine that happened to have libxau
-- installed -- which is every desktop Linux. The stack looked self-contained
-- and never was.
--
-- WHY THE SUBOS LINK DIRECTORY DOES NOT ALREADY COVER THIS
--
-- `sysroot.declare_libs` symlinks every payload library into `<subos>/lib`, and
-- a consumer built in the subos gets `<subos>/lib` in its DT_RPATH -- which IS
-- transitive, so one might expect it to serve libxcb's search for libXau.
--
-- It does not, and the reason is the single most load-bearing sentence in
-- ld.so's search order: **if an object has DT_RUNPATH, its DT_RPATH-inherited
-- search path is not consulted at all.** libxcb has DT_RUNPATH ($ORIGIN). So
-- for libxcb's own dependencies the loader consults $ORIGIN and then goes
-- straight to the cache. No ancestor's RPATH is reachable from there, however
-- many of them name the right directory.
--
-- Measured, on a sealed bwrap with no /usr at all:
--
--   as shipped        EGL_CLIENT_EXTENSIONS= , "surfaceless refused 0x300c"
--                     -- mesa's vendor never loads
--   closure-patched   GL_RENDERER=llvmpipe (LLVM 20.1.7), PIXEL=336699
--                     -- every LOADED= line inside our own payload
--
-- WHY PER-PACKAGE CLOSURE AND NOT ONE BIG DIRECTORY
--
-- The tempting shortcut is to put `<subos>/lib` -- which already has a symlink
-- to every payload library -- on every payload library's RPATH, and stop
-- there. Two reasons that is the wrong primary mechanism:
--
--   * A payload is shared by every subos in the home. A payload that resolves
--     through one subos's link directory answers for a subos it has no
--     business knowing about, and the answer goes stale when that subos is
--     removed.
--   * `<subos>/lib` holds glibc. It is a directory where a second libc can be
--     reached, which is the hazard build-in-subos.sh already documents.
--
-- What actually gets written, measured rather than assumed:
--
--     libxcb.so.1  RUNPATH = <libxcb>/lib : <libXau>/lib : <libXdmcp>/lib
--                            : <glibc>/lib64 : <subos>/lib
--
-- The per-package closure comes first and decides; `closure_lib_paths` appends
-- the subos link directory itself, last, as a backstop. So the shortcut is
-- present but never load-bearing -- and the `$ORIGIN` this module asks for is
-- dropped by libxpkg in favour of the payload's own absolute libdir, which is
-- equivalent here because xlings never relocates a payload.
--
-- Design: xlings/.agents/docs/2026-08-07-graphics-experience-industry-survey-and-plan.md §S1

import("xim.libxpkg.log")
import("xim.libxpkg.elfpatch")

local selfcontain = {}

-- Stamp this payload's own dependency closure onto its shared libraries.
--
--   selfcontain.seal(pkginfo.install_dir())
--   selfcontain.seal(pkginfo.install_dir(), { "lib", "lib64" })
--
-- `$ORIGIN` stays first: it is what the upstream build shipped, it keeps a
-- payload's intra-package references working if the tree is ever relocated, and
-- it costs one stat per lookup that almost always hits.
--
-- Returns true when the payload was patched, false when this client is too old
-- -- never nil, so a caller can branch. A false is WARNED rather than silent:
-- the package still installs and still works on any host that has the
-- dependency, which is precisely the failure mode that hid this for so long.
-- Refuse to call an install that produced nothing a success.
--
-- Every recipe here ends `os.mv(srcdir, install_dir); return true`, and the
-- move is not checked. When the extracted source directory is already gone the
-- move does nothing, `install()` returns true anyway, and xlings prints
-- `✓ pkg@ver done` over an EMPTY payload directory.
--
-- That is not hypothetical. CI registers each changed recipe under `local:`
-- while its dependents still resolve `xim:`, so one package+version can be
-- installed twice from one extraction. Reproduced verbatim:
--
--     xim:libffi@3.4.4     installed as a dependency   -- consumes the srcdir
--     local:libffi@3.4.4   ✓ done, 1 package installed -- payload is empty
--
-- and the only thing that complained was the *config* hook, two steps later,
-- with a message about pkgconfig globs. The error named the wrong subsystem
-- because by then nothing remembered that the payload never arrived.
--
-- Checked here because this is the one hook every sealed recipe already calls,
-- and because it is the last moment inside install() where the truth is cheap.
--
-- It will NOT fire in CI's install test, and that is not a bug in the check.
-- `xlings config --add-xpkg` registers a recipe under `local:` without the
-- index's `libs/`, so `import("xim.pkgindex.selfcontain")` yields a permissive
-- proxy and every call through it is a truthy no-op. The same is true of
-- `selfcontain.seal` itself: **the linux-install-test job does not exercise the
-- seal**, and a green run there says nothing about whether payloads are sealed.
-- The evidence for that lives in verify-stack.sh cell 6, which runs a real
-- `xim:` install in a bwrap with no /usr.
local function _assert_payload(install_dir, libdirs)
    for _, sub in ipairs(libdirs) do
        if os.isdir(path.join(install_dir, sub)) then return true end
    end
    error(string.format(
        "install produced no payload: %s has none of {%s}. The extracted source "
        .. "directory was most likely already consumed by another install of the "
        .. "same package and version (a second namespace, e.g. xim: and local:), "
        .. "and this recipe's os.mv silently did nothing.",
        install_dir, table.concat(libdirs, ", ")))
end

function selfcontain.seal(install_dir, libdirs)
    local dirs = libdirs or { "lib", "lib64" }
    _assert_payload(install_dir, dirs)

    -- type(), not truthiness: import() answers an unknown module with a
    -- permissive proxy whose every key is truthy, so `if elfpatch.x then`
    -- takes the new branch on clients that then discard the call.
    if type(elfpatch.closure_lib_paths) ~= "function"
       or type(elfpatch.patch_elf_loader_rpath) ~= "function" then
        log.warn("this xlings cannot compute a dependency closure; %s keeps its "
                 .. "as-shipped RPATH and will resolve its dependencies from "
                 .. "the HOST. Run `xlings self update`.", install_dir)
        return false
    end

    local closure = elfpatch.closure_lib_paths()
    if not closure or #closure == 0 then
        -- A package with no runtime deps and no self libdir: nothing to say.
        return true
    end

    local rpath = { "$ORIGIN" }
    for _, d in ipairs(closure) do table.insert(rpath, d) end

    -- Both, always, unless the caller says otherwise: `lib` is the convention
    -- for the X11 and mesa payloads, `lib64` for the toolchain ones
    -- (gcc-runtime ships only lib64). A directory that does not exist
    -- collects no targets, so naming both costs nothing and forgetting one
    -- silently leaves that payload resolving from the host.
    local r = elfpatch.patch_elf_loader_rpath(install_dir, {
        libs  = dirs,
        rpath = rpath,
        -- No shrink. --shrink-rpath keeps only the entries that satisfy a
        -- current DT_NEEDED, which would drop exactly the directories a
        -- dlopen needs later -- mesa's driver modules are loaded by path and
        -- name nothing at link time.
        shrink = false,
    })
    if r and r.failed and r.failed > 0 then
        log.warn("%d/%d libraries in %s could not be patched; those will "
                 .. "resolve from the host", r.failed, r.scanned, install_dir)
    end
    return true
end

return selfcontain
