-- macOS 的系统库和框架、Windows 的 kernel32.dll 均随操作系统提供
package = {
    spec = "2",

    name = "kubens",
    description = "Switch the active Kubernetes namespace in kubeconfig",
    type = "package",
    licenses = {"Apache-2.0"},
    repo = "https://github.com/ahmetb/kubectx",

    archs = {"x86_64", "aarch64"},
    status = "stable",
    programs = {"kubens"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/ahmetb/kubectx/releases",
            resources = {
                GLOBAL = { url = {
                    linux = {
                        x86_64 = "https://github.com/ahmetb/kubectx/releases/download/${tag}/kubens_${tag}_linux_x86_64.tar.gz",
                        aarch64 = "https://github.com/ahmetb/kubectx/releases/download/${tag}/kubens_${tag}_linux_arm64.tar.gz",
                    },
                    macosx = {
                        x86_64 = "https://github.com/ahmetb/kubectx/releases/download/${tag}/kubens_${tag}_darwin_x86_64.tar.gz",
                        aarch64 = "https://github.com/ahmetb/kubectx/releases/download/${tag}/kubens_${tag}_darwin_arm64.tar.gz",
                    },
                    windows = {
                        x86_64 = "https://github.com/ahmetb/kubectx/releases/download/${tag}/kubens_${tag}_windows_x86_64.zip",
                        aarch64 = "https://github.com/ahmetb/kubectx/releases/download/${tag}/kubens_${tag}_windows_arm64.zip",
                    },
                } },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/ahmetb/kubectx/releases/download/v${version}/kubens_v${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.11.0" },
            ["0.11.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "326c021c7b35468ed9a187b361198d0f22ae32828139c65eb6670c0d8301cc09",
                    aarch64 = "37058abe82ef20c93b44f3dc8ca2382dbb95d416cec958fbf7b8f79f011be86c",
                },
            },
        },
        macosx = {
            source = "https://github.com/ahmetb/kubectx/releases/download/v${version}/kubens_v${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.11.0" },
            ["0.11.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "9dbe1bf26fd911f2f56661a2f34bf2fe32dfd3af5f11287d0a864da92a746509",
                    aarch64 = "b1c87ddca22f1afc3e980ac807a715cd1183750022798d28a0a4e0cf66bec4e3",
                },
            },
        },
        windows = {
            source = "https://github.com/ahmetb/kubectx/releases/download/v${version}/kubens_v${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "0.11.0" },
            ["0.11.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "aa10daca6ce321377d61a7e9534911df9eee42a0b6e198000757f8d1e8d0a480",
                    aarch64 = "8d801fc38965a08488678763b92aad537086f00768ce8a7527e416e797870e0d",
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

-- 从平铺归档提取命令和许可证，将文件限制在本版本的安装目录
function install()
    local archive = pkginfo.install_file()
    if archive:match("%.zip$") then
        payload.unpack{}
        return payload.require({ "kubens.exe", "LICENSE" })
    end

    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    fs.mkdir_p(dir)
    shell.exec({ "tar", "-xzf", archive, "-C", dir })
    return payload.require({ "kubens", "LICENSE" })
end

-- 在当前子系统中注册 kubens 命令
function config()
    xvm.add("kubens", { bindir = pkginfo.install_dir() })
    return true
end

-- 移除 kubens 的命令注册
function uninstall()
    xvm.remove("kubens")
    return true
end
