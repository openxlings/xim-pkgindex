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
graphics.SHARE_DIR      = "share"

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

return graphics
