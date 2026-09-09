package = {
    spec = "1",

    name = "libcuda-host-link",
    description = "Sentinel: stable symlinks to the host's NVIDIA driver user-space libraries",

    licenses = {"Apache-2.0"},  -- the package recipe; the driver libraries are NVIDIA's
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
    --   * Probe the host for each library in SONAMES below (the NVIDIA
    --     driver's user-space halves).
    --   * Install one symlink per name at
    --       <install_dir>/lib/<soname>
    --     pointing to the host file. If host has no driver, the symlink
    --     points to the canonical /usr/lib/x86_64-linux-gnu/<soname>
    --     (or the distro's equivalent), and is intentionally dangling
    --     until the user installs the driver — at which point GPU-using
    --     consumer xpkgs auto-resolve.
    --
    -- DOES NOT:
    --   * Redistribute any of them. The NVIDIA Driver EULA forbids
    --     third-party redistribution, and even if it didn't, these
    --     libraries are in strict ABI lockstep with the kernel
    --     module — versioning them as an xpkg is impossible.
    --
    -- Why a sentinel package and not just probe-in-each-consumer:
    --   * Single source of truth for "where is the host's driver" → all
    --     GPU xpkgs (ollama / future vllm / jax / cupy / ...) read from
    --     pkginfo.dep_install_dir("libcuda-host-link").."/lib/<soname>"
    --     and don't reimplement ldconfig probing each.
    --   * Reinstall once → all consumers' transitive symlinks stay
    --     valid (they link to this package's link, not directly to host).
    --   * Driver post-install self-heal: install nvidia-driver later →
    --     re-`xim install libcuda-host-link` → consumer chains auto-fix
    --     without each consumer reinstall.
    --
    -- WHY THE ANSWER IS A SET AND NOT A NAME (0.0.2).
    --
    -- 0.0.1 linked `libcuda.so.1` alone, and a consumer that farmed only
    -- what this package published inherited that as its own limit. The
    -- SYCL runtime's CUDA adapter carries `libnvidia-ml.so.1` in its
    -- DT_NEEDED as well, so on a machine whose loader consults no host
    -- directory the adapter did not load, the CUDA back end vanished, and
    -- the program aborted with no diagnosis (mcpp#596). Nothing reported
    -- it, because a back end that fails to load is reported by nothing.
    --
    -- The two libraries ship in one driver package, are covered by one
    -- EULA and move in one ABI lockstep, so every sentence above holds for
    -- both without amendment. A consumer that enumerates this directory
    -- rather than naming a file gets the next one for free.
    -- ─────────────────────────────────────────────────────────────────────

    xpm = {
        linux = {
            -- Version is the recipe version, not the driver version
            -- (drivers are owned by the host). Bump on recipe changes.
            --
            -- 0.0.1 is kept so a consumer that pinned it keeps resolving.
            --
            -- WHAT THE NEW KEY BUYS IS A REINSTALL, NOT A DIFFERENT RECIPE.
            -- There is one `install()` here and it never reads
            -- `pkginfo.version()`, so installing 0.0.1 today creates both
            -- links as well. What a version key changes is whether a machine
            -- that ALREADY holds the directory does anything: it does not, so
            -- a host installed before this change keeps a one-link sentinel
            -- until some consumer asks for a version it does not have. That
            -- is what 0.0.2 is for, and it is why the consumers that need the
            -- second soname move their pin rather than relying on this
            -- file's contents.
            ["latest"] = { ref = "0.0.2" },
            ["0.0.2"]  = { },  -- no download; install hook does everything
            ["0.0.1"]  = { },
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
-- The driver's user-space libraries this sentinel answers for.
--
-- One list, read by install() and asserted by tests/l/test_libcuda_host_link.py,
-- so "which libraries does this package promise" has one spelling. A consumer
-- that enumerates the installed directory rather than naming a file inherits
-- additions here without a change of its own.
--
-- `libnvidia-ml.so.1` is NVML, the driver's management library. It is in this
-- list because `libur_adapter_cuda.so.0` -- the SYCL runtime's CUDA back end --
-- has it in DT_NEEDED beside `libcuda.so.1`, and a consumer that farmed only
-- the first name produced an adapter that could not load (mcpp#596).
--
-- WHAT IS DELIBERATELY NOT HERE, and it is a measured absence rather than an
-- unconsidered one: `libnvidia-ptxjitcompiler.so.1`. A draft of mcpp's
-- `compat.cuda-driver` harvested it on the theory that PTX JIT would otherwise
-- fail. Measured on driver 550.144.03 -- a binary built for `compute_80`
-- alone, run with only `libcuda.so.1` reachable, JITs and produces the right
-- answer on an sm_89 device. The driver loads its own siblings through its own
-- paths, which a private loader does not interfere with.
--
-- That result is recorded HERE rather than in the consumer it was measured in,
-- because this list is what decides the set: a farm that mirrors this
-- directory inherits both the additions and the omissions, and an omission
-- whose reason lives in one consumer is an omission the next consumer
-- re-litigates.
local SONAMES = { "libcuda.so.1", "libnvidia-ml.so.1" }

local function __probe_host_lib(soname)
    return hostlib.path_of(soname)
end

-- Choose the symlink target for the "no driver yet" case.
-- The link target is a path the user's distro WILL provide once the
-- nvidia-driver package is installed, so the symlink self-heals later
-- without re-running this package's install hook.
--
-- This is the one question that cannot be probed -- there is no file yet, so
-- there is no ELF class to read -- and the distro-ID table that answers it now
-- lives in hostlib.canonical_libdir(), so layout knowledge stays in one file.
local function __canonical_path_for_distro(soname)
    return path.join(hostlib.canonical_libdir(), soname)
end

function install()
    local libdir = path.join(pkginfo.install_dir(), "lib")
    os.tryrm(pkginfo.install_dir())
    os.mkdir(libdir)

    -- One link per name, and the same treatment for every name: a probe, a
    -- canonical fallback, a link that is created whether or not its target
    -- exists yet.
    --
    -- Dangling-but-canonical is intentional: when the user later installs
    -- nvidia-driver via their distro package manager, the driver will
    -- materialize at the canonical path, and these symlinks (plus all
    -- transitive consumer symlinks pointing to them) will resolve
    -- automatically — no xpkg reinstall needed.
    local found = 0
    for _, soname in ipairs(SONAMES) do
        local host   = __probe_host_lib(soname)
        local target = host or __canonical_path_for_distro(soname)
        -- Use `ln -sf` rather than os.ln (xmake's lua has no os.ln helper);
        -- -f is harmless here since we just os.tryrm'd the parent.
        system.exec(string.format([[ln -sf "%s" "%s"]],
                                  target, path.join(libdir, soname)))
        if host then
            found = found + 1
            log.info("libcuda-host-link: %s -> %s", soname, host)
        else
            log.info("libcuda-host-link: %s -> %s (dangling)", soname, target)
        end
    end

    -- The count, not just the individual lines. A sentinel that resolved one
    -- of two names is a different machine from one that resolved neither, and
    -- reading that off a scrolled log is what "the driver is installed" was
    -- being inferred from before.
    log.info("libcuda-host-link: %d of %d resolved on this host",
             found, #SONAMES)

    if found < #SONAMES then
        log.warn("NVIDIA driver not fully detected on this host.")
        log.warn("  %d of %d libraries are dangling links", #SONAMES - found, #SONAMES)
        log.warn("  GPU-using xpkgs (ollama / vllm / ...) will fall back")
        log.warn("  to CPU until you install the NVIDIA driver via your")
        log.warn("  distro package manager — at which point the links")
        log.warn("  self-heal and GPU acceleration starts working.")
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
