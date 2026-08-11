package = {
    spec = "2",

    homepage = "https://github.com/openxlings/xim-pkgindex",
    name = "graphics",
    description = "The xlings graphics stack: OpenGL that adapts to whatever GPU this host has",

    authors = {"xlings contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/openxlings/xim-pkgindex",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "opengl", "meta"},
    keywords = {"graphics", "opengl", "gl", "egl", "mesa", "nvidia", "wsl", "meta"},

    -- ─────────────────────────────────────────────────────────────────────
    -- One command, five host shapes, no conditional syntax anywhere.
    --
    --     xlings install graphics
    --
    -- | host                       | what renders          | via                  |
    -- |----------------------------|-----------------------|----------------------|
    -- | NVIDIA proprietary driver  | the GPU               | nvidia-gl-host-link  |
    -- | AMD                        | the GPU (radeonsi)    | mesa                 |
    -- | Intel                      | the GPU (iris)        | mesa                 |
    -- | WSL2                       | the GPU (d3d12)       | wsl-gl-host-link     |
    -- | no GPU / container         | the CPU (llvmpipe)    | mesa                 |
    --
    -- HOW, WITHOUT AN `if`
    --
    -- The two host-facing packages are SENTINELS: each probes for a userspace
    -- half it does not own, links it if present, and succeeds having linked
    -- nothing if not. "This machine does not have that" is a normal return
    -- value, not a branch -- so depending on both is correct on every host, and
    -- the dependency graph adapts by itself.
    --
    -- That is the same effect conda gets from `__cuda` / `__glibc` virtual
    -- packages -- the solver trimming a graph by host capability -- reached
    -- without a solver feature, because a sentinel can answer at install time
    -- what a solver would have to be told.
    --
    -- WHAT IT IS NOT
    --
    -- Not a version-pinning umbrella. Every dependency is a lower bound, so
    -- installing this does not freeze the stack; and it carries no payload, so
    -- removing it leaves the stack in place. It exists so a user does not have
    -- to know that "GL" means twenty-two packages plus a driver bridge whose
    -- name depends on their hardware.
    --
    -- Design: xlings/.agents/docs/2026-08-07-graphics-experience-industry-survey-and-plan.md §A3
    xpm = {
        linux = {
            -- The split form. A `deps` table with an array part makes every
            -- client before libxpkg 0.0.52 drop the `build` sub-table and copy
            -- the runtime entries into build_deps instead, silently.
            deps = {
                runtime = {
                    -- The stack itself. mesa's own deps pull in the twenty-one
                    -- packages below it (libglvnd, libllvm, the X11 client
                    -- libraries, wayland, libdrm, …) -- listing them here would
                    -- be a second, drifting copy of that graph.
                    -- BARE, no range, and that is measured rather than
                    -- stylistic: mesa's version is `25.0.7.1` -- four
                    -- components, upstream's three plus ours, deliberately (see
                    -- that recipe) -- and the resolver's range comparison
                    -- cannot parse a four-component version at all. Both
                    -- `@>=25.0.7` and `@>=25.0.7.1` resolve to
                    -- "package not found", which reads as a missing package
                    -- rather than an unparseable constraint.
                    --
                    -- A bare namespaced name means "whatever mesa this home
                    -- resolves", which is what a lower bound was trying to say.
                    "xim:mesa",
                    -- Sentinel: the host's proprietary NVIDIA GL userspace.
                    -- A no-op on a machine without that driver.
                    -- >=0.1.2, not >=0.1. The interposer's DT_RPATH fix is in
                    -- 0.1.2, and 0.1.1 already satisfies `>=0.1` -- so an
                    -- already-installed home would keep the broken build and
                    -- stay on software rendering with nothing to say so.
                    -- Measured: after bumping the recipe, the home reported
                    -- "installed, but 'nvidia-gl-host-link' still resolves to
                    -- 0.1.1" and needed a manual `xlings use` to switch. A
                    -- lower bound only pulls what it excludes.
                    "xim:nvidia-gl-host-link@>=0.1.2",
                    -- Sentinel: WSL2's Windows-side D3D12 userspace.
                    -- A no-op anywhere that is not WSL2.
                    --
                    -- This was BARE, unlike its two siblings above, while
                    -- `wsl-gl-host-link` was NEW: CI registers a changed recipe
                    -- under `local`, and an `xim:` prefix resolves from that one
                    -- namespace alone -- so a batch of new interdependent
                    -- packages can never install until every one of them is
                    -- already published. Measured then as
                    -- `package 'xim:wsl-gl-host-link@>=0.1' not found`; #498 hit
                    -- the same wall and fixed it the same way.
                    --
                    -- That exemption lasts exactly until the package ships, and
                    -- then inverts. #540 published it. A published recipe that a
                    -- PR also CHANGES exists under BOTH `xim` and `local`, and a
                    -- bare name is ambiguous there -- the resolver refuses to
                    -- guess. New package: bare, and say so here. Published
                    -- package: namespaced, which is what CI now enforces.
                    "xim:wsl-gl-host-link@>=0.1",

                    -- The rest of what a GUI PROGRAM needs, as opposed to what
                    -- mesa needs.
                    --
                    -- This distinction cost a regression. `godot` stops adding
                    -- host library directories to its RPATH when this package is
                    -- present -- correct, that is the point -- and then failed to
                    -- start on a machine where it used to work:
                    --
                    --   libfontconfig.so.1: cannot open shared object file
                    --   libXcursor.so.1:    cannot open shared object file
                    --   libxkbcommon.so.0:  cannot open shared object file
                    --   ERROR: Can't load XCursor dynamically.
                    --   ERROR: Could not initialize the Wayland thread.
                    --
                    -- mesa's dependency closure is the closure of a RENDERING
                    -- library: libX11/libxcb to talk to the server, libdrm for
                    -- the kernel, wayland because libEGL_mesa NEEDs it. An
                    -- application also opens windows, draws text and reacts to
                    -- input, and every library for that is dlopen'd by the app
                    -- itself -- so it appears in no DT_NEEDED and in no
                    -- dependency graph derived from one.
                    --
                    -- They were all already in the index. Nothing pulled them,
                    -- because nothing had ever tried to RUN a GUI application
                    -- out of this stack; the acceptance criterion up to now was
                    -- a surfaceless probe, which needs none of them.
                    "xim:libXcursor@>=1.2",
                    "xim:libXi@>=1.8",
                    "xim:libXrandr@>=1.5",
                    "xim:libXrender@>=0.9",
                    "xim:libxkbcommon@>=1.7",
                    "xim:fontconfig@>=2.14",
                    -- Non-fatal when absent (single-screen fallback), which is
                    -- exactly why it went unnoticed until a real toolkit ran.
                    "xim:libXinerama@>=1.1",
                    -- An ICD is a driver; a driver needs a loader. mesa ships
                    -- RADV and its manifest, and without libvulkan.so.1 nothing
                    -- ever reads it -- which also leaves zink dead.
                    "xim:vulkan-loader@>=1.4",
                    -- The GL dispatch. It arrives transitively through mesa
                    -- anyway; it is declared HERE because config() wires the
                    -- GLX vendor libraries into its payload, and a transitive
                    -- dependency has no resolver record to ask for -- the
                    -- query would just return nil (openxlings/xlings#524).
                    --
                    -- The lower bound is the version that carries the vendor
                    -- directory and the `$ORIGIN/glx-vendor` RPATH, so a home
                    -- upgrading from an older stack actually re-runs
                    -- libglvnd's config instead of keeping a libGLX.so.0 that
                    -- can reach no vendor at all.
                    "xim:libglvnd@>=1.7.0.1",
                },
            },
            ["latest"] = { ref = "0.1.5" },
            -- No payload. This package is its dependency list and the report
            -- below; there is nothing to download.
            --
            -- 0.1.1 exists so an already-assembled home re-runs config() and
            -- picks up the GLX vendor wiring. Without a new key the hook never
            -- fires again and the fix reaches only fresh installs -- silently,
            -- which is the failure mode this stack keeps producing.
            -- 0.1.2 re-runs config() on an already-assembled home so it
            -- probes its vendors and records the wiring. Same payload-less
            -- recipe; the hook that consumes it is what changed.
            -- 0.1.3 re-runs config() so an already-assembled home re-records
            -- its wiring with the third state. Without a new key the hook
            -- never fires again and the corrected verdict reaches only fresh
            -- installs -- silently, which is the failure this stack keeps
            -- producing and the reason every one of these keys exists.
            -- 0.1.4 re-runs config() so an already-assembled home re-records
            -- wiring that no longer says `native` about two things it never
            -- examined: a vendor whose dynamic section could not be read, and
            -- a vendor that is a bare symlink to the host driver. Measured on
            -- a real home, ALL SIX vendors were recorded `native` -- a pass --
            -- while the stack was wired to nothing.
            -- 0.1.5 re-runs config() so an already-assembled home re-records
            -- its wiring WITH the payload each verdict was measured against.
            -- The reader (xlings 2026.8.11.2) expires a verdict whose vendor
            -- symlink no longer lands inside that directory -- and a record
            -- without the field produces no verdict at all, by design. So
            -- without this key the read side would be permanently inert on
            -- every home that already has the stack: safe, and useless. The
            -- same reasoning as every key above it.
            ["0.1.5"] = { },
            ["0.1.4"] = { },
            ["0.1.3"] = { },
            ["0.1.2"] = { },
            ["0.1.1"] = { },
            ["0.1.0"] = { },
        },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.graphics")

-- Wire every GLX vendor in this stack into the dispatch's vendor directory.
--
-- glvnd dlopens `libGLX_<vendor>.so.0` by name from inside libGLX.so.0, and
-- there is no GLX counterpart to `egl_vendor.d` to point at -- see
-- libs/graphics.lua GLX_VENDOR_SUBDIR. libglvnd's config gives its own
-- libGLX.so.0 an `$ORIGIN/glx-vendor` RPATH; this fills that directory.
--
-- Done by the assembler rather than by each vendor because a libglvnd
-- reinstall wipes its payload, taking every registration with it, and the
-- vendors do not reinstall just because their dependency did. This package
-- declares all of them, so it installs last and can rebuild the whole set.
--
-- mesa is the software/AMD/Intel path; nvidia-gl-host-link bridges the
-- proprietary driver. The WSL2 sentinel has no GLX vendor of its own -- it
-- renders through mesa's d3d12 driver behind libGLX_mesa -- so it is not
-- listed. A vendor whose library is absent (a sentinel on a host without that
-- driver) is skipped, not an error.
local _GLX_VENDORS = {
    { dep = "xim:mesa",                soname = "libGLX_mesa.so.0",   vendor = "mesa" },
    { dep = "xim:nvidia-gl-host-link", soname = "libGLX_nvidia.so.0", vendor = "nvidia" },
}

function __wire_glx_vendors()
    local dispatch = pkginfo.dep_install_dir("xim:libglvnd")
    if not dispatch or dispatch == "" then
        log.error("cannot locate the libglvnd payload; GLX programs will find "
                  .. "no vendor and fall back to software rendering")
        return false
    end

    local found = {}
    for _, v in ipairs(_GLX_VENDORS) do
        local dir = pkginfo.dep_install_dir(v.dep)
        if dir and dir ~= "" then
            table.insert(found, { dir = dir, soname = v.soname })
        end
    end

    local n = graphics.wire_glx_vendors(dispatch, found)

    -- Probe every entry point each vendor ships, and RECORD the result.
    --
    -- Every entry point, not just the GLX one we wired above: glvnd dlopens
    -- each vendor library by name, so each is its own load-chain root and each
    -- can fail on its own. Measured on an NVIDIA 550.144.03 host -- GLX loaded
    -- and rendered on the GPU while `libEGL_nvidia.so.0` never loaded at all
    -- and EGL silently fell back to zink. A probe that only covered what the
    -- GLX wiring touches would have reported a healthy stack.
    --
    -- The record exists so nothing probes again later. A reader that
    -- re-derives this is a second answerer, and the sentinels in this same
    -- file already set the precedent: read the state, do not re-measure.
    local ENTRY_POINTS = {
        "libEGL_%s.so.0", "libGLX_%s.so.0",
        "libGLESv1_CM_%s.so.1", "libGLESv2_%s.so.2",
    }
    -- PROVENANCE: which payload each verdict is about.
    --
    -- This record is written by `graphics` and every line in it describes a
    -- DIFFERENT package -- mesa, libglvnd, nvidia-gl-host-link. Those packages
    -- upgrade on their own schedule, and until now nothing could tell that a
    -- record had outlived what it describes. Measured on a real home: the
    -- record was written at 01:37:17 and the nvidia payload it speaks for at
    -- 01:38:14 -- the verdict predated its subject by 57 seconds.
    --
    -- The dispatch layer already had this (`dispatch=` -> the reader compares
    -- it against what the farm resolves to, and says `stale wiring`). The
    -- vendor layer had nothing.
    --
    -- WHAT THE READER CAN DO WITH IT decided the shape. "Is this the current
    -- version of that package" is unanswerable there: `subos info` answers
    -- from local state by contract and must not parse the index. A PATH is
    -- different -- the reader can follow `glx-vendor/<soname>` and see whether
    -- it still lands inside this directory, which is precisely what changes
    -- when a vendor is upgraded and the assembler is not re-run. Local, cheap,
    -- and it needs nobody's cooperation.
    --
    -- LAST ON THE LINE, because it is a path and a path may contain a space;
    -- the reader takes the whole remainder, exactly as it does for `dispatch=`.
    local function vendor_line(soname, dir, rest)
        return "vendor=" .. soname .. " " .. rest .. " payload=" .. dir
    end

    local lines = { "dispatch=" .. dispatch }
    for _, v in ipairs(_GLX_VENDORS) do
        local dir = pkginfo.dep_install_dir(v.dep)
        if dir and dir ~= "" then
            for _, pat in ipairs(ENTRY_POINTS) do
                local soname = string.format(pat, v.vendor)
                local lib = path.join(dir, "lib", soname)
                if os.isfile(lib) then
                    local host, form = graphics.host_vendor_behind(lib)
                    if form == "unreadable" then
                        -- The tool did not run. That is not a fact about this
                        -- library, and it used to be recorded as `native` --
                        -- which the panel shows as a PASS. An absent
                        -- observation must never be spent as a verdict.
                        table.insert(lines, vendor_line(soname, dir, "state=unverified"))
                        log.warn("%s: cannot read its dynamic section (readelf "
                                 .. "unavailable); its wiring is unknown, not "
                                 .. "healthy", soname)
                    elseif form == "native" then
                        -- No absolute DT_NEEDED and the file resolves inside
                        -- our store: this vendor is OURS, built against our
                        -- payloads. There is no host closure to check, which
                        -- is not the same as a failed check.
                        table.insert(lines, vendor_line(soname, dir, "state=native"))
                    else
                        local gaps = graphics.vendor_closure_gaps(lib, host)
                        if not gaps.ok then
                            table.insert(lines, vendor_line(soname, dir, "state=unverified"))
                            log.warn("%s: cannot verify its dependency closure "
                                     .. "(readelf or patchelf unavailable); if it "
                                     .. "is incomplete, GL renders through another "
                                     .. "driver and says nothing", soname)
                        elseif gaps.reason == "tag" then
                            -- NOT `broken`: the verdict depends on WHO OPENS
                            -- IT. A consumer's DT_RPATH is transitive and
                            -- covers this whole chain, so an INSTALLED program
                            -- (elfpatch stamps DT_RPATH since libxpkg 0.0.57)
                            -- reaches the GPU through this vendor, while a
                            -- program the user builds in this subos still
                            -- cannot -- those get DT_RUNPATH
                            -- (openxlings/xlings#532).
                            --
                            -- Measured on one home, one interposer, changing
                            -- only the consumer: DT_RUNPATH cannot open
                            -- libEGL_nvidia, DT_RPATH loads it and renders on
                            -- the GPU.
                            --
                            -- `broken` was accurate before 0.0.57, when nearly
                            -- every executable was DT_RUNPATH. It now
                            -- UNDER-reports, which is the worse direction: it
                            -- sends someone to fix a problem that is not there
                            -- and hides the one that is
                            -- (openxlings/xlings#537).
                            table.insert(lines, vendor_line(soname, dir,
                                         "state=needs-transitive-consumer"))
                            log.warn("%s carries DT_RUNPATH. Installed "
                                     .. "programs still reach it -- their own "
                                     .. "DT_RPATH is transitive and covers this "
                                     .. "chain -- but a program built in this "
                                     .. "subos gets DT_RUNPATH and cannot load "
                                     .. "it, so its GL silently renders "
                                     .. "elsewhere (openxlings/xlings#532).",
                                     soname)
                        elseif #gaps.missing > 0 then
                            table.insert(lines, vendor_line(soname, dir,
                                         "state=broken missing="
                                         .. table.concat(gaps.missing, ",")))
                            log.warn("%s cannot load: the host driver behind it "
                                     .. "needs %s, which nothing on its search "
                                     .. "path provides. glvnd falls back to "
                                     .. "another vendor WITHOUT saying so -- GL "
                                     .. "still renders, just not on this driver.",
                                     soname, table.concat(gaps.missing, ", "))
                        else
                            table.insert(lines, vendor_line(soname, dir, "state=ok"))
                        end
                    end
                end
            end
        end
    end
    graphics.record_wiring(dispatch, lines)

    if n == 0 then
        -- Not fatal: a stack with no GLX vendor still runs, on llvmpipe. It
        -- must not do that quietly -- llvmpipe and an RTX 4080 draw the same
        -- pixels, and this is the one place that difference is visible.
        log.warn("no GLX vendor library was registered; GL will render in "
                 .. "software. `xlings install xim:mesa` provides one.")
    end
    return true
end

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mkdir(dir)
    return true
end

function config()
    xvm.add(package.name)

    -- Before the report below, so the banner describes a stack that is
    -- actually wired rather than one that is only installed.
    if not __wire_glx_vendors() then return false end

    -- Say which path this host actually took.
    --
    -- This is the whole reason a meta-package has a hook at all. Every
    -- component reports its own result, but they scroll past in a
    -- twenty-two-package install, and the one thing a user needs to know is
    -- whether they got the GPU or the CPU -- which is precisely the pair this
    -- ecosystem keeps rendering indistinguishable. A GL program on llvmpipe
    -- draws the same pixels as one on an RTX 4080.
    --
    -- Read from the sentinels' own state files rather than re-probed here: a
    -- second probe is a second answer, and the point of a sentinel is to be the
    -- only one. Absent state means an older payload, and "unknown" is the honest
    -- word for that.
    local function __sentinel_state(name, marker)
        local d = pkginfo.dep_install_dir and pkginfo.dep_install_dir(name)
        if not d or d == "" then return nil end
        local f = path.join(d, marker)
        if not os.isfile(f) then return nil end
        return (io.readfile(f) or ""):gsub("%s+$", "")
    end

    -- Namespaced, as declared above. Bare names returned nil under explicit
    -- dependency store roots (openxlings/xlings#524), and this one fails
    -- SILENTLY: both sentinels read as absent, so the banner says "unknown"
    -- and the user cannot tell a GPU install from an llvmpipe one -- which is
    -- precisely the pair this banner exists to distinguish.
    local nv  = __sentinel_state("xim:nvidia-gl-host-link", ".host-driver-version")
    local wsl = __sentinel_state("xim:wsl-gl-host-link", ".wsl-host")

    log.info("graphics stack installed. On this host:")
    if nv and nv ~= "" then
        log.info("  NVIDIA proprietary driver %s — GL renders on the GPU", nv)
    elseif wsl and wsl:find("^yes") then
        log.info("  WSL2 D3D12 — GL renders on the Windows GPU")
    else
        log.info("  no borrowed driver userspace — GL renders through mesa")
        log.info("  (radeonsi/iris/nouveau if a supported GPU is present, else")
        log.info("   llvmpipe on the CPU). `xlings-gl-doctor` reports which.")
    end
    log.info("  a GL program installed through xlings needs no environment")
    log.info("  variables; run it through its xlings shim.")
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
