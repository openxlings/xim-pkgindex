-- htop -- an interactive process viewer (htop-dev/htop), built static by
-- this index's factory (tools/res/build.sh htop: musl, ncursesw) with the
-- terminfo entries of the terminals it meets in share/terminfo, which its
-- shim names in TERMINFO_DIRS (an environment may have no terminfo of its
-- own). xlings-res/htop on GitHub and GitCode (tools/res/publish.py).
package = {
    spec = "1",

    name = "htop",
    description = "htop: an interactive process viewer for the terminal",
    homepage = "https://htop.dev",
    repo = "https://github.com/htop-dev/htop",
    licenses = {"GPL-2.0-or-later"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "system", "monitor"},
    keywords = {"htop", "top", "process", "monitor"},

    programs = {"htop"},
    xvm_enable = true,



    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/htop/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/xlings-res/htop/releases/download/${version}/htop-${version}-linux-x86_64.tar.gz",
                            aarch64 = "https://github.com/xlings-res/htop/releases/download/${version}/htop-${version}-linux-aarch64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            x86_64 = "https://gitcode.com/xlings-res/htop/releases/download/${version}/htop-${version}-linux-x86_64.tar.gz",
                            aarch64 = "https://gitcode.com/xlings-res/htop/releases/download/${version}/htop-${version}-linux-aarch64.tar.gz",
                        },
                    },
                    required = true,
                },
            },
            verify = "sha256-sidecar",
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "3.5.3" },
            ["3.5.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "1b5c282f09b0a3da1018c5afc04c9b1bcfa793e85eb5fdb67797015ca5617bc7",
                    aarch64 = "701eb708672b9183fc40c50ad8c65013a068327638874eaab0f655cd4050bb65",
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
    return os.isfile(path.join(dir, "bin", "htop"))
end

function config()
    local dir = pkginfo.install_dir()
    xvm.add("htop", {
        bindir = path.join(dir, "bin"),
        envs = { TERMINFO_DIRS = path.join(dir, "share", "terminfo") .. ":/usr/share/terminfo:/etc/terminfo" },
    })
    return true
end

function uninstall()
    xvm.remove("htop")
    return true
end
