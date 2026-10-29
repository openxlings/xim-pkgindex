package = {
    spec = "2",
    -- base info
    name = "mcpp-ide-nvim",
    description = "Neovim plugin for mcpp projects over the mcpp-ide backend, set up at Neovim's start: builds, tests, cleanups and packs streamed into a buffer, the program in a terminal, mcpp's diagnostics, targets, toolchains, libraries, the build cache and the graphs through :Mcpp",

    authors = {"mcpp-community"},
    maintainers = {"https://github.com/mcpp-community/mcpp-ide/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/mcpp-community/mcpp-ide",
    docs = "https://github.com/mcpp-community/mcpp-ide/blob/main/mide-plugins/nvim/README.md",
    homepage = "https://github.com/mcpp-community/mcpp-ide",

    -- xim pkg info
    type = "package",
    -- The plugin is pure Lua — arch-independent. The systems and arches
    -- declared are where its dependency (xim:mcpp-ide) runs: Linux on both,
    -- macOS on aarch64, Windows on x86_64, as okrun; the source archive is
    -- the same file for all of them, hence the identical sha256.
    archs = {"aarch64", "x86_64"},
    status = "dev", -- 0.x
    categories = {"cpp", "ide", "mcpp", "nvim"},
    keywords = {"cpp", "c++", "modules", "mcpp", "ide", "nvim", "neovim", "plugin"},

    -- Neovim itself is deliberately NOT a declared dep, as for mcppls-nvim:
    -- the plugin drives whatever Neovim >= 0.10 the machine already has,
    -- detected on PATH at install time, and is configured through Neovim's
    -- own user site pack; the index's editor package (`xim:nvim`) is
    -- installed only when no Neovim answers. libs/nvim_plugin.lua
    -- (`xim.pkgindex.nvim_plugin`) holds that handling and the facts it
    -- rests on. The backend the plugin drives, `mcpp-ide` on PATH, is a hard
    -- dep and comes from this index. mcppls-nvim is not a dep: the plugin
    -- registers no language service, and C++ files are mcppls's, through
    -- that sibling package.
    --
    -- The plugin is the `mide-plugins/nvim` directory of the mcpp-ide source
    -- tree at the matching tag (README: "mcpp-nvim, this directory
    -- (`mide-plugins/nvim` of mcpp-ide); its version is mcpp-ide's"). The
    -- archive's top directory is `mcpp-ide-<version>/`, codeload's tag name.
    --
    -- GLOBAL is GitHub's tag archive (`archive/refs/tags`: the saved file's
    -- name is what xim unpacks by, and the basename of the plain codeload
    -- URL has no .tar.gz suffix, as mcppls-nvim.lua records); CN is the same
    -- bytes, uploaded as the release asset src-<version>.tar.gz of the
    -- gitcode.com/xlings-res/mcpp-ide mirror, so one sha256 serves both legs.
    xpm = {
        linux = {
            deps = { "xim:mcpp-ide" },
            source = {
                GLOBAL = "https://github.com/mcpp-community/mcpp-ide/archive/refs/tags/v${version}.tar.gz",
                CN = "https://gitcode.com/xlings-res/mcpp-ide/releases/download/v${version}/src-${version}.tar.gz",
            },
            ["latest"] = { ref = "0.1.1" },
            ["0.1.1"] = {
                sha256 = {
                    x86_64 = "96529fd063cbb586d6c09c5830a84d74fbffedf37526481f2a6ea8b60faf8d82",
                    aarch64 = "96529fd063cbb586d6c09c5830a84d74fbffedf37526481f2a6ea8b60faf8d82",
                },
            },
        },
        macosx = {
            deps = { "xim:mcpp-ide" },
            source = {
                GLOBAL = "https://github.com/mcpp-community/mcpp-ide/archive/refs/tags/v${version}.tar.gz",
                CN = "https://gitcode.com/xlings-res/mcpp-ide/releases/download/v${version}/src-${version}.tar.gz",
            },
            ["latest"] = { ref = "0.1.1" },
            ["0.1.1"] = {
                sha256 = {
                    aarch64 = "96529fd063cbb586d6c09c5830a84d74fbffedf37526481f2a6ea8b60faf8d82",
                },
            },
        },
        windows = {
            deps = { "xim:mcpp-ide" },
            source = {
                GLOBAL = "https://github.com/mcpp-community/mcpp-ide/archive/refs/tags/v${version}.tar.gz",
                CN = "https://gitcode.com/xlings-res/mcpp-ide/releases/download/v${version}/src-${version}.tar.gz",
            },
            ["latest"] = { ref = "0.1.1" },
            ["0.1.1"] = {
                sha256 = {
                    x86_64 = "96529fd063cbb586d6c09c5830a84d74fbffedf37526481f2a6ea8b60faf8d82",
                },
            },
        },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.nvim_plugin")

-- The plugin root files: `lua/mcpp/` carries the module (require('mcpp'))
-- and the session that starts the backend, `plugin/xim-mcpp-auto.lua` the
-- start this package adds on top of the upstream tree (see
-- __auto_start_lua()).
function __required_files()
    local d = pkginfo.install_dir()
    return {
        path.join(d, "lua", "mcpp", "init.lua"),
        path.join(d, "lua", "mcpp", "session.lua"),
        path.join(d, "plugin", "xim-mcpp-auto.lua"),
        path.join(d, "README.md"),
    }
end

-- Sourced by Neovim at startup from every runtimepath plugin/ directory —
-- site pack start dirs included — so `require('mcpp').setup()` runs without
-- the user writing any init.lua line: open a file of an mcpp project and the
-- backend starts; `:Mcpp` offers its commands. setup() configures the
-- session with the options it is given, so a second call without options
-- would replace the user's: init.lua runs before plugin/ files are sourced
-- (`:h startup`), and a module it has loaded is left as it set it up.
-- Anyone who wants manual control sets `vim.g.mcpp_auto_start = false` in
-- their init.lua.
function __auto_start_lua()
    return [==[
-- Added by the xim `mcpp-ide-nvim` package: mcpp in every project with no init.lua line.
-- Opt out in your init.lua with:  vim.g.mcpp_auto_start = false
-- A setup() of your own keeps its options: init.lua runs before this file, and a module it
-- already loaded is left as it set it up.
if vim.g.mcpp_auto_start == false or package.loaded['mcpp'] then
  return
end
require('mcpp').setup()
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
    os.mv(path.join("mcpp-ide-" .. pkginfo.version(), "mide-plugins", "nvim"),
        pkginfo.install_dir())
    nvim_plugin.provision()
    -- The start shim (upstream ships no plugin/ dir, so the directory and
    -- the file are entirely ours).
    os.mkdir(path.join(pkginfo.install_dir(), "plugin"))
    io.writefile(path.join(pkginfo.install_dir(), "plugin", "xim-mcpp-auto.lua"),
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
        log.error("mcpp-ide-nvim install incomplete, files missing:\n    "
            .. table.concat(missing, "\n    "))
        return false
    end
    return true
end

function config()
    -- Package-name placeholder node: this package ships no program of its
    -- own; the `mcpp-ide` backend it drives is registered by the mcpp-ide
    -- package and is found by the plugin on PATH.
    xvm.add(package.name, { type = "group" })

    -- Put the plugin on Neovim's runtimepath (a copy under the user's nvim
    -- site pack, `pack/xim/start/mcpp`): `require('mcpp')` resolves, and
    -- plugin/xim-mcpp-auto.lua sets it up unless the user opted out.
    local pack_dir = nvim_plugin.copy_to_pack(pkginfo.install_dir(), "mcpp",
        path.join("lua", "mcpp", "init.lua"))
    if not pack_dir then
        return false
    end

    log.info("mcpp-ide-nvim installed into: %s", pack_dir)
    log.info("auto-configured: opening a file of an mcpp project starts the mcpp-ide "
        .. "backend, and :Mcpp offers its commands — no init.lua change")
    log.info("to disable the auto-start:  vim.g.mcpp_auto_start = false  (init.lua), "
        .. "then require('mcpp').setup() manually when wanted")
    return true
end

function uninstall()
    -- Only the copy this package made — never the user's own nvim config.
    nvim_plugin.remove_from_pack("mcpp")
    xvm.remove(package.name)
    return true
end
