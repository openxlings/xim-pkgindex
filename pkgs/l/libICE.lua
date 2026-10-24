-- X.Org runtime, from conda-forge's portable linux-64 build.
package = {
    spec = "2",
    name = "libICE",
    description = "X.Org libICE shared runtime library",
    homepage = "https://www.x.org/",
    repo = "https://gitlab.freedesktop.org/xorg/lib/libice",
    licenses = {"MIT"},
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = { runtime = { "xim:glibc", "xim:gcc-runtime" } },
            exports = { runtime = { libdirs = {"lib"} } },
            ["latest"] = { ref = "1.0.10" },
            ["1.0.10"] = {
                x86_64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-64/xorg-libice-1.0.10-h7f98852_0.tar.bz2",
                    sha256 = "f15ce1dff16823888bcc2be1738aadcb36699be1e2dd2afa347794c7ec6c1587",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

function installed()
    return os.isfile(pkginfo.install_dir() .. "/lib/libICE.so.6")
end

function install()
    local dir = pkginfo.install_dir()
    os.mkdir(dir)
    -- Extract into this store directory explicitly: conda archives have no
    -- wrapper directory, and the shared download directory is not a prefix.
    local function quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
    system.exec("tar -xf " .. quote(pkginfo.install_file()) .. " -C " .. quote(dir))
    assert(installed(), "Missing libICE runtime")
    return true
end

function config()
    xvm.add("libICE", { type = "group" })
    return true
end

function uninstall()
    xvm.remove("libICE")
    return true
end
