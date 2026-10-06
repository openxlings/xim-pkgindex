package = {
    spec = "2",
    -- base info
    name = "mcppls-nvim",
    description = "Neovim plugin for mcppls: C++20/23 named modules in Neovim (go-to-definition, hover, references, completion, import highlighting) through Neovim's own LSP client",

    authors = {"sunrisepeak"},
    maintainers = {"https://github.com/Sunrisepeak/mcpp-language-server/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/Sunrisepeak/mcpp-language-server",
    docs = "https://github.com/Sunrisepeak/mcpp-language-server/blob/main/editors/nvim/README.md",
    homepage = "https://github.com/Sunrisepeak/mcpp-language-server",

    -- xim pkg info
    type = "package",
    -- The plugin is pure Lua — arch-independent. Both arches are declared so
    -- the package tracks where its dependencies (nvim + mcppls) exist; the
    -- source archive is the same file for both, hence the identical sha256.
    archs = {"x86_64", "aarch64"},
    status = "dev", -- 0.0.x: upstream is pre-1.0, expect breaking changes
    categories = {"cpp", "language-server", "lsp", "nvim"},
    keywords = {"cpp", "c++", "modules", "lsp", "clangd", "mcpp", "nvim", "neovim", "plugin"},

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
            deps = { "xim:mcppls", "xim:nvim@>=0.10" },
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
            deps = { "xim:mcppls", "xim:nvim@>=0.10" },
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
            deps = { "xim:mcppls", "xim:nvim@>=0.10" },
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
import("xim.libxpkg.xvm")

-- The plugin root files: `lua/` carries the module (require('mcppls')),
-- `lsp/` the nvim-0.11+ built-in config for vim.lsp.enable('mcppls').
function __required_files()
    local d = pkginfo.install_dir()
    return {
        path.join(d, "lua", "mcppls", "init.lua"),
        path.join(d, "lsp", "mcppls.lua"),
        path.join(d, "README.md"),
    }
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

function install()
    os.tryrm(pkginfo.install_dir())
    os.mv(path.join("mcpp-language-server-" .. pkginfo.version(), "editors", "nvim"),
        pkginfo.install_dir())
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
    log.info("enable it in your init.lua (one line):")
    log.info("  Neovim >= 0.11:  vim.lsp.enable('mcppls')")
    log.info("  any Neovim >= 0.10:  require('mcppls').setup()")
    log.info("the mcppls server is found on PATH via xvm; see the plugin README "
        .. "for options (root_markers, semantic tokens, statusline, :McpplsStatus)")
    return true
end

function uninstall()
    -- Only the copy this package made — never the user's own nvim config.
    os.tryrm(__pack_dir())
    xvm.remove(package.name)
    return true
end
