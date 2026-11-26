-- kubeconform — A FAST Kubernetes manifests validator, with support for Custom Resources.
--
-- Verified 2026-11-26 against upstream GitHub release v0.8.0 (yannh/kubeconform):
--   linux    x86_64, aarch64   kubeconform-linux-{amd64,arm64}.tar.gz
--   macosx   x86_64, aarch64   kubeconform-darwin-{amd64,arm64}.tar.gz
--   windows  x86_64, aarch64   kubeconform-windows-{amd64,arm64}.zip
--
-- Every archive is flat at root containing `LICENSE` and a single executable
-- (`kubeconform` on POSIX, `kubeconform.exe` on Windows). All six SHA-256 digests
-- match upstream `CHECKSUMS` and locally downloaded archives.
--
-- Both Linux ELF binaries are statically linked Go executables (`readelf -d`:
-- no dynamic section; `ldd`: not a dynamic executable), so no runtime library
-- deps are required. Both Windows PE32+ executables (`0x8664`, `0xaa64`) import
-- only `kernel32.dll` (no VCRUNTIME DLL dependency). `kubeconform "/?"` does
-- not block on stdin and exits immediately with status 1 (`/? - failed
-- validation: lstat /?: no such file or directory`).

package = {
    spec = "2",

    name = "kubeconform",
    description = "A FAST Kubernetes manifests validator, with support for Custom Resources",
    homepage = "https://github.com/yannh/kubeconform",
    authors = {"Yann Hamon"},
    maintainers = {"https://github.com/yannh/kubeconform/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/yannh/kubeconform",
    docs = "https://github.com/yannh/kubeconform#usage",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"kubernetes", "devops", "cli", "yaml", "tools"},
    keywords = {"kubeconform", "kubernetes", "k8s", "yaml", "schema", "validation", "cli"},

    programs = {"kubeconform"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/yannh/kubeconform/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/yannh/kubeconform/releases/download/${tag}/kubeconform-linux-amd64.tar.gz",
                            aarch64 = "https://github.com/yannh/kubeconform/releases/download/${tag}/kubeconform-linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/yannh/kubeconform/releases/download/${tag}/kubeconform-darwin-amd64.tar.gz",
                            aarch64 = "https://github.com/yannh/kubeconform/releases/download/${tag}/kubeconform-darwin-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/yannh/kubeconform/releases/download/${tag}/kubeconform-windows-amd64.zip",
                            aarch64 = "https://github.com/yannh/kubeconform/releases/download/${tag}/kubeconform-windows-arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/yannh/kubeconform/releases/download/v${version}/kubeconform-linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.8.0" },
            ["0.8.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "9bc2bffbf71f261128533edaf912153948b7ff238f9a531ae6d34466ec287883",
                    aarch64 = "1f53fc8e81258197a35e8603054162a5af1de8c5af13746c71ab680d9534ed87",
                },
            },
        },
        macosx = {
            source = "https://github.com/yannh/kubeconform/releases/download/v${version}/kubeconform-darwin-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.8.0" },
            ["0.8.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "71dbc87ac9f24099a62b93570e65aa06312ba6ac8aea63b7f86e9d999edf5a92",
                    aarch64 = "f84f4dfbebf4a6b0b230385fa065a39ea35e02608c2b50d025dcf64775a69d67",
                },
            },
        },
        windows = {
            source = "https://github.com/yannh/kubeconform/releases/download/v${version}/kubeconform-windows-${arch_alias}.zip",
            ["latest"] = { ref = "0.8.0" },
            ["0.8.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "e3f56102bcf4f50b034a567e2482a1c5330799983ddd655952310211aef73d93",
                    aarch64 = "4f3c9889f5f3a1e4aba84f9212f599ad3164d1fb32175fba3a53b505b0fffd0f",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

function installed()
    return payload.present({ "kubeconform" })
        or payload.present({ "kubeconform.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("kubeconform: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
        or normalized:match("%-windows%-") ~= nil
        or os.getenv("OS") == "Windows_NT"
    local exe = is_win and "kubeconform.exe" or "kubeconform"

    os.tryrm(dir)

    -- Upstream archives are flat (no top-level wrapper directory). Extract
    -- directly into install_dir so unrelated files in the shared download
    -- directory cannot leak into this payload.
    if is_win then
        if os.isfile(archive) then
            payload.unpack{}
        elseif os.isfile(parent .. "/" .. exe) then
            fs.mkdir_p(dir)
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("kubeconform: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        fs.mkdir_p(dir)
        if os.isfile(archive) then
            system.exec(string.format('tar -xzf "%s" -C "%s"', normalized, dir))
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("kubeconform: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe))
        end
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("kubeconform", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("kubeconform")
    return true
end
