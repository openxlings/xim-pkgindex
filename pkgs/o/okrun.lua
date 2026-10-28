-- Written by `mcpp emit xpkg --package` from the four okrun-0.1.3-<os>-<arch>.zip
-- that openkal-image's `release binaries` workflow attaches to its release
-- (each `mcpp pack` of the tool over openkal-platform's hosted arrangement:
-- static on Linux, no SDK on macOS, no MSVC run-time on Windows), with the
-- index's own parts added: description, authors, license, the CN mirror.
--
-- GLOBAL is the upstream release; CN is the same bytes at
-- gitcode.com/xlings-res/okrun (uploaded with `gtc release upload` and verified
-- by download), so one sha256 serves both. A POSIX package holds the program
-- under bin/ (the root's `okrun` is a convenience script); a Windows one holds
-- okrun.exe at its root -- hence the per-system bindir in config().
package = {
    spec = "2",
    name = "okrun",
    description = "Run ok images (openkal) on Linux, macOS and Windows: the loader that starts an image (.oke) or an image bundle (.okb) of the machine's architecture",

    authors = {"mcpplibs"},
    maintainers = {"https://github.com/mcpplibs/openkal-image/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/mcpplibs/openkal-image",
    docs = "https://github.com/mcpplibs/openkal-image#readme",
    homepage = "https://github.com/mcpplibs/openkal-image",
    type = "package",
    status = "dev", -- 0.x: the ok-image format and its tools are pre-1.0
    categories = {"openkal", "runtime", "tools"},
    keywords = {"openkal", "loader", "ok-image", "okb", "runtime"},
    archs = {"aarch64", "x86_64"},
    programs = {"okrun"},
    xvm_enable = true,
    xpm = {
        linux = {
            source = {
                GLOBAL = "https://github.com/mcpplibs/openkal-image/releases/download/${version}/okrun-${version}-linux-${arch}.zip",
                CN = "https://gitcode.com/xlings-res/okrun/releases/download/${version}/okrun-${version}-linux-${arch}.zip",
            },
            ["latest"] = { ref = "0.1.3" },
            ["0.1.3"] = {
                sha256 = {
                    ["aarch64"] = "09a0ff3174f62a4410000149814f4cd75a726aba0623ee8addf21263d2da417e",
                    ["x86_64"] = "dfcf30f81d38ab2e8dbb9edac186dc7d7ace6da48a44533a9f17425151ef82a9",
                },
            },
        },
        macosx = {
            source = {
                GLOBAL = "https://github.com/mcpplibs/openkal-image/releases/download/${version}/okrun-${version}-macos-${arch}.zip",
                CN = "https://gitcode.com/xlings-res/okrun/releases/download/${version}/okrun-${version}-macos-${arch}.zip",
            },
            ["latest"] = { ref = "0.1.3" },
            ["0.1.3"] = {
                sha256 = {
                    ["aarch64"] = "e15ace24913b697b583ca8b172e9701b68288500f3744f36ec6d764bd4e091d7",
                },
            },
        },
        windows = {
            source = {
                GLOBAL = "https://github.com/mcpplibs/openkal-image/releases/download/${version}/okrun-${version}-windows-${arch}.zip",
                CN = "https://gitcode.com/xlings-res/okrun/releases/download/${version}/okrun-${version}-windows-${arch}.zip",
            },
            ["latest"] = { ref = "0.1.3" },
            ["0.1.3"] = {
                sha256 = {
                    ["x86_64"] = "738c17d4d8b95b6db956a247f246d68f87a73532ddddfcd8437b594538336125",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    -- The archive's one top-level directory is the package; it is named
    -- after the archive, which xim unpacks beside it.
    local top = pkginfo.install_file()
    for _, ext in ipairs({ ".zip" }) do
        if top:sub(-#ext) == ext then top = top:sub(1, #top - #ext) break end
    end
    if not os.isdir(top) then return false end
    os.tryrm(pkginfo.install_dir())
    os.mv(top, pkginfo.install_dir())
    return os.isdir(pkginfo.install_dir())
end

function config()
    local bindir = { linux = "bin", macosx = "bin", windows = "." }
    local opts = { bindir = path.join(pkginfo.install_dir(), bindir[os.host()]) }
    xvm.add("okrun", opts)
    return true
end

function uninstall()
    xvm.remove("okrun")
    return true
end
