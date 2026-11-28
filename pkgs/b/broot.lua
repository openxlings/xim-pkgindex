-- 上游把各架构的可执行文件放在同一个 ZIP 中，默认配置与 br 函数已嵌入程序
package = {
    spec = "2",
    name = "broot",
    description = "Explore, search and navigate directory trees in the terminal",
    type = "package",
    licenses = {"MIT"},
    repo = "https://github.com/Canop/broot",
    homepage = "https://dystroy.org/broot/",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    programs = {"broot"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/Canop/broot/releases",
            resources = {
                GLOBAL = { url = {
                    linux = {
                        x86_64 = "https://github.com/Canop/broot/releases/download/${tag}/broot_${version}.zip",
                        aarch64 = "https://github.com/Canop/broot/releases/download/${tag}/broot_${version}.zip",
                    },
                    macosx = {
                        aarch64 = "https://github.com/Canop/broot/releases/download/${tag}/broot_${version}.zip",
                    },
                    windows = {
                        x86_64 = "https://github.com/Canop/broot/releases/download/${tag}/broot_${version}.zip",
                    },
                } },
            },
        },
    },

    xpm = {
        source = "https://github.com/Canop/broot/releases/download/v${version}/broot_${version}.zip",
        linux = {
            deps = { build = { "xim:7zip" } },
            ["latest"] = { ref = "1.62.0" },
            ["1.62.0"] = {
                sha256 = {
                    x86_64 = "13630ae5d3b011ddc81fca05cb80dbee6189dad3ba393dd477f5f687c7b5106d",
                    aarch64 = "13630ae5d3b011ddc81fca05cb80dbee6189dad3ba393dd477f5f687c7b5106d",
                },
            },
        },
        macosx = {
            deps = { build = { "xim:7zip" } },
            ["latest"] = { ref = "1.62.0" },
            ["1.62.0"] = {
                sha256 = { aarch64 = "13630ae5d3b011ddc81fca05cb80dbee6189dad3ba393dd477f5f687c7b5106d" },
            },
        },
        windows = {
            deps = { build = { "xim:7zip" } },
            ["latest"] = { ref = "1.62.0" },
            ["1.62.0"] = {
                sha256 = { x86_64 = "13630ae5d3b011ddc81fca05cb80dbee6189dad3ba393dd477f5f687c7b5106d" },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.shell")
import("xim.pkgindex.winpath")

-- 解析器已按客户端 ABI 选好 Linux 版 7zz，可用其 ELF 头识别同架构的 broot
local function linux_member(extractor)
    local file = assert(io.open(extractor, "rb"))
    local header = file:read(20)
    file:close()
    assert(header and #header == 20 and header:sub(1, 6) == "\127ELF\2\1", "expected a little-endian ELF64 7zz")
    local arch = ({ [62] = "x86_64", [183] = "aarch64" })[string.unpack("<I2", header, 19)]
    return assert(arch, "unsupported 7zz ELF machine") .. "-unknown-linux-musl/broot"
end

-- 从已校验归档中只提取当前客户端架构对应的程序
function install()
    local host = os.host()
    local dir = pkginfo.install_dir()
    local archive = pkginfo.install_file()
    local sevenzip = assert(pkginfo.build_dep("7zip"), "missing xim:7zip build dependency")
    local name = host == "windows" and "broot.exe" or "broot"

    os.tryrm(dir)
    fs.mkdir_p(dir)
    if host == "windows" then
        local args = {
            winpath.native(sevenzip.path .. "/7z.exe"), "e", "-y", "-o" .. winpath.native(dir),
            winpath.native(archive), "x86_64-pc-windows-gnu/broot.exe",
        }
        system.exec("call " .. shell.join(args))
    else
        local extractor = sevenzip.path .. "/7zz"
        local member = host == "macosx" and "aarch64-apple-darwin/broot" or linux_member(extractor)
        shell.exec({ extractor, "e", "-y", "-o" .. dir, archive, member })
    end
    assert(os.isfile(dir .. "/" .. name), "broot: missing extracted program " .. name)
    return true
end

-- 将本版本的 broot 命令注册到当前子环境
function config()
    xvm.add("broot", { bindir = pkginfo.install_dir() })
    return true
end

-- 卸载时移除 broot 的命令注册
function uninstall()
    xvm.remove("broot")
    return true
end
