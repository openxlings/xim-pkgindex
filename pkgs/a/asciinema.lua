-- Linux ARM64 的官方程序动态链接 glibc 与 libgcc，运行依赖由索引提供
package = {
    spec = "2",
    name = "asciinema",
    description = "Record, replay and stream terminal sessions",
    type = "package",
    licenses = {"GPL-3.0"},
    repo = "https://github.com/asciinema/asciinema",
    homepage = "https://asciinema.org/",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"terminal", "tools"},
    programs = {"asciinema"},
    xvm_enable = true,
    ci = { mirror = true },
    extensions = {
        autoupdate = {
            source = "https://github.com/asciinema/asciinema/releases",
            resources = { GLOBAL = { required = true, url = {
                linux = {
                    x86_64 = "https://github.com/asciinema/asciinema/releases/download/${tag}/asciinema-x86_64-unknown-linux-musl",
                    aarch64 = "https://github.com/asciinema/asciinema/releases/download/${tag}/asciinema-aarch64-unknown-linux-gnu",
                },
                macosx = {
                    x86_64 = "https://github.com/asciinema/asciinema/releases/download/${tag}/asciinema-x86_64-apple-darwin",
                    aarch64 = "https://github.com/asciinema/asciinema/releases/download/${tag}/asciinema-aarch64-apple-darwin",
                },
            } } },
        },
    },
    xpm = {
        linux = {
            deps = { runtime = {"xim:glibc@>=2.39", "xim:gcc-runtime@15.1.0"} },
            source = "https://github.com/asciinema/asciinema/releases/download/v${version}/asciinema-${arch_alias}",
            ["latest"] = { ref = "3.2.1" },
            ["3.2.1"] = {
                arch_alias = {
                    x86_64 = "x86_64-unknown-linux-musl",
                    aarch64 = "aarch64-unknown-linux-gnu",
                },
                sha256 = {
                    x86_64 = "bec9781bc8f297a9d3d74ff60205599507f2abba1183578b8b2f22be4c999214",
                    aarch64 = "b516a6d896844c0ffbc96e0a55afe4cbcc79216abde0fc64fdda4e39bee421ea",
                },
            },
        },
        macosx = {
            source = "https://github.com/asciinema/asciinema/releases/download/v${version}/asciinema-${arch_alias}",
            ["latest"] = { ref = "3.2.1" },
            ["3.2.1"] = {
                arch_alias = {
                    x86_64 = "x86_64-apple-darwin",
                    aarch64 = "aarch64-apple-darwin",
                },
                sha256 = {
                    x86_64 = "1b388af0e1566ab19deea663b0ce64730ad46ade2825fadd43cc88f0bd28140a",
                    aarch64 = "1f0c76da7855601df93e5dccdf69b7c683b81beff1411e38b3802de1f5fc7a1c",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.shell")

-- 确认当前版本的录制程序已经落地
function installed()
    return os.isfile(pkginfo.install_dir() .. "/asciinema")
end

-- 将官方独立程序复制到安装目录并赋予执行权限
function install()
    local source = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    if not os.isfile(source) then error("asciinema: missing downloaded binary: " .. source) end
    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.cp(source, dir .. "/asciinema")
    shell.exec({"chmod", "+x", dir .. "/asciinema"})
    if not installed() then error("asciinema: installed binary is missing") end
    return true
end

-- 注册隔离环境中的录制程序
function config()
    xvm.add("asciinema", { bindir = pkginfo.install_dir() })
    return true
end

-- 注销程序，由框架移除当前版本载荷
function uninstall()
    xvm.remove("asciinema")
    return true
end
