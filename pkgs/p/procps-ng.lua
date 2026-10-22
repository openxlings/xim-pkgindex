-- procps-ng -- the process tools in full (ps, top, free, pgrep, pkill, pidof,
-- uptime, vmstat, watch), built static by this index's factory
-- (tools/res/build.sh procps-ng: musl, ncursesw) with the terminfo entries of
-- the terminals it meets in share/terminfo, which its shims name in
-- TERMINFO_DIRS. A Luban core system has it above BusyBox's applets of the
-- same names (xlings design 2026-10-19 §20): BusyBox's ps has no -C and few
-- -o fields. xlings-res/procps-ng on GitHub and GitCode.
package = {
    spec = "1",

    name = "procps-ng",
    description = "procps-ng: ps, top, free, pgrep, pkill, pidof, uptime, vmstat and watch",
    homepage = "https://gitlab.com/procps-ng/procps",
    repo = "https://gitlab.com/procps-ng/procps",
    licenses = {"GPL-2.0-or-later", "LGPL-2.1-or-later"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "system", "monitor"},
    keywords = {"procps", "ps", "top", "free", "pgrep", "pkill", "watch", "process"},

    programs = {"ps", "top", "free", "pgrep", "pkill", "pidof", "uptime", "vmstat", "watch"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/procps-ng/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/xlings-res/procps-ng/releases/download/${version}/procps-ng-${version}-linux-x86_64.tar.gz",
                            aarch64 = "https://github.com/xlings-res/procps-ng/releases/download/${version}/procps-ng-${version}-linux-aarch64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            x86_64 = "https://gitcode.com/xlings-res/procps-ng/releases/download/${version}/procps-ng-${version}-linux-x86_64.tar.gz",
                            aarch64 = "https://gitcode.com/xlings-res/procps-ng/releases/download/${version}/procps-ng-${version}-linux-aarch64.tar.gz",
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
            ["latest"] = { ref = "4.0.5" },
            ["4.0.5"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "2f1eb032ee453bfc2cc8d4a4477a7855e58e93eb1294f5cfd7e09452c5e57597",
                    aarch64 = "34e9099d882fbcc8148533e0e9cc0ad12e96c636ef840ea6e01ee1284fb69725",
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
    return os.isfile(path.join(dir, "bin", "ps"))
end

function config()
    -- The root every program binds to, as coreutils does.
    xvm.add("procps-ng")
    local dir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()
    local terminfo = path.join(dir, "share", "terminfo") .. ":/usr/share/terminfo:/etc/terminfo"
    for _, prog in ipairs(package.programs) do
        xvm.add(prog, {
            bindir = path.join(dir, "bin"),
            binding = binding,
            envs = { TERMINFO_DIRS = terminfo },
        })
    end
    return true
end

function uninstall()
    for _, prog in ipairs(package.programs) do
        xvm.remove(prog)
    end
    xvm.remove("procps-ng")
    return true
end
