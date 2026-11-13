-- wine: Wine, which runs a Windows program on Linux --- the runner of the Windows rows on a
-- Linux machine (design 2026-11-12 D28: a runner a test needs is a package, not a host
-- dependency). The build is Kron4ek/Wine-Builds' portable WoW64 build of the stable release:
-- one tree that runs 32- and 64-bit PE programs without the host's 32-bit libraries. GLOBAL is
-- the upstream release; CN is the same bytes at gitcode.com/xlings-res/wine, so one sha256
-- serves both. A program is run headless:
--
--     WINEPREFIX=<dir> WINEDEBUG=-all wine <program>.exe <arguments>
--
-- The program's output and its exit status are wine's (measured: a mingw program built by mcpp
-- printed its line and returned 42 through wine 11.0, 3.3 s with the prefix created).
package = {
    spec = "2",
    homepage = "https://www.winehq.org/",
    name = "wine",
    description = "Wine, which runs Windows programs on Linux: the portable WoW64 build of the stable release",
    maintainers = {"https://github.com/Kron4ek/Wine-Builds"},
    licenses = {"LGPL-2.1-or-later"},
    repo = "https://gitlab.winehq.org/wine/wine",
    docs = "https://gitlab.winehq.org/wine/wine/-/wikis/home",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"runner", "compatibility"},
    keywords = {"wine", "windows", "pe", "runner", "mingw"},
    programs = {"wine", "wineserver", "wineboot"},
    xvm_enable = true,
    xpm = {
        linux = {
            ["latest"] = { ref = "11.0" },
            ["11.0"] = {
                url = {
                    GLOBAL = "https://github.com/Kron4ek/Wine-Builds/releases/download/11.0/wine-11.0-amd64-wow64.tar.xz",
                    CN = "https://gitcode.com/xlings-res/wine/releases/download/11.0/wine-11.0-amd64-wow64.tar.xz",
                },
                sha256 = { ["x86_64"] = "39574efa1132c3ca0d5c77dd2eddbe4a49cca0d6cc2c290ff4924493a1c40314" },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    -- The archive's one directory, wine-<version>-amd64-wow64, is the package.
    local top = path.join(path.directory(pkginfo.install_file()), "wine-" .. pkginfo.version() .. "-amd64-wow64")
    if not os.isdir(top) then return false end
    os.tryrm(pkginfo.install_dir())
    os.mv(top, pkginfo.install_dir())
    return os.isfile(path.join(pkginfo.install_dir(), "bin", "wine"))
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    -- wine, the package's own name, anchors the release (Spec D1); the other programs
    -- bind to it, so `xlings use wine@<v>` moves them together.
    xvm.add("wine", { bindir = bindir })
    local binding = package.name .. "@" .. pkginfo.version()
    for _, prog in ipairs({"wineserver", "wineboot"}) do
        xvm.add(prog, { bindir = bindir, binding = binding })
    end
    return true
end

function uninstall()
    for _, prog in ipairs({"wineserver", "wineboot"}) do
        xvm.remove(prog)
    end
    xvm.remove("wine")
    return true
end
