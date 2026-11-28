package = {
    spec = "2",
    name = "oh-my-posh",
    description = "Customizable shell prompt engine",
    type = "package",
    licenses = {"MIT"},
    repo = "https://github.com/JanDeDobbeleer/oh-my-posh",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    programs = {"oh-my-posh"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/JanDeDobbeleer/oh-my-posh/releases",
            resources = {
                GLOBAL = { url = {
                    linux = {
                        x86_64 = "https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/${tag}/posh-linux-amd64",
                        aarch64 = "https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/${tag}/posh-linux-arm64",
                    },
                    macosx = {
                        x86_64 = "https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/${tag}/posh-darwin-amd64",
                        aarch64 = "https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/${tag}/posh-darwin-arm64",
                    },
                    windows = {
                        x86_64 = "https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/${tag}/posh-windows-amd64.exe",
                        aarch64 = "https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/${tag}/posh-windows-arm64.exe",
                    },
                } },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/v${version}/posh-linux-${arch_alias}",
            ["latest"] = { ref = "33.4.1" },
            ["33.4.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "48f0f61b1f106ec296f024ebaae675c4cd6f2a185a4132f9adfcd4db7f3a3a9d",
                    aarch64 = "32001936db4f51d7ee4d5312823d1fb72eda8ec1fe6ce2efcaba884ec33d6129",
                },
            },
        },
        macosx = {
            source = "https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/v${version}/posh-darwin-${arch_alias}",
            ["latest"] = { ref = "33.4.1" },
            ["33.4.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "b6090ccab2544870b6b7672eb9baf9c3f18073044e84fa405af968d9c28a58b4",
                    aarch64 = "3f8667d918df22eb2e975d0dc39c71081b7cef6d843a33c070c405f039fba810",
                },
            },
        },
        windows = {
            source = "https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/v${version}/posh-windows-${arch_alias}.exe",
            ["latest"] = { ref = "33.4.1" },
            ["33.4.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "3ae87ffa0b0f0126baf3f0d176fb4e326cb6ec082b13a9cdd10d6cf8aa2f73fc",
                    aarch64 = "ecd288b918e652f187bc49212a9684aa6eb14ae4c1dbf237c418ce25ff55a0ff",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

-- 将上游单文件程序改为命令名，并在 Unix 系统上赋予执行权限
function install()
    local source = pkginfo.install_file()
    local windows = source:match("%.exe$") ~= nil
    local dir = pkginfo.install_dir()
    local target = dir .. (windows and "/oh-my-posh.exe" or "/oh-my-posh")
    os.mkdir(dir)
    os.cp(source, target)
    if not windows then
        system.exec("chmod +x '" .. target:gsub("'", "'\\''") .. "'")
    end
    return os.isfile(target)
end

-- 注册当前版本的提示符命令
function config()
    xvm.add("oh-my-posh", { bindir = pkginfo.install_dir() })
    return true
end

-- 注销当前版本的提示符命令
function uninstall()
    xvm.remove("oh-my-posh")
    return true
end
