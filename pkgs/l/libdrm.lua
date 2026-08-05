package = {
    spec = "2",

    homepage = "https://dri.freedesktop.org/",
    name = "libdrm",
    description = "Userspace interface to the kernel DRM services",

    authors = {"Mesa contributors"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/mesa/drm",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libdrm", "graphics", "gl"},

    xpm = {
        linux = {
            deps = { "xim:libpciaccess@>=0.18" },
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "2.4.123" },
            ["2.4.123"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libdrm/releases/download/2.4.123/libdrm-2.4.123-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libdrm/releases/download/2.4.123/libdrm-2.4.123-linux-x86_64.tar.gz",
                },
                sha256 = "8f70c903b3cd593c6b42f9621aacff2c6f6dcd96732cc91e5aad4a00357c53c1",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("libdrm-2.4.123", dir)
    return true
end

function config()
    xvm.add(package.name)

    -- Headers into the subos sysroot, so a compiler in this subos can find
    -- them. Declared rather than copied: xlings removes them with the package.
    if xvm.files then
        xvm.files{ src = "include", dst = "usr/include",
                   binding = package.name .. "@" .. pkginfo.version() }
    end
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
