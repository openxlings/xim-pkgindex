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
    -- whatever Neovim >= 0.10 the machine already has, detected on PATH at
    -- install time, and is configured through Neovim's own user site pack;
    -- the index's editor package (`xim:nvim`) is installed only when no
    -- Neovim answers. libs/nvim_plugin.lua (`xim.pkgindex.nvim_plugin`)
    -- holds that handling and the facts it rests on. The server the plugin
    -- drives is a hard dep and comes from this index.
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
            ["latest"] = { ref = "0.0.19" },
            ["0.0.19"] = {
                sha256 = {
                    x86_64 = "395ccb478ca4d50b94fd0164d506578252c9be47f0fc4b16cd32400c4350a19d",
                    aarch64 = "395ccb478ca4d50b94fd0164d506578252c9be47f0fc4b16cd32400c4350a19d",
                },
            },
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
            ["latest"] = { ref = "0.0.19" },
            ["0.0.19"] = {
                sha256 = {
                    aarch64 = "395ccb478ca4d50b94fd0164d506578252c9be47f0fc4b16cd32400c4350a19d",
                },
            },
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
            ["latest"] = { ref = "0.0.19" },
            ["0.0.19"] = {
                sha256 = {
                    x86_64 = "395ccb478ca4d50b94fd0164d506578252c9be47f0fc4b16cd32400c4350a19d",
                },
            },
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
import("xim.pkgindex.nvim_plugin")

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

function install()
    os.tryrm(pkginfo.install_dir())
    os.mv(path.join("mcpp-language-server-" .. pkginfo.version(), "editors", "nvim"),
        pkginfo.install_dir())
    nvim_plugin.provision()
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
    -- site pack, `pack/xim/start/mcppls`): `require('mcppls')` and
    -- `vim.lsp.enable('mcppls')` resolve, and plugin/xim-mcppls-auto.lua
    -- starts the server unless the user opted out.
    local pack_dir = nvim_plugin.copy_to_pack(pkginfo.install_dir(), "mcppls",
        path.join("lua", "mcppls", "init.lua"))
    if not pack_dir then
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
    nvim_plugin.remove_from_pack("mcppls")
    xvm.remove(package.name)
    return true
end
