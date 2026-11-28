package = {
    spec = "2",
    name = "navi",
    description = "An interactive command-line cheatsheet tool",
    type = "package",
    licenses = { "Apache-2.0" },
    repo = "https://github.com/denisidoro/navi",
    archs = { "x86_64" },
    status = "stable",
    programs = { "navi" },
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/denisidoro/navi/releases",
            resources = {
                GLOBAL = { url = {
                    linux = {
                        x86_64 = "https://github.com/denisidoro/navi/releases/download/${tag}/navi-${tag}-x86_64-unknown-linux-musl.tar.gz",
                    },
                    windows = {
                        x86_64 = "https://github.com/denisidoro/navi/releases/download/${tag}/navi-${tag}-x86_64-pc-windows-gnu.zip",
                    },
                } },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/denisidoro/navi/releases/download/v${version}/navi-v${version}-${arch}-unknown-linux-musl.tar.gz",
            deps = { runtime = { "xim:fzf", "xim:bash", "xim:coreutils", "xim:git" } },
            ["latest"] = { ref = "2.24.0" },
            ["2.24.0"] = {
                sha256 = { x86_64 = "f334047479241f7c8b48d091f4e814dcc798a51a74dfd04ee63cbf67e8c921ba" },
            },
        },
        windows = {
            source = "https://github.com/denisidoro/navi/releases/download/v${version}/navi-v${version}-${arch}-pc-windows-gnu.zip",
            deps = { runtime = { "xim:fzf", "xim:git" } },
            ["latest"] = { ref = "2.24.0" },
            ["2.24.0"] = {
                sha256 = { x86_64 = "db5b4babe00b93de5636c07df3d8c149972373a69f131e686b0c565051651bb9" },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.shell")

-- 检查当前平台的 navi 可执行文件
function installed()
    return payload.present({ is_host("windows") and "navi.exe" or "navi" })
end

-- 在独立安装目录解压单文件归档，避免混入共享下载目录的文件
function install()
    if is_host("windows") then
        payload.unpack{}
        return payload.require({ "navi.exe" })
    end

    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    fs.mkdir_p(dir)
    shell.exec({ "tar", "-xzf", pkginfo.install_file(), "-C", dir })
    return payload.require({ "navi" })
end

-- 注册命令，让 Windows 子进程能找到 Git 提供的 Bash 和终端工具
function config()
    local options = { bindir = pkginfo.install_dir() }
    if is_host("windows") then
        local git = assert(pkginfo.dep_install_dir("xim:git"), "navi: missing Git for Windows")
        local tools = path.join(git, "usr", "bin")
        assert(os.isfile(path.join(tools, "bash.exe")), "navi: Git for Windows is missing Bash")
        options.envs = { PATH = tools }
    end
    xvm.add("navi", options)
    return true
end

-- 移除当前 navi 版本的命令注册
function uninstall()
    xvm.remove("navi")
    return true
end
