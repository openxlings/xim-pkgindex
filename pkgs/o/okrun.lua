-- Written by `mcpp emit xpkg --package` from the four okrun-<version>-<os>-<arch>.zip
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
            ["latest"] = { ref = "0.1.6" },
            ["0.1.6"] = {
                sha256 = {
                    ["aarch64"] = "2bc85d6f915ed570b1b36ae0de3105c3dbae3d9561c197bfa5369968a4977246",
                    ["x86_64"] = "4ffeabbcf1b27de80c261984d1cfd3406066441d98d81ce0394d4c21588c51c4",
                },
            },
            ["0.1.5"] = {
                sha256 = {
                    ["aarch64"] = "74d1e3c61884faf42f12e359d02a11a428172bf70cdce3499f01984a77c8b623",
                    ["x86_64"] = "725328091cb283172ff14d409bb5a3401eb59733ce33907318905fce30b69a2c",
                },
            },
            ["0.1.4"] = {
                sha256 = {
                    ["aarch64"] = "d85a3c80f4af8b04694dc94efce5a2e01d3b8432d588092f557bed11874c0f07",
                    ["x86_64"] = "3c1a0367b8462d7721daacaae5054e1c49fe38706f0bee46dd18b796a659ea42",
                },
            },
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
            ["latest"] = { ref = "0.1.6" },
            ["0.1.6"] = {
                sha256 = {
                    ["aarch64"] = "0967054374c5835efb140226643fe7515f83480af96e0e7e8bd8ed0befa15a95",
                },
            },
            ["0.1.5"] = {
                sha256 = {
                    ["aarch64"] = "bf3f96589826e8e9dcfb44a3ec7d1a0578935a2cf4c64c2a25c7975036b3009c",
                },
            },
            ["0.1.4"] = {
                sha256 = {
                    ["aarch64"] = "851a89983888ca3a3e313cccdc28edea3926dd994f2c68ed3ce6d21d202fbe4c",
                },
            },
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
            ["latest"] = { ref = "0.1.6" },
            ["0.1.6"] = {
                sha256 = {
                    ["x86_64"] = "09a646a821a4eabc74b30a03d7d69936d9fd87cdeec2970234ece576ff1f7e6d",
                },
            },
            ["0.1.5"] = {
                sha256 = {
                    ["x86_64"] = "a58a6bdab9ca1e25690ff81372c06f3692b32a8a61a17b98f1d5ca546dbde368",
                },
            },
            ["0.1.4"] = {
                sha256 = {
                    ["x86_64"] = "978e39f9c715a5bf21067ef2f28c46442402b2a96d47ff696c6ea822e789653d",
                },
            },
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
