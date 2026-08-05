package = {
    spec = "2",

    homepage = "https://www.x.org",
    name = "libXfixes",
    description = "X Fixes extension client library",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/libXfixes",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libxfixes", "graphics", "x11"},

    xpm = {
        linux = {
            deps = { "xim:libX11@>=1.8" },
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "6.0.1" },
            ["6.0.1"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libXfixes/releases/download/6.0.1/libXfixes-6.0.1-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libXfixes/releases/download/6.0.1/libXfixes-6.0.1-linux-x86_64.tar.gz",
                },
                sha256 = "9e52c227f93b668a2c8fc1ee4c0768226c3e9168010a32466a95339d27dd6974",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("libXfixes-6.0.1", dir)
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
