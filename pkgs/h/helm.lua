-- Helm - The Kubernetes Package Manager.
--
-- Verified 2026-11-24 against the upstream GitHub release v4.3.2 and
-- https://get.helm.sh/: every SHA256 below was verified against both the
-- upstream `.sha256sum` files and downloaded archives. All six archives pack
-- `<os>-<arch>/helm[.exe]`, `LICENSE`, and `README.md` under a single
-- top-level directory (`linux-amd64`, `linux-arm64`, `darwin-amd64`,
-- `darwin-arm64`, `windows-amd64`, `windows-arm64`). The Linux binaries are
-- statically linked Go executables with no dynamic section or external libc
-- dependency.
package = {
    spec = "2",

    name = "helm",
    description = "The Kubernetes Package Manager",
    homepage = "https://helm.sh",
    authors = {"The Helm Authors"},
    maintainers = {"https://github.com/helm/helm/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/helm/helm",
    docs = "https://helm.sh/docs/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"kubernetes", "devops", "cli", "tools"},
    keywords = {"helm", "kubernetes", "k8s", "charts", "package-manager"},

    programs = {"helm"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/helm/helm/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://get.helm.sh/helm-v${version}-linux-amd64.tar.gz",
                            aarch64 = "https://get.helm.sh/helm-v${version}-linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://get.helm.sh/helm-v${version}-darwin-amd64.tar.gz",
                            aarch64 = "https://get.helm.sh/helm-v${version}-darwin-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://get.helm.sh/helm-v${version}-windows-amd64.zip",
                            aarch64 = "https://get.helm.sh/helm-v${version}-windows-arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://get.helm.sh/helm-v${version}-linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "4.3.2" },
            ["4.3.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "d1c0278d46beab79582d7e50f5b3dc206944ba8e577cde618513fd07daa53983",
                    aarch64 = "df31cb61680ef728f82c770e5280dd565617bee6b039d37e85c677288be4bbb0",
                },
            },
        },
        macosx = {
            source = "https://get.helm.sh/helm-v${version}-darwin-${arch_alias}.tar.gz",
            ["latest"] = { ref = "4.3.2" },
            ["4.3.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "9e0068e9ae18c441d27388190ee7f53ae65eba44bfe910b40bdac44c4b51fa71",
                    aarch64 = "6f3421de3a8cc2ac578c8cfb33b8edde290dde2871bc1bab12e24f2e5caeaa90",
                },
            },
        },
        windows = {
            source = "https://get.helm.sh/helm-v${version}-windows-${arch_alias}.zip",
            ["latest"] = { ref = "4.3.2" },
            ["4.3.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "77c5c782aaef1abbfafe75b88412d2b6df8e4a36d14522273397f0d02c6ecc29",
                    aarch64 = "eedb67c7838fdc266b4f33650ccab88052e9e7ec476ea180d7f0728381a26b09",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local TOP_DIRS = {
    "linux-amd64",
    "linux-arm64",
    "darwin-amd64",
    "darwin-arm64",
    "windows-amd64",
    "windows-arm64",
}

function installed()
    return payload.present({ "helm", "LICENSE" })
        or payload.present({ "helm.exe", "LICENSE" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local normalized = archive:gsub("\\", "/")
    local filename = normalized:match("([^/]+)$") or ""
    local is_win = normalized:match("%.zip$") ~= nil
    local dir_name = filename:match("^helm%-v[^-]+%-([^-]+%-[^.]+)%.")

    payload.unpack{
        extracted = dir_name and { dir_name } or TOP_DIRS,
        strip = 1,
    }
    payload.require({ is_win and "helm.exe" or "helm", "LICENSE" })
    return true
end

function config()
    xvm.add("helm", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("helm")
    return true
end
