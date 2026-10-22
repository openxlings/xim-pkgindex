package = {
    spec = "1",

    name = "audacious",
    namespace = "luban",
    description = "Audacious: a light music player -- the one every Luban desktop carries",

    homepage = "https://audacious-media-player.org",
    repo = "https://github.com/audacious-media-player/audacious",
    licenses = {"BSD-2-Clause", "GPL-3.0-or-later"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"audio", "player", "luban", "qt"},
    keywords = {"audacious", "music", "player", "audio", "luban"},

    -- The desktops' music player (xlings design 2026-10-21 §6.3, E11): a Qt
    -- one, on the runtime the Qt desktops and Falkon carry. Form: a bundle on
    -- luban:qt-runtime, as luban:falkon is (tools/res/build.sh audacious):
    -- Alpine 3.24's Audacious and its plugins, the libraries beyond the
    -- runtime's and the musl loader private in libexec/audacious. It plays
    -- through PulseAudio (luban:audio's pipewire-pulse); no FFmpeg, PipeWire,
    -- JACK or SDL plugin. Its program runs as itself: config() names this
    -- tree's loader and the library directories in it, where it is installed.
    programs = {"audacious"},
    xvm_enable = true,

    -- How it is checked (xlings design 2026-10-21 §6.1).
    extensions = { luban = { checks = {
        { id = "audacious-runs", what = "it starts", run = "QT_QPA_PLATFORM=offscreen audacious --version", timeout = 20 },
        { id = "audacious-listed", what = "the launcher lists it", launcher = "audacious" },
        { id = "audacious-plays", what = "it plays the sample", sound = "audacious -H -q /usr/share/luban/samples/music/aria.ogg", timeout = 30 },
    } } },

    xpm = {
        linux = {
            deps = { "luban:qt-runtime@6.11.1-r2", "luban:sample-music", "xim:patchelf" },
            ["latest"] = { ref = "4.5.1-r1" },
            ["4.5.1-r1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "6c95cfe801dce5c5b3815de508a20af68c57af388b770453e0c24dea53e7e766",
                    aarch64 = "62cf14528adbee3ff724be9e4e6f5e3b51fd384c0178f8b0af0871331e085093",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.elfpatch")
import("xim.libxpkg.fs")
import("xim.pkgindex.luban_component")

local RUNTIME = "6.11.1-r2"

function install()
    return luban_component.install({ "bin/audacious", "libexec/audacious/bin/audacious", "libexec/audacious/env",
                                     "libexec/audacious/lib/audacious/Input/vorbis.so" })
end

function config()
    local dir = pkginfo.install_dir()
    local runtime = pkginfo.dep_install_dir("luban:qt-runtime", RUNTIME)
    if not runtime then
        log.error("luban:audacious: luban:qt-runtime %s is not installed", RUNTIME)
        return false
    end
    local f = io.open(path.join(dir, "libexec", "audacious", "qt-runtime"), "w")
    if not f then return false end
    f:write(runtime)
    f:close()
    local lib = path.join(dir, "libexec", "audacious", "lib")
    local loaders = {}
    for _, file in ipairs(fs.files(lib) or {}) do
        if path.filename(file):match("^ld%-musl%-.+%.so%.1$") then table.insert(loaders, file) end
    end
    if #loaders ~= 1 then
        log.error("luban:audacious: no musl loader in %s", lib)
        return false
    end
    local bin = path.join(dir, "libexec", "audacious", "bin")
    local opts = { include_shared_libs = false, shrink = false }
    local set = elfpatch.set_interpreter(bin, loaders[1], opts)
    local paths = elfpatch.set_rpath(bin, lib .. ":" .. path.join(runtime, "libexec", "qt-runtime", "lib"), opts)
    if set.failed > 0 or set.patched == 0 or (paths.failed or 0) > 0 then
        log.error("luban:audacious: its program could not be pointed at its loader (%d of %d)", set.failed, set.scanned)
        return false
    end
    return luban_component.config(package.programs, { "share/applications", "share/icons" },
                                  package.extensions.luban.checks)
end

function uninstall()
    return luban_component.uninstall(package.programs)
end
