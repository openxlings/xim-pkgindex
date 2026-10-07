package = {
    spec = "2",
    -- base info
    name = "mcppls-nvim",
    description = "Neovim plugin for mcppls, configured out of the box: module-aware C++20/23 completion, go-to-definition, hover, references and import highlighting through Neovim's own LSP client",

    authors = {"sunrisepeak"},
    maintainers = {"https://github.com/Sunrisepeak/mcpp-language-server/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/Sunrisepeak/mcpp-language-server",
    docs = "https://github.com/Sunrisepeak/mcpp-language-server/blob/main/editors/nvim/README.md",
    homepage = "https://github.com/Sunrisepeak/mcpp-language-server",

    -- xim pkg info
    type = "package",
    -- The plugin is pure Lua — arch-independent. Both arches are declared so
    -- the package tracks where its dependency (xim:mcppls) exists; the
    -- source archive is the same file for both, hence the identical sha256.
    archs = {"x86_64", "aarch64"},
    status = "dev", -- 0.0.x: upstream is pre-1.0, expect breaking changes
    categories = {"cpp", "language-server", "lsp", "nvim"},
    keywords = {"cpp", "c++", "modules", "lsp", "clangd", "mcpp", "nvim", "neovim", "plugin"},

    -- Neovim itself is deliberately NOT a declared dep: the plugin drives
    -- whatever Neovim >= 0.10 the machine already has — xim's, the distro's,
    -- Homebrew's, Scoop's. The config target below is Neovim's own user site
    -- pack (`:h stdpath("data")`-based), the same directory for every install
    -- source, so the configuration is unified, not per-source. install()
    -- detects `nvim` on PATH and only when it is absent asks xlings itself
    -- for the index's editor package (`xim:nvim`) — the equivalent-dep,
    -- deferred: `pkgmanager.install` reports nothing a recipe can read
    -- (cuda-nvcc.lua's warning) and the bare spelling resolves to nothing
    -- while this recipe is registered as a local overlay (how CI tests a
    -- changed package), so both spellings are tried and the outcome is
    -- re-detected and reported honestly. A distro Neovim older than 0.10 is
    -- a platform fact to warn about, not an install failure. The server the
    -- plugin drives is a hard dep and comes from this index.
    --
    -- The plugin is the `editors/nvim` directory of the mcpp-language-server
    -- source tree at the matching tag (README: "The plugin is the
    -- editors/nvim directory of this repository"). The archive's top
    -- directory is `mcpp-language-server-<version>/`, codeload's tag name.
    --
    -- GLOBAL is GitHub's tag archive (`archive/refs/tags` — the redirect
    -- target is codeload, same bytes, but the plain codeload URL's basename
    -- has no .tar.gz suffix, and the saved file's name is what xim unpacks
    -- by: measured on all three CI runners, the codeload form downloaded
    -- fine and extracted nothing, so `mv` found no tree); CN is the same
    -- bytes uploaded as a release asset of the gitcode.com/xlings-res/mcppls
    -- mirror (verified by re-download), so one sha256 serves both legs.
    xpm = {
        linux = {
            deps = { "xim:mcppls" },
            source = {
                GLOBAL = "https://github.com/Sunrisepeak/mcpp-language-server/archive/refs/tags/v${version}.tar.gz",
                CN = "https://gitcode.com/xlings-res/mcppls/releases/download/v${version}/src-${version}.tar.gz",
            },
            ["latest"] = { ref = "0.0.11" },
            ["0.0.11"] = {
                sha256 = {
                    x86_64 = "e7b6b8494e067da09227f35023f2a7378d2349ae7fed1814aeec2980c9f83797",
                    aarch64 = "e7b6b8494e067da09227f35023f2a7378d2349ae7fed1814aeec2980c9f83797",
                },
            },
        },
        macosx = {
            deps = { "xim:mcppls" },
            source = {
                GLOBAL = "https://github.com/Sunrisepeak/mcpp-language-server/archive/refs/tags/v${version}.tar.gz",
                CN = "https://gitcode.com/xlings-res/mcppls/releases/download/v${version}/src-${version}.tar.gz",
            },
            ["latest"] = { ref = "0.0.11" },
            ["0.0.11"] = {
                sha256 = {
                    aarch64 = "e7b6b8494e067da09227f35023f2a7378d2349ae7fed1814aeec2980c9f83797",
                },
            },
        },
        windows = {
            deps = { "xim:mcppls" },
            source = {
                GLOBAL = "https://github.com/Sunrisepeak/mcpp-language-server/archive/refs/tags/v${version}.tar.gz",
                CN = "https://gitcode.com/xlings-res/mcppls/releases/download/v${version}/src-${version}.tar.gz",
            },
            ["latest"] = { ref = "0.0.11" },
            ["0.0.11"] = {
                sha256 = {
                    x86_64 = "e7b6b8494e067da09227f35023f2a7378d2349ae7fed1814aeec2980c9f83797",
                },
            },
        },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.pkgmanager")
import("xim.libxpkg.xvm")

-- The plugin root files: `lua/` carries the module (require('mcppls')),
-- `lsp/` the nvim-0.11+ built-in config for vim.lsp.enable('mcppls'),
-- `plugin/xim-mcppls-auto.lua` the auto-start this package adds on top of
-- the upstream tree (see __auto_start_lua()).
function __required_files()
    local d = pkginfo.install_dir()
    return {
        path.join(d, "lua", "mcppls", "init.lua"),
        path.join(d, "lsp", "mcppls.lua"),
        path.join(d, "plugin", "xim-mcppls-auto.lua"),
        path.join(d, "README.md"),
    }
end

-- Sourced by Neovim at startup from every runtimepath plugin/ directory —
-- site pack start dirs included — so `require('mcppls').setup()` runs
-- without the user writing any init.lua line: open a C/C++ file and the
-- server attaches (completion, module-syntax highlighting, ...). setup()
-- is idempotent upstream (augroup with clear = true), so a user who ALSO
-- calls it from their own config loses nothing; anyone who wants manual
-- control sets `vim.g.mcppls_auto_start = false` in their init.lua.
function __auto_start_lua()
    return [==[
-- Added by the xim `mcppls-nvim` package: out-of-the-box auto-start.
-- Opt out in your init.lua with:  vim.g.mcppls_auto_start = false
if vim.g.mcppls_auto_start == false then
  return
end
require('mcppls').setup()

-- Completions stay on Neovim's default flow: the LSP client sets
-- 'omnifunc' on attach, so insert mode answers to CTRL-X CTRL-O — and to
-- whatever completion plugin you run. If you want the popup while typing
-- with no plugin, opt IN with:
--   vim.api.nvim_create_autocmd('LspAttach', {
--     callback = function(args)
--       if vim.lsp.completion then
--         pcall(vim.lsp.completion.enable, true, args.data.client_id,
--           args.buf, { autotrigger = true })
--       end
--     end,
--   })
]==]
end

function installed()
    -- Quiet: xim asks this before an install too, where "no" is the normal
    -- answer, not an error.
    for _, f in ipairs(__required_files()) do
        if not os.isfile(f) then
            return false
        end
    end
    return true
end

-- Neovim's user data root (`:h stdpath("data")`) + `site`, where
-- `pack/<name>/start/<plugin>` is on every Neovim's runtimepath with no
-- plugin manager involved. Only namespaced under `pack/xim/`: uninstall
-- removes exactly this one directory and touches nothing else of the
-- user's Neovim setup.
function __nvim_site_dir()
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

-- Where config() installs the plugin copy, and uninstall() removes it.
function __pack_dir()
    return path.join(__nvim_site_dir(), "pack", "xim", "start", "mcppls")
end

-- The Neovim the plugin will drive, detected at install time rather than
-- declared as a dep: whatever `nvim` is on PATH — xim's shim, a distro
-- package, Homebrew, Scoop — drives the same site-pack config. Returns the
-- parsed "x.y.z" or nil when Neovim is not runnable from PATH.
function __nvim_version()
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

function __version_at_least(v, minimum)
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
-- editor package. Both spellings, because `pkgmanager.install` reports
-- nothing a recipe can read AND the bare name resolves to nothing while
-- this recipe is a local overlay (cuda-nvcc.lua measured both); each
-- attempt is followed by a fresh probe, and the final outcome is reported
-- honestly — the plugin stays installed either way and activates the
-- moment an adequate Neovim is on PATH.
function __provision_nvim()
    local ver = __nvim_version()
    if ver then
        log.info("Neovim %s detected on PATH", ver)
        if not __version_at_least(ver, "0.10.0") then
            log.warn("Neovim %s on PATH is older than the 0.10 the plugin requires; "
                .. "upgrade it — the plugin activates automatically once you do", ver)
        end
        return ver
    end
    for _, coord in ipairs({ "xim:nvim", "nvim" }) do
        log.info("no Neovim on PATH — installing the index's editor package %s", coord)
        pcall(pkgmanager.install, coord)
        ver = __nvim_version()
        if ver then
            log.info("Neovim %s available after installing %s", ver, coord)
            return ver
        end
    end
    log.warn("Neovim is still not available on PATH; install Neovim >= 0.10 "
        .. "(any source works) and the plugin activates automatically")
    return nil
end

function install()
    os.tryrm(pkginfo.install_dir())
    os.mv(path.join("mcpp-language-server-" .. pkginfo.version(), "editors", "nvim"),
        pkginfo.install_dir())
    __provision_nvim()
    -- The out-of-the-box auto-start shim (upstream ships no plugin/ dir, so
    -- the directory and the file are entirely ours).
    os.mkdir(path.join(pkginfo.install_dir(), "plugin"))
    io.writefile(path.join(pkginfo.install_dir(), "plugin", "xim-mcppls-auto.lua"),
        __auto_start_lua())
    -- A failed extraction surfaces here, naming what did not land, rather
    -- than as a silent empty install dir behind a green install banner.
    local missing = {}
    for _, f in ipairs(__required_files()) do
        if not os.isfile(f) then
            table.insert(missing, f)
        end
    end
    if #missing > 0 then
        log.error("mcppls-nvim install incomplete, files missing:\n    "
            .. table.concat(missing, "\n    "))
        return false
    end
    return true
end

function config()
    -- Package-name placeholder node: this package ships no program of its
    -- own; the `mcppls` server it drives is registered by the mcppls package
    -- and is found by the plugin on PATH.
    xvm.add(package.name, { type = "group" })

    -- Put the plugin on Neovim's runtimepath (a copy under the user's nvim
    -- site pack, `pack/xim/start/mcppls`). This only makes `require('mcppls')`
    -- and `vim.lsp.enable('mcppls')` resolvable — it does not start the LSP
    -- anywhere until the user asks for it in their init.lua.
    local pack_dir = __pack_dir()
    -- os.cp semantics: if the target path already exists, the source lands
    -- INSIDE it (`cp -r src dst`). So create the parents, remove the empty
    -- leaf, and only then copy — pack_dir becomes the plugin root itself.
    os.tryrm(pack_dir)
    os.mkdir(pack_dir)
    os.tryrm(pack_dir)
    os.cp(pkginfo.install_dir(), pack_dir)
    if not os.isfile(path.join(pack_dir, "lua", "mcppls", "init.lua")) then
        log.error("failed to install the plugin into %s", pack_dir)
        return false
    end

    log.info("mcppls-nvim installed into: %s", pack_dir)
    log.info("auto-configured: opening a C/C++ file starts the mcppls server — "
        .. "module-syntax highlighting and go-to-definition work with no init.lua change")
    log.info("completions stay on Neovim's default flow: CTRL-X CTRL-O in insert "
        .. "mode (omnifunc is set on attach), or your own completion plugin")
    log.info("to disable the auto-start:  vim.g.mcppls_auto_start = false  (init.lua), "
        .. "then require('mcppls').setup() manually when wanted")
    return true
end

function uninstall()
    -- Only the copy this package made — never the user's own nvim config.
    os.tryrm(__pack_dir())
    xvm.remove(package.name)
    return true
end
