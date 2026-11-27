-- jj 的 Git 后端要求 Git 2.42 及以上，依赖由索引提供
-- macOS Git 与 Windows ARM64 Git 的索引资源尚未齐备，首版不声明这些平台
package = {
    spec = "2",
    name = "jj",
    description = "Git-compatible version control with undoable operations and flexible history editing",
    type = "package",
    licenses = {"Apache-2.0"},
    repo = "https://github.com/jj-vcs/jj",
    homepage = "https://jj-vcs.dev/",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"git", "tools"},
    programs = {"jj"},
    xvm_enable = true,
    ci = { mirror = true },
    extensions = {
        autoupdate = {
            source = "https://github.com/jj-vcs/jj/releases",
            resources = { GLOBAL = { required = true, url = {
                linux = {
                    x86_64 = "https://github.com/jj-vcs/jj/releases/download/${tag}/jj-${tag}-x86_64-unknown-linux-musl.tar.gz",
                    aarch64 = "https://github.com/jj-vcs/jj/releases/download/${tag}/jj-${tag}-aarch64-unknown-linux-musl.tar.gz",
                },
                windows = {
                    x86_64 = "https://github.com/jj-vcs/jj/releases/download/${tag}/jj-${tag}-x86_64-pc-windows-msvc.zip",
                },
            } } },
        },
    },
    xpm = {
        linux = {
            deps = { runtime = {"xim:git@>=2.42.0"} },
            source = "https://github.com/jj-vcs/jj/releases/download/v${version}/jj-v${version}-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.47.1" },
            ["0.47.1"] = {
                arch_alias = {
                    x86_64 = "x86_64-unknown-linux-musl",
                    aarch64 = "aarch64-unknown-linux-musl",
                },
                sha256 = {
                    x86_64 = "d4b657f622ee50929c8916466dfa3d6a6c17a0a32b50e7b2c793707ec9ebcad7",
                    aarch64 = "0f300e1576de8dabe0a9dedf0b87ae44f8accea5cf54d9a342a51061c1fb1bcd",
                },
            },
        },
        windows = {
            deps = { runtime = {"xim:git@>=2.42.0"} },
            source = "https://github.com/jj-vcs/jj/releases/download/v${version}/jj-v${version}-${arch_alias}.zip",
            ["latest"] = { ref = "0.47.1" },
            ["0.47.1"] = {
                arch_alias = {
                    x86_64 = "x86_64-pc-windows-msvc",
                },
                sha256 = {
                    x86_64 = "72f9f80bc99d07a7f48d5f219cf5bab91f7e906e4b53f6c827948e646cd1152f",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.shell")

-- 返回当前平台必须保留的程序与许可证文件
local function required_files(windows)
    return {windows and "jj.exe" or "jj", "LICENSE", "README.md"}
end

-- 检查程序和随包文档是否完整落地
function installed()
    return payload.present(required_files(false)) or payload.present(required_files(true))
end

-- 将官方平铺归档独立解压，避免搬入其他包的共享缓存内容
function install()
    local archive = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local windows = archive:match("%.zip$") ~= nil
    if not os.isfile(archive) then error("jj: missing release archive: " .. archive) end
    if windows then
        payload.unpack{}
    else
        os.tryrm(dir)
        fs.mkdir_p(dir)
        shell.exec({"tar", "-xzf", archive, "-C", dir})
    end
    payload.require(required_files(windows))
    if not windows then shell.exec({"chmod", "+x", dir .. "/jj"}) end
    return true
end

-- 将当前版本的程序注册到隔离环境
function config()
    xvm.add("jj", { bindir = pkginfo.install_dir() })
    return true
end

-- 移除当前包的程序注册，由框架清理安装目录
function uninstall()
    xvm.remove("jj")
    return true
end
