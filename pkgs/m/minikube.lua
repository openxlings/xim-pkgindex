-- Portable CLI only: upstream release assets are raw executables, not archives.
-- No kicbase images, ISOs, container/VM drivers, cluster, or privileged setup.
-- Windows ARM64 is omitted because upstream v1.39.0 has no matching CLI asset.
-- Linux x86_64 needs host glibc >= 2.14 (libc, libpthread, libresolv, libdl);
-- Linux aarch64 is static. macOS uses system libraries/frameworks only;
-- Windows imports kernel32.dll. No bundled or installed runtime/driver stack.
package = {
    spec = "2",
    name = "minikube",
    description = "Run local Kubernetes clusters with the portable minikube CLI",
    homepage = "https://minikube.sigs.k8s.io/",
    authors = {"Kubernetes Authors"},
    maintainers = {"kubernetes"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/kubernetes/minikube",
    docs = "https://minikube.sigs.k8s.io/docs/",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"kubernetes", "containers", "cli", "devops"},
    keywords = {"minikube", "kubernetes", "k8s", "cluster"},
    programs = {"minikube"},
    xvm_enable = true,
    ci = { mirror = true },

    -- Only official upstream resources; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/kubernetes/minikube/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/kubernetes/minikube/releases/download/${tag}/minikube-linux-amd64",
                            aarch64 = "https://github.com/kubernetes/minikube/releases/download/${tag}/minikube-linux-arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/kubernetes/minikube/releases/download/${tag}/minikube-darwin-amd64",
                            aarch64 = "https://github.com/kubernetes/minikube/releases/download/${tag}/minikube-darwin-arm64",
                        },
                        windows = {
                            x86_64 = "https://github.com/kubernetes/minikube/releases/download/${tag}/minikube-windows-amd64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/kubernetes/minikube/releases/download/v${version}/minikube-linux-${arch_alias}",
            ["latest"] = { ref = "1.39.0" },
            ["1.39.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "b738496da01be06bbaf80c688f57ce25acd3849fbb518155f3a88e03ef555aa4",
                    aarch64 = "202f331cb677761c5aec81c58472d16d65707358b9f66226210be3fe3275b1c3",
                },
            },
        },
        macosx = {
            source = "https://github.com/kubernetes/minikube/releases/download/v${version}/minikube-darwin-${arch_alias}",
            ["latest"] = { ref = "1.39.0" },
            ["1.39.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "12247c653b6f1b58ac7bb634f6d1e31a1d33f7c63a6f99cbdaef160de15d2175",
                    aarch64 = "78ad8f2f3b35a81e9c2501b1a65961c1521aa4c76fbbe1b5409053db49e29bcd",
                },
            },
        },
        windows = {
            source = "https://github.com/kubernetes/minikube/releases/download/v${version}/minikube-windows-${arch_alias}.exe",
            ["latest"] = { ref = "1.39.0" },
            ["1.39.0"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "776386465ded2cf610ae397fe302de32c44d12134b5ce7ce98ab05bd7713b360",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/minikube") or os.isfile(dir .. "/minikube.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_windows = src:lower():match("%.exe$") ~= nil or os.getenv("OS") == "Windows_NT"
    local target = dir .. (is_windows and "/minikube.exe" or "/minikube")
    if not os.isfile(src) then
        error("minikube: downloaded executable missing at " .. tostring(src))
    end
    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(src, target)
    if not is_windows then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("minikube: installed executable missing at " .. target)
    end
    return true
end

function config()
    xvm.add("minikube", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("minikube")
    return true
end
