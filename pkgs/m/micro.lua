package = {
    spec = "2",
    name = "micro",
    description = "A terminal-based text editor",
    type = "package",
    licenses = {"MIT"},
    repo = "https://github.com/micro-editor/micro",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    programs = {"micro"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/micro-editor/micro/releases",
            resources = {
                GLOBAL = { url = {
                    linux = {
                        x86_64 = "https://github.com/micro-editor/micro/releases/download/${tag}/micro-${version}-linux64-static.tar.gz",
                        aarch64 = "https://github.com/micro-editor/micro/releases/download/${tag}/micro-${version}-linux-arm64.tar.gz",
                    },
                    macosx = {
                        x86_64 = "https://github.com/micro-editor/micro/releases/download/${tag}/micro-${version}-osx.tar.gz",
                        aarch64 = "https://github.com/micro-editor/micro/releases/download/${tag}/micro-${version}-macos-arm64.tar.gz",
                    },
                    windows = {
                        x86_64 = "https://github.com/micro-editor/micro/releases/download/${tag}/micro-${version}-win64.zip",
                        aarch64 = "https://github.com/micro-editor/micro/releases/download/${tag}/micro-${version}-win-arm64.zip",
                    },
                } },
            },
        },
    },

    xpm = {
        source = "https://github.com/micro-editor/micro/releases/download/v${version}/micro-${version}-${arch_alias}.${ext}",
        linux = {
            ["latest"] = { ref = "2.0.15" },
            ["2.0.15"] = {
                arch_alias = { x86_64 = "linux64-static", aarch64 = "linux-arm64" },
                sha256 = {
                    x86_64 = "267d238eac1e26ed053d13d4d48bd421b87f9eb538b604f0b2f74a85598b6cc2",
                    aarch64 = "5ca127857bf5500be3879f1a70b27556e737a49da04a1be5334de9e8e8781ad9",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "2.0.15" },
            ["2.0.15"] = {
                arch_alias = { x86_64 = "osx", aarch64 = "macos-arm64" },
                sha256 = {
                    x86_64 = "d765b9bdd6478c4f5a3cbd5a93ebe7bab2b9cec30b5350016975cf1045855cee",
                    aarch64 = "2ff285cc49f2ac3f7a6e9110e2dabd3c848b73eed56a8396d627c0af80a34624",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "2.0.15" },
            ["2.0.15"] = {
                arch_alias = { x86_64 = "win64", aarch64 = "win-arm64" },
                sha256 = {
                    x86_64 = "90635c53c11aa2a0d997f5e3ed43528877740725500207640b29551cef18479b",
                    aarch64 = "c3d5acd5fc05afd65b7dcad3a18e0c08148e4885b4044be8d19e22a8efbf670b",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

-- 安装上游版本目录，并检查编辑器和随附的许可证文件
function install()
    payload.unpack{ extracted = "micro-" .. pkginfo.version(), strip = 1 }
    local exe = is_host("windows") and "micro.exe" or "micro"
    return payload.require{ exe, "LICENSE", "LICENSE-THIRD-PARTY" }
end

-- 将当前版本的编辑器注册到 xvm
function config()
    xvm.add("micro", { bindir = pkginfo.install_dir() })
    return true
end

-- 移除当前版本的编辑器注册
function uninstall()
    xvm.remove("micro")
    return true
end
