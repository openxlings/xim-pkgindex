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

-- GBM backends. Same shape as DRI_DIR and for the same reasons -- under `usr/`
-- because of the destination whitelist described above, and a directory of
-- dlopen'd plugins rather than link targets.
--
-- WHY IT WAS MISSING, AND WHAT IT BREAKS. mesa is built with `--prefix=/usr`,
-- so `gbmbackendspath=/usr/lib/gbm` is compiled INTO libgbm.so (visible in its
-- gbm.pc). Once the payload is relocated that path is wrong, and libgbm is a
-- pure loader: every gbm_create_device() dlopens `<path>/<driver>_gbm.so`.
-- Measured before this entry existed:
--
--   MESA-LOADER: failed to open dri: /usr/lib/gbm/dri_gbm.so: cannot open
--   shared object file (search paths /usr/lib/gbm, suffix _gbm)
--
-- DRI and the EGL vendor directory were already covered by the two entries
-- above; GBM is the same class of problem and simply never got its
-- counterpart. Anything that allocates scanout buffers -- a KMS/DRM console
-- app, a Wayland compositor back end, headless GPU rendering, SDL2's KMSDRM
-- video driver, ffmpeg's VAAPI hwcontext -- gets a NULL device without it.
graphics.GBM_DIR        = "usr/lib/gbm"

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

-- Where libxkbcommon looks for keyboard layouts.
--
-- `share/X11/xkb` is the path every distribution uses and the one upstream's
-- own compiled-in default is built from, so a consumer that hard-codes it —
-- some do — still works when this is the subos view.
graphics.XKB_DIR        = "share/X11/xkb"

-- Where libinput looks for its device quirks.
--
-- `share/libinput` is `$datadir/libinput`, upstream's own layout, and the files
-- sit FLAT in it -- meson's `install_subdir('quirks', strip_directory: true)`
-- drops the `quirks/` level. `quirks.c:1217` then does
-- `scandir(data_path, …, is_data_file, versionsort)` over exactly that one
-- directory, taking every `*.quirks` file.
--
-- `versionsort`, so the `10-` / `30-` / `50-` filename prefixes decide
-- precedence -- the same convention that orders the glvnd vendor JSONs, and
-- the reason HAVE_VERSIONSORT is not optional in compat.libinput.
graphics.QUIRKS_DIR     = "share/libinput"

-- The variables, once. Keys are variable names; values are subos-relative
-- paths, with no placeholder syntax -- the two emitters below add their own.
--
-- XDG_DATA_DIRS carries the Vulkan ICD search path as a side effect, and that
-- is deliberate rather than incidental: the Vulkan loader searches
-- `$XDG_DATA_DIRS/vulkan/icd.d`, so once a `vulkan-loader` package exists,
-- mesa's ICD manifests are found with no new variable. `VK_DRIVER_FILES` would
-- be wrong here -- it is an OVERRIDE that suppresses system discovery, so it
-- would hide any other ICD on the machine.
--
-- GBM_BACKENDS_PATH is a colon-separated LIST that libgbm walks in order
-- (src/gbm/main/backend.c splits on ':' and dlopens `<dir>/<driver>_gbm.so` at
-- each), so `prepend` is both correct and non-destructive here, exactly as for
-- the three above. It is also the variable every other relocated stack reaches
-- for: Valve's pressure-vessel answers the identical breakage with
-- GBM_BACKENDS_PATH=/run/host/usr/lib64/gbm (steam-runtime#797), and Nix and
-- Conda set it at environment-activation time.
local DISCOVERY = {
    { var = "LIBGL_DRIVERS_PATH",        rel = graphics.DRI_DIR },
    { var = "__EGL_VENDOR_LIBRARY_DIRS", rel = graphics.EGL_VENDOR_DIR },
    { var = "XDG_DATA_DIRS",             rel = graphics.SHARE_DIR },
    { var = "GBM_BACKENDS_PATH",         rel = graphics.GBM_DIR },
    -- The xkeyboard-config data tree. libxkbcommon COMPILES keymaps and
    -- contains none: `xkb_keymap_new_from_names(rules, model, layout, …)`
    -- reads the layouts off disk, and the path comes from XKB_CONFIG_ROOT with
    -- a compiled-in fallback.
    --
    -- Same class as the four above, and it was missing for the same reason
    -- GBM_BACKENDS_PATH was: the mechanism existed and one subsystem never got
    -- its row. Measured before this entry — `xim:libxkbcommon`'s payload ships
    -- `bin include lib share/{bash-completion,man}` and NO xkb data — so a
    -- compositor asking for the "us" layout fell through to the HOST's
    -- /usr/share/X11/xkb. That is the same silent host fallback that gave
    -- Vulkan an llvmpipe device instead of the GPU.
    --
    -- `op = "set"`, and it is the FIRST row that is not a list.
    --
    -- The four above are colon-separated search paths, which is what makes
    -- `prepend` both correct and non-destructive there. XKB_CONFIG_ROOT is a
    -- SCALAR: libxkbcommon reads it once and uses it as one directory, which
    -- must itself contain rules/, symbols/, keycodes/, types/ and compat/.
    -- Prepend a second provider onto it and the value becomes `dirA:dirB` —
    -- a path that does not exist, so `xkb_keymap_new_from_names` fails to find
    -- its rules and reports nothing more specific than a compile failure.
    --
    -- Only `xkeyboard-config` fills this today, so `prepend` would behave
    -- identically right now and break the day a second provider appears. `set`
    -- is what the variable actually means.
    { var = "XKB_CONFIG_ROOT",           rel = graphics.XKB_DIR, op = "set" },
    -- libinput's device quirks: per-model tuning like a touchpad's pressure
    -- range or a mouse's wheel click angle. `libinput.c:1911` reads this
    -- variable and falls back to a compiled-in path, which compat.libinput
    -- leaves EMPTY for the usual reason -- upstream's default is
    -- `$prefix/share/libinput`, and after relocation that is the HOST's.
    --
    -- Scalar, so `set`, for the same reason as XKB_CONFIG_ROOT: `quirks.c`
    -- scandir()s ONE directory. It is also why the degradation is loud but
    -- gentle -- without this, libinput logs
    --
    --     failed to find data files ... will negatively affect device behavior
    --
    -- and runs on built-in defaults: enumeration, events and gestures all
    -- work, only the per-model tuning is gone.
    { var = "LIBINPUT_QUIRKS_DIR",       rel = graphics.QUIRKS_DIR, op = "set" },
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
-- `prepend` for every SEARCH PATH, and the reason is not stylistic: they are
-- colon-separated LISTS and more than one package is entitled to be on them. A
-- `set` by one provider beats a `prepend` by another in xlings's resolution, so
-- a `set` on one of those would silently erase the NVIDIA vendor directory and
-- the machine with the GPU would render on llvmpipe.
--
-- A row may override this with `op`, and exactly one does: XKB_CONFIG_ROOT is a
-- scalar rather than a list, so the argument above inverts for it. The rule is
-- the variable's own type, not a default to be departed from lightly — see the
-- row itself.
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
--
-- OMITTING `only` MEANS "EVERY ROW", AND NO PACKAGE SHOULD DO IT. It reads as a
-- convenience and behaves as a claim that grows behind the caller's back: mesa
-- omitted it, a fifth row was added for a different subsystem, and mesa began
-- declaring a path its payload does not contain. Pass a set -- RENDER_PATHS,
-- EGL_VENDOR_ONLY, EGL_VENDOR_AND_ICD, XKB_ONLY, or a new one -- so that adding
-- a row is a decision each provider makes rather than one it inherits.
function graphics.declare_subos_env(tag, only)
    if type(subos.env) ~= "function" then return false end
    for _, d in ipairs(DISCOVERY) do
        if not only or only[d.var] then
            subos.env{ var = d.var, op = d.op or "prepend",
                       value = "${subosdir}/" .. d.rel, binding = tag }
        end
    end
    return true
end

-- The set a vendor-only provider passes to declare_subos_env.
graphics.EGL_VENDOR_ONLY = { ["__EGL_VENDOR_LIBRARY_DIRS"] = true }

-- The four RENDERING paths — what a GL/Vulkan driver stack provides.
--
-- This set exists because omitting `only` means "declare every row", and that
-- was a safe default only while every row belonged to one provider. It is not
-- safe as the table grows: `mesa` passed no set, so adding XKB_CONFIG_ROOT
-- silently made mesa declare the keyboard-layout root, which its payload does
-- not contain (`share/{drirc.d,glvnd,vulkan}` and no `share/X11`).
--
-- The rule this encodes: A PROVIDER DECLARES ONLY WHAT IT FILLS. The three
-- `declare_*` helpers enforce it by checking `os.isdir` and declining;
-- `declare_subos_env` has no payload to check, so the set is how a provider
-- says the same thing.
graphics.RENDER_PATHS = {
    ["LIBGL_DRIVERS_PATH"]        = true,
    ["__EGL_VENDOR_LIBRARY_DIRS"] = true,
    ["XDG_DATA_DIRS"]             = true,
    ["GBM_BACKENDS_PATH"]         = true,
}

-- The set the keyboard-layout dataset passes. `xkeyboard-config` is DATA only:
-- no libraries, no DRI modules, no EGL vendor, no `share/vulkan`. Declaring the
-- other rows from it would name four directories it does not fill.
graphics.XKB_ONLY = { ["XKB_CONFIG_ROOT"] = true }

-- The set the libinput quirks dataset passes. Same reasoning as XKB_ONLY: data
-- only, so it names the one directory it fills and none of the others.
graphics.QUIRKS_ONLY = { ["LIBINPUT_QUIRKS_DIR"] = true }

-- The set for a provider that contributes a Vulkan ICD as well as a GL vendor.
--
-- XDG_DATA_DIRS is how the Khronos loader finds `vulkan/icd.d`; it is not a
-- Vulkan-specific variable, which is why it is not in the EGL-only set above.
-- A provider that stages an ICD must declare it, or the manifest sits in the
-- subos and the loader never looks there — and the failure is invisible,
-- because the loader then scans the HOST's /usr/share and usually finds
-- something loadable (llvmpipe), so the program renders in software instead of
-- reporting that the GPU was dropped. Measured on nvidia-gl-host-link.
--
-- LIBGL_DRIVERS_PATH stays out: an ICD is not a DRI driver module, and naming
-- a directory this package does not fill is what the EGL-only set exists to
-- avoid.
graphics.EGL_VENDOR_AND_ICD = {
    ["__EGL_VENDOR_LIBRARY_DIRS"] = true,
    ["XDG_DATA_DIRS"]             = true,
}

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

-- The GBM counterpart of declare_dri, and deliberately its mirror image rather
-- than a variation: the two directories hold the same KIND of thing (backend
-- modules dlopen'd by absolute path), so the same rejection applies --
-- `sysroot.declare_libs(dir, "lib/gbm", ...)` would flatten them into
-- `<subos>/lib`, which is the LINK directory, and they are not link targets.
--
-- NOT required. A mesa built without the dri gbm backend is a legitimate
-- configuration, and so is a consumer that only ever calls the pure half of the
-- API (gbm_format_get_name and friends need no device). So this warns and
-- returns false rather than failing the install -- but it does warn, because
-- the alternative is GBM_BACKENDS_PATH naming an empty directory and
-- gbm_create_device() returning NULL with no diagnostic of its own.
function graphics.declare_gbm(install_dir, rel_dir, tag)
    if not xvm.files then return false end
    if not os.isdir(path.join(install_dir, rel_dir)) then
        log.warn("no %s in this payload -- GBM_BACKENDS_PATH would point at an "
                 .. "empty directory and gbm_create_device() would find no "
                 .. "backend and return NULL", rel_dir)
        return false
    end
    xvm.files{ src = rel_dir, dst = graphics.GBM_DIR, binding = tag }
    return true
end

-- The keyboard-layout dataset, placed the same way the two above place their
-- modules — and it has to be placed, not merely declared.
--
-- That is the whole lesson of this helper. `declare_subos_env` writes the
-- VARIABLE; `xvm.files` puts the CONTENT where the variable points. Declaring
-- XKB_CONFIG_ROOT without this gives a subos where the variable is set, reads
-- correctly in a shell, and names a directory that does not exist — which
-- libxkbcommon reports as "keymap compilation failed", the same message it
-- gives for a genuinely broken layout. Measured: the first version of
-- `xkeyboard-config` declared and did not place, and the shell showed
--
--     XKB_CONFIG_ROOT=[.../share/X11/xkb]
--     ls: cannot access '.../share/X11/xkb': No such file or directory
--
-- What it carries is DATA, not code — text files that libxkbcommon's own
-- parser reads. That is worth saying explicitly because `subos.env` warns that
-- a declared variable can load code from our payload into processes we do not
-- own. It cannot here: there is no dlopen at the end of this path, and the
-- worst a bad tree can do is fail to compile a keymap.
function graphics.declare_xkb(install_dir, rel_dir, tag)
    if not xvm.files then return false end
    local src = path.join(install_dir, rel_dir)
    if not os.isdir(src) then
        log.warn("no %s in this payload -- XKB_CONFIG_ROOT would name a "
                 .. "directory that does not exist and every RMLVO keymap "
                 .. "would fail to compile", rel_dir)
        return false
    end
    xvm.files{ src = rel_dir, dst = graphics.XKB_DIR, binding = tag }
    return true
end

-- libinput's device quirks, placed the same way. Data, like declare_xkb: what
-- `LIBINPUT_QUIRKS_DIR` leads to is a flat directory of `.quirks` INI files
-- that libinput's own parser reads, with no dlopen anywhere along the path.
--
-- Checks for a `.quirks` FILE and not just the directory, because an empty
-- directory is the one case that fails SILENTLY: `quirks.c:1217` scandir()s it,
-- finds zero matches, and libinput carries on with built-in defaults -- the
-- same outcome as declaring nothing, reached WITHOUT the "failed to find data
-- files" message that would have named the problem.
--
-- One canonical filename rather than a glob, and that is a constraint rather
-- than a preference: `os.files` does not exist in a package hook's restricted
-- `os` table (nor do `os.filedirs`, `os.exists`, `os.curdir`, `os.iorunv`), and
-- a `#(os.files(...) or {}) == 0` guard turns that absence into a confident
-- "the directory is empty". `10-generic-keyboard.quirks` is the least
-- version-sensitive name in the set -- it predates every vendor file and ships
-- in libinput releases years apart.
function graphics.declare_quirks(install_dir, rel_dir, tag)
    if not xvm.files then return false end
    local src = path.join(install_dir, rel_dir)
    if not os.isdir(src)
       or not os.isfile(path.join(src, "10-generic-keyboard.quirks")) then
        log.warn("no quirks in %s -- LIBINPUT_QUIRKS_DIR would name an empty "
                 .. "directory and libinput would fall back to its built-in "
                 .. "defaults without saying so", rel_dir)
        return false
    end
    xvm.files{ src = rel_dir, dst = graphics.QUIRKS_DIR, binding = tag }
    return true
end

-- ─────────────────────────────────────────────────────────────────────
-- GLX vendor registration — the counterpart `declare_egl_vendor` has and
-- GLX did not. See GLX_VENDOR_SUBDIR above for why it is a directory plus an
-- RPATH rather than a variable: glvnd offers no GLX variable to point.
-- ─────────────────────────────────────────────────────────────────────

-- Can this vendor library actually load, and if not, WHICH dependency is
-- missing?
--
-- glvnd swallows a vendor's dlopen failure. The user sees GL rendering --
-- through somebody else's driver -- and nothing else. Measured on an NVIDIA
-- 550.144.03 host: `libEGL_nvidia.so.0` never loaded, EGL silently fell back
-- to zink, and the acceptance script could only say "did NOT load our
-- interposer". The actual cause took a hand-written dlopen probe to find:
--
--   dlopen FAILED: libpthread.so.0: cannot open shared object file
--
-- The host's vendor declares DT_NEEDED on libpthread/librt/libdl -- the
-- libraries glibc merged into libc in 2.34 -- and the host vendor carries no
-- search path of its own, so only a TRANSITIVE tag on our interposer reaches
-- them.
--
-- So: resolve the HOST vendor's own DT_NEEDED against the search path our
-- interposer provides, and name anything that does not resolve. That is a
-- string operation over `readelf -d` plus `os.isfile` -- no compiler, no
-- dlopen, no subprocess per candidate.
--
-- Returns a list of unresolved SONAMEs (empty when the closure is complete).
-- An empty list is NOT proof of success when the tools are missing, so a
-- caller that cannot read anything is told separately via `ok`.
function graphics.vendor_closure_gaps(interposer, host_vendor)
    local out = { ok = false, missing = {}, reason = nil }

    local dyn = os.iorun(string.format([[readelf -d "%s"]], host_vendor))
    -- `os.iorun` returns "" on failure and swallows stderr, so an empty
    -- result is the ONLY signal the tool did not run. It is not evidence of
    -- an empty closure.
    if dyn == "" then return out end

    -- The TAG first, because it decides whether the path is reachable at all.
    --
    -- The host vendor behind the interposer carries no search path of its own.
    -- Its DT_NEEDED is resolved using the interposer's path only if that path
    -- is TRANSITIVE -- DT_RPATH. Under DT_RUNPATH the interposer's directories
    -- are not consulted for it, so the file being present on that path proves
    -- nothing.
    --
    -- A first version of this probe checked only presence and reported
    -- `libEGL_nvidia.so.0 state=ok` for a library measured to fail with
    -- `libpthread.so.0: cannot open shared object file`. Presence was true and
    -- reachability was false.
    local tags = os.iorun(string.format([[readelf -d "%s"]], interposer))
    if tags == "" then return out end
    -- The tag on the INTERPOSER decides whether the host driver behind it can
    -- resolve its own DT_NEEDED *from this library alone*. It does not decide
    -- what happens in a real process, because a CONSUMER's DT_RPATH is
    -- transitive: when an executable stamped that way opens this vendor, its
    -- search path covers the whole chain and the host driver resolves.
    --
    -- Measured on one home, one interposer, changing only the consumer:
    -- a DT_RUNPATH consumer cannot open libEGL_nvidia; a DT_RPATH consumer
    -- loads it and renders on the GPU.
    --
    -- So this is NOT `broken`. Before libxpkg 0.0.57 nearly every installed
    -- executable carried DT_RUNPATH and calling it broken was accurate in
    -- practice; since 0.0.57 elfpatch stamps DT_RPATH on executables, so
    -- installed programs reach the GPU through this vendor and only programs
    -- the USER builds -- which still get DT_RUNPATH (openxlings/xlings#532) --
    -- cannot. Reporting that as `broken` under-reports, which is the worse
    -- direction: it sends someone to fix a problem that is not there and hides
    -- the one that is. See openxlings/xlings#537.
    -- The tag on the INTERPOSER decides whether the host driver behind it
    -- resolves its own DT_NEEDED *from this library alone*. It does not decide
    -- what happens in a process: a CONSUMER's DT_RPATH is transitive, so an
    -- executable stamped that way covers this whole chain when it opens the
    -- vendor. Measured -- DT_RUNPATH consumer cannot open libEGL_nvidia,
    -- DT_RPATH loads it and renders on the GPU. The caller turns this into
    -- `needs-transitive-consumer`, not `broken` (openxlings/xlings#537).
    if not tags:find("(RPATH)", 1, true) then
        out.ok = true
        out.reason = "tag"
        return out
    end

    local search = {}
    local rp = os.iorun(string.format([[patchelf --print-rpath "%s"]], interposer))
    for dir in (((rp or "") .. ":"):gmatch("([^:\n]*):")) do
        if dir ~= "" then table.insert(search, dir) end
    end
    if #search == 0 then return out end

    out.ok = true
    for soname in dyn:gmatch("Shared library:%s*%[([^%]]+)%]") do
        -- An absolute DT_NEEDED is the interposer naming the host vendor
        -- itself; it needs no search path.
        if soname:sub(1, 1) ~= "/" then
            local found = false
            for _, dir in ipairs(search) do
                if os.isfile(path.join(dir, soname)) then found = true break end
            end
            if not found then table.insert(out.missing, soname) end
        end
    end
    return out
end

-- The host driver library an interposer stands in front of.
--
-- The interposer names it by ABSOLUTE path in its own DT_NEEDED -- that is the
-- whole design: we do not copy the host's driver, which must stay paired with
-- the running kernel module. So the absolute entry IS the host vendor.
--
-- Returns `host_path, form` where form is one of:
--
--   "interposed"  a stub of ours with the host driver named absolutely
--   "direct"      the host's own driver, symlinked into the payload with no
--                 stub in front of it
--   "native"      our own build; there is no host closure to complete
--   "unreadable"  readelf did not run. NOT a verdict about the library.
--
-- WHY THIS RETURNS FOUR THINGS AND NOT A POINTER-OR-NIL
--
-- It used to return nil for three of these, and the caller turned every nil
-- into `state=native` -- which the panel reports as a PASS. Measured on a real
-- home, ALL SIX vendors were recorded `native`, including an EGL interposer
-- that plainly has an absolute DT_NEEDED and three GLX/GLES entries that are
-- bare symlinks to `/lib/x86_64-linux-gnu/`. The stack was wired to nothing
-- and four independent channels said it was fine.
--
-- Two distinct conflations produced that:
--
--   * `os.iorun` returns "" when the tool is missing, and "the tool did not
--     run" became "this is ours, nothing to check". The sibling function
--     `vendor_closure_gaps` guards exactly this case and says so in its own
--     comment -- the guard existed, one function away.
--   * since 0.1.2 the GLX and GLES vendors are DIRECT SYMLINKS to the host
--     driver. A host library has no absolute DT_NEEDED (it names its
--     siblings by soname), so the old test read "no absolute entry" as "our
--     own build". It is literally the host driver. The verdict was inverted
--     for precisely the vendors that most needed checking.
function graphics.host_vendor_behind(interposer)
    local dyn = os.iorun(string.format([[readelf -d "%s"]], interposer))
    -- "" is the ONLY signal os.iorun gives for a tool that did not run, and
    -- it is not evidence about the library.
    if dyn == "" then return nil, "unreadable" end
    for soname in dyn:gmatch("Shared library:%s*%[([^%]]+)%]") do
        if soname:sub(1, 1) == "/" then return soname, "interposed" end
    end
    -- No stub in front of it. Follow the file: a vendor that resolves outside
    -- our store is the host's driver wearing our filename, and its closure is
    -- every bit as unchecked as an interposer's.
    local real = os.iorun(string.format([[readlink -f "%s"]], interposer))
    real = (real or ""):gsub("%s+$", "")
    if real ~= "" and not real:find("xpkgs", 1, true) then
        return real, "direct"
    end
    return nil, "native"
end

-- Record what was wired, next to what was wired.
--
-- So no reader ever has to probe. `xlings subos info` reaching for patchelf
-- would break the contract that local queries answer instantly, and a second
-- probe is a second answer to a question this function already answered.
-- Plain key=value: it is read by a C++ command, and a format that needs a
-- parser is a format that can fail to parse.
function graphics.record_wiring(dispatch_dir, lines)
    local f = path.join(dispatch_dir, graphics.GLX_VENDOR_SUBDIR, ".wiring")
    io.writefile(f, table.concat(lines, "\n") .. "\n")
    return os.isfile(f)
end

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
