package = {
    spec = "2",

    homepage = "https://www.khronos.org/vulkan/",
    name = "vulkan-headers",
    description = "Vulkan API headers and registry",

    authors = {"The Khronos Group"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/KhronosGroup/Vulkan-Headers",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "vulkan", "lib"},
    keywords = {"vulkan", "graphics", "vulkan-headers"},

    xpm = {
        linux = {
            deps = { "xim:glibc@>=2.38" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.4.313" },
            ["1.4.313"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/vulkan-headers/releases/download/1.4.313/vulkan-headers-1.4.313-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/vulkan-headers/releases/download/1.4.313/vulkan-headers-1.4.313-linux-x86_64.tar.gz",
                },
                sha256 = "bb305ab10c4d5c5ce5935099b4b8f364376e360bea53fee85a5e86370cef860a",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("vulkan-headers-1.4.313", dir)
    return true
end

function config()
    local binding = package.name .. "@" .. pkginfo.version()
    xvm.add(package.name)
    sysroot.declare_libs(pkginfo.install_dir(), "lib", binding, pkginfo.version())
    if not sysroot.declare_headers_tree(pkginfo.install_dir(), "include",
                                        "usr/include", binding) then
        sysroot.install_headers_tree(
            path.join(pkginfo.install_dir(), "include"),
            path.join(system.subos_sysrootdir(), "usr", "include"))
    end
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
