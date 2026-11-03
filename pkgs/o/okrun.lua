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
            ["latest"] = { ref = "0.4.2" },
            ["0.4.2"] = {
                sha256 = {
                    ["aarch64"] = "520fea263887bb809cd1f2a08d7b81f634dec46bd6d1f0c7b797d821ee871def",
                    ["x86_64"] = "a3116aee2771b007b25d73756d612e87003ee1ec64ee55402fb50e9edc732921",
                },
            },
            ["0.3.1"] = {
                sha256 = {
                    ["aarch64"] = "1f3c9ae5e49e24b149d6a41ffca7326ee17783ed3152139a9ffa1e60f8ae7c4b",
                    ["x86_64"] = "3103b2aac055fe6e174aba9dd7192d0e027770a5710aff935f6804fff027323c",
                },
            },
            ["0.3.0"] = {
                sha256 = {
                    ["aarch64"] = "f1ff25ea8ea6cecd8e9d7d212bd2de42ba0d5950db6da157ed83120b72528d74",
                    ["x86_64"] = "60b14920966bec1e37e544ab1e5004d7e13669361b5952cdb408e20c4e2f9b8d",
                },
            },
            ["0.1.9"] = {
                sha256 = {
                    ["aarch64"] = "d1010705720bd800bd8125cc8bd17b5f765417940aaf153de674eef89b3a521a",
                    ["x86_64"] = "f6e40e1e36d1988a7c4cc991a0479b05840b0d23507194b265a02e9e5c1dd734",
                },
            },
            ["0.1.8"] = {
                sha256 = {
                    ["aarch64"] = "4cb38fcd762f5a535c87ee6da83744c43eccc09b57a310c3158ac92be40e06e0",
                    ["x86_64"] = "d0b966f8aa6297c9266ecce8f6b16b6187e28191d716f0d3dd55efdfb9d479f8",
                },
            },
            ["0.1.7"] = {
                sha256 = {
                    ["aarch64"] = "5668eed1c0d4bf36c329aec45d210071d72e803310055e7dd78214edcc9a7b55",
                    ["x86_64"] = "ddaa089c77d79d7b4283fe7ce7b3ec04c9a8e8852f062e9b41e1c4209f315b41",
                },
            },
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
            ["latest"] = { ref = "0.4.2" },
            ["0.4.2"] = {
                sha256 = {
                    ["aarch64"] = "7545eb1886a7fc1079284a2a79649df03ca6cdce208c7e07f6e929063aaeb538",
                },
            },
            ["0.3.1"] = {
                sha256 = {
                    ["aarch64"] = "95fb1374cd5333ea94e0ed947275312be38ec3d53699ae7ce859c6a9b2b76873",
                },
            },
            ["0.3.0"] = {
                sha256 = {
                    ["aarch64"] = "f2c031737084146023f2f7f61367bec36ac9beae7cee83d215c0c05e23edd78d",
                },
            },
            ["0.1.9"] = {
                sha256 = {
                    ["aarch64"] = "ca61fcc40d5c959cf1243ca29098b082fc42621fe12d33a386ccabafa258c39d",
                },
            },
            ["0.1.8"] = {
                sha256 = {
                    ["aarch64"] = "d6a3692afc71a3c4d4a950d33b9add9b2df3a34d9580d26abb381a10fe30f363",
                },
            },
            ["0.1.7"] = {
                sha256 = {
                    ["aarch64"] = "67cbe7057a42fa7bfad1fbf8665831a320d15af538225bb9e9f1f22c07a837f2",
                },
            },
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
            ["latest"] = { ref = "0.4.2" },
            ["0.4.2"] = {
                sha256 = {
                    ["x86_64"] = "ff2d119e93cb69c7fe41f9123c91f8b9361c01296dccf6ee8aa27152b9c9659c",
                },
            },
            ["0.3.1"] = {
                sha256 = {
                    ["x86_64"] = "ee233584eb9c8d3e248117e9915eaa3616ae7823a982c6194ddf3824af835b87",
                },
            },
            ["0.3.0"] = {
                sha256 = {
                    ["x86_64"] = "6a500781d62dc3822fa092d8f26bfb39174065e37c945365fd014dd270966017",
                },
            },
            ["0.1.9"] = {
                sha256 = {
                    ["x86_64"] = "4f9d53ac77ff223c83dafca87fe2cc5640d941f7824c67dd16d43e9e717f746f",
                },
            },
            ["0.1.8"] = {
                sha256 = {
                    ["x86_64"] = "4bb1f1cdc86775ee4de228161972c3566fd1378e45273099015d1ec349dfa75c",
                },
            },
            ["0.1.7"] = {
                sha256 = {
                    ["x86_64"] = "f775bbb89dd5b00d08445b381f7f37324a4d59787e45b955eefd0b80d871f1ec",
                },
            },
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
