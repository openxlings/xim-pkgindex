package = {
    spec = "1",

    name = "falkon",
    namespace = "luban",
    description = "Falkon: KDE's web browser on QtWebEngine -- the browser every Luban desktop carries",

    homepage = "https://www.falkon.org",
    repo = "https://invent.kde.org/network/falkon",
    licenses = {"GPL-3.0-or-later", "LGPL-3.0-only"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"browser", "web", "luban", "qt"},
    keywords = {"falkon", "browser", "web", "qtwebengine", "luban"},

    -- The browser of the Luban desktops (xlings design 2026-10-20 §20.2,
    -- G27): a Qt one, on the runtime the Qt desktops already carry, the
    -- browser KDE makes; what LXQt suggests too. Every desktop edition brings
    -- it, so a system with a desktop opens a page.
    --
    -- Form: a bundle on luban:qt-runtime, as luban:lxqt is (tools/res/build.sh
    -- falkon): Alpine 3.24's Falkon and QtWebEngine, the libraries beyond the
    -- runtime's and the musl loader private in libexec/falkon, QtWebEngine's
    -- resources and locales in share/qt6 (libexec/falkon/env names them).
    -- Its programs run as themselves: config() names this tree's loader and
    -- the library directories in them, where they are installed. Without a
    -- GPU it composes in software; Chromium's sandbox is off (it needs user
    -- namespaces a Luban sandbox does not nest; the system is the boundary).
    programs = {"falkon"},
    xvm_enable = true,

    xpm = {
        linux = {
            deps = { "luban:qt-runtime@6.11.1-r2", "xim:luban-fonts", "xim:patchelf" },
            ["latest"] = { ref = "26.04.2-r1" },
            -- r1: ICU's data carried (Qt's ICU found none: pages and its
            -- settings failed), the GPU used when the system has a render
            -- node, and what it says when there is no desktop (xlings
            -- design 2026-10-20 WuXian §14, §7.6). The same Falkon.
            ["26.04.2-r1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "47ae69741b86ab9b155c345123b9b655ac7f644d6e3e8d8fbe60273efa2bc875",
                    aarch64 = "1cba47c816bb70a206cae32df2cc2ee71c6bb918771dd317ddb1b7f52e677d67",
                },
            },
            ["26.04.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "a66afc92e3e592159927adbb974b22819236734e48fed653648b392d54dead11",
                    aarch64 = "7d83a3dae32a808fa6c9bd24c0ad6b9adbcdfe33be8101d92d969887566da4f8",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.elfpatch")
import("xim.libxpkg.log")
import("xim.libxpkg.fs")
import("xim.pkgindex.luban_component")

local RUNTIME = "6.11.1-r2"

function install()
    return luban_component.install({ "bin/falkon", "libexec/falkon/bin/falkon", "libexec/falkon/bin/QtWebEngineProcess",
                                     "libexec/falkon/env" })
end

function config()
    local dir = pkginfo.install_dir()
    local runtime = pkginfo.dep_install_dir("luban:qt-runtime", RUNTIME)
    if not runtime then
        log.error("luban:falkon: luban:qt-runtime %s is not installed", RUNTIME)
        return false
    end
    local f = io.open(path.join(dir, "libexec", "falkon", "qt-runtime"), "w")
    if not f then return false end
    f:write(runtime)
    f:close()
    local lib = path.join(dir, "libexec", "falkon", "lib")
    local loaders = {}
    for _, file in ipairs(fs.files(lib) or {}) do
        if path.filename(file):match("^ld%-musl%-.+%.so%.1$") then table.insert(loaders, file) end
    end
    if #loaders ~= 1 then
        log.error("luban:falkon: no musl loader in %s", lib)
        return false
    end
    local bin = path.join(dir, "libexec", "falkon", "bin")
    local opts = { include_shared_libs = false, shrink = false }
    local set = elfpatch.set_interpreter(bin, loaders[1], opts)
    local paths = elfpatch.set_rpath(bin, lib .. ":" .. path.join(runtime, "libexec", "qt-runtime", "lib"), opts)
    if set.failed > 0 or set.patched == 0 or (paths.failed or 0) > 0 then
        log.error("luban:falkon: its programs could not be pointed at their loader (%d of %d)", set.failed, set.scanned)
        return false
    end
    return luban_component.config(package.programs, { "share/applications", "share/icons", "share/metainfo" })
end

function uninstall()
    return luban_component.uninstall(package.programs)
end
