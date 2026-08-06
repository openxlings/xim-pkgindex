package = {
    spec = "1",
    -- base info
    name = "cmake",
    description = "A Powerful Software Build System",

    maintainers = {"Kitware"},
    licenses = {"BSD-3Clause"},
    repo = "https://github.com/Kitware/CMake",
    contributors = "https://github.com/Kitware/CMake/blob/master/CONTRIBUTORS.rst",
    docs = "https://cmake.org/documentation",

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "arm64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"build", "system", "cmake"},
    keywords = {"build", "system", "cmake", "make", "generator", "cross-platform"},

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        linux = {
            -- Runtime deps. cmake prebuilt is dynamically linked
            -- (INTERP=/lib64/ld-linux-x86-64.so.2) and needs
            -- libc/libdl/librt/libpthread/libm from glibc. No libstdc++
            -- (statically linked into the binary).
            deps = {
                runtime = { "xim:glibc@>=2.39" },
            },
            ["latest"] = { ref = "4.0.2" },
            ["4.0.2"] = "XLINGS_RES",
        },
        macosx = {
            ["latest"] = { ref = "4.0.2" },
            ["4.0.2"] = "XLINGS_RES",
        },
        windows = {
            ["latest"] = { ref = "4.0.2" },
            ["4.0.2"] = "XLINGS_RES",
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    os.tryrm(pkginfo.install_dir())
    local cmakedir = pkginfo.install_file()
        :replace(".zip", "")
        :replace(".tar.gz", "")
    os.mv(cmakedir, pkginfo.install_dir())
    return true
end

function config()
    local config
    if os.host() == "macosx" then
        config = { bindir = path.join(pkginfo.install_dir(), "CMake.app/Contents/bin") }
    else
        config = { bindir = path.join(pkginfo.install_dir(), "bin") }
    end
    xvm.add("cmake", config)
    return true
end

function uninstall()
    xvm.remove("cmake")
    return true
end