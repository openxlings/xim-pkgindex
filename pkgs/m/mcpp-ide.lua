-- Written by `mcpp emit xpkg --package` from mcpp-ide's universal package
-- (mcpp-ide-0.1.0-openkal.tar.gz, `mcpp pack --mode self-contained --systems
-- linux,macos,windows` of the backend's ok images over openkal-platform), with
-- the index's own parts added: description, authors, license, the CN mirror.
--
-- One asset serves every system: the package holds the x86_64 and aarch64
-- images, the launchers bin/mcpp-ide and bin/mcpp-ide.cmd, and okrun for each
-- system it names (libexec/okrun/<os>-<arch>/), so it depends on nothing.
-- GLOBAL is the upstream release; CN is the same bytes at
-- gitcode.com/xlings-res/mcpp-ide (uploaded with `gtc release upload` and
-- verified by download), so one sha256 serves both.
package = {
    spec = "2",
    name = "mcpp-ide",
    description = "The IDE backend for mcpp: sessions, jobs, records and view models over mcpp's control contract, served as JSON-RPC by `mcpp-ide serve` (one ok-image package for every system)",

    authors = {"mcpp-community"},
    maintainers = {"https://github.com/mcpp-community/mcpp-ide/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/mcpp-community/mcpp-ide",
    docs = "https://github.com/mcpp-community/mcpp-ide#readme",
    homepage = "https://github.com/mcpp-community/mcpp-ide",
    type = "package",
    status = "dev", -- 0.x
    categories = {"cpp", "ide", "mcpp"},
    keywords = {"cpp", "c++", "modules", "mcpp", "ide", "json-rpc", "openkal"},
    archs = {"aarch64", "x86_64"},
    programs = {"mcpp-ide"},
    xvm_enable = true,
    xpm = {
        linux = {
            ["latest"] = { ref = "0.1.0" },
            ["0.1.0"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mcpp-ide/releases/download/v0.1.0/mcpp-ide-0.1.0-openkal.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mcpp-ide/releases/download/v0.1.0/mcpp-ide-0.1.0-openkal.tar.gz",
                },
                sha256 = "4c033c3decaabb90fc87786dc6b0e1ba01becddf457f1eb1f1c3a28066256149",
            },
        },
        macosx = {
            ["latest"] = { ref = "0.1.0" },
            ["0.1.0"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mcpp-ide/releases/download/v0.1.0/mcpp-ide-0.1.0-openkal.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mcpp-ide/releases/download/v0.1.0/mcpp-ide-0.1.0-openkal.tar.gz",
                },
                sha256 = "4c033c3decaabb90fc87786dc6b0e1ba01becddf457f1eb1f1c3a28066256149",
            },
        },
        windows = {
            ["latest"] = { ref = "0.1.0" },
            ["0.1.0"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mcpp-ide/releases/download/v0.1.0/mcpp-ide-0.1.0-openkal.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mcpp-ide/releases/download/v0.1.0/mcpp-ide-0.1.0-openkal.tar.gz",
                },
                sha256 = "4c033c3decaabb90fc87786dc6b0e1ba01becddf457f1eb1f1c3a28066256149",
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
    for _, ext in ipairs({ ".tar.gz" }) do
        if top:sub(-#ext) == ext then top = top:sub(1, #top - #ext) break end
    end
    if not os.isdir(top) then return false end
    os.tryrm(pkginfo.install_dir())
    os.mv(top, pkginfo.install_dir())
    return os.isdir(pkginfo.install_dir())
end

function config()
    local opts = { bindir = path.join(pkginfo.install_dir(), "bin") }
    if os.host() == "windows" then opts.alias = "mcpp-ide.cmd" end
    xvm.add("mcpp-ide", opts)
    return true
end

function uninstall()
    xvm.remove("mcpp-ide")
    return true
end
