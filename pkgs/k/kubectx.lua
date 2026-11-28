-- macOS 由系统提供 libSystem、libresolv、CoreFoundation 和 Security，Windows 由系统提供 kernel32.dll
package = {
    spec = "2",
    name = "kubectx",
    description = "List and switch Kubernetes contexts in kubeconfig",
    type = "package",
    licenses = {"Apache-2.0"},
    repo = "https://github.com/ahmetb/kubectx",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    programs = {"kubectx"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/ahmetb/kubectx/releases",
            resources = {
                GLOBAL = { url = {
                    linux = {
                        x86_64 = "https://github.com/ahmetb/kubectx/releases/download/${tag}/kubectx_${tag}_linux_x86_64.tar.gz",
                        aarch64 = "https://github.com/ahmetb/kubectx/releases/download/${tag}/kubectx_${tag}_linux_arm64.tar.gz",
                    },
                    macosx = {
                        x86_64 = "https://github.com/ahmetb/kubectx/releases/download/${tag}/kubectx_${tag}_darwin_x86_64.tar.gz",
                        aarch64 = "https://github.com/ahmetb/kubectx/releases/download/${tag}/kubectx_${tag}_darwin_arm64.tar.gz",
                    },
                    windows = {
                        x86_64 = "https://github.com/ahmetb/kubectx/releases/download/${tag}/kubectx_${tag}_windows_x86_64.zip",
                        aarch64 = "https://github.com/ahmetb/kubectx/releases/download/${tag}/kubectx_${tag}_windows_arm64.zip",
                    },
                } },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/ahmetb/kubectx/releases/download/v${version}/kubectx_v${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.11.0" },
            ["0.11.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "08e031c54fbffb3f100e904e4eae94bba2730fedf4869921fda79e4d7a8f5d4c",
                    aarch64 = "1dac2072216689e773325cb7587b858ea7415706ebcf04e23bf80e7e70555340",
                },
            },
        },
        macosx = {
            source = "https://github.com/ahmetb/kubectx/releases/download/v${version}/kubectx_v${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.11.0" },
            ["0.11.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "80097893b478c55be51ffe826c172f0fd5095d23cca02adbcbcabc412700a689",
                    aarch64 = "b8c9b5150ca6d902474a115cf7e535831081b9ae10cbe561ea36c82bb3823d02",
                },
            },
        },
        windows = {
            source = "https://github.com/ahmetb/kubectx/releases/download/v${version}/kubectx_v${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "0.11.0" },
            ["0.11.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "a28fc2f0c69e715c34ea6d7520b9a17aa00cea642ff6fab0c64614d436d47a5d",
                    aarch64 = "b195c4e6aaa65585df35b5f4cde8516b844d961026517198a7da9d631442417f",
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

-- 将上游程序和许可证直接解压到本版本的安装目录
function install()
    local archive = pkginfo.install_file()
    if archive:match("%.zip$") then
        payload.unpack{}
        return payload.require({ "kubectx.exe", "LICENSE" })
    end

    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    fs.mkdir_p(dir)
    shell.exec({ "tar", "-xzf", archive, "-C", dir })
    return payload.require({ "kubectx", "LICENSE" })
end

-- 注册当前版本的 kubectx 命令
function config()
    xvm.add("kubectx", { bindir = pkginfo.install_dir() })
    return true
end

-- 注销当前版本的 kubectx 命令
function uninstall()
    xvm.remove("kubectx")
    return true
end
