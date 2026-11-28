-- Flux - Open and extensible continuous delivery solution for Kubernetes (Flux v2).
--
-- Verified 2026-11-26 against upstream GitHub release v2.10.1 (fluxcd/flux2):
--   linux    x86_64, aarch64   flux_<ver>_linux_{amd64,arm64}.tar.gz
--   macosx   x86_64, aarch64   flux_<ver>_darwin_{amd64,arm64}.tar.gz
--   windows  x86_64, aarch64   flux_<ver>_windows_{amd64,arm64}.zip
--
-- Every archive is flat at root containing a single executable (`flux` on
-- POSIX, `flux.exe` on Windows). All six SHA-256 digests match upstream
-- `flux_2.10.1_checksums.txt` and locally downloaded archives.
--
-- Both Linux ELF binaries are statically linked Go executables (`readelf -d`:
-- no dynamic section; `ldd`: not a dynamic executable), so no runtime library
-- deps are required. Both Windows PE32+ executables (`0x8664`, `0xaa64`) import
-- only `kernel32.dll` (no VCRUNTIME DLL dependency). `flux "/?"` exits
-- immediately with status 1 (`unknown command "/?" for "flux"`).

package = {
    spec = "2",

    name = "flux",
    description = "Open and extensible continuous delivery solution for Kubernetes",
    homepage = "https://fluxcd.io",
    authors = {"The Flux authors"},
    maintainers = {"https://github.com/fluxcd/flux2/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/fluxcd/flux2",
    docs = "https://fluxcd.io/flux/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"kubernetes", "gitops", "devops", "cli", "tools"},
    keywords = {"flux", "flux2", "fluxcd", "gitops", "kubernetes", "k8s", "cd"},

    programs = {"flux"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/fluxcd/flux2/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/fluxcd/flux2/releases/download/${tag}/flux_${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/fluxcd/flux2/releases/download/${tag}/flux_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/fluxcd/flux2/releases/download/${tag}/flux_${version}_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/fluxcd/flux2/releases/download/${tag}/flux_${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/fluxcd/flux2/releases/download/${tag}/flux_${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/fluxcd/flux2/releases/download/${tag}/flux_${version}_windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/fluxcd/flux2/releases/download/v${version}/flux_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.10.1" },
            ["2.10.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "967365ff84aabc97871827ff33713ef0c09f62dd83c18759e3a5e39adcea9285",
                    aarch64 = "da18ddb25c9614405d9e2f13ad014fd660bfcbe7218674cabf9325db73f811e2",
                },
            },
        },
        macosx = {
            source = "https://github.com/fluxcd/flux2/releases/download/v${version}/flux_${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.10.1" },
            ["2.10.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "0e083b1a53887ffee1624c67de74eea3ed9d7fd0215efb4b4090c8cc97abb824",
                    aarch64 = "c0a8dc285c568905ae38e25074985f3181c82a3c8d66316959561f27a626909d",
                },
            },
        },
        windows = {
            source = "https://github.com/fluxcd/flux2/releases/download/v${version}/flux_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "2.10.1" },
            ["2.10.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "acb91b95222166bf0f2f62f81ea0bbbe7f271732700f5db164de306dd4efbdf3",
                    aarch64 = "95bfc91322caa740cac418880252d2d889e527cd6a506d3de7d065f3be73ba4f",
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
    return payload.present({ "flux" })
        or payload.present({ "flux.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("flux: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
        or normalized:match("_windows_") ~= nil
        or os.getenv("OS") == "Windows_NT"
    local exe = is_win and "flux.exe" or "flux"

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
            error("flux: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        fs.mkdir_p(dir)
        if os.isfile(archive) then
            system.exec(string.format('tar -xzf "%s" -C "%s"', normalized, dir))
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("flux: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe))
        end
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("flux", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("flux")
    return true
end
