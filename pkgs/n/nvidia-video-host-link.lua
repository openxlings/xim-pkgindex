package = {
    spec = "1",

    name = "nvidia-video-host-link",
    description = "Sentinel: stable symlinks to the host's NVIDIA video-codec user-space libraries",

    licenses = {"Apache-2.0"},  -- the package recipe; the driver libraries are NVIDIA's
    repo = "https://github.com/openxlings/xim-pkgindex",

    -- xim pkg info
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"runtime", "lib", "gpu", "nvidia"},
    keywords = {"nvenc", "nvdec", "nvcuvid", "nvidia", "driver", "host-link", "sentinel"},

    -- ─────────────────────────────────────────────────────────────────────
    -- WHY THIS IS ITS OWN PACKAGE AND NOT TWO MORE NAMES IN
    -- `libcuda-host-link`.
    --
    -- A host-link package is the ecosystem's answer to one question: "where is
    -- the host's copy of a library that cannot be redistributed". There are
    -- three of them already -- `libcuda-host-link` for the compute driver,
    -- `nvidia-gl-host-link` for the GL/EGL vendor stack, `wsl-gl-host-link` for
    -- the WSL variant -- and each one answers for a DIFFERENT NEED, so a
    -- consumer declares the reach it actually has instead of inheriting three.
    --
    -- The video codec user-space is a fourth need. `libnvcuvid.so.1` is what
    -- NVDEC is reached through, and it is what `libnvidia-encode.so.1` and
    -- `libnvidia-opticalflow.so.1` have in `DT_NEEDED`. Nothing about compute
    -- or graphics requires it, and nothing that requires it needs the compute
    -- driver's management library. Folding it into `libcuda-host-link` would
    -- make every CUDA consumer carry a codec reach it never uses, which is the
    -- opposite of holding the host surface to what is asked for.
    --
    -- DOES:
    --   * Probe the host for each library in SONAMES below.
    --   * Install one symlink per name at `<install_dir>/lib/<soname>`. On a
    --     machine with no driver the link points at the canonical distro path
    --     and is deliberately dangling until the driver is installed, at which
    --     point it and every consumer link pointing through it resolve.
    --
    -- DOES NOT:
    --   * Redistribute any of them. The NVIDIA Driver EULA forbids third-party
    --     redistribution, and these libraries are in ABI lockstep with the
    --     kernel module, so versioning them as an xpkg is not possible either.
    --
    -- HOW A CONSUMER USES IT. It declares this package and reads
    -- `pkginfo.dep_install_dir("nvidia-video-host-link").."/lib"`, or -- better
    -- -- enumerates that directory. mcpp's `compat.opencl-runtime` and
    -- `compat.vulkan-runtime` take the second route: their farms find the
    -- soname in an installed payload and never reach into /usr/lib themselves.
    -- That is the property this package exists to give them: the farm has one
    -- rule for the host, and the rule is "declare the host-link package that
    -- owns it".
    -- ─────────────────────────────────────────────────────────────────────

    xpm = {
        linux = {
            -- The version is the recipe's, not the driver's: the driver belongs
            -- to the host. A new key buys a REINSTALL on machines that already
            -- hold the directory, which is the only thing a key changes here --
            -- `install()` never reads `pkginfo.version()`.
            ["latest"] = { ref = "0.0.1" },
            ["0.0.1"]  = { },  -- no download; the install hook does everything
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")
import("xim.libxpkg.system")
import("xim.pkgindex.hostlib")

-- The video-codec user-space libraries this sentinel answers for.
--
-- ONE LIST, so "which libraries does this package promise" has one spelling,
-- and a consumer that enumerates the installed directory inherits an addition
-- here without a change of its own. `libcuda-host-link` carries the same shape
-- and the same reason.
--
-- `libnvcuvid.so.1` is the NVDEC entry point. It is here because
-- `libnvidia-encode.so.1` and `libnvidia-opticalflow.so.1` name it in
-- `DT_NEEDED`, and a farm that carried those two without it published two
-- libraries that could not load -- measured by mcpp's dlopen-surface check on
-- driver 550.144.03, where both appeared as findings against
-- `compat:opencl-runtime` and `compat:vulkan-runtime`.
--
-- WHAT IS DELIBERATELY NOT HERE. `libnvidia-encode.so.1` and
-- `libnvidia-opticalflow.so.1` themselves: they are already reached by the
-- vendor pattern those two farms match, and adding them here would be a second
-- route to the same files -- the failure `compat.glx-runtime` records for the
-- GL vendor names, where two routes disagree the day the driver is upgraded
-- underneath. This package answers for what those files NEED and not for the
-- files themselves.
local SONAMES = { "libnvcuvid.so.1" }

local function __probe_host_lib(soname)
    return hostlib.path_of(soname)
end

-- The "no driver yet" target. It cannot be probed -- there is no file, so there
-- is no ELF class to read -- and the distro layout table that answers it lives
-- in `hostlib.canonical_libdir()` so that knowledge stays in one file.
local function __canonical_path_for_distro(soname)
    return path.join(hostlib.canonical_libdir(), soname)
end

function install()
    local libdir = path.join(pkginfo.install_dir(), "lib")
    os.tryrm(pkginfo.install_dir())
    os.mkdir(libdir)

    -- One link per name, and the same treatment for every name: a probe, a
    -- canonical fallback, and a link created whether or not its target exists
    -- yet. Dangling-but-canonical is intentional and self-heals when the distro
    -- driver package materialises the file.
    local found = 0
    for _, soname in ipairs(SONAMES) do
        local host   = __probe_host_lib(soname)
        local target = host or __canonical_path_for_distro(soname)
        -- `ln -sf` rather than os.ln: xmake's lua has no os.ln helper, and -f
        -- is harmless directly after the os.tryrm above.
        system.exec(string.format([[ln -sf "%s" "%s"]],
                                  target, path.join(libdir, soname)))
        if host then
            found = found + 1
            log.info("nvidia-video-host-link: %s -> %s", soname, host)
        else
            log.info("nvidia-video-host-link: %s -> %s (dangling)", soname, target)
        end
    end

    -- The count, not only the individual lines. A sentinel that resolved some
    -- of its names is a different machine from one that resolved none, and that
    -- difference should not have to be read off a scrolled log.
    log.info("nvidia-video-host-link: %d of %d resolved on this host",
             found, #SONAMES)

    if found < #SONAMES then
        log.warn("NVIDIA video-codec user-space not detected on this host.")
        log.warn("  %d of %d libraries are dangling links", #SONAMES - found, #SONAMES)
        log.warn("  NVDEC/NVENC back ends stay unreachable until the driver is")
        log.warn("  installed through the distro package manager, at which")
        log.warn("  point these links self-heal.")
    end

    return true
end

function config()
    xvm.add(package.name)
    return true
end

function uninstall()
    return true
end
