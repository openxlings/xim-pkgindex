package = {
    spec = "1",

    name = "terminfo",
    description = "Terminal descriptions: ncurses' terminfo database, compiled (xterm, screen, tmux, linux, kitty, foot, alacritty, wezterm, ghostty and the rest)",

    homepage = "https://invisible-island.net/ncurses/",
    repo = "https://github.com/ThomasDickey/ncurses-snapshots",
    licenses = {"MIT"},

    type = "package",
    -- Data: the same files whichever machine reads them.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"terminal", "system"},
    keywords = {"terminfo", "ncurses", "terminal", "TERM", "luban"},

    -- What a program that draws on a terminal reads to know it (xlings design
    -- 2026-10-16 L §10): share/terminfo/<letter>/<name>, ncurses'
    -- misc/terminfo.src at the snapshot the version names, compiled whole
    -- with `tic -x`, plus xterm-kitty and xterm-ghostty -- the names kitty
    -- and Ghostty set in $TERM -- for the entries ncurses calls kitty and
    -- ghostty (tools/res/build.sh terminfo). In a Luban root it is
    -- /usr/share/terminfo; a person who enters from any terminal is
    -- described there.


    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/terminfo/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = "https://github.com/xlings-res/terminfo/releases/download/${version}/terminfo-${version}.tar.gz",
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = "https://gitcode.com/xlings-res/terminfo/releases/download/${version}/terminfo-${version}.tar.gz",
                    },
                    required = true,
                },
            },
            verify = "sha256-sidecar",
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "6.6.20261010" },
            ["6.6.20261010"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/terminfo/releases/download/6.6.20261010/terminfo-6.6.20261010.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/terminfo/releases/download/6.6.20261010/terminfo-6.6.20261010.tar.gz",
                },
                sha256 = "4e661726e9f7d2fefc8ee142a2442fbf080ec91642cfdc6af4d6499b61779394",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    local payload = path.join(path.directory(pkginfo.install_file()), "terminfo-" .. pkginfo.version())
    if os.isdir(payload) then
        os.tryrm(dir)
        os.mv(payload, dir)
    end
    return os.isfile(path.join(dir, "share", "terminfo", "x", "xterm-256color"))
        and os.isfile(path.join(dir, "share", "terminfo", "l", "linux"))
end

-- Data, not a program: the package name is registered so a home knows it has
-- it (a group: it names no program, so it has no shim).
function config()
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
