-- fastfetch - A maintained, feature-rich and performance oriented, neofetch like system information tool.
--
-- Platform and architecture coverage (verified against fastfetch-cli/fastfetch 2.71.0):
--   linux    x86_64, aarch64   fastfetch-linux-{amd64,aarch64}.tar.gz
--     (dynamic ELF; DT_NEEDED: libm.so.6, libc.so.6[, ld-linux-aarch64.so.1]; max GLIBC_2.34)
--   macosx   x86_64, aarch64   fastfetch-macos-universal.tar.gz
--   windows  x86_64            fastfetch-windows-amd64.zip

package = {
    spec = "2",

    name = "fastfetch",
    description = "A maintained, feature-rich and performance oriented, neofetch like system information tool",
    homepage = "https://github.com/fastfetch-cli/fastfetch",
    authors = {"Linus Dierheimer"},
    maintainers = {"https://github.com/fastfetch-cli/fastfetch/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/fastfetch-cli/fastfetch",
    docs = "https://github.com/fastfetch-cli/fastfetch/wiki",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "system", "tools"},
    keywords = {"fastfetch", "neofetch", "sysinfo", "system-info", "cli"},

    programs = {"fastfetch", "flashfetch"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/fastfetch-cli/fastfetch/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/fastfetch-cli/fastfetch/releases/download/${tag}/fastfetch-linux-amd64.tar.gz",
                            aarch64 = "https://github.com/fastfetch-cli/fastfetch/releases/download/${tag}/fastfetch-linux-aarch64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/fastfetch-cli/fastfetch/releases/download/${tag}/fastfetch-macos-universal.tar.gz",
                            aarch64 = "https://github.com/fastfetch-cli/fastfetch/releases/download/${tag}/fastfetch-macos-universal.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/fastfetch-cli/fastfetch/releases/download/${tag}/fastfetch-windows-amd64.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            deps = {
                runtime = { "xim:glibc@>=2.39" },
            },
            source = "https://github.com/fastfetch-cli/fastfetch/releases/download/${version}/fastfetch-linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.71.0" },
            ["2.71.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "aarch64" },
                sha256 = {
                    x86_64 = "abf5c99a3702cce8d3c7fa2cccd3ac205076ae0f2e45bced24a42a68821702d6",
                    aarch64 = "458248f2b3abab9c5e0a5b9df12cdcd1a966b355ddd5f3244a5eb47d17d33412",
                },
            },
        },
        macosx = {
            source = "https://github.com/fastfetch-cli/fastfetch/releases/download/${version}/fastfetch-macos-universal.tar.gz",
            ["latest"] = { ref = "2.71.0" },
            ["2.71.0"] = {
                sha256 = {
                    x86_64 = "6e503980ac268b072259f00e5c439eb90a420535f3593704c096b5b3bea64199",
                    aarch64 = "6e503980ac268b072259f00e5c439eb90a420535f3593704c096b5b3bea64199",
                },
            },
        },
        windows = {
            source = "https://github.com/fastfetch-cli/fastfetch/releases/download/${version}/fastfetch-windows-amd64.zip",
            ["latest"] = { ref = "2.71.0" },
            ["2.71.0"] = {
                sha256 = {
                    x86_64 = "58eeee82c52120e981891826be1c5810788bc0083b13d870684bbc85b03628e9",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

local function _bindir()
    local dir = pkginfo.install_dir()
    if os.isfile(dir .. "/fastfetch.exe") then
        return dir
    end
    return dir .. "/usr/bin"
end

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/usr/bin/fastfetch") or os.isfile(dir .. "/fastfetch.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()

    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(src .. "/*", dir)
    return true
end

function config()
    local bindir = _bindir()
    xvm.add("fastfetch", { bindir = bindir })
    xvm.add("flashfetch", { bindir = bindir })
    return true
end

function uninstall()
    xvm.remove("fastfetch")
    xvm.remove("flashfetch")
    os.tryrm(pkginfo.install_dir())
    return true
end
