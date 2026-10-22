package = {
    spec = "1",
    homepage = "https://www.gnu.org/software/make",
    -- base info
    name = "make",
    description = "GNU Make — tool which controls the generation of executables from source files",

    authors = {"GNU"},
    licenses = {"GPL-3.0+"},
    repo = "https://git.savannah.gnu.org/cgit/make.git",
    docs = "https://www.gnu.org/software/make/manual",

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"make", "gnu", "build-system"},
    keywords = {"make", "gnu", "makefile", "build-system"},

    -- xvm: xlings version management
    xvm_enable = true,

    programs = { "make", "gmake" },

    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/make/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/xlings-res/make/releases/download/${version}/make-${version}-linux-x86_64.tar.gz",
                            aarch64 = "https://github.com/xlings-res/make/releases/download/${version}/make-${version}-linux-aarch64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            x86_64 = "https://gitcode.com/xlings-res/make/releases/download/${version}/make-${version}-linux-x86_64.tar.gz",
                            aarch64 = "https://gitcode.com/xlings-res/make/releases/download/${version}/make-${version}-linux-aarch64.tar.gz",
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
            ["latest"] = { ref = "4.3" },
            ["4.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "2c7aa65d8369a39b5ecc55d4521a4d8065532f270535fffb6f504272fac6d5f0",
                    aarch64 = "c6bd4aba44e154f12bad3380e046b10f50fbdb174397a3710d65dcf6ae989b40",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    -- XLINGS_RES ships a musl-static tarball (no glibc dependency, so no
    -- elfpatch step is needed). It extracts to `make-<ver>-linux-x86_64/`.
    local srcdir = pkginfo.install_file():replace(".tar.gz", "")
    os.tryrm(pkginfo.install_dir())
    os.mv(srcdir, pkginfo.install_dir())
    return true
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    local root = "make@" .. pkginfo.version()
    xvm.add("make", { bindir = bindir })
    -- gmake is a symlink to `make` in the same bindir; tie its lifecycle to make@<ver>.
    xvm.add("gmake", { bindir = bindir, binding = root })
    return true
end

function uninstall()
    xvm.remove("make")
    xvm.remove("gmake")
    return true
end
