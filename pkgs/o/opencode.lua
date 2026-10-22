-- opencode -- an AI coding agent for the terminal (sst/opencode), from its
-- official release binaries (one bun-compiled program per target).
--
-- Linux takes the glibc build: `opencode` NEEDS only libc, libpthread, libdl
-- and libm, so glibc is its one dependency and elfpatch puts it on the
-- index's loader. macOS and Windows binaries are self-contained.
--
-- GLOBAL = the upstream GitHub release (tag v<version>).
-- CN     = gitcode.com/xlings-res/opencode, the same files under the same
--          names (tag without the `v`), copied by the index's mirror job --
--          which reads these templates literally.

package = {
    spec = "1",

    name = "opencode",
    description = "opencode: an AI coding agent built for the terminal",
    homepage = "https://opencode.ai",
    repo = "https://github.com/sst/opencode",
    licenses = {"MIT"},
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"ai", "agent", "cli", "tools"},
    keywords = {"opencode", "agent", "ai", "coding", "llm", "terminal"},

    programs = {"opencode"},
    xvm_enable = true,



    extensions = {
        autoupdate = {
            source = "https://github.com/sst/opencode/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/sst/opencode/releases/download/v${version}/opencode-linux-x64.tar.gz",
                            aarch64 = "https://github.com/sst/opencode/releases/download/v${version}/opencode-linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/sst/opencode/releases/download/v${version}/opencode-darwin-x64.zip",
                            aarch64 = "https://github.com/sst/opencode/releases/download/v${version}/opencode-darwin-arm64.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/sst/opencode/releases/download/v${version}/opencode-windows-x64.zip",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            x86_64 = "https://gitcode.com/xlings-res/opencode/releases/download/${version}/opencode-linux-x64.tar.gz",
                            aarch64 = "https://gitcode.com/xlings-res/opencode/releases/download/${version}/opencode-linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://gitcode.com/xlings-res/opencode/releases/download/${version}/opencode-darwin-x64.zip",
                            aarch64 = "https://gitcode.com/xlings-res/opencode/releases/download/${version}/opencode-darwin-arm64.zip",
                        },
                        windows = {
                            x86_64 = "https://gitcode.com/xlings-res/opencode/releases/download/${version}/opencode-windows-x64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            deps = { "xim:glibc@>=2.39" },
            source = {
                GLOBAL = "https://github.com/sst/opencode/releases/download/v${version}/opencode-linux-${arch_alias}.tar.gz",
                CN = "https://gitcode.com/xlings-res/opencode/releases/download/${version}/opencode-linux-${arch_alias}.tar.gz",
            },
            ["latest"] = { ref = "1.19.0" },
            ["1.19.0"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "7bb9e61ad6feacf2e89c10a6a2c1840e3de4220bb50ba1fc7110f31806076aec",
                    aarch64 = "e9841d43d3e1a8f36ed2691592d3b8b4fb097e606c8b559a277a1b845840e26b",
                },
            },
        },
        macosx = {
            source = {
                GLOBAL = "https://github.com/sst/opencode/releases/download/v${version}/opencode-darwin-${arch_alias}.zip",
                CN = "https://gitcode.com/xlings-res/opencode/releases/download/${version}/opencode-darwin-${arch_alias}.zip",
            },
            ["latest"] = { ref = "1.19.0" },
            ["1.19.0"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "515380b03f3410f2178c8c1c7ba6d1e9556a3bdee2a01d114e7b1681952131a0",
                    aarch64 = "0d5f511948d6fbfedf9bb16753c0ac42613dcc8de75d9deb7e8d0cf584c8fba6",
                },
            },
        },
        windows = {
            source = {
                GLOBAL = "https://github.com/sst/opencode/releases/download/v${version}/opencode-windows-${arch_alias}.zip",
                CN = "https://gitcode.com/xlings-res/opencode/releases/download/${version}/opencode-windows-${arch_alias}.zip",
            },
            ["latest"] = { ref = "1.19.0" },
            ["1.19.0"] = {
                arch_alias = { x86_64 = "x64" },
                sha256 = {
                    x86_64 = "17108e9448c4fdad48eb8714c4ed6f5dfc9cf86c2eb8f2ce5d02043fef806eb5",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")

local function _exe()
    return is_host("windows") and "opencode.exe" or "opencode"
end

function install()
    -- The archive holds the program alone, beside the download.
    local src = path.join(path.directory(pkginfo.install_file()), _exe())
    if not os.isfile(src) then return false end
    os.tryrm(pkginfo.install_dir())
    os.mkdir(path.join(pkginfo.install_dir(), "bin"))
    local dst = path.join(pkginfo.install_dir(), "bin", _exe())
    os.mv(src, dst)
    if not is_host("windows") then system.exec(string.format([[chmod +x "%s"]], dst)) end
    return os.isfile(dst)
end

function config()
    xvm.add("opencode", { bindir = path.join(pkginfo.install_dir(), "bin") })
    return true
end

function uninstall()
    xvm.remove("opencode")
    return true
end
