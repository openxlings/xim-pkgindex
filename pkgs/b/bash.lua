package = {
    spec = "1",

    homepage = "https://www.gnu.org/software/bash/",
    name = "bash",
    description = "GNU Bash, the Bourne Again SHell",

    authors = {"Chet Ramey", "Free Software Foundation"},
    licenses = {"GPL-3.0-or-later"},
    repo = "https://git.savannah.gnu.org/cgit/bash.git",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"shell", "system"},
    keywords = {"bash", "shell", "sh", "gnu"},

    programs = {"bash"},
    xvm_enable = true,

    -- Built from upstream 5.2.37 against xim:glibc 2.44.3 with xim:gcc 16.1.0
    -- (CFLAGS -O2 -std=gnu17: bash 5.2 predates C23's prototypes), no curses
    -- (bash's own termcap). Its only NEEDED is libc.so.6, so the installer's
    -- elfpatch is the whole relocation. A SubOS root (`subos new --rootfs`,
    -- luban-core) puts its bin/ into /usr/bin.
    xpm = {
        linux = {
            deps = { "xim:glibc" },
            ["latest"] = { ref = "5.2.37" },
            ["5.2.37"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "4e2f4be7fd46b747d321310c655eb65ba5493ed442ab7df2c6af8801478940c9" },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    local staged = path.join(dir, "bin", "bash")
    if not os.isfile(staged) then
        local payload = "bash-" .. pkginfo.version()
        if os.isdir(payload) then
            os.tryrm(dir)
            os.mv(payload, dir)
        end
    end
    return os.isfile(staged)
end

function config()
    xvm.add("bash", { bindir = path.join(pkginfo.install_dir(), "bin") })
    return true
end

function uninstall()
    xvm.remove("bash")
    return true
end
