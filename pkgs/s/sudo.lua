-- sudo -- acting as root, for a Luban system (xlings design 2026-10-20 §4.5):
-- built static by this index's factory (tools/res/build.sh sudo: musl, no
-- PAM -- it reads the system's /etc/shadow -- the sudoers policy built in).
-- The system's rules are luban's (/etc/sudoers, /etc/sudoers.d/luban: the
-- wheel group with its password). bin/sudo is setuid; a machine makes it
-- root's at boot (a share shows the host's owner). A sandbox needs none: its
-- writes go through the system's broker. xlings-res/sudo on GitHub and GitCode.
package = {
    spec = "1",

    name = "sudo",
    description = "sudo: run a command as root (or another user), with the system's sudoers",
    homepage = "https://www.sudo.ws",
    repo = "https://github.com/sudo-project/sudo",
    licenses = {"ISC"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"system", "security", "cli"},
    keywords = {"sudo", "root", "admin", "visudo", "sudoers"},

    programs = {"sudo", "sudoedit", "visudo"},
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "1.9.17p2" },
            ["1.9.17p2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "4bcc91ed3a29c470791695a6f4e7c7d575f2395492af00949f31acef66d84535",
                    aarch64 = "4a57d751ed87c4992de395de6284193fe400ea5ba5fe761d6a8d767bcd827168",
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
    local sudo = path.join(dir, "bin", "sudo")
    if not os.isfile(sudo) then return false end
    -- Setuid as sudo must be; root's where the system is (a machine's boot,
    -- a root-owned install). An ordinary user's copy stays an ordinary file.
    os.exec("chmod 4755 " .. sudo)
    return true
end

function config()
    local dir = pkginfo.install_dir()
    xvm.add("sudo", { bindir = path.join(dir, "bin") })
    xvm.add("sudoedit", { bindir = path.join(dir, "bin") })
    xvm.add("visudo", { bindir = path.join(dir, "sbin") })
    return true
end

function uninstall()
    for _, prog in ipairs(package.programs) do
        xvm.remove(prog)
    end
    return true
end
