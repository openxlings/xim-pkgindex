package = {
    spec = "2",

    homepage = "https://llvm.org",
    name = "libllvm",
    description = "LLVM as a shared library — the code generator mesa's llvmpipe and radeonsi use",

    authors = {"LLVM Project"},
    licenses = {"Apache-2.0 WITH LLVM-exception"},
    repo = "https://github.com/llvm/llvm-project",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libllvm", "graphics", "gl"},

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
                url = {
                    GLOBAL = "https://github.com/xlings-res/libllvm/releases/download/20.1.7/libllvm-20.1.7-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libllvm/releases/download/20.1.7/libllvm-20.1.7-linux-x86_64.tar.gz",
                },
                sha256 = "1de66726fb14ed043e1f6a17ffb80e03578c2e01da85f024c46689140d31246f",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("libllvm-20.1.7", dir)
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
