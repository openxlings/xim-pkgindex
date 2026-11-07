-- Written by `mcpp emit xpkg --package` from mtest's universal package
-- (mtest-<version>-openkal-bundle-all.tar.gz, `mcpp pack mtest -p mtest.mtest --target openkal
-- --mode self-contained --systems all` of the engine's ok images over openkal-platform), with the
-- index's own parts added: description, authors, license, the CN mirror.
--
-- One asset serves every system: the package holds the x86_64 and aarch64 images, the launchers
-- bin/mtest and bin/mtest.exe, and okrun for each system it names (libexec/okrun/<os>-<arch>/), so
-- it depends on nothing. GLOBAL is the upstream release; CN is the same bytes at
-- gitcode.com/xlings-res/mtest (uploaded with `gtc release upload` and verified by download), so
-- one sha256 serves both.
package = {
    spec = "2",
    name = "mtest",
    description = "mtest: run tests of any language by the mtest test protocol, store every run, and explain, analyze and gate them on the command line, as a JSON-RPC service and as MCP tools (one ok-image package for every system)",

    authors = {"mcpp-community"},
    maintainers = {"https://github.com/mcpp-community/mtest/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/mcpp-community/mtest",
    docs = "https://github.com/mcpp-community/mtest#readme",
    homepage = "https://github.com/mcpp-community/mtest",
    type = "package",
    status = "dev", -- 0.x
    categories = {"testing", "cpp", "mcpp"},
    keywords = {"test", "testing", "protocol", "mcp", "agent", "openkal"},
    archs = {"aarch64", "x86_64"},
    programs = {"mtest"},
    xvm_enable = true,
    xpm = {
        linux = {
            ["latest"] = { ref = "0.1.0" },
            ["0.1.0"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.1.0/mtest-0.1.0-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.1.0/mtest-0.1.0-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "087759881c1a85b9013254bf60a6a7daebfafdd5ddcec327a3733ff09a8c476a",
                    ["x86_64"] = "087759881c1a85b9013254bf60a6a7daebfafdd5ddcec327a3733ff09a8c476a",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "0.1.0" },
            ["0.1.0"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.1.0/mtest-0.1.0-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.1.0/mtest-0.1.0-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "087759881c1a85b9013254bf60a6a7daebfafdd5ddcec327a3733ff09a8c476a",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "0.1.0" },
            ["0.1.0"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.1.0/mtest-0.1.0-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.1.0/mtest-0.1.0-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["x86_64"] = "087759881c1a85b9013254bf60a6a7daebfafdd5ddcec327a3733ff09a8c476a",
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
    if os.host() == "windows" then opts.alias = "mtest.exe" end
    xvm.add("mtest", opts)
    return true
end

function uninstall()
    xvm.remove("mtest")
    return true
end
