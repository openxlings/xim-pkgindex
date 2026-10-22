package = {
    spec = "2",

    homepage = "https://firefox-source-docs.mozilla.org/nspr/",
    name = "nspr",
    description = "Netscape Portable Runtime (libnspr4, libplc4, libplds4), with headers and pkg-config data",

    licenses = {"MPL-2.0"},
    repo = "https://hg.mozilla.org/projects/nspr",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"system", "lib"},
    keywords = {"nspr", "mozilla", "lib"},

    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/nspr/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            aarch64 = "https://github.com/xlings-res/nspr/releases/download/${version}/nspr-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://github.com/xlings-res/nspr/releases/download/${version}/nspr-${version}-linux-x86_64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            aarch64 = "https://gitcode.com/xlings-res/nspr/releases/download/${version}/nspr-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://gitcode.com/xlings-res/nspr/releases/download/${version}/nspr-${version}-linux-x86_64.tar.gz",
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
            ["latest"] = { ref = "4.40" },
            ["4.40"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/nspr/releases/download/4.40/nspr-4.40-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/nspr/releases/download/4.40/nspr-4.40-linux-x86_64.tar.gz",
                    },
                    sha256 = "e5793e6d31f9ecd8b39c2c5dcba678125b230e735924a8e24b581a01a5a44e5a",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/nspr/releases/download/4.40/nspr-4.40-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/nspr/releases/download/4.40/nspr-4.40-linux-aarch64.tar.gz",
                    },
                    sha256 = "4d7bde97142649f1342d0a43efe459559ac26b14632ae85147c38887c436303d",
                },
            },
        },
    },
}

-- Repacked from conda-forge by .agents/tools/repack/repack.py, x86_64 from
--     nspr-4.40-h29cc59b_0.conda
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
    return os.isfile(dir .. "/lib/libnspr4.so")
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
