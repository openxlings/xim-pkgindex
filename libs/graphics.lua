-- The graphics stack's discovery layer, declared in one place.
--
-- Loaded by package hooks via:
--     import("xim.pkgindex.graphics")
--
-- WHAT "DISCOVERY" MEANS HERE
--
-- A GL program needs three things: a loader and a libc (bootstrap), a way to
-- find its libraries (RPATH), and the paths its subsystems read at runtime --
-- which driver modules to load, which GL vendors exist, where the Vulkan ICD
-- manifests are. The third one is this module. It cannot be an RPATH: the
-- process that has to see it is the user's own binary, and mesa reads it from
-- the environment.
--
-- THE SCOPE RULE
--
-- Configuration that reaches a process should be bound to the narrowest thing
-- that works. Three scopes exist, and the graphics stack now uses the two
-- narrow ones:
--
--   S1  object   DT_RPATH / interposer     -- one load chain
--   S2  program  xvm.add{ envs = ... }     -- one program and its children
--   S3  shell    subos.env{}               -- every process in the subos
--
-- S3 alone was what this stack had, and it is wrong in both directions. It
-- LEAKS: a host binary run inside the subos inherits LIBGL_DRIVERS_PATH and
-- dlopens OUR driver module under the HOST loader, which fails on
-- libgallium. And it does not REACH: `subos.env` is applied by `subos use`,
-- so `xlings install godot && godot` in an ordinary login shell gets a subos
-- on PATH and none of the paths below.
--
-- No other ecosystem binds graphics discovery to a shell. Nix wraps the
-- program (`makeWrapper`), Snap uses a `command-chain` wrapper, Flatpak and
-- pressure-vessel set it for the sandbox/container. S2 is that mechanism, and
-- xlings has had it all along -- ten recipes use `xvm.add{envs}`; the graphics
-- stack used none.
--
-- ONE SOURCE, TWO RENDERINGS
--
-- The values are subos-relative, and the two consumers spell "this subos"
-- differently: `subos.env` resolves `${subosdir}`, and an xvm shim resolves
-- `${XLINGS_DYNAMIC_SUBOS_DIR}` -- the latter at DISPATCH time, so a program
-- installed while subos A was active still gets subos B's paths when run
-- there. Both spellings are generated from one table below, so S2 and S3
-- cannot say different things.
--
-- WHY SUBOS-RELATIVE AND NOT `${pkgdir}`
--
-- `${pkgdir}` is the declaring package's payload, which pins a version
-- directory: upgrading mesa leaves a consumer's recorded env naming the old
-- one. The subos view is the stable indirection -- the same role
-- `/run/opengl-driver` plays on NixOS, `/overrides` in pressure-vessel and
-- `$SNAP/gpu-2404` in a snap. It is assembled by the declarations below, so
-- it is complete by construction rather than by hope.
--
-- Design: xlings/.agents/docs/2026-08-07-graphics-experience-industry-survey-and-plan.md §A1, §A2

import("xim.libxpkg.log")
import("xim.libxpkg.xvm")
import("xim.libxpkg.subos")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.fs")

local graphics = {}

-- The subos-relative locations that make up the discovery layer.
--
-- `dri` is under `usr/`, not `lib/`, and that is not cosmetic: xlings only
-- permits a file asset whose destination starts with `usr`, `etc` or `share`
-- (xvm/bindings.cppm is_permitted_file_destination), and a rejected
-- destination is NOT an error -- the placement simply does not happen. A
-- `dst = "lib/dri"` would have produced a recipe that installs cleanly, sets
-- LIBGL_DRIVERS_PATH to a directory that does not exist, and renders on
-- llvmpipe. `usr/lib/dri` is also consistent with `usr/include`, where the
-- stack's headers already live.
graphics.DRI_DIR        = "usr/lib/dri"
graphics.EGL_VENDOR_DIR = "share/glvnd/egl_vendor.d"

-- The GLX vendor directory — and why it is NOT next to the two above.
--
-- Those are subos-relative, because an ENVIRONMENT VARIABLE points at them.
-- GLX has no such variable. Measured on a host libglvnd 1.7:
--
--   libEGL.so.1   __EGL_VENDOR_LIBRARY_DIRS, __EGL_VENDOR_LIBRARY_FILENAMES,
--                 a default search path, and a JSON `library_path` that may be
--                 an ABSOLUTE path (our recipes rewrite it to one).
--   libGLX.so.0   `libGLX_%s.so.0` and `__GLX_VENDOR_LIBRARY_NAME`. That is
--                 all of it. A NAME, never a path, never a directory.
--
-- So GLX vendor discovery is a bare-SONAME `dlopen` from inside libGLX.so.0,
-- and glibc serves that from exactly four places: the calling object's
-- DT_RPATH (transitive up its load chain) or DT_RUNPATH (not transitive),
-- LD_LIBRARY_PATH, and ld.so.cache. LD_LIBRARY_PATH is out -- it is
-- process-global and loads our payload into host binaries, which is the
-- `__pointer_chk_guard` crash xim's own install warning describes. Our
-- loader's cache path exists nowhere. What is left is the search path of the
-- object that CALLS dlopen: libGLX.so.0, which is ours.
--
-- Hence a directory inside libglvnd's OWN payload, reached by `$ORIGIN`:
-- home-relocatable, and one directory serves every subos in the home, with
-- per-subos vendor SELECTION staying where glvnd already put it
-- (`__GLX_VENDOR_LIBRARY_NAME`). A subos-absolute path would pin the shared
-- payload to whichever subos installed it last.
--
-- A subdirectory, not `lib/` itself: `lib/` is published into the subos by
-- `sysroot.declare_libs`, and vendor libraries are dlopen'd plugins, not link
-- targets. This also keeps the farm out of it -- `<subos>/lib` holds
-- libc.so.6 and ld-linux symlinks, and that directory in an RPATH is a known
-- landmine.
--
-- Relative to libglvnd's install_dir. openxlings/xlings#525.
graphics.GLX_VENDOR_SUBDIR = "lib/glx-vendor"
graphics.SHARE_DIR      = "share"
-- Where the Vulkan loader looks, relative to the subos: it searches
-- $XDG_DATA_DIRS/vulkan/icd.d and mesa puts ${subosdir}/share on that list.
graphics.VULKAN_ICD_DIR = "share/vulkan/icd.d"

-- The variables, once. Keys are variable names; values are subos-relative
-- paths, with no placeholder syntax -- the two emitters below add their own.
--
-- XDG_DATA_DIRS carries the Vulkan ICD search path as a side effect, and that
-- is deliberate rather than incidental: the Vulkan loader searches
-- `$XDG_DATA_DIRS/vulkan/icd.d`, so once a `vulkan-loader` package exists,
-- mesa's ICD manifests are found with no new variable. `VK_DRIVER_FILES` would
-- be wrong here -- it is an OVERRIDE that suppresses system discovery, so it
-- would hide any other ICD on the machine.
local DISCOVERY = {
    { var = "LIBGL_DRIVERS_PATH",        rel = graphics.DRI_DIR },
    { var = "__EGL_VENDOR_LIBRARY_DIRS", rel = graphics.EGL_VENDOR_DIR },
    { var = "XDG_DATA_DIRS",             rel = graphics.SHARE_DIR },
}

-- S2 -- the table a CONSUMER's shim carries.
--
--     xvm.add("godot", { envs = graphics.consumer_envs(), ... })
--
-- Every value is identical for every consumer, which is the point: a consumer
-- does not need to locate mesa's payload, and nothing has to be re-recorded
-- when mesa is upgraded.
--
-- The shim merges each value into whatever the process already has, front-most
-- and de-duplicated, so a user who exported their own LIBGL_DRIVERS_PATH keeps
-- it and a doubled entry cannot accumulate across nested invocations.
function graphics.consumer_envs()
    local envs = {}
    for _, d in ipairs(DISCOVERY) do
        envs[d.var] = "${XLINGS_DYNAMIC_SUBOS_DIR}/" .. d.rel
    end
    return envs
end

-- S3 -- the same values for a subos shell.
--
-- `prepend`, never `set`, for all three: they are colon-separated LISTS and
-- more than one package is entitled to be on them. A `set` by one provider
-- beats a `prepend` by another in xlings's resolution, so a `set` here would
-- silently erase the NVIDIA vendor directory and the machine with the GPU
-- would render on llvmpipe.
--
-- Returns false on a client with no `subos.env`, so a caller can say so. The
-- probe is `type(...) == "function"`, never truthiness: `import()` answers an
-- unknown module with a permissive proxy whose every key is truthy, so
-- `if subos.env then` takes the new branch on clients that then discard the
-- call.
-- `only` restricts the declaration to a set of variable names. A vendor
-- sentinel contributes an EGL vendor directory and nothing else: it has no
-- driver modules and no `share/` tree, so declaring LIBGL_DRIVERS_PATH from
-- there would name a path it does not fill. Both packages declaring the SAME
-- shared vendor directory is fine and intended -- `prepend` de-duplicates, and
-- either package being absent must not remove it for the other.
function graphics.declare_subos_env(tag, only)
    if type(subos.env) ~= "function" then return false end
    for _, d in ipairs(DISCOVERY) do
        if not only or only[d.var] then
            subos.env{ var = d.var, op = "prepend",
                       value = "${subosdir}/" .. d.rel, binding = tag }
        end
    end
    return true
end

-- The set a vendor-only provider passes to declare_subos_env.
graphics.EGL_VENDOR_ONLY = { ["__EGL_VENDOR_LIBRARY_DIRS"] = true }

-- Place one glvnd EGL vendor JSON into the subos's SHARED vendor directory.
--
-- WHY SHARED, AND WHY THIS IS THE POINT OF THE CHANGE
--
-- libglvnd scans the directories in `__EGL_VENDOR_LIBRARY_DIRS` IN LIST ORDER
-- and sorts the `*.json` files WITHIN each directory by filename (scandir +
-- strcmp). So the `10_nvidia.json` < `50_mesa.json` convention -- which is how
-- every distribution expresses vendor priority -- only has meaning inside one
-- directory.
--
-- When mesa and nvidia-gl-host-link each contributed their OWN payload
-- directory, cross-vendor priority was decided by the order xlings happened to
-- resolve two `prepend` declarations: sorted by binding string, later provider
-- front-most. `mesa@...` < `nvidia-gl-host-link@...`, so NVIDIA landed first
-- and the result was correct -- by alphabetical accident, with a third vendor
-- or a renamed package enough to change it.
--
-- Both packages now place into ONE directory and declare that one directory,
-- so the filename convention decides, exactly as it does on the host. This is
-- what "behaves the same inside the subos as outside" means for this variable.
--
-- Distributions went through this: before libglvnd they swapped the whole
-- libGL.so.1 with `update-alternatives` / `eselect opengl`, one vendor at a
-- time; glvnd plus one shared vendor directory is what made Mesa and a
-- proprietary driver coexist. Two directories is the halfway state.
function graphics.declare_egl_vendor(install_dir, rel_json, tag)
    if not xvm.files then
        log.warn("this xlings has no `xvm.files`; the EGL vendor JSON stays in "
                 .. "the payload and cross-vendor priority falls back to "
                 .. "declaration order. Run `xlings self update`.")
        return false
    end
    if not os.isfile(path.join(install_dir, rel_json)) then
        -- Not an error: a sentinel with no host driver writes no vendor JSON.
        return true
    end
    xvm.files{
        src = rel_json,
        dst = path.join(graphics.EGL_VENDOR_DIR, path.filename(rel_json)),
        binding = tag,
    }
    return true
end

-- Place a Vulkan ICD manifest into the subos, where the loader looks.
--
-- The loader searches `$XDG_DATA_DIRS/vulkan/icd.d`, and mesa's declaration
-- already puts `${subosdir}/share` on that variable -- so the manifest has to be
-- under the SUBOS's share, not only in the payload. Without this the loader
-- installs, starts, finds the HOST's ICDs and reports success: `vulkaninfo`
-- works, zink works, and none of it is ours. That is the same boundary the GL
-- side needed interposers for, one API over, and it looks like a pass from every
-- angle except asking whose ICD answered.
--
-- Same shared-directory shape as the glvnd vendor JSON, and for the same reason:
-- one directory, filenames decide, several packages may contribute.
function graphics.declare_vulkan_icd(install_dir, rel_dir, tag)
    if not xvm.files then return false end
    local dir = path.join(install_dir, rel_dir)
    if not os.isdir(dir) then return true end   -- a build with no Vulkan driver
    local f = io.popen(string.format([[ls -1 "%s"/*.json 2>/dev/null]], dir))
    if not f then return false end
    local n = 0
    for line in f:lines() do
        local p = line:gsub("[\r\n]+$", "")
        if p ~= "" then
            local base = p:match("([^/]+)$")
            xvm.files{
                src = path.join(rel_dir, base),
                dst = path.join(graphics.VULKAN_ICD_DIR, base),
                binding = tag,
            }
            n = n + 1
        end
    end
    f:close()
    return n > 0
end

-- Place the DRI driver modules where LIBGL_DRIVERS_PATH points.
--
-- The whole directory as ONE asset, which is safe here and would not be for
-- headers: mesa is the only package that ships `lib/dri`, so there is nothing
-- to merge. A file asset is placed as a symlink (`fs::create_symlink` after a
-- staging rename), so the payload is untouched and re-placement is idempotent.
--
-- The alternative -- `sysroot.declare_libs(dir, "lib/dri", ...)` -- would work
-- and was rejected: it flattens twelve driver modules into `<subos>/lib`,
-- which is the LINK directory. Those modules are loaded by path and are not
-- link targets; mesa's own recipe already says so.
function graphics.declare_dri(install_dir, rel_dir, tag)
    if not xvm.files then return false end
    if not os.isdir(path.join(install_dir, rel_dir)) then
        log.warn("no %s in this payload -- LIBGL_DRIVERS_PATH would point at "
                 .. "an empty directory and GL would fall back to software "
                 .. "rendering with no diagnostic", rel_dir)
        return false
    end
    xvm.files{ src = rel_dir, dst = graphics.DRI_DIR, binding = tag }
    return true
end

-- ─────────────────────────────────────────────────────────────────────
-- GLX vendor registration — the counterpart `declare_egl_vendor` has and
-- GLX did not. See GLX_VENDOR_SUBDIR above for why it is a directory plus an
-- RPATH rather than a variable: glvnd offers no GLX variable to point.
-- ─────────────────────────────────────────────────────────────────────

-- Populate libglvnd's vendor directory from the vendors in this stack.
--
-- WHY THE ASSEMBLER DOES THIS, AND NOT EACH VENDOR
--
-- Per-vendor self-registration is the obvious shape -- it mirrors
-- `declare_egl_vendor` exactly -- and it has an ordering hole that this
-- ecosystem has been bitten by before. The directory lives in libglvnd's
-- payload, and a libglvnd reinstall does `os.tryrm(install_dir)`: every
-- registration disappears. The vendors do not reinstall just because their
-- dependency did, so nothing puts them back. The stack would come up with an
-- empty vendor directory and render on llvmpipe, reporting success -- the
-- precise failure this whole mechanism exists to remove.
--
-- `graphics` cannot have that hole. It declares every vendor AND the
-- dispatch, so it installs strictly after all of them, and re-running it
-- rewires the whole set from scratch. One writer, one moment, no ordering
-- assumption.
--
-- `vendors` is a list of {dir, soname} -- the payload directory and the
-- library's SONAME, which is also the filename glvnd builds and dlopens.
-- Returns the number registered.
-- `fs.*`, not `os.*`. The recipe sandbox's `os` table is the one prelude.lua
-- builds -- isfile/isdir/dirs/mkdir/mv/cp/tryrm/exec/iorun and nothing else.
-- `os.ln` and `os.files` do not exist there, and calling one raises from
-- inside a hook rather than failing a check.
function graphics.wire_glx_vendors(dispatch_dir, vendors)
    local vendor_dir = path.join(dispatch_dir, graphics.GLX_VENDOR_SUBDIR)
    fs.mkdir_p(vendor_dir)

    -- Rebuild, do not merge. A vendor dropped from the stack must not leave a
    -- dangling entry: glvnd would dlopen it, fail, and swallow the error.
    for _, stale in ipairs(fs.files(vendor_dir) or {}) do
        fs.remove(stale)
    end

    local n = 0
    for _, v in ipairs(vendors) do
        local src = path.join(v.dir, "lib", v.soname)
        if os.isfile(src) then
            -- Absolute symlink: the target is a different payload in the same
            -- home, so a relative one would break if either moved.
            fs.symlink(src, path.join(vendor_dir, v.soname))
            n = n + 1
            log.info("GLX vendor: %s", v.soname)
        end
    end
    return n
end

return graphics
