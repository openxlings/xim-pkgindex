package = {
    spec = "2",

    homepage = "https://www.x.org",
    name = "libXdmcp",
    description = "X Display Manager Control Protocol library",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xorg/lib/libXdmcp",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libxdmcp", "graphics", "x11"},

    xpm = {
        linux = {
            deps = { "xorgproto@>=2024" },
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.1.5" },
            ["1.1.5"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libXdmcp/releases/download/1.1.5/libXdmcp-1.1.5-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libXdmcp/releases/download/1.1.5/libXdmcp-1.1.5-linux-x86_64.tar.gz",
                },
                sha256 = "d7f0c96723d92af1275e43c39cd66e64802409aa5c4f2f9aba43aaf0b113de08",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("libXdmcp-1.1.5", dir)
    return true
end

function config()
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
