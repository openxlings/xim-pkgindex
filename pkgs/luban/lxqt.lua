package = {
    spec = "1",

    name = "lxqt",
    namespace = "luban",
    description = "The LXQt desktop: a panel, a desktop and file manager, a runner and settings, on labwc -- traditional and light",

    homepage = "https://lxqt-project.org",
    repo = "https://github.com/lxqt",
    licenses = {"LGPL-2.1-or-later", "GPL-2.0-or-later"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    -- luban-desktop: offered where a desktop is chosen (xlings: 2026-10-18
    -- Luban OS distribution design §6.4).
    categories = {"desktop", "wayland", "luban", "luban-desktop", "qt"},
    keywords = {"lxqt", "qt", "wayland", "desktop", "luban", "labwc", "pcmanfm-qt"},

    -- What Luban shows of it (xlings design 2026-10-19 §5.4; xpkg spec
    -- "extensions"): T3.
    extensions = {
        luban = {
            tier = 3,
            title = { en = "LXQt", zh = "LXQt" },
            summary = { en = "Traditional: a panel, a desktop, a file manager and settings",
                        zh = "传统桌面：面板、桌面、文件管理器和设置" },
        },
    },

    -- The T3 desktop (design §7): LXQt 2.4 on Wayland -- its session on
    -- luban:labwc as upstream's lxqt-wayland-session starts it (`labwc -S
    -- lxqt-session`, on a D-Bus session bus of its own), its panel, desktop
    -- and file manager (pcmanfm-qt), runner, notifications and settings, the
    -- breeze icons. The session is share/wayland-sessions/lxqt.desktop
    -- (X-Luban-Shell=own); its defaults are LXQt's own (share/lxqt, and
    -- etc/xdg read after the system's and the user's). The terminal is the
    -- default one (luban:foot here), found through xdg-terminal-exec.
    --
    -- Form: a bundle on a runtime (design §4.6, §13.5) -- Alpine 3.24's LXQt
    -- and the libraries it needs beyond luban:qt-runtime's, the musl loader
    -- private in libexec/lxqt (tools/res/build.sh lxqt). Its programs run as
    -- themselves: config() names this tree's loader and the library
    -- directories (its own, the runtime's) in them, where they are installed
    -- -- a Qt program reads its own path, which a loader run on it would take
    -- (LXQt's panel then takes no theme). lxqt-panel's plugins are in
    -- lib/lxqt-panel, where a Luban system's /usr/lib has them: LXQt is a
    -- desktop of a Luban system.
    programs = {"luban-lxqt", "lxqt-session", "lxqt-panel", "lxqt-runner", "lxqt-config", "lxqt-config-appearance",
                "lxqt-config-session", "lxqt-config-input", "lxqt-config-monitor", "lxqt-notificationd", "lxqt-about",
                "lxqt-leave", "pcmanfm-qt", "qterminal"},
    xvm_enable = true,

    xpm = {
        linux = {
            -- luban:falkon: the browser every Luban desktop carries (xlings design 2026-10-20 §20.2).
            deps = { "luban:qt-runtime@6.11.1-r2", "luban:labwc", "luban:foot", "luban:falkon", "xim:luban-fonts",
                     "xim:xkeyboard-config", "xim:patchelf" },
            ["latest"] = { ref = "2.4.0-r4" },
            -- r4: qterminal (the desktop's own terminal, which its menus name),
            -- Home and Trash on the desktop, a quick launch (xlings design
            -- 2026-10-20 §20, G24-G26).
            ["2.4.0-r4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "3a3c509ff9ff26ed624b5eba0b4d3d48da6d5fcc29bb7843a893c8c52ed7be29",
                    aarch64 = "9219782ff54798932943f290f11c339c09eb638749fb9533decc8c15f1222d56",
                },
            },
            ["2.4.0-r3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "9eb90133861ecbf1e1fadfd259f7747a56970dca4c68770c9c553e864d9cee70",
                    aarch64 = "0a6bc69cd1e0a0702c4c544814fbac324f01b41e350267009f4e65039db63c0d",
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
    return luban_component.install({ "bin/luban-lxqt", "libexec/lxqt/bin/lxqt-session", "share/wayland-sessions/lxqt.desktop" })
end

function config()
    local dir = pkginfo.install_dir()
    local runtime = pkginfo.dep_install_dir("luban:qt-runtime", RUNTIME)
    if not runtime then
        log.error("luban:lxqt: luban:qt-runtime %s is not installed", RUNTIME)
        return false
    end
    -- Where the runtime is: its plugins and QML, for the programs' wrappers.
    local f = io.open(path.join(dir, "libexec", "lxqt", "qt-runtime"), "w")
    if not f then return false end
    f:write(runtime)
    f:close()
    -- Its programs run as themselves, by this tree's loader, on its libraries and the runtime's.
    local lib = path.join(dir, "libexec", "lxqt", "lib")
    local loaders = {}
    for _, f in ipairs(fs.files(lib) or {}) do
        if path.filename(f):match("^ld%-musl%-.+%.so%.1$") then table.insert(loaders, f) end
    end
    if #loaders ~= 1 then
        log.error("luban:lxqt: no musl loader in %s", lib)
        return false
    end
    local bin = path.join(dir, "libexec", "lxqt", "bin")
    -- Every directory kept: what they dlopen (Qt's plugins, the panel's)
    -- finds its libraries through the program's.
    local opts = { include_shared_libs = false, shrink = false }
    local set = elfpatch.set_interpreter(bin, loaders[1], opts)
    local paths = elfpatch.set_rpath(bin, lib .. ":" .. path.join(runtime, "libexec", "qt-runtime", "lib"), opts)
    if set.failed > 0 or set.patched == 0 or (paths.failed or 0) > 0 then
        log.error("luban:lxqt: its programs could not be pointed at their loader (%d of %d)", set.failed, set.scanned)
        return false
    end
    return luban_component.config(package.programs, { "share/wayland-sessions", "share/luban/checks.d" })
end

function uninstall()
    return luban_component.uninstall(package.programs)
end
