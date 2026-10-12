-- tmux -- a terminal multiplexer (tmux/tmux), built static by
-- this index's factory (tools/res/build.sh tmux: musl, libevent, ncursesw) with the
-- terminfo entries of the terminals it meets in share/terminfo, which its
-- shim names in TERMINFO_DIRS (an environment may have no terminfo of its
-- own). xlings-res/tmux on GitHub and GitCode (tools/res/publish.py).
package = {
    spec = "1",

    name = "tmux",
    description = "tmux: a terminal multiplexer -- sessions that outlive the terminal, windows and panes",
    homepage = "https://github.com/tmux/tmux/wiki",
    repo = "https://github.com/tmux/tmux",
    licenses = {"ISC"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "terminal"},
    keywords = {"tmux", "top", "process", "monitor"},

    programs = {"tmux"},
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "3.8" },
            ["3.8"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "6f37eda1cf62cf097864de957898c6992aa646399a0fdd50705d417d474596f5",
                    aarch64 = "900bb67ca653794543ba676365f3594bfdcd2fc30f94e1fd98d57a4b7bec009b",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    local payload = pkginfo.install_file():replace(".tar.gz", "")
    if os.isdir(payload) then
        os.tryrm(dir)
        os.mv(payload, dir)
    end
    return os.isfile(path.join(dir, "bin", "tmux"))
end

function config()
    local dir = pkginfo.install_dir()
    xvm.add("tmux", {
        bindir = path.join(dir, "bin"),
        envs = { TERMINFO_DIRS = path.join(dir, "share", "terminfo") .. ":/usr/share/terminfo:/etc/terminfo" },
    })
    return true
end

function uninstall()
    xvm.remove("tmux")
    return true
end
