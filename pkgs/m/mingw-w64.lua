function __mingw_cn_mirror_url(version)
    return string.format(
        "https://gitcode.com/xlings-res/mingw-w64/releases/download/%s/mingw-w64-%s-windows-x86_64.zip", version, version)
end

package = {
    spec = "1",
    -- base info
    name = "mingw-w64",
    description = "A complete runtime environment for GCC & LLVM for Windows",

    licenses = {"ZPL 2.1"},
    contributors = "https://github.com/mingw-w64/mingw-w64/graphs/contributors",
    repo = "https://github.com/mingw-w64/mingw-w64",
    homepage = "https://mingw-w64.org",
    docs = "https://www.winlibs.com",

    -- xim pkg info
    type = "package",
    archs = { "x86_64" },
    status = "stable", -- dev, stable, deprecated
    categories = { "mingw", "cross-platform", "runtime" },
    keywords = { "gcc", "runtime", "c", "c++", "mingw", "llvm" },

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        windows = {
            ["latest"] = { ref = "13.0.0" },
            ["13.0.0"] = {
                url = {
                    GLOBAL =
                    "https://github.com/brechtsanders/winlibs_mingw/releases/download/15.1.0posix-13.0.0-ucrt-r2/winlibs-x86_64-posix-seh-gcc-15.1.0-mingw-w64ucrt-13.0.0-r2.zip",
                    CN = __mingw_cn_mirror_url("13.0.0"),
                },
                sha256 = nil
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")

local gcc_version_map = {
    ["13.0.0"] = "15.1.0",
}

function installed()
    local installdir = pkginfo.install_dir()
    return os.isfile(path.join(installdir, "version_info.txt"))
end

function install()
    os.tryrm(pkginfo.install_dir())
    os.mv("mingw64", pkginfo.install_dir())
    return true
end

function config()
    local mingw_bindir = path.join(pkginfo.install_dir(), "bin")

    local config = {
        bindir = mingw_bindir,
    }

    xvm.add("x86_64-w64-mingw32-gcc", config)
    xvm.add("x86_64-w64-mingw32-g++", config)
    xvm.add("x86_64-w64-mingw32-c++", config)

    config.version = string.format([[%s(mingw-w64-%s)]],
        gcc_version_map[pkginfo.version()], pkginfo.version()
    )

    xvm.add("gcc", config)
    xvm.add("c++", config)
    xvm.add("g++", config)

    -- Group placeholder: `mingw-w64` is an umbrella toolchain package whose
    -- registered programs are the gcc/g++/c++ multilib triples.
    -- Empty placeholder under the package name so install detection
    -- (`xvm info mingw-w64`) finds an entry.
    -- `group` is the only kind that both avoids a bogus shim under the
    -- package name and lets `xlings remove` find the package; removal of a
    -- group root needs xlings >= 2026.7.x, which is why CI pins a current
    -- client (older ones refuse the remove and leak the shims).
    xvm.add("mingw-w64", { type = "group" })

    __config_mingw_bin(mingw_bindir)

    return true
end

function uninstall()
    xvm.remove("x86_64-w64-mingw32-gcc")
    xvm.remove("x86_64-w64-mingw32-g++")
    xvm.remove("x86_64-w64-mingw32-c++")

    local version = string.format([[%s(mingw-w64-%s)]],
        gcc_version_map[pkginfo.version()], pkginfo.version()
    )
    xvm.remove("gcc", version)
    xvm.remove("g++", version)
    xvm.remove("c++", version)

    xvm.remove("mingw-w64")

    -- TODO: support multi-version (auto switch bin path)
    __config_mingw_bin("")

    return true
end

-- private environment variables

function __config_mingw_bin(bin_path)
    -- create temp script
    local tmp_bat_script = path.join(os.getenv("TEMP") or os.getenv("TMP") or "C:\\Temp", "mingw-w64-config.bat")

    -- 1. set MINGW_BIN env
    log.info("set MINGW_BIN -> %s", bin_path)
    io.writefile(tmp_bat_script, string.format([[setx MINGW_BIN "%s"]], bin_path))
    system.exec(tmp_bat_script)

    -- 2. add MINGW_BIN to PATH
    local path_env = os.getenv("PATH")
    if not path_env:find("MINGW_BIN", 1, true) then
        log.warn("MINGW_BIN not found in PATH, adding it...")
        io.writefile(tmp_bat_script, [[setx PATH "%%MINGW_BIN%%;%PATH%"]])
        system.exec(tmp_bat_script)
    end
end
