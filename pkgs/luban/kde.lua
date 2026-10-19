package = {
    spec = "1",

    name = "kde",
    namespace = "luban",
    description = "KDE Plasma: the complete desktop -- Plasma, KWin, Dolphin, Konsole, System Settings (preview)",

    homepage = "https://kde.org/plasma-desktop",
    repo = "https://invent.kde.org/plasma",
    licenses = {"GPL-2.0-or-later", "LGPL-2.1-or-later"},

    type = "package",
    -- x86_64: on aarch64 Plasma's shell crashes on llvmpipe in the factory's
    -- headless session (a later build).
    archs = {"x86_64"},
    status = "preview",
    -- luban-desktop: offered where a desktop is chosen (xlings: 2026-10-18
    -- Luban OS distribution design §6.4).
    categories = {"desktop", "wayland", "luban", "luban-desktop", "qt", "kde"},
    keywords = {"kde", "plasma", "kwin", "qt", "wayland", "desktop", "luban", "dolphin", "konsole"},

    -- What Luban shows of it (xlings design 2026-10-19 §5.4; xpkg spec
    -- "extensions"): T4, better with the host's GPU.
    extensions = {
        luban = {
            tier = 4,
            gpu = "better",
            title = { en = "KDE Plasma", zh = "KDE Plasma" },
            summary = { en = "The complete desktop: Plasma, Dolphin, Konsole, System Settings",
                        zh = "完整桌面：Plasma、Dolphin、Konsole、系统设置" },
        },
    },

    -- The T4 desktop (design §7, §13.3): KDE Plasma 6.6 -- KWin, Plasma's
    -- shell, Dolphin, Konsole, System Settings -- with KWin a window of
    -- luban:labwc filling its output, the compositor the Luban OS window
    -- shows ((a) nested: a KDE-native adapter -- KWin's screencast and fake
    -- input, as KDE's own remote desktop does -- is its next form). The
    -- session is share/wayland-sessions/kde.desktop (X-Luban-Shell=own); no
    -- GPU: mesa's llvmpipe draws (the runtime's).
    --
    -- Form: a bundle on a runtime (design §4.6, §13.5) -- every package
    -- Alpine 3.24's Plasma brings beyond luban:qt-runtime's, laid out as
    -- Alpine lays it out under /usr (its helpers in libexec and lib/<dir>,
    -- where a Luban system's /usr has them), its libraries and the musl
    -- loader private in libexec/kde (tools/res/build.sh kde). Its programs
    -- run as themselves: config() names this tree's loader and the library
    -- directories in them where they are installed. Preview: large (KDE pulls
    -- much of a distribution), and a desktop of a Luban system only.
    programs = {"luban-kde", "startplasma-wayland", "plasmashell", "kwin_wayland", "konsole", "dolphin", "systemsettings",
                "krunner"},
    xvm_enable = true,

    xpm = {
        linux = {
            deps = { "luban:qt-runtime@6.11.1-r2", "luban:labwc", "luban:foot", "xim:luban-fonts", "xim:xkeyboard-config",
                     "xim:patchelf" },
            ["latest"] = { ref = "6.6.6-r1" },
            ["6.6.6-r1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "4abfc384b87a20b3200273271ea56a8cbc21ab1a9c1921a251adef3490ee8c5e",
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
    return luban_component.install({ "bin/luban-kde", "libexec/kde/bin/plasmashell", "share/wayland-sessions/kde.desktop" })
end

function config()
    local dir = pkginfo.install_dir()
    local runtime = pkginfo.dep_install_dir("luban:qt-runtime", RUNTIME)
    if not runtime then
        log.error("luban:kde: luban:qt-runtime %s is not installed", RUNTIME)
        return false
    end
    local f = io.open(path.join(dir, "libexec", "kde", "qt-runtime"), "w")
    if not f then return false end
    f:write(runtime)
    f:close()
    local lib = path.join(dir, "libexec", "kde", "lib")
    local loaders = {}
    for _, file in ipairs(fs.files(lib) or {}) do
        if path.filename(file):match("^ld%-musl%-.+%.so%.1$") then table.insert(loaders, file) end
    end
    if #loaders ~= 1 then
        log.error("luban:kde: no musl loader in %s", lib)
        return false
    end
    -- Every program of the tree -- its own and the helpers in libexec and
    -- lib/<dir> -- runs as itself, by this tree's loader, on its libraries and
    -- the runtime's; what they dlopen finds its libraries through them.
    -- (libexec/kde/programs lists them: every ELF of the tree that names a loader).
    local list = io.open(path.join(dir, "libexec", "kde", "programs"), "r")
    if not list then
        log.error("luban:kde: its list of programs is missing")
        return false
    end
    local rpath = lib .. ":" .. path.join(runtime, "libexec", "qt-runtime", "lib")
    local done, failed = 0, 0
    for rel in list:lines() do
        if rel ~= "" then
            local program = path.join(dir, rel)
            local set = elfpatch.set_interpreter(program, loaders[1])
            local paths = elfpatch.set_rpath(program, rpath, { shrink = false })
            if set.patched == 1 and paths.patched == 1 then done = done + 1 else failed = failed + 1 end
        end
    end
    list:close()
    if failed > 0 or done == 0 then
        log.error("luban:kde: %d of its programs could not be pointed at their loader", failed)
        return false
    end
    return luban_component.config(package.programs, { "share/wayland-sessions", "share/luban/checks.d" })
end

function uninstall()
    return luban_component.uninstall(package.programs)
end
