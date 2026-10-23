package = {
    spec = "2",

    homepage = "https://sites.google.com/site/fullycapable/",
    name = "libcap",
    description = "The POSIX capabilities libraries (libcap, libpsx), with headers and pkg-config data",

    licenses = {"BSD-3-Clause"},
    repo = "https://git.kernel.org/pub/scm/libs/libcap/libcap.git",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"system", "lib"},
    keywords = {"libcap", "capabilities", "lib"},

    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/libcap/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            aarch64 = "https://github.com/xlings-res/libcap/releases/download/${version}/libcap-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://github.com/xlings-res/libcap/releases/download/${version}/libcap-${version}-linux-x86_64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            aarch64 = "https://gitcode.com/xlings-res/libcap/releases/download/${version}/libcap-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://gitcode.com/xlings-res/libcap/releases/download/${version}/libcap-${version}-linux-x86_64.tar.gz",
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
            ["latest"] = { ref = "2.71" },
            ["2.71"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libcap/releases/download/2.71/libcap-2.71-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libcap/releases/download/2.71/libcap-2.71-linux-x86_64.tar.gz",
                    },
                    sha256 = "0f13a2fa973f82c7e99d06231ff77c2ff07ad2d7b6c51d999ce42f18c396a619",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libcap/releases/download/2.71/libcap-2.71-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libcap/releases/download/2.71/libcap-2.71-linux-aarch64.tar.gz",
                    },
                    sha256 = "16b4198432a304f3f90f806fc630c0f49622b35efe0d350bc64812c443fe83dd",
                },
            },
        },
    },
}

-- Repacked from conda-forge by .agents/tools/repack/repack.py, x86_64 from
--     libcap-2.71-h39aace5_0.conda
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
    return os.isfile(dir .. "/lib/libcap.so.2")
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
