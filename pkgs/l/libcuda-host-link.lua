package = {
    spec = "1",

    name = "libcuda-host-link",
    description = "Sentinel: stable symlink to host's libcuda.so.1 (NVIDIA driver userspace lib)",

    licenses = {"Apache-2.0"},  -- the package recipe; libcuda.so.1 itself is NVIDIA's
    repo = "https://github.com/openxlings/xim-pkgindex",

    -- xim pkg info
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"runtime", "lib", "gpu", "nvidia"},
    keywords = {"cuda", "nvidia", "driver", "host-link", "sentinel"},

    -- ─────────────────────────────────────────────────────────────────────
    -- What this package does (and what it does NOT do)
    --
    -- DOES:
    --   * Probe the host for an existing `libcuda.so.1`
    --     (NVIDIA driver userspace lib).
    --   * Install a single symlink at
    --       <install_dir>/lib/libcuda.so.1
    --     pointing to the host file. If host has no driver, the symlink
    --     points to the canonical /usr/lib/x86_64-linux-gnu/libcuda.so.1
    --     (or the distro's equivalent), and is intentionally dangling
    --     until the user installs the driver — at which point GPU-using
    --     consumer xpkgs auto-resolve.
    --
    -- DOES NOT:
    --   * Redistribute libcuda.so.1. The NVIDIA Driver EULA forbids
    --     third-party redistribution, and even if it didn't, the
    --     userspace lib is in strict ABI lockstep with the kernel
    --     module — versioning it as an xpkg is impossible.
    --
    -- Why a sentinel package and not just probe-in-each-consumer:
    --   * Single source of truth for "where is host libcuda" → all GPU
    --     xpkgs (ollama / future vllm / jax / cupy / ...) read from
    --     pkginfo.dep_install_dir("libcuda-host-link").."/lib/libcuda.so.1"
    --     and don't reimplement ldconfig probing each.
    --   * Reinstall once → all consumers' transitive symlinks stay
    --     valid (they link to this package's link, not directly to host).
    --   * Driver post-install self-heal: install nvidia-driver later →
    --     re-`xim install libcuda-host-link` → consumer chains auto-fix
    --     without each consumer reinstall.
    -- ─────────────────────────────────────────────────────────────────────

    xpm = {
        linux = {
            -- Version is the recipe version, not the driver version
            -- (drivers are owned by the host). Bump on recipe changes.
            ["latest"] = { ref = "0.0.1" },
            ["0.0.1"]  = { },  -- no download; install hook does everything
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")
import("xim.libxpkg.system")
import("xim.pkgindex.hostlib")

-- Probe the host for libcuda.so.1.
--
-- The probe lives in `hostlib` now. It was written here first -- this package
-- is the original sentinel -- and it was then copied into
-- `nvidia-gl-host-link`, adapted (wrongly) into mcpp's `compat.glx-runtime`,
-- and adapted again into `godot`. Four answers to one question, which is the
-- shape hostlib exists to collapse.
--
-- What is NEW relative to what was here: the fallback paths are ELF-class
-- checked. `/usr/lib` is the 32-BIT directory on Fedora/RHEL/SUSE, and the
-- list below reached it third -- so on a biarch host with a 32-bit CUDA stub
-- installed, this returned a 32-bit libcuda and the failure appeared at
-- dlopen as `wrong ELF class: ELFCLASS32`, three layers from here. That is
-- mcpp#352, in the package the whole pattern came from.
local function __probe_host_libcuda()
    return hostlib.path_of("libcuda.so.1")
end

-- Choose the symlink target for the "no driver yet" case.
-- The link target is a path the user's distro WILL provide once the
-- nvidia-driver package is installed, so the symlink self-heals later
-- without re-running this package's install hook.
--
-- This is the one question that cannot be probed -- there is no file yet, so
-- there is no ELF class to read -- and the distro-ID table that answers it now
-- lives in hostlib.canonical_libdir(), so layout knowledge stays in one file.
local function __canonical_path_for_distro()
    return path.join(hostlib.canonical_libdir(), "libcuda.so.1")
end

function install()
    local host_libcuda = __probe_host_libcuda()
    local target       = host_libcuda or __canonical_path_for_distro()

    -- Always create the symlink, even when the target doesn't exist yet.
    -- Dangling-but-canonical is intentional: when the user later installs
    -- nvidia-driver via their distro package manager, the driver will
    -- materialize at the canonical path, and this symlink (plus all
    -- transitive consumer symlinks pointing to it) will resolve
    -- automatically — no xpkg reinstall needed.
    local link = path.join(pkginfo.install_dir(), "lib", "libcuda.so.1")
    os.tryrm(pkginfo.install_dir())
    os.mkdir(path.directory(link))
    -- Use `ln -sf` rather than os.ln (xmake's lua has no os.ln helper);
    -- -f is harmless here since we just os.tryrm'd the parent.
    system.exec(string.format([[ln -sf "%s" "%s"]], target, link))

    if host_libcuda then
        log.info("libcuda-host-link → %s ✓", host_libcuda)
    else
        log.warn("NVIDIA driver not detected on this host.")
        log.warn("  symlink target: %s (currently dangling)", target)
        log.warn("  GPU-using xpkgs (ollama / vllm / ...) will fall back")
        log.warn("  to CPU until you install the NVIDIA driver via your")
        log.warn("  distro package manager — at which point the link")
        log.warn("  self-heals and GPU acceleration starts working.")
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
