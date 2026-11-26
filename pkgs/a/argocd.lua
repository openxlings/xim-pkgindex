-- argocd - Declarative Continuous Deployment for Kubernetes CLI (argoproj/argo-cd).
--
-- Distribution: upstream publishes standalone raw single-file binaries on
-- GitHub Releases (no archive container). xlings skips auto-extract for
-- unarchived binaries and passes the downloaded file via pkginfo.install_file(),
-- which install() moves to `<install_dir>/argocd` (or `argocd.exe` on Windows).
--
-- Platform and architecture coverage (verified against argoproj/argo-cd v3.6.3;
-- SHA-256 matched cli_checksums.txt, GitHub release digests, and downloaded bytes):
--   linux/x86_64    argocd-linux-amd64        (ELF64 static, readelf -d: no dynamic section, ldd: not dynamic)
--   linux/aarch64   argocd-linux-arm64        (ELF64 static, readelf -d: no dynamic section, ldd: not dynamic)
--   macosx/x86_64   argocd-darwin-amd64       (Mach-O 64-bit x86_64)
--   macosx/aarch64  argocd-darwin-arm64       (Mach-O 64-bit arm64)
--   windows/x86_64  argocd-windows-amd64.exe  (PE32+ console x86-64, imports kernel32.dll only; no windows-arm64 asset upstream)

package = {
    spec = "2",

    name = "argocd",
    description = "Declarative Continuous Deployment for Kubernetes",
    homepage = "https://argo-cd.readthedocs.io",
    authors = {"Argo Project Authors"},
    maintainers = {"argoproj"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/argoproj/argo-cd",
    docs = "https://argo-cd.readthedocs.io/en/stable/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"kubernetes", "k8s", "gitops", "cd", "devops", "cli", "tools"},
    keywords = {"argocd", "argo", "gitops", "kubernetes", "k8s", "cd", "deployment", "cli"},

    programs = {"argocd"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/argoproj/argo-cd/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/argoproj/argo-cd/releases/download/${tag}/argocd-linux-amd64",
                            aarch64 = "https://github.com/argoproj/argo-cd/releases/download/${tag}/argocd-linux-arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/argoproj/argo-cd/releases/download/${tag}/argocd-darwin-amd64",
                            aarch64 = "https://github.com/argoproj/argo-cd/releases/download/${tag}/argocd-darwin-arm64",
                        },
                        windows = {
                            x86_64 = "https://github.com/argoproj/argo-cd/releases/download/${tag}/argocd-windows-amd64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/argoproj/argo-cd/releases/download/v${version}/argocd-linux-${arch_alias}",
            ["latest"] = { ref = "3.6.3" },
            ["3.6.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "3750cd7ed2a2ef05c640344b86f29aa99c9783e847c8f326c81e3900ad39412b",
                    aarch64 = "04a7b681d6c5eec193159705c5556114f8cba98abada4c17c3991124065e1964",
                },
            },
        },
        macosx = {
            source = "https://github.com/argoproj/argo-cd/releases/download/v${version}/argocd-darwin-${arch_alias}",
            ["latest"] = { ref = "3.6.3" },
            ["3.6.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "21acb09f5bbf53ee04b213fa9e0d1ce80a5efa6ad597107084dbc7c09a601721",
                    aarch64 = "1b45f9805b54375d7b0d18fb646b64dca153b98527443716e07b0aced45ce623",
                },
            },
        },
        windows = {
            -- Upstream publishes only argocd-windows-amd64.exe (no windows-arm64 asset).
            source = "https://github.com/argoproj/argo-cd/releases/download/v${version}/argocd-windows-${arch_alias}.exe",
            ["latest"] = { ref = "3.6.3" },
            ["3.6.3"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "e49cfc037bac335932bfbb9e5ff62663a56082bb4255f8ee2c1583cc4e39d8c2",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local function _is_windows_payload(file)
    return tostring(file):lower():match("%.exe$") ~= nil
end

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/argocd") or os.isfile(dir .. "/argocd.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src)
    local target = dir .. (is_win and "/argocd.exe" or "/argocd")

    if not os.isfile(src) then
        error("argocd: downloaded binary not found at " .. tostring(src))
    end

    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(src, target)
    if not is_win then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("argocd: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("argocd", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("argocd")
    return true
end
