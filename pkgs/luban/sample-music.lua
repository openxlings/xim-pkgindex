package = {
    spec = "1",

    name = "sample-music",
    namespace = "luban",
    description = "A piece to play: the Aria of the Open Goldberg Variations (J.S. Bach; Kimiko Ishizaka, piano; CC0)",

    homepage = "https://opengoldbergvariations.org",
    repo = "https://archive.org/details/OpenGoldbergVariations",
    licenses = {"CC0-1.0"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"audio", "data", "luban"},
    keywords = {"music", "sample", "bach", "goldberg", "luban"},

    -- What a Luban desktop plays to show its sound works (xlings design
    -- 2026-10-21 §6.3, E12): share/luban/samples/music/aria.ogg, the
    -- recording's licence beside it (tools/res/build.sh sample-music). The
    -- same file on every architecture.
    xpm = {
        linux = {
            ["latest"] = { ref = "2026.10.22" },
            ["2026.10.22"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/sample-music/releases/download/2026.10.22/sample-music-2026.10.22.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/sample-music/releases/download/2026.10.22/sample-music-2026.10.22.tar.gz",
                },
                sha256 = "cbcbafb85a607b83b02ec10af1ffbedf9e7a966aa4a6637b47f8d25d80176ab5",
            },
        },
    },
}

import("xim.pkgindex.luban_component")

function install()
    return luban_component.install({ "share/luban/samples/music/aria.ogg" })
end

function config()
    return luban_component.config({}, { "share/luban/samples", "share/licenses/sample-music" })
end

function uninstall()
    return luban_component.uninstall({})
end
