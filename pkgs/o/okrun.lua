package = {
    spec = "2",
    homepage = "https://github.com/mcpplibs/openkal-image",

    name = "okrun",
    description = "The openkal image runner, prebuilt: runs an .oke image on the host system, the entry a [target.<triple>] runner declaration names",

    maintainers = {"https://github.com/mcpplibs/openkal-image"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/mcpplibs/openkal-image",
    docs = "https://github.com/mcpplibs/openkal-image#readme",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"runner", "openkal"},
    keywords = {"openkal", "okrun", "runner", "mcpp"},

    xvm_enable = true,

    -- The prebuilt form of mcpplibs/openkal-image's okrun, pinned to the
    -- release's own archives (the same shape pkgs/o/okld.lua takes). GLOBAL
    -- is the release; CN is the same bytes at the okrun mirror. Building
    -- from source stays the openkal-image repository's way (mcpp workspace);
    -- this package is for a machine that wants the runner alone -- an image
    -- to run, no toolchain to build one. The version is the release's. The
    -- CI matrix has no freebsd leg: a freebsd host runs its images through
    -- openkal-freebsd's own vm-runner entry, not this prebuilt.

    xpm = {
        linux = {
            source = {
                GLOBAL = "https://github.com/mcpplibs/openkal-image/releases/download/${version}/okrun-${version}-linux-${arch}.zip",
                CN = "https://gitcode.com/xlings-res/okrun/releases/download/${version}/okrun-${version}-linux-${arch}.zip",
            },
            ["latest"] = { ref = "0.6.2" },
            ["0.6.2"] = {
                url = {
                    GLOBAL = "https://github.com/mcpplibs/openkal-image/releases/download/0.6.2/okrun-0.6.2-linux-${arch}.zip",
                    CN = "https://gitcode.com/xlings-res/okrun/releases/download/0.6.2/okrun-0.6.2-linux-${arch}.zip",
                },
                sha256 = {
                    ["aarch64"] = "d8b73bbe3b0db07506fb32c55ef0aac283236d43aa62b28692373806cbbb1af3",
                    ["x86_64"] = "03fa591f6b04b127a893d90d1239aafcb4460c30896d9997f3319db5b251c792",
                },
            },
        },
        macosx = {
            source = {
                GLOBAL = "https://github.com/mcpplibs/openkal-image/releases/download/${version}/okrun-${version}-macos-${arch}.zip",
                CN = "https://gitcode.com/xlings-res/okrun/releases/download/${version}/okrun-${version}-macos-${arch}.zip",
            },
            ["latest"] = { ref = "0.6.2" },
            ["0.6.2"] = {
                url = {
                    GLOBAL = "https://github.com/mcpplibs/openkal-image/releases/download/0.6.2/okrun-0.6.2-macos-${arch}.zip",
                    CN = "https://gitcode.com/xlings-res/okrun/releases/download/0.6.2/okrun-0.6.2-macos-${arch}.zip",
                },
                sha256 = {
                    ["aarch64"] = "07a39938d2dde06c4deca3045b962abcfbe6d945bbb988f981ae33bedf1d3132",
                },
            },
        },
        windows = {
            source = {
                GLOBAL = "https://github.com/mcpplibs/openkal-image/releases/download/${version}/okrun-${version}-windows-${arch}.zip",
                CN = "https://gitcode.com/xlings-res/okrun/releases/download/${version}/okrun-${version}-windows-${arch}.zip",
            },
            ["latest"] = { ref = "0.6.2" },
            ["0.6.2"] = {
                url = {
                    GLOBAL = "https://github.com/mcpplibs/openkal-image/releases/download/0.6.2/okrun-0.6.2-windows-${arch}.zip",
                    CN = "https://gitcode.com/xlings-res/okrun/releases/download/0.6.2/okrun-0.6.2-windows-${arch}.zip",
                },
                sha256 = {
                    ["x86_64"] = "e24f1035fab5c095a26b46fbbdb52cbc8e8c19dd687d2c9ca968a07e3b1d8901",
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
    -- The per-system bindir is the release archive's own layout: a
    -- linux/macos archive holds okrun under bin/, a windows one holds
    -- okrun.exe at its root (the same split okld's config states).
    local bindir = { linux = "bin", macosx = "bin", windows = "." }
    local opts = { bindir = path.join(pkginfo.install_dir(), bindir[os.host()]) }
    xvm.add("okrun", opts)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
