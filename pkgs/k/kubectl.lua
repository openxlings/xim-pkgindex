package = {
    spec = "2",

    name = "kubectl",
    description = "Kubernetes command-line tool for controlling Kubernetes clusters",
    homepage = "https://kubernetes.io/docs/reference/kubectl/",
    maintainers = {"Kubernetes Authors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/kubernetes/kubernetes",
    docs = "https://kubernetes.io/docs/reference/kubectl/kubectl/",

    -- Note: kubectl publishes raw single-file binaries under
    -- /bin/<os>/<arch>/kubectl(.exe) where basenames collide across
    -- platforms/arches; keep ci.mirror = true per repository convention,
    -- noting tools/xpkg_ci.py materialize flattens by basename.
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"kubernetes", "k8s", "cli", "cloud", "tools"},
    keywords = {"kubectl", "kubernetes", "k8s", "cli", "container", "cluster"},

    programs = {"kubectl"},
    xvm_enable = true,

    -- kubectl publishes standalone single-file binaries with no archive
    -- container. xlings skips auto-extract for unarchived binaries and hands
    -- the downloaded binary directly via pkginfo.install_file().
    extensions = {
        autoupdate = {
            source = "https://github.com/kubernetes/kubernetes/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://dl.k8s.io/release/v${version}/bin/linux/amd64/kubectl",
                            aarch64 = "https://dl.k8s.io/release/v${version}/bin/linux/arm64/kubectl",
                        },
                        macosx = {
                            x86_64 = "https://dl.k8s.io/release/v${version}/bin/darwin/amd64/kubectl",
                            aarch64 = "https://dl.k8s.io/release/v${version}/bin/darwin/arm64/kubectl",
                        },
                        windows = {
                            x86_64 = "https://dl.k8s.io/release/v${version}/bin/windows/amd64/kubectl.exe",
                            aarch64 = "https://dl.k8s.io/release/v${version}/bin/windows/arm64/kubectl.exe",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "1.37.2" },
            ["1.37.2"] = {
                x86_64 = {
                    url = "https://dl.k8s.io/release/v1.37.2/bin/linux/amd64/kubectl",
                    sha256 = "c04487523e7aa7d1493f7808174c899db93d7a9cf57531420cd76b9bd415f8f4",
                },
                aarch64 = {
                    url = "https://dl.k8s.io/release/v1.37.2/bin/linux/arm64/kubectl",
                    sha256 = "fcc16f63186659d9722014b7e02d5fdd2d4e669cb8c0ab66365d7d3b8ba03509",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "1.37.2" },
            ["1.37.2"] = {
                x86_64 = {
                    url = "https://dl.k8s.io/release/v1.37.2/bin/darwin/amd64/kubectl",
                    sha256 = "88379aff5c8111de6be0a394adffba2819e44cde269f3ab23cef76de1a48eaa8",
                },
                aarch64 = {
                    url = "https://dl.k8s.io/release/v1.37.2/bin/darwin/arm64/kubectl",
                    sha256 = "55701af0d51815ee335f240e48acf0959c3c23017ed3fa816e880c4a92bae581",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "1.37.2" },
            ["1.37.2"] = {
                x86_64 = {
                    url = "https://dl.k8s.io/release/v1.37.2/bin/windows/amd64/kubectl.exe",
                    sha256 = "1691938f7de0e931969f9968c3601cf32d6b0d573573afb4ce471f3d28f51984",
                },
                aarch64 = {
                    url = "https://dl.k8s.io/release/v1.37.2/bin/windows/arm64/kubectl.exe",
                    sha256 = "0f5965e47e4d864cf3409d8a744560b335a7c8244d0cab25e5bbba38738ef9ae",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local function _exe_name()
    return os.host() == "windows" and "kubectl.exe" or "kubectl"
end

function installed()
    return os.isfile(pkginfo.install_dir() .. "/" .. _exe_name())
end

function install()
    local dir = pkginfo.install_dir()
    local target = dir .. "/" .. _exe_name()

    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(pkginfo.install_file(), target)

    if os.host() ~= "windows" then
        system.exec(string.format([[chmod +x "%s"]], target))
    end

    if not os.isfile(target) then
        error("kubectl: binary missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("kubectl", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("kubectl")
    return true
end
