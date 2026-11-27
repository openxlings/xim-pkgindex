package = {
    spec = "2",

    homepage = "https://llvm.org",
    name = "libllvm",
    description = "LLVM as a shared library — the code generator mesa's llvmpipe and radeonsi use",

    authors = {"LLVM Project"},
    licenses = {"Apache-2.0 WITH LLVM-exception"},
    repo = "https://github.com/llvm/llvm-project",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libllvm", "graphics", "gl"},

    extensions = {


        autoupdate = {
            source = "https://github.com/xlings-res/libllvm/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            aarch64 = "https://github.com/xlings-res/libllvm/releases/download/${version}/libllvm-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://github.com/xlings-res/libllvm/releases/download/${version}/libllvm-${version}-linux-x86_64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            aarch64 = "https://gitcode.com/xlings-res/libllvm/releases/download/${version}/libllvm-${version}-linux-aarch64.tar.gz",
                            x86_64 = "https://gitcode.com/xlings-res/libllvm/releases/download/${version}/libllvm-${version}-linux-x86_64.tar.gz",
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
            deps = { "xim:gcc-runtime@>=15", "xim:glibc@>=2.38" },
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "20.1.7" },
            ["20.1.7"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libllvm/releases/download/20.1.7/libllvm-20.1.7-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libllvm/releases/download/20.1.7/libllvm-20.1.7-linux-x86_64.tar.gz",
                    },
                    sha256 = "1de66726fb14ed043e1f6a17ffb80e03578c2e01da85f024c46689140d31246f",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/libllvm/releases/download/20.1.7/libllvm-20.1.7-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/libllvm/releases/download/20.1.7/libllvm-20.1.7-linux-aarch64.tar.gz",
                    },
                    sha256 = "a8d79cb8d1a4ebd75ae4d75850056a2cec6f42f7b447441947ff42b786b96e80",
                },
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
    os.mv("libllvm-20.1.7", dir)

    -- Stamp this payload's own dependency closure onto its libraries, so they
    -- resolve from our payloads and not from the host's ld.so.cache.
    selfcontain.seal(pkginfo.install_dir())
    return true
end

function config()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    sysroot.declare_libs(pkginfo.install_dir(), "lib", binding, pkginfo.version())
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
