package = {
    spec = "2",

    homepage = "https://github.com/microsoft/wslg",
    name = "wsl-gl-host-link",
    description = "Sentinel: links WSL2's host D3D12/DXCore userspace so mesa's d3d12 driver can reach the Windows GPU",

    authors = {"xlings contributors"},
    -- The recipe. The libraries it links to are Microsoft's, shipped as part of
    -- Windows and mounted into the distribution by WSL; this package neither
    -- copies nor redistributes them.
    licenses = {"Apache-2.0"},
    repo = "https://github.com/openxlings/xim-pkgindex",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "gpu", "wsl", "lib"},
    keywords = {"wsl", "wsl2", "d3d12", "dxcore", "opengl", "host-link", "sentinel"},

    -- ─────────────────────────────────────────────────────────────────────
    -- The second userspace dependency the graphics stack keeps on the host,
    -- and the reason is the same as NVIDIA's: it is the half of a driver whose
    -- other half we do not own.
    --
    -- In WSL2 there is no native DRM driver for the GPU. The GPU is reached
    -- through `/dev/dxg`, a character device provided by the `dxgkrnl` module,
    -- and the userspace half is `libd3d12core.so` / `libdxcore.so` --
    -- closed-source binaries that ship as part of WINDOWS and are mounted by
    -- WSL at /usr/lib/wsl/lib. Mesa reaches them through its `d3d12` gallium
    -- driver.
    --
    -- WITHOUT THIS PACKAGE
    --   A GL program in a subos on WSL2 renders on llvmpipe, silently. That is
    --   the same shape as an Intel machine with no `iris`: it works, on the CPU,
    --   and nothing says the GPU was available.
    --
    -- WHY THIS IS SIMPLER THAN `nvidia-gl-host-link`
    --   The borrowed library is a LEAF, not the root of a load chain.
    --   glvnd dlopens a vendor library BY NAME, so `libGLX_nvidia.so.0` is its
    --   own load-chain root with no RPATH of ours anywhere above it -- hence the
    --   interposer. `libd3d12core.so` is dlopened by `d3d12_dri.so`, which is
    --   OUR file with OUR DT_RPATH, and DT_RPATH is searched along the load
    --   chain. So a symlink in the subos lib directory is enough: no interposer,
    --   no LD_LIBRARY_PATH.
    --
    -- WHY THE LINKS MUST BE OURS AND NOT THE HOST'S ld.so.cache
    --   WSL makes /usr/lib/wsl/lib visible to the HOST loader through
    --   /etc/ld.so.conf.d. Our processes run on our own glibc with its own
    --   hermetic ld.so.cache, which does not contain that path -- the same fact
    --   godot's recipe records ("xim's ld.so.cache is hermetic and does NOT see
    --   /lib/x86_64-linux-gnu").
    --
    -- WHEN THE HOST IS NOT WSL2
    --   install() succeeds and links nothing, config() declares nothing. That
    --   is the sentinel contract, and it is load-bearing here: this package is a
    --   dependency of `graphics`, so it is installed on EVERY machine that
    --   installs the stack. A sentinel with a side effect on a host it does not
    --   apply to would be a regression for everyone.
    --
    -- Design: xlings/.agents/docs/2026-08-07-graphics-experience-industry-survey-and-plan.md §A9
    xpm = {
        linux = {
            -- The split form, spelled out. A `deps` table with an array part
            -- makes every client before libxpkg 0.0.52 take the legacy branch:
            -- `build` is dropped and the runtime entries are copied into
            -- build_deps in its place, with nothing reporting it.
            deps = {
                runtime = {
                    -- mesa is what loads the borrowed libraries: the `d3d12`
                    -- gallium driver module lives in its payload. Without mesa
                    -- there is no consumer for anything this package links.
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
                    "xim:glibc@>=2.39",
                },
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "0.1.0" },
            -- No payload: every file this package installs is a symlink it
            -- creates from what it finds on the host. The version is the
            -- recipe's -- the Windows-side version is whatever Windows has, and
            -- pinning it here would make the package wrong on every machine but
            -- one.
            ["0.1.0"] = { },
        },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.subos")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.hostlib")

-- Where WSL mounts the Windows-side GPU userspace.
--
-- A fixed path, and legitimately so: it is not a distribution layout, it is
-- WSL's own mount point, identical on every distribution WSL supports. It is
-- still ELF-class checked via hostlib rather than trusted.
local WSL_LIBDIR = "/usr/lib/wsl/lib"

-- Is this WSL2, and does it have the D3D12 userspace?
--
-- Two questions, deliberately answered as one: a WSL2 kernel with no GPU
-- passthrough (an old Windows build, or a VM without WDDM) has /dev/dxg absent
-- or the libraries missing, and in that case there is nothing to link and the
-- correct behaviour is the same as "not WSL at all".
--
-- Probed by the LIBRARIES rather than by /proc/version containing "microsoft":
-- the kernel string says which kernel is running, and this package cares
-- whether the userspace half is reachable. A WSL2 kernel booted outside WSL
-- (people do this) would pass the string test and have nothing to link.
local function __probe_wsl_dir()
    -- hostlib asks ldconfig first, which on WSL2 knows this directory (WSL adds
    -- it via /etc/ld.so.conf.d), and falls back to the explicit path for a
    -- distribution whose cache was never built -- a minimal container image
    -- under WSL is exactly that case.
    local dir = hostlib.dir_of("libd3d12core.so", { extra_dirs = { WSL_LIBDIR } })
    if dir then return dir end
    return nil
end

-- Every Windows-side library in DIR.
--
-- The WHOLE set, not the two names that appear in a design document. Same rule
-- as the NVIDIA sentinel and for the same measured reason (R7): a hand-written
-- list is a list of what someone thought of, and the ones it misses come from
-- the host silently. `libd3d12core.so` dlopens `libdxcore.so`, which is a
-- Microsoft file with no RPATH of ours -- so it can only be found if it is in
-- the subos lib directory too.
--
-- `libcuda.so.1` and `libnvidia-ml.so.1` appear here on an NVIDIA WSL2 host.
-- They are linked as well: they are the CUDA half of the same arrangement, and
-- `libcuda-host-link` -- which is what a CUDA consumer depends on -- probes for
-- them through hostlib and therefore already finds them here or on the host.
-- Linking them costs one symlink and removes a second probe path.
local function __wsl_entries(dir)
    return hostlib.entries_with_prefix(dir, { "^lib.*%.so" })
end

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mkdir(path.join(dir, "lib"))

    local wsldir = __probe_wsl_dir()
    if not wsldir then
        -- NOT a failure, and not silent either. On a non-WSL host this is the
        -- expected outcome and the message has to say so, because this package
        -- is installed everywhere `graphics` is.
        log.info("not a WSL2 host with D3D12 userspace (%s) — nothing to link. "
                 .. "GL uses the native driver or llvmpipe.", WSL_LIBDIR)
        io.writefile(path.join(dir, ".wsl-host"), "no\n")
        return true
    end

    local names = __wsl_entries(wsldir)
    for _, name in ipairs(names) do
        system.exec(string.format([[ln -sf "%s" "%s"]],
            path.join(wsldir, name), path.join(dir, "lib", name)))
    end

    -- The glibc floor of the borrowed set, measured rather than assumed.
    --
    -- This is the line between "borrowing" and "chasing versions" -- the whole
    -- argument for taking a driver from the host rather than shipping one.
    -- NVIDIA's userspace requires at most GLIBC_2.10, which is why borrowing it
    -- is safe forever. Microsoft documents these libraries as compatible with
    -- "Ubuntu, Debian, Fedora, CentOS, SUSE and other glibc-based
    -- distributions", which implies a low floor but does not measure one.
    --
    -- So: report it. If it ever exceeds the glibc in the subos, the symptom is
    -- `version GLIBC_x.yz not found` from inside a dlopen three layers down --
    -- mcpp#352 exactly -- and this line is what makes that diagnosable.
    local floor = __glibc_floor(path.join(wsldir, "libd3d12core.so"))
    io.writefile(path.join(dir, ".wsl-host"),
                 string.format("yes\n%s\n%s\n", wsldir, floor or "unknown"))

    log.info("wsl-gl-host-link → %s (%d host libraries linked, glibc floor %s) ✓",
             wsldir, #names, floor or "unknown")
    if #names == 0 then
        log.warn("no libraries under %s — GL will fall back to llvmpipe", wsldir)
    end
    return true
end

-- The highest GLIBC_x.y version FILE requires, read from its dynamic symbols.
--
-- `readelf`/`llvm-readelf` may not exist at install time, so this greps the raw
-- bytes for the version strings. Crude and sufficient: the strings are in
-- .gnu.version_r as plain `GLIBC_2.34` text, and the question is only "what is
-- the highest one".
function __glibc_floor(file)
    local out = try {
        function()
            return os.iorun(string.format(
                [[sh -c 'strings %s 2>/dev/null | grep -o "^GLIBC_[0-9.]*" | sort -Vu | tail -1']],
                file))
        end
    }
    if not out then return nil end
    out = out:gsub("%s+$", "")
    return out ~= "" and out or nil
end

function config()
    local dir = pkginfo.install_dir()
    local tag = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    -- Nothing declared on a non-WSL host. W5 in the plan's acceptance table:
    -- this package ships to every machine that installs `graphics`, so "no
    -- effect where it does not apply" is a property to assert, not to assume.
    local state = io.readfile(path.join(dir, ".wsl-host")) or ""
    if not state:find("^yes") then return true end

    -- Into `<subos>/lib`, which is what makes the borrowed libraries reachable
    -- at all: `d3d12_dri.so` carries a DT_RPATH ending in the subos lib
    -- directory (verified on the shipped payload), and DT_RPATH is searched
    -- along the load chain -- so its dlopen of `libd3d12core.so` resolves here.
    sysroot.declare_libs(dir, "lib", tag, pkginfo.version())

    -- Tell mesa which gallium driver to use.
    --
    -- Measured upstream (microsoft/wslg#1332): mesa does not always select
    -- `d3d12` on its own under WSL, because the usual selection path goes
    -- through a DRM device and there is not one. Declared ONLY on a WSL host,
    -- which is the whole point of putting it in a sentinel: adapting to the
    -- host needs no conditional syntax in the consumer, only a package that is
    -- a no-op elsewhere.
    --
    -- `set`, not `prepend`: this is a single value, not a list. A user who
    -- exported GALLIUM_DRIVER themselves keeps it (UC-1), so
    -- `GALLIUM_DRIVER=llvmpipe` remains the escape hatch when the GPU path
    -- misbehaves -- and that escape is why forcing the value here is safe.
    if type(subos.env) == "function" then
        subos.env{ var = "GALLIUM_DRIVER", op = "set",
                   value = "d3d12", binding = tag }
    end
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
