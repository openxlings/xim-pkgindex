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
                    "xim:nvidia-gl-host-link@>=0.1",
                    -- Sentinel: WSL2's Windows-side D3D12 userspace.
                    -- A no-op anywhere that is not WSL2.
                    --
                    -- BARE, unlike its two siblings above, and the asymmetry is
                    -- the point: `wsl-gl-host-link` is NEW in this change, so it
                    -- does not exist in the `xim` namespace yet. CI registers a
                    -- changed recipe under `local`, and an `xim:` prefix can only
                    -- resolve from that one namespace -- so a batch of new
                    -- interdependent packages can never install until every one
                    -- of them is already published. Measured here as
                    -- `package 'xim:wsl-gl-host-link@>=0.1' not found`; #498 hit
                    -- the same wall and fixed it the same way.
                    --
                    -- `mesa` and `nvidia-gl-host-link` keep their prefix because
                    -- they ARE published: a changed recipe exists under BOTH
                    -- `xim` and `local` during CI, and a bare name is then
                    -- ambiguous -- the resolver refuses to guess. New package:
                    -- bare. Existing package: namespaced.
                    "wsl-gl-host-link@>=0.1",
                },
            },
            ["latest"] = { ref = "0.1.0" },
            -- No payload. This package is its dependency list and the report
            -- below; there is nothing to download.
            ["0.1.0"] = { },
        },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mkdir(dir)
    return true
end

function config()
    xvm.add(package.name)

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

    local nv  = __sentinel_state("nvidia-gl-host-link", ".host-driver-version")
    local wsl = __sentinel_state("wsl-gl-host-link", ".wsl-host")

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
