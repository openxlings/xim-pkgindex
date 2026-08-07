package = {
    spec = "2",

    homepage = "https://www.khronos.org/vulkan/",
    name = "vulkan-loader",
    description = "Vulkan ICD loader - libvulkan.so.1, without which an ICD manifest is never read",

    authors = {"The Khronos Group"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/KhronosGroup/Vulkan-Loader",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "vulkan", "lib"},
    keywords = {"vulkan", "graphics", "vulkan-loader"},

    -- Why the stack needs this at all.
    --
    -- mesa already ships a Vulkan driver (RADV) and rewrites its ICD manifest to
    -- an absolute path inside our payload -- but an ICD is a DRIVER, and a driver
    -- is loaded BY a loader. Without libvulkan.so.1 the manifest sits there
    -- unread: `vulkaninfo` cannot run, and zink (GL over Vulkan) is dead in a
    -- payload that ships it.
    --
    -- Discovery needs NO new declaration. The Vulkan loader searches
    -- $XDG_DATA_DIRS/vulkan/icd.d, and mesa's config() already prepends its
    -- share directory to XDG_DATA_DIRS. VK_DRIVER_FILES would be wrong here --
    -- it is an OVERRIDE that suppresses system discovery, so it would hide every
    -- other ICD on the machine.

    xpm = {
        linux = {
            deps = { "xim:libX11@>=1.8", "xim:libxcb@>=1.17", "xim:libXrandr@>=1.5",
                     "xim:wayland@>=1.23", "xim:glibc@>=2.38" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.4.313" },
            ["1.4.313"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/vulkan-loader/releases/download/1.4.313/vulkan-loader-1.4.313-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/vulkan-loader/releases/download/1.4.313/vulkan-loader-1.4.313-linux-x86_64.tar.gz",
                },
                sha256 = "4870e17d573117378132db72d338723c849bef5aa4ae3f01eb0aabbdfabd3c2b",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("vulkan-loader-1.4.313", dir)

    -- Stamp this payload's own dependency closure onto its libraries, so
    -- they resolve from our payloads and not from the host's ld.so.cache.
    selfcontain.seal(pkginfo.install_dir())
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
