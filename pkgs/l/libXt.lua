-- X.Org runtime, from conda-forge's portable linux-64 build.
package = {
    spec = "2",
    name = "libXt",
    description = "X.Org libXt shared runtime library",
    homepage = "https://www.x.org/",
    repo = "https://gitlab.freedesktop.org/xorg/lib/libxt",
    licenses = {"MIT"},
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = { runtime = { "xim:glibc", "xim:gcc-runtime", "libICE", "libSM", "xim:libX11" } },
            exports = { runtime = { libdirs = {"lib"} } },
            ["latest"] = { ref = "1.2.1" },
            ["1.2.1"] = {
                x86_64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-64/xorg-libxt-1.2.1-h7f98852_2.tar.bz2",
                    sha256 = "25bfc4d86df3498b88aac2f02ecf65e739bf99a687805c31a635df6f2e60a163",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

function installed()
    return os.isfile(pkginfo.install_dir() .. "/lib/libXt.so.6")
end

function install()
    local dir = pkginfo.install_dir()
    os.mkdir(dir)
    -- Extract into this store directory explicitly: conda archives have no
    -- wrapper directory, and the shared download directory is not a prefix.
    local function quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
    system.exec("tar -xf " .. quote(pkginfo.install_file()) .. " -C " .. quote(dir))
    assert(installed(), "Missing libXt runtime")
    return true
end

function config()
    xvm.add("libXt", { type = "group" })
    return true
end

function uninstall()
    xvm.remove("libXt")
    return true
end
