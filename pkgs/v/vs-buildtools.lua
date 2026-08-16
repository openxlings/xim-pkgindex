-- DEPRECATED -- use `xim:msvc` instead.
--
-- This recipe does not install Visual Studio Build Tools. It downloads the
-- ~1 MB bootstrapper and stops there (`install()` is `return true`), so
-- `xlings install vs-buildtools` leaves nothing that can compile anything.
-- What it was used for -- being a dependency of the old `msvc` recipe, which
-- then shelled out to that bootstrapper -- is gone: `msvc` now unpacks a
-- pinned toolset into the xlings payload store and needs no installer.
--
-- Kept, not deleted, so an existing `xlings install vs-buildtools` keeps
-- resolving. Nothing in this index depends on it any more.
package = {
    spec = "1",
    name = "vs-buildtools",
    description = "Visual Studio Build Tools bootstrapper (DEPRECATED -- use xim:msvc)",

    type = "config",
    status = "deprecated",
    maintainers = {"Microsoft"},
    categories = { "build-tools" },
    keywords = { "msvc" },

    xpm = {
        windows = {
            ["latest"] = { ref = "2022" },
            ["2022"] = {
                url = "https://download.visualstudio.microsoft.com/download/pr/f2819554-a618-400d-bced-774bb5379965/ab3cff3d3a8c48804f47eb521cf138480f5ed4fe86476dd449a420777d7f2ead/vs_BuildTools.exe",
                --sha256 = "ab3cff3d3a8c48804f47eb521cf138480f5ed4fe86476dd449a420777d7f2ead"
            }
        },
    }
}

import("xim.libxpkg.pkginfo")

function installed()
    return os.isfile(pkginfo.install_file())
end

function install() return true end

function uninstall()
    os.tryrm(pkginfo.install_file())
    return true
end