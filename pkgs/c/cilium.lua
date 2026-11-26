-- Cilium CLI - CLI to install, manage & troubleshoot Kubernetes clusters running Cilium.
--
-- Verified 2026-11-26 against upstream GitHub release v0.20.3 (cilium/cilium-cli):
--   linux    x86_64, aarch64   cilium-linux-{amd64,arm64}.tar.gz
--   macosx   x86_64, aarch64   cilium-darwin-{amd64,arm64}.tar.gz
--   windows  x86_64, aarch64   cilium-windows-{amd64,arm64}.zip
--
-- Every archive is flat at root containing a single executable (`cilium` on
-- POSIX, `cilium.exe` on Windows). All six SHA-256 digests were computed from
-- locally downloaded upstream release archives.
--
-- Both Linux ELF binaries are statically linked Go executables (`readelf -d`:
-- no dynamic section; `ldd`: not a dynamic executable), so no runtime library
-- deps are required. Both Windows PE32+ executables (`x86-64`, `ARM64`) are
-- console binaries; `cilium-windows-amd64.zip` imports only `kernel32.dll`
-- (no VCRUNTIME DLL dependency). `cilium "/?"` exits immediately with status 1
-- (`unknown command "/?" for "cilium"`).

package = {
    spec = "2",

    name = "cilium",
    description = "CLI to install, manage & troubleshoot Kubernetes clusters running Cilium",
    homepage = "https://cilium.io",
    authors = {"The Cilium authors"},
    maintainers = {"https://github.com/cilium/cilium-cli/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/cilium/cilium-cli",
    docs = "https://docs.cilium.io/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"kubernetes", "networking", "ebpf", "devops", "cli", "tools"},
    keywords = {"cilium", "ebpf", "kubernetes", "k8s", "cni", "hubble", "networking"},

    programs = {"cilium"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/cilium/cilium-cli/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/cilium/cilium-cli/releases/download/${tag}/cilium-linux-amd64.tar.gz",
                            aarch64 = "https://github.com/cilium/cilium-cli/releases/download/${tag}/cilium-linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/cilium/cilium-cli/releases/download/${tag}/cilium-darwin-amd64.tar.gz",
                            aarch64 = "https://github.com/cilium/cilium-cli/releases/download/${tag}/cilium-darwin-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/cilium/cilium-cli/releases/download/${tag}/cilium-windows-amd64.zip",
                            aarch64 = "https://github.com/cilium/cilium-cli/releases/download/${tag}/cilium-windows-arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/cilium/cilium-cli/releases/download/v${version}/cilium-linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.20.3" },
            ["0.20.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "b987ad0d195310d3fc96553aa7bcd41d1e97b64713ecdfee3eb48dd27e1ec7d7",
                    aarch64 = "fa1bd66b407ec205e88746fc0b17590a247f255bf71bb9dfb0008b14d158f68d",
                },
            },
        },
        macosx = {
            source = "https://github.com/cilium/cilium-cli/releases/download/v${version}/cilium-darwin-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.20.3" },
            ["0.20.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "6141f85d8ddb9c2b26fb0ab7eb2ed7a5d0e9efe1fe59006419f30d8c2434b60c",
                    aarch64 = "5a53acbe09f1515f52b7e625517872dd0d0e02e2f6082c919527cc507b110a15",
                },
            },
        },
        windows = {
            source = "https://github.com/cilium/cilium-cli/releases/download/v${version}/cilium-windows-${arch_alias}.zip",
            ["latest"] = { ref = "0.20.3" },
            ["0.20.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "3fe0df6fbf6471b958863106e23e46cc6339c86b74bf28b805e8a4113f7a2cde",
                    aarch64 = "8804ede2eaa054d28ba1f6772256f584c3f6ce7e3e836b5c7c1b714a2a2366fb",
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
    return payload.present({ "cilium" })
        or payload.present({ "cilium.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("cilium: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
        or normalized:match("%-windows%-") ~= nil
        or os.getenv("OS") == "Windows_NT"
    local exe = is_win and "cilium.exe" or "cilium"

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
            error("cilium: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        fs.mkdir_p(dir)
        if os.isfile(archive) then
            system.exec(string.format('tar -xzf "%s" -C "%s"', normalized, dir))
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("cilium: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe))
        end
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("cilium", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("cilium")
    return true
end
