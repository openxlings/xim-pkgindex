-- Helmfile - Declaratively deploy your Kubernetes manifests, Kustomize configs,
-- and Charts as Helm releases.
--
-- Verified 2026-11-26 against upstream GitHub release v1.8.5 (helmfile/helmfile):
--   linux    x86_64, aarch64   helmfile_<ver>_linux_{amd64,arm64}.tar.gz
--   macosx   x86_64, aarch64   helmfile_<ver>_darwin_{amd64,arm64}.tar.gz
--   windows  x86_64, aarch64   helmfile_<ver>_windows_{amd64,arm64}.tar.gz
--
-- Every archive is flat at root (`helmfile` / `helmfile.exe`, `LICENSE`,
-- `CHANGELOG.md`, `README.md`, `README-zh_CN.md`, `README.zh-TW.md`).
-- All six SHA-256 digests match upstream `helmfile_1.8.5_checksums.txt` and
-- downloaded archives. Both Linux ELF binaries are statically linked Go
-- executables (`readelf -d`: no dynamic section; `ldd`: not a dynamic
-- executable), so no runtime library deps are required. Both Windows PE32+
-- executables (`x86_64`, `aarch64`) import only `kernel32.dll`.
package = {
    spec = "2",

    name = "helmfile",
    description = "Declaratively deploy your Kubernetes manifests, Kustomize configs, and Charts as Helm releases",
    homepage = "https://helmfile.readthedocs.io",
    authors = {"The Helmfile Authors"},
    maintainers = {"https://github.com/helmfile/helmfile/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/helmfile/helmfile",
    docs = "https://helmfile.readthedocs.io/en/latest/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"kubernetes", "devops", "cli", "tools"},
    keywords = {"helmfile", "helm", "kubernetes", "k8s", "charts", "gitops"},

    programs = {"helmfile"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/helmfile/helmfile/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/helmfile/helmfile/releases/download/${tag}/helmfile_${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/helmfile/helmfile/releases/download/${tag}/helmfile_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/helmfile/helmfile/releases/download/${tag}/helmfile_${version}_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/helmfile/helmfile/releases/download/${tag}/helmfile_${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/helmfile/helmfile/releases/download/${tag}/helmfile_${version}_windows_amd64.tar.gz",
                            aarch64 = "https://github.com/helmfile/helmfile/releases/download/${tag}/helmfile_${version}_windows_arm64.tar.gz",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/helmfile/helmfile/releases/download/v${version}/helmfile_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.8.5" },
            ["1.8.5"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "e10344a4e6121689265c8fbe8ce96977b4722a9f953db862014a08b99938c333",
                    aarch64 = "023b28a0630b60b392407f107b336502d11fec7e901dc631cfff7d2cc86a80c2",
                },
            },
        },
        macosx = {
            source = "https://github.com/helmfile/helmfile/releases/download/v${version}/helmfile_${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.8.5" },
            ["1.8.5"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "4a3919de8d4401a0e3ab751a4f15806c0b72561c1045eebe0c9ad91d90f90021",
                    aarch64 = "aa8c5e0c0ebb331e5a3eacbe3ee4bacd45f8a0c6ef361a79dea23b7bf4c4a76f",
                },
            },
        },
        windows = {
            source = "https://github.com/helmfile/helmfile/releases/download/v${version}/helmfile_${version}_windows_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.8.5" },
            ["1.8.5"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "37b7014bbcd2abc5bd8508b39812f7125d3bd0f70717fe578ae99cee7cc36b4e",
                    aarch64 = "9c747e2fb723f40714bfe82afdb4a7b897521e89b5776d3000fb2c97446e09b3",
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
import("xim.pkgindex.winpath")

local DOC_FILES = {
    "LICENSE",
    "CHANGELOG.md",
    "README.md",
    "README-zh_CN.md",
    "README.zh-TW.md",
}

function installed()
    return payload.present({ "helmfile", "LICENSE" })
        or payload.present({ "helmfile.exe", "LICENSE" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("_windows_") ~= nil
        or normalized:match("^[A-Za-z]:/") ~= nil
        or os.getenv("OS") == "Windows_NT"
    local exe = is_win and "helmfile.exe" or "helmfile"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if os.isfile(archive) then
        if is_win then
            local sysroot = winpath.native(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
            local systar = sysroot .. "\\System32\\tar.exe"
            -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
            system.exec(string.format('%s -xf "%s" -C "%s"',
                                      systar, winpath.native(archive), winpath.native(dir)))
        else
            -- Extract flat .tar.gz directly into install_dir so files never mix
            -- with other flat archives in the shared runtimedir.
            system.exec(string.format('tar -xf "%s" -C "%s"', archive, dir))
            system.exec(string.format('chmod +x "%s"', dir .. "/helmfile"))
        end
    elseif os.isfile(parent .. "/" .. exe) then
        os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        for _, f in ipairs(DOC_FILES) do
            if os.isfile(parent .. "/" .. f) then
                os.mv(parent .. "/" .. f, dir .. "/" .. f)
            end
        end
        if not is_win then
            system.exec(string.format('chmod +x "%s"', dir .. "/helmfile"))
        end
    else
        error("helmfile: archive not found at " .. archive)
    end

    payload.require({ exe, "LICENSE" })
    return true
end

function config()
    xvm.add("helmfile", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("helmfile")
    return true
end
