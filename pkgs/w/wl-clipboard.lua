package = {
    spec = "1",

    name = "wl-clipboard",
    description = "wl-copy and wl-paste: the Wayland clipboard from the command line (static)",

    homepage = "https://github.com/bugaevc/wl-clipboard",
    repo = "https://github.com/bugaevc/wl-clipboard",
    licenses = {"GPL-3.0-or-later"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"desktop", "cli", "tool"},
    keywords = {"wayland", "clipboard", "wl-copy", "wl-paste", "subos"},

    -- What a SubOS granted the clipboard reaches the host's through, on a
    -- Wayland desktop (xlings' broker runs it outside the sandbox): built
    -- static with libwayland-client (tools/res/build.sh wl-clipboard), so a
    -- desktop that does not ship it still has it.
    programs = {"wl-copy", "wl-paste"},
    xvm_enable = true,



    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/wl-clipboard/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/xlings-res/wl-clipboard/releases/download/${version}/wl-clipboard-${version}-linux-x86_64.tar.gz",
                            aarch64 = "https://github.com/xlings-res/wl-clipboard/releases/download/${version}/wl-clipboard-${version}-linux-aarch64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            x86_64 = "https://gitcode.com/xlings-res/wl-clipboard/releases/download/${version}/wl-clipboard-${version}-linux-x86_64.tar.gz",
                            aarch64 = "https://gitcode.com/xlings-res/wl-clipboard/releases/download/${version}/wl-clipboard-${version}-linux-aarch64.tar.gz",
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
            ["latest"] = { ref = "2.3.0" },
            ["2.3.0"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "20f54faea689afc48e616e3d4a8d539daf660bce00dc56e83c0ff058ebc25f19",
                    aarch64 = "48fc4e68df2d5af7dd48b0f19e2b2449a4363ed4221c3fb1b2223822d4d7b0c2",
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
    return os.isfile(path.join(dir, "bin", "wl-copy")) and os.isfile(path.join(dir, "bin", "wl-paste"))
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    xvm.add(package.name)
    xvm.add("wl-copy", { bindir = bindir, binding = package.name .. "@" .. pkginfo.version() })
    xvm.add("wl-paste", { bindir = bindir, binding = package.name .. "@" .. pkginfo.version() })
    return true
end

function uninstall()
    xvm.remove("wl-copy")
    xvm.remove("wl-paste")
    xvm.remove(package.name)
    return true
end
