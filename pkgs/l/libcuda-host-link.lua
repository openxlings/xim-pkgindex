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

-- Probe the host for libcuda.so.1.
-- Strategy:
--   1) ldconfig -p | grep libcuda.so.1 → covers properly registered drivers
--      across distros (Debian/Ubuntu, Fedora/RHEL, Arch, openSUSE).
--   2) If ldconfig misses (containers without /etc/ld.so.cache populated,
--      or NixOS-style non-FHS), check the canonical FHS paths directly.
--   3) Return nil if none found → caller decides what to do.
local function __probe_host_libcuda()
    -- Strategy 1: ldconfig cache (works on properly-registered drivers).
    -- Use try{} to swallow non-zero exits (ldconfig itself, or grep with
    -- no match). On x86_64-linux-gnu hosts the line shape is:
    --   "\tlibcuda.so.1 (libc6,x86-64) => /lib/x86_64-linux-gnu/libcuda.so.1"
    -- (filter for "x86-64" to skip the 32-bit i386 line.)
    local out = try {
        function() return os.iorun("ldconfig -p 2>/dev/null") end
    }
    if out and out ~= "" then
        for line in out:gmatch("[^\n]+") do
            if line:find("libcuda.so.1", 1, true)
               and line:find("x86-64", 1, true) then
                local p = line:match("=>%s*(/%S+)")
                if p and os.isfile(p) then return p end
            end
        end
    end
    -- Strategy 2: well-known FHS paths (containers without populated
    -- ld.so.cache, or NixOS-style non-FHS hosts where ldconfig is empty).
    for _, p in ipairs({
        "/usr/lib/x86_64-linux-gnu/libcuda.so.1",  -- Debian / Ubuntu / Mint
        "/usr/lib64/libcuda.so.1",                 -- RHEL / Fedora / openSUSE / Arch
        "/usr/lib/libcuda.so.1",                   -- Arch (older) / minimal distros
    }) do
        if os.isfile(p) then return p end
    end
    return nil
end

-- Choose the symlink target for the "no driver yet" case.
-- The link target is a path the user's distro WILL provide once the
-- nvidia-driver package is installed, so the symlink self-heals later
-- without re-running this package's install hook.
local function __canonical_path_for_distro()
    if os.isfile("/etc/os-release") then
        local content = io.readfile("/etc/os-release") or ""
        local idl = ((content:match("ID=([^\n]*)") or "") .. " " ..
                     (content:match("ID_LIKE=([^\n]*)") or "")):lower()
        idl = idl:gsub('"', '')
        if idl:find("debian") or idl:find("ubuntu") or idl:find("mint") then
            return "/usr/lib/x86_64-linux-gnu/libcuda.so.1"
        elseif idl:find("fedora") or idl:find("rhel") or idl:find("centos")
            or idl:find("opensuse") or idl:find("suse") then
            return "/usr/lib64/libcuda.so.1"
        elseif idl:find("arch") or idl:find("manjaro") then
            return "/usr/lib/libcuda.so.1"
        end
    end
    -- Default to Debian/Ubuntu layout (most common xim Linux user)
    return "/usr/lib/x86_64-linux-gnu/libcuda.so.1"
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
