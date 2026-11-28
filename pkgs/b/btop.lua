-- Official static Linux musl archives; upstream publishes no macOS/Windows binaries.
-- btop v1.4.8 resolves ../share/btop/themes relative to /proc/self/exe.
-- Keep bin/btop and relocate the bundled themes accordingly, entirely inside
-- the package root. Never run upstream install/setuid scripts or copy user config.
package = {
    spec = "2",
    name = "btop",
    description = "Terminal resource monitor for processors, memory, disks, network and processes",
    homepage = "https://github.com/aristocratos/btop",
    authors = {"Aristocratos and contributors"},
    maintainers = {"aristocratos"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/aristocratos/btop",
    docs = "https://github.com/aristocratos/btop#readme",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tools", "system"},
    keywords = {"btop", "monitor", "terminal", "processes"},
    programs = {"btop"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/aristocratos/btop/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/aristocratos/btop/releases/download/${tag}/btop-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/aristocratos/btop/releases/download/${tag}/btop-aarch64-unknown-linux-musl.tar.gz",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        source = "https://github.com/aristocratos/btop/releases/download/v${version}/btop-${arch}-unknown-linux-musl.tar.gz",
        linux = {
            ["latest"] = { ref = "1.4.8" },
            ["1.4.8"] = {
                sha256 = {
                    x86_64 = "af589cf82cc9ea9c29ce050b9239a13bef2d1492256d476156e1054a42ce89ad",
                    aarch64 = "95328e26ab08f42033af26628e2d169206a5a420f35669ce17459ef85114c14c",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local required_files = {
    "bin/btop", "LICENSE", "README.md", "Img/icon.svg",
    "share/btop/themes/dracula.theme", "share/btop/themes/nord.theme",
}

function installed()
    return payload.present(required_files)
end

function install()
    payload.unpack({ extracted = "btop", strip = 1 })
    local dir = pkginfo.install_dir()
    fs.mkdir_p(dir .. "/share/btop")
    os.mv(dir .. "/themes", dir .. "/share/btop/themes")
    payload.require(required_files)
    return true
end

function config()
    xvm.add("btop", { bindir = pkginfo.install_dir() .. "/bin" })
    return true
end

function uninstall()
    xvm.remove("btop")
    return true
end
