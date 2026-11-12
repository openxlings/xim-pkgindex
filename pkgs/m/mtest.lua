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
            ["latest"] = { ref = "0.6.1" },
            ["0.6.1"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.6.1/mtest-0.6.1-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.6.1/mtest-0.6.1-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "d6caae62095dfc1a3977ce384fb039bb6b97706eaf18e8203dbacb10aa5df9a4",
                    ["x86_64"] = "d6caae62095dfc1a3977ce384fb039bb6b97706eaf18e8203dbacb10aa5df9a4",
                },
            },
            ["0.6.0"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.6.0/mtest-0.6.0-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.6.0/mtest-0.6.0-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "f69c57b860cfa1160c78259b93c1b38592c51d3bf8485be54ca359d2199126df",
                    ["x86_64"] = "f69c57b860cfa1160c78259b93c1b38592c51d3bf8485be54ca359d2199126df",
                },
            },
            ["0.5.2"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.5.2/mtest-0.5.2-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.5.2/mtest-0.5.2-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "be443f8c546b3f4628dcd3f1eb6f45b4d698a7f805232f966349faf8250863c6",
                    ["x86_64"] = "be443f8c546b3f4628dcd3f1eb6f45b4d698a7f805232f966349faf8250863c6",
                },
            },
            ["0.4.1"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.4.1/mtest-0.4.1-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.4.1/mtest-0.4.1-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "8431cbc9389e6e6a876096d60d533bb3ab00dd662923a0904887cfd7a52eb634",
                    ["x86_64"] = "8431cbc9389e6e6a876096d60d533bb3ab00dd662923a0904887cfd7a52eb634",
                },
            },
            ["0.4.0"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.4.0/mtest-0.4.0-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.4.0/mtest-0.4.0-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "b62e4ac7cd76b20dbdc48a5d041d377444e8815ee7a4ff1e7686145d13acc925",
                    ["x86_64"] = "b62e4ac7cd76b20dbdc48a5d041d377444e8815ee7a4ff1e7686145d13acc925",
                },
            },
            ["0.3.0"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.3.0/mtest-0.3.0-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.3.0/mtest-0.3.0-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "0d17fdfe1ad4f48706528a4a20c57e645a6d1b6dbc1e0820ef1966af97f50cbf",
                    ["x86_64"] = "0d17fdfe1ad4f48706528a4a20c57e645a6d1b6dbc1e0820ef1966af97f50cbf",
                },
            },
            ["0.2.0"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.2.0/mtest-0.2.0-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.2.0/mtest-0.2.0-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "283e8752d1aa009c95ed9399247ab93a46a3f734c7c1cf7b7af8ca1b5de0070b",
                    ["x86_64"] = "283e8752d1aa009c95ed9399247ab93a46a3f734c7c1cf7b7af8ca1b5de0070b",
                },
            },
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
            ["latest"] = { ref = "0.6.1" },
            ["0.6.1"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.6.1/mtest-0.6.1-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.6.1/mtest-0.6.1-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "d6caae62095dfc1a3977ce384fb039bb6b97706eaf18e8203dbacb10aa5df9a4",
                },
            },
            ["0.6.0"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.6.0/mtest-0.6.0-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.6.0/mtest-0.6.0-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "f69c57b860cfa1160c78259b93c1b38592c51d3bf8485be54ca359d2199126df",
                },
            },
            ["0.5.2"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.5.2/mtest-0.5.2-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.5.2/mtest-0.5.2-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "be443f8c546b3f4628dcd3f1eb6f45b4d698a7f805232f966349faf8250863c6",
                },
            },
            ["0.4.1"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.4.1/mtest-0.4.1-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.4.1/mtest-0.4.1-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "8431cbc9389e6e6a876096d60d533bb3ab00dd662923a0904887cfd7a52eb634",
                },
            },
            ["0.4.0"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.4.0/mtest-0.4.0-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.4.0/mtest-0.4.0-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "b62e4ac7cd76b20dbdc48a5d041d377444e8815ee7a4ff1e7686145d13acc925",
                },
            },
            ["0.3.0"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.3.0/mtest-0.3.0-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.3.0/mtest-0.3.0-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "0d17fdfe1ad4f48706528a4a20c57e645a6d1b6dbc1e0820ef1966af97f50cbf",
                },
            },
            ["0.2.0"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.2.0/mtest-0.2.0-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.2.0/mtest-0.2.0-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["aarch64"] = "283e8752d1aa009c95ed9399247ab93a46a3f734c7c1cf7b7af8ca1b5de0070b",
                },
            },
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
            ["latest"] = { ref = "0.6.1" },
            ["0.6.1"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.6.1/mtest-0.6.1-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.6.1/mtest-0.6.1-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["x86_64"] = "d6caae62095dfc1a3977ce384fb039bb6b97706eaf18e8203dbacb10aa5df9a4",
                },
            },
            ["0.6.0"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.6.0/mtest-0.6.0-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.6.0/mtest-0.6.0-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["x86_64"] = "f69c57b860cfa1160c78259b93c1b38592c51d3bf8485be54ca359d2199126df",
                },
            },
            ["0.5.2"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.5.2/mtest-0.5.2-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.5.2/mtest-0.5.2-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["x86_64"] = "be443f8c546b3f4628dcd3f1eb6f45b4d698a7f805232f966349faf8250863c6",
                },
            },
            ["0.4.1"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.4.1/mtest-0.4.1-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.4.1/mtest-0.4.1-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["x86_64"] = "8431cbc9389e6e6a876096d60d533bb3ab00dd662923a0904887cfd7a52eb634",
                },
            },
            ["0.4.0"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.4.0/mtest-0.4.0-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.4.0/mtest-0.4.0-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["x86_64"] = "b62e4ac7cd76b20dbdc48a5d041d377444e8815ee7a4ff1e7686145d13acc925",
                },
            },
            ["0.3.0"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.3.0/mtest-0.3.0-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.3.0/mtest-0.3.0-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["x86_64"] = "0d17fdfe1ad4f48706528a4a20c57e645a6d1b6dbc1e0820ef1966af97f50cbf",
                },
            },
            ["0.2.0"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/mtest/releases/download/v0.2.0/mtest-0.2.0-openkal-bundle-all.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mtest/releases/download/v0.2.0/mtest-0.2.0-openkal-bundle-all.tar.gz",
                },
                sha256 = {
                    ["x86_64"] = "283e8752d1aa009c95ed9399247ab93a46a3f734c7c1cf7b7af8ca1b5de0070b",
                },
            },
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
