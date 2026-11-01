-- Written by `mcpp emit xpkg --package` from the four okld-0.1.3-<os>-<arch>.zip
-- that openkal-image's `release binaries` workflow attaches to its release
-- (each `mcpp pack` of the tool over openkal-platform's hosted arrangement:
-- static on Linux, no SDK on macOS, no MSVC run-time on Windows), with the
-- index's own parts added: description, authors, license, the CN mirror.
--
-- GLOBAL is the upstream release; CN is the same bytes at
-- gitcode.com/xlings-res/okld (uploaded with `gtc release upload` and verified
-- by download), so one sha256 serves both. A POSIX package holds the program
-- under bin/ (the root's `okld` is a convenience script); a Windows one holds
-- okld.exe at its root -- hence the per-system bindir in config().
package = {
    spec = "2",
    name = "okld",
    description = "Link, check, sign and bundle ok images (openkal): the linker and bundler of .oke images and .okb bundles",

    authors = {"mcpplibs"},
    maintainers = {"https://github.com/mcpplibs/openkal-image/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/mcpplibs/openkal-image",
    docs = "https://github.com/mcpplibs/openkal-image#readme",
    homepage = "https://github.com/mcpplibs/openkal-image",
    type = "package",
    status = "dev", -- 0.x: the ok-image format and its tools are pre-1.0
    categories = {"openkal", "runtime", "tools"},
    keywords = {"openkal", "linker", "ok-image", "okb", "bundle"},
    archs = {"aarch64", "x86_64"},
    programs = {"okld"},
    xvm_enable = true,
    xpm = {
        linux = {
            source = {
                GLOBAL = "https://github.com/mcpplibs/openkal-image/releases/download/${version}/okld-${version}-linux-${arch}.zip",
                CN = "https://gitcode.com/xlings-res/okld/releases/download/${version}/okld-${version}-linux-${arch}.zip",
            },
            ["latest"] = { ref = "0.1.3" },
            ["0.1.3"] = {
                sha256 = {
                    ["aarch64"] = "f52be058ebf3b1af8151633ac5a05ae209f699e363373ea53e6d62e16d0f6366",
                    ["x86_64"] = "baa13039f8f2b0a87577c79c85c5ea815eae34ca6aebb5cf156bb7553b543f54",
                },
            },
        },
        macosx = {
            source = {
                GLOBAL = "https://github.com/mcpplibs/openkal-image/releases/download/${version}/okld-${version}-macos-${arch}.zip",
                CN = "https://gitcode.com/xlings-res/okld/releases/download/${version}/okld-${version}-macos-${arch}.zip",
            },
            ["latest"] = { ref = "0.1.3" },
            ["0.1.3"] = {
                sha256 = {
                    ["aarch64"] = "f392b94a9398a604f668cca9868324961db98823cb30c1c72a1e9c5e4d463534",
                },
            },
        },
        windows = {
            source = {
                GLOBAL = "https://github.com/mcpplibs/openkal-image/releases/download/${version}/okld-${version}-windows-${arch}.zip",
                CN = "https://gitcode.com/xlings-res/okld/releases/download/${version}/okld-${version}-windows-${arch}.zip",
            },
            ["latest"] = { ref = "0.1.3" },
            ["0.1.3"] = {
                sha256 = {
                    ["x86_64"] = "bd8a58922655a7fe0f6852729552a5112ca90af4b808507593adcc30b993c2dd",
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
    xvm.add("okld", opts)
    return true
end

function uninstall()
    xvm.remove("okld")
    return true
end
