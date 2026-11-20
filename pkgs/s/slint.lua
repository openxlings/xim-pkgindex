-- slint — Slint's C++ SDK: libslint_cpp, its headers (include/slint) and
-- slint-compiler, built from the release tag by .agents/tools/slint/build-slint.sh
-- on native runners (.github/workflows/slint-payload.yml) and published to
-- xlings-res/slint, GitHub and GitCode byte-identical.
--
-- The feature set is upstream CMake's DESKTOP DEFAULT (api/cpp/cmake/
-- SlintFeatures.cmake): interpreter, backend-winit, renderer-femtovg,
-- renderer-software, accessibility, system-tray, testing, and the compiler
-- (archives named `-default-`). Built so, libslint_cpp NEEDs libfontconfig and
-- the C runtime only — X11, Wayland and GL are dlopen()ed — so on Linux the
-- payload declares xim:fontconfig, and selfcontain.seal writes its RUNPATH.
--
-- Linux is x86_64 only: xim:fontconfig (and the freetype/expat under it) has
-- no aarch64 payload, and an aarch64 slint would link a host fontconfig the
-- recipe cannot name. A linux-aarch64 row follows an aarch64 xim:fontconfig.
--
-- Layout, as upstream's SDK (a CMake user's find_package works from it):
--   bin/slint-compiler, lib/libslint_cpp.{so,dylib} | bin/slint_cpp.dll +
--   lib/slint_cpp.lib, include/slint/, licenses/, BUILD-INFO.txt
--
-- License: GPL-3.0-only OR LicenseRef-Slint-Royalty-free-2.0 OR
-- LicenseRef-Slint-Software-3.0, at the user's choice (licenses/LICENSE.md).
package = {
    spec = "2",
    homepage = "https://slint.dev",
    name = "slint",
    description = "Slint C++ SDK (libslint_cpp, headers, slint-compiler; upstream CMake's default features)",
    authors = {"SixtyFPS GmbH"},
    licenses = {"GPL-3.0-only", "LicenseRef-Slint-Royalty-free-2.0", "LicenseRef-Slint-Software-3.0"},
    repo = "https://github.com/slint-ui/slint",
    type = "package",
    archs = {"x86_64", "aarch64", "arm64"},
    status = "stable",
    categories = {"gui", "lib"},
    keywords = {"slint", "gui", "ui"},
    xpm = {
        linux = {
            deps = { "xim:fontconfig@2.15.0.1", "xim:gcc-runtime@15.1.0", "xim:glibc" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.19.0" },
            ["1.19.0"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/slint/releases/download/1.19.0/slint-1.19.0-default-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/slint/releases/download/1.19.0/slint-1.19.0-default-linux-x86_64.tar.gz",
                    },
                    sha256 = "447194e4238f16249eb323cba9190a7deff38fc089617c614116b9aaaf17b43f",
                },
            },
        },
        macosx = {
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.19.0" },
            ["1.19.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/slint/releases/download/1.19.0/slint-1.19.0-default-macosx-arm64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/slint/releases/download/1.19.0/slint-1.19.0-default-macosx-arm64.tar.gz",
                },
                sha256 = "a7d3b9c4c2bec1d34001b166e8bd6a665e3dfc261eb796508f918f8d8f009798",
            },
        },
        windows = {
            exports = {
                runtime = { libdirs = { "bin" } },
            },
            ["latest"] = { ref = "1.19.0" },
            ["1.19.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/slint/releases/download/1.19.0/slint-1.19.0-default-windows-x86_64.zip",
                    CN     = "https://gitcode.com/xlings-res/slint/releases/download/1.19.0/slint-1.19.0-default-windows-x86_64.zip",
                },
                sha256 = "41997f5c774fcb26cbaab38e2fd9d655af973b7d6103b9d9cd085c9533e26be1",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    local top = pkginfo.install_file():replace(".tar.gz", ""):replace(".zip", "")
    top = path.filename(top)
    if not os.isdir(top) then
        return false
    end
    os.tryrm(dir)
    os.mv(top, dir)
    if os.host() == "linux" then
        selfcontain.seal(dir)
    end
    return os.isfile(path.join(dir, "include", "slint", "slint.h"))
end

function config()
    xvm.add(package.name, { type = "group" })
    xvm.add("slint-compiler", { bindir = path.join(pkginfo.install_dir(), "bin") })
    return true
end

function uninstall()
    xvm.remove("slint-compiler")
    xvm.remove(package.name)
    return true
end
