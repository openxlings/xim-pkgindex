package = {
    spec = "2",

    homepage = "https://gnupg.org/software/libgpg-error/",
    name = "libgpg-error",
    description = "The GnuPG error-code library (libgpg-error), with headers and pkg-config data",

    licenses = {"LGPL-2.1-or-later"},
    repo = "https://dev.gnupg.org/source/libgpg-error.git",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"security", "lib"},
    keywords = {"gnupg", "gpg-error", "lib"},

    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/libgpg-error/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            aarch64 = "https://github.com/xlings-res/libgpg-error/releases/download/${version}/libgpg-error-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://github.com/xlings-res/libgpg-error/releases/download/${version}/libgpg-error-${version}-linux-x86_64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            aarch64 = "https://gitcode.com/xlings-res/libgpg-error/releases/download/${version}/libgpg-error-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://gitcode.com/xlings-res/libgpg-error/releases/download/${version}/libgpg-error-${version}-linux-x86_64.tar.gz",
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
            -- DT_NEEDED outside the payload (readelf -d): libc only.
            deps = { "xim:glibc" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.61" },
            ["1.61"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libgpg-error/releases/download/1.61/libgpg-error-1.61-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libgpg-error/releases/download/1.61/libgpg-error-1.61-linux-x86_64.tar.gz",
                    },
                    sha256 = "e3b5a956606e9d4172825b4932cd24f6a5e1b72644c68c967093a40035f66306",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libgpg-error/releases/download/1.61/libgpg-error-1.61-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libgpg-error/releases/download/1.61/libgpg-error-1.61-linux-aarch64.tar.gz",
                    },
                    sha256 = "0b0addbbf43094b140ce08c57b30e733e8a21a597b014469e1bd8078eb8611d5",
                },
            },
        },
    },
}

-- Repacked from conda-forge by .agents/tools/repack/repack.py, x86_64 from
--     libgpg-error-1.61-h54a6638_2.conda
-- and aarch64 from the same release's arm64 build. PROVENANCE.md inside the
-- payload records every artefact, its sha256 and the exact command.
--
-- PLACEHOLDERS: libgpg-error.so.0 names /etc (gpgrt.conf) and /usr/share/locale; both are the
-- host's, so the repack maps them there (--host).
-- .pc files, if any, -> prefix=/usr.

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
    return os.isfile(dir .. "/lib/libgpg-error.so.0")
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
