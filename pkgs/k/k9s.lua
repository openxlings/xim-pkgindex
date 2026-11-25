-- k9s - Kubernetes CLI to manage your clusters in style.
--
-- Platform and architecture coverage (verified against derailed/k9s v0.51.0):
--   linux    x86_64, aarch64   k9s_Linux_<arch>.tar.gz   (static Go ELF, no .dynamic section)
--   macosx   x86_64, aarch64   k9s_Darwin_<arch>.tar.gz  (official Mach-O binary)
--   windows  x86_64, aarch64   k9s_Windows_<arch>.zip    (official PE binary, imports kernel32.dll only)
--
-- All upstream archives are flat at root (`k9s` / `k9s.exe`, `LICENSE`, `README.md`)
-- with no top-level wrapper directory. Every SHA256 below was verified against both
-- upstream `checksums.sha256` and downloaded release archives.

package = {
    spec = "2",

    name = "k9s",
    description = "Kubernetes CLI to manage your clusters in style",
    homepage = "https://k9scli.io",
    maintainers = {"derailed"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/derailed/k9s",
    docs = "https://k9scli.io",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"kubernetes", "k8s", "cli", "tui", "tools"},
    keywords = {"k9s", "kubernetes", "k8s", "tui", "cli", "cluster", "go"},

    programs = {"k9s"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/derailed/k9s/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/derailed/k9s/releases/download/v${version}/k9s_Linux_amd64.tar.gz",
                            aarch64 = "https://github.com/derailed/k9s/releases/download/v${version}/k9s_Linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/derailed/k9s/releases/download/v${version}/k9s_Darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/derailed/k9s/releases/download/v${version}/k9s_Darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/derailed/k9s/releases/download/v${version}/k9s_Windows_amd64.zip",
                            aarch64 = "https://github.com/derailed/k9s/releases/download/v${version}/k9s_Windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/derailed/k9s/releases/download/v${version}/k9s_Linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.51.0" },
            ["0.51.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "c3752ad51a5a4015a113819c4eeb6e55a4d0e4b8e652494797532f6fc8161dd7",
                    aarch64 = "3ee05c82e5f9198928a4e86133608ba6a2c10a2244d6a7789e820f78319d640c",
                },
            },
        },
        macosx = {
            source = "https://github.com/derailed/k9s/releases/download/v${version}/k9s_Darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.51.0" },
            ["0.51.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "7e8802c57c45a0cd389e8fc38472243fe4cf48d8ad5957e189ce370e19e5eda0",
                    aarch64 = "9b8c0e8f461e5d33aeee43a67f5ef4aff646a008a786887b8266cbb153c610cc",
                },
            },
        },
        windows = {
            source = "https://github.com/derailed/k9s/releases/download/v${version}/k9s_Windows_${arch_alias}.zip",
            ["latest"] = { ref = "0.51.0" },
            ["0.51.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "bba299f1877913979831543a008f2e104995d2ea4ac8f23d7f49c0444857d973",
                    aarch64 = "a61c11ac1e9c64e02ce852dd43b630abafda8f0a2c5fd46c752a39f0670a0244",
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
    return payload.present({ "k9s" }) or payload.present({ "k9s.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("k9s: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "k9s.exe" or "k9s"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    -- Upstream archives are flat (no top-level wrapper directory). Extract
    -- directly from the archive into install_dir so files from unrelated flat
    -- packages in the shared download directory cannot leak into this payload.
    if is_win then
        if os.isfile(archive) then
            payload.unpack{}
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("k9s: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        if os.isfile(archive) then
            system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("k9s: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/" .. exe))
        end
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("k9s", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("k9s")
    return true
end
