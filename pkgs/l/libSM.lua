-- X.Org runtime, from conda-forge's portable linux-64 build.
package = {
    spec = "2",
    name = "libSM",
    description = "X.Org libSM shared runtime library",
    homepage = "https://www.x.org/",
    repo = "https://gitlab.freedesktop.org/xorg/lib/libsm",
    licenses = {"MIT"},
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = { runtime = { "xim:glibc", "xim:gcc-runtime", "libICE", "xim:util-linux" } },
            exports = { runtime = { libdirs = {"lib"} } },
            ["latest"] = { ref = "1.2.3" },
            ["1.2.3"] = {
                x86_64 = {
                    url = "https://conda.anaconda.org/conda-forge/linux-64/xorg-libsm-1.2.3-hd9c2040_1000.tar.bz2",
                    sha256 = "bdb350539521ddc1f30cc721b6604eced8ef72a0ec146e378bfe89e2be17ab35",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

function installed()
    return os.isfile(pkginfo.install_dir() .. "/lib/libSM.so.6")
end

function install()
    local dir = pkginfo.install_dir()
    os.mkdir(dir)
    -- Extract into this store directory explicitly: conda archives have no
    -- wrapper directory, and the shared download directory is not a prefix.
    local function quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
    system.exec("tar -xf " .. quote(pkginfo.install_file()) .. " -C " .. quote(dir))
    assert(installed(), "Missing libSM runtime")
    return true
end

function config()
    xvm.add("libSM", { type = "group" })
    return true
end

function uninstall()
    xvm.remove("libSM")
    return true
end
