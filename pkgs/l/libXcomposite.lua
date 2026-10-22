package = {
    spec = "2",

    homepage = "https://gitlab.freedesktop.org/xorg/lib/libxcomposite",
    name = "libXcomposite",
    description = "The X Composite extension client library (libXcomposite), with headers and pkg-config data",

    licenses = {"MIT"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"graphics", "x11", "lib"},
    keywords = {"x11", "xcomposite", "lib"},

    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/libXcomposite/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            aarch64 = "https://github.com/xlings-res/libXcomposite/releases/download/${version}/libXcomposite-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://github.com/xlings-res/libXcomposite/releases/download/${version}/libXcomposite-${version}-linux-x86_64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            aarch64 = "https://gitcode.com/xlings-res/libXcomposite/releases/download/${version}/libXcomposite-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://gitcode.com/xlings-res/libXcomposite/releases/download/${version}/libXcomposite-${version}-linux-x86_64.tar.gz",
                        },
                    },
                    required = true,
                },
            },
            verify = "sha256-sidecar",
        },
    },

    xpm = {
        linux = {
            -- DT_NEEDED outside the payload (readelf -d): libX11.
            deps = { "xim:glibc", "xim:libX11" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "0.4.6" },
            ["0.4.6"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libXcomposite/releases/download/0.4.6/libXcomposite-0.4.6-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libXcomposite/releases/download/0.4.6/libXcomposite-0.4.6-linux-x86_64.tar.gz",
                    },
                    sha256 = "5dd7911014e5a67f581ed51af0fe7360b866f0928202b39310ce7785827f3474",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libXcomposite/releases/download/0.4.6/libXcomposite-0.4.6-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libXcomposite/releases/download/0.4.6/libXcomposite-0.4.6-linux-aarch64.tar.gz",
                    },
                    sha256 = "858a3477b86e3e06f6c69becff8c2152c238dc01e1fdfccb815fa7d88c5f611f",
                },
            },
        },
    },
}

-- Repacked from conda-forge by .agents/tools/repack/repack.py, x86_64 from
--     xorg-libxcomposite-0.4.6-hb9d3cd8_2.conda
-- and aarch64 from the same release's arm64 build. PROVENANCE.md inside the
-- payload records every artefact, its sha256 and the exact command.
--
-- PLACEHOLDERS: only the .pc files carried one; rewritten to prefix=/usr.

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv(package.name .. "-" .. pkginfo.version(), dir)
    selfcontain.seal(dir)
    sysroot.relocate_pkgconfig(dir, "lib/pkgconfig")
    return os.isfile(dir .. "/lib/libXcomposite.so.1")
end

function config()
    local dir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()
    xvm.add(package.name, { type = "group" })
    sysroot.declare_libs(dir, "lib", binding, pkginfo.version())
    sysroot.declare_headers_tree(dir, "include", "usr/include", binding)
    sysroot.declare_pkgconfig(dir, "lib/pkgconfig", binding)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
