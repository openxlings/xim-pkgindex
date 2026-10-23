package = {
    spec = "2",

    homepage = "https://gitlab.gnome.org/GNOME/libsecret",
    name = "libsecret",
    description = "The Secret Service client library (libsecret-1), with headers and pkg-config data",

    licenses = {"LGPL-2.1-or-later"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"security", "lib"},
    keywords = {"secret", "keyring", "secret-service", "lib"},

    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/libsecret/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            aarch64 = "https://github.com/xlings-res/libsecret/releases/download/${version}/libsecret-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://github.com/xlings-res/libsecret/releases/download/${version}/libsecret-${version}-linux-x86_64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            aarch64 = "https://gitcode.com/xlings-res/libsecret/releases/download/${version}/libsecret-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://gitcode.com/xlings-res/libsecret/releases/download/${version}/libsecret-${version}-linux-x86_64.tar.gz",
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
            -- DT_NEEDED outside the payload (readelf -d): libgcrypt, libgio-2.0, libglib-2.0, libgobject-2.0.
            deps = { "xim:glibc", "xim:glib", "xim:libgcrypt" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "0.21.7" },
            ["0.21.7"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libsecret/releases/download/0.21.7/libsecret-0.21.7-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libsecret/releases/download/0.21.7/libsecret-0.21.7-linux-x86_64.tar.gz",
                    },
                    sha256 = "b2e4b3578f9108e3f428f35bb6f558653b2a1567f359c70e19ece2460d4dc198",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libsecret/releases/download/0.21.7/libsecret-0.21.7-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libsecret/releases/download/0.21.7/libsecret-0.21.7-linux-aarch64.tar.gz",
                    },
                    sha256 = "6a6ad1a16f6fe23e46acb76a54990dfdb33987085aff62d4008ef7de8fd62c15",
                },
            },
        },
    },
}

-- Repacked from conda-forge by .agents/tools/repack/repack.py, x86_64 from
--     libsecret-0.21.7-h1e2da66_0.conda
-- and aarch64 from the same release's arm64 build. PROVENANCE.md inside the
-- payload records every artefact, its sha256 and the exact command.
--
-- PLACEHOLDERS: only the .pc files carried one; rewritten to prefix=/usr.
--
-- Chromium and Electron dlopen libsecret-1.so.0 to keep credentials in the
-- desktop keyring; without it they fall back to a plain-text store.

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
    return os.isfile(dir .. "/lib/libsecret-1.so.0")
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
