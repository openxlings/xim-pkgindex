-- A Neovim plugin as a package: the plugin directory is copied into Neovim's
-- own user site pack, and the Neovim that loads it is detected on PATH, not
-- declared as a dep.
--
-- Loaded by package hooks via:
--     import("xim.pkgindex.nvim_plugin")
--
--     nvim_plugin.provision()                                  -- install()
--     nvim_plugin.copy_to_pack(pkginfo.install_dir(), "mcppls",
--         path.join("lua", "mcppls", "init.lua"))              -- config()
--     nvim_plugin.remove_from_pack("mcppls")                   -- uninstall()
--
-- Neovim is deliberately not a dep of such a package: the plugin drives
-- whatever Neovim >= 0.10 the machine already has -- xim's, the distro's,
-- Homebrew's, Scoop's. The copy goes to Neovim's own user site pack
-- (`:h stdpath("data")`-based), the same directory for every install source,
-- so the configuration is unified, not per-source. A distro Neovim older than
-- 0.10 is a platform fact to warn about, not an install failure.

import("xim.libxpkg.log")
import("xim.libxpkg.pkgmanager")

local nvim_plugin = {}

-- The oldest Neovim the plugins packaged on this module support.
local MINIMUM = "0.10.0"

-- Neovim's user data root (`:h stdpath("data")`) + `site`, where
-- `pack/<name>/start/<plugin>` is on every Neovim's runtimepath with no
-- plugin manager involved.
function nvim_plugin.site_dir()
    if os.host() == "windows" then
        return path.join(os.getenv("LOCALAPPDATA") or "", "nvim-data", "site")
    elseif os.host() == "macosx" then
        return path.join(os.getenv("HOME") or "", "Library", "Application Support", "nvim", "site")
    end
    local data_home = os.getenv("XDG_DATA_HOME")
    if not data_home or data_home == "" then
        data_home = path.join(os.getenv("HOME") or "", ".local", "share")
    end
    return path.join(data_home, "nvim", "site")
end

-- Where copy_to_pack() puts plugin NAME, and remove_from_pack() removes it.
-- Only namespaced under `pack/xim/`: removing it touches nothing else of the
-- user's Neovim setup.
function nvim_plugin.pack_dir(name)
    return path.join(nvim_plugin.site_dir(), "pack", "xim", "start", name)
end

-- The Neovim the plugin will drive, detected at install time rather than
-- declared as a dep: whatever `nvim` is on PATH -- xim's shim, a distro
-- package, Homebrew, Scoop -- drives the same site-pack config. Returns the
-- parsed "x.y.z" or nil when Neovim is not runnable from PATH.
function nvim_plugin.version()
    local candidates = { "nvim --version" }
    if os.host() == "windows" then
        table.insert(candidates, "nvim.exe --version")
    end
    for _, cmd in ipairs(candidates) do
        local ok, out = pcall(os.iorun, cmd)
        if ok and type(out) == "string" then
            local v = out:match("NVIM v(%d+%.%d+%.%d+)")
            if v then
                return v
            end
        end
    end
    return nil
end

-- Whether version V is MINIMUM or newer, compared numerically component by
-- component; a missing component counts as 0.
function nvim_plugin.version_at_least(v, minimum)
    local vi, mi = {}, {}
    for n in v:gmatch("%d+") do vi[#vi + 1] = tonumber(n) end
    for n in minimum:gmatch("%d+") do mi[#mi + 1] = tonumber(n) end
    for i = 1, math.max(#vi, #mi) do
        local a, b = vi[i] or 0, mi[i] or 0
        if a ~= b then
            return a > b
        end
    end
    return true
end

-- Make sure some Neovim >= 0.10 is available: use the machine's own first,
-- and only when there is none on PATH ask xlings itself for the index's
-- editor package (`xim:nvim`) -- the equivalent dep, deferred. Both
-- spellings, because `pkgmanager.install` reports nothing a recipe can read
-- AND the bare name resolves to nothing while the calling recipe is
-- registered as a local overlay, how CI tests a changed package (cuda-nvcc.lua
-- measured both); each attempt is followed by a fresh probe, and the final
-- outcome is reported honestly -- the plugin stays installed either way and
-- activates the moment an adequate Neovim is on PATH. Returns the version
-- found or nil; it never fails the install.
function nvim_plugin.provision()
    local ver = nvim_plugin.version()
    if ver then
        log.info("Neovim %s detected on PATH", ver)
        if not nvim_plugin.version_at_least(ver, MINIMUM) then
            log.warn("Neovim %s on PATH is older than the 0.10 the plugin requires; "
                .. "upgrade it — the plugin activates automatically once you do", ver)
        end
        return ver
    end
    for _, coord in ipairs({ "xim:nvim", "nvim" }) do
        log.info("no Neovim on PATH — installing the index's editor package %s", coord)
        pcall(pkgmanager.install, coord)
        ver = nvim_plugin.version()
        if ver then
            log.info("Neovim %s available after installing %s", ver, coord)
            return ver
        end
    end
    log.warn("Neovim is still not available on PATH; install Neovim >= 0.10 "
        .. "(any source works) and the plugin activates automatically")
    return nil
end

-- Copy the plugin at INSTALL_DIR to pack_dir(NAME), which puts it on
-- Neovim's runtimepath. LANDED is a file relative to the plugin root whose
-- presence proves the copy. Returns the pack dir, or nil after logging that
-- the copy failed.
function nvim_plugin.copy_to_pack(install_dir, name, landed)
    local pack_dir = nvim_plugin.pack_dir(name)
    -- os.cp semantics: if the target path already exists, the source lands
    -- INSIDE it (`cp -r src dst`). So create the parents, remove the empty
    -- leaf, and only then copy — pack_dir becomes the plugin root itself.
    os.tryrm(pack_dir)
    os.mkdir(pack_dir)
    os.tryrm(pack_dir)
    os.cp(install_dir, pack_dir)
    if not os.isfile(path.join(pack_dir, landed)) then
        log.error("failed to install the plugin into %s", pack_dir)
        return nil
    end
    return pack_dir
end

-- Remove the copy copy_to_pack() made: only that directory, never the user's
-- own Neovim config.
function nvim_plugin.remove_from_pack(name)
    os.tryrm(nvim_plugin.pack_dir(name))
    return true
end

return nvim_plugin
