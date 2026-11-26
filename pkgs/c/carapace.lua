-- carapace - Multi-shell multi-command argument completer (carapace-sh/carapace-bin).
--
-- Verified 2026-11-26 against upstream GitHub release v1.8.5 and
-- `carapace-bin_1.8.5_checksums.txt`: every SHA-256 below matched the upstream
-- checksums file and downloaded archive bytes:
--   linux/x86_64    carapace-bin_1.8.5_linux_amd64.tar.gz   (static Go ELF, no .dynamic section)
--   linux/aarch64   carapace-bin_1.8.5_linux_arm64.tar.gz   (static Go ELF, no .dynamic section)
--   macosx/x86_64   carapace-bin_1.8.5_darwin_amd64.tar.gz
--   macosx/aarch64  carapace-bin_1.8.5_darwin_arm64.tar.gz
--   windows/x86_64  carapace-bin_1.8.5_windows_amd64.zip    (PE32+ x86-64 CUI, imports kernel32.dll only)
--   windows/aarch64 carapace-bin_1.8.5_windows_arm64.zip    (PE32+ ARM64 CUI, imports kernel32.dll only)
--
-- Upstream also publishes 32-bit x86, Termux, Android, deb/rpm/apk packages,
-- which are outside `archs`. All six supported archives are flat at root
-- (`carapace` / `carapace.exe`, `LICENSE`, `README.md` with no wrapper
-- directory). `install()` extracts directly from `pkginfo.install_file()` into
-- a clean `pkginfo.install_dir()` so shared `runtimedir` contents from other
-- flat archives cannot leak into carapace's payload.

package = {
    spec = "2",

    name = "carapace",
    description = "A multi-shell completion binary",
    homepage = "https://carapace.sh",
    maintainers = {"https://github.com/carapace-sh/carapace-bin/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/carapace-sh/carapace-bin",
    docs = "https://carapace-sh.github.io/carapace-bin/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "shell", "completion", "tools"},
    keywords = {"carapace", "completion", "shell", "cli", "bash", "zsh", "fish", "powershell"},

    programs = {"carapace"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/carapace-sh/carapace-bin/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/carapace-sh/carapace-bin/releases/download/${tag}/carapace-bin_${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/carapace-sh/carapace-bin/releases/download/${tag}/carapace-bin_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/carapace-sh/carapace-bin/releases/download/${tag}/carapace-bin_${version}_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/carapace-sh/carapace-bin/releases/download/${tag}/carapace-bin_${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/carapace-sh/carapace-bin/releases/download/${tag}/carapace-bin_${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/carapace-sh/carapace-bin/releases/download/${tag}/carapace-bin_${version}_windows_arm64.zip",
                        },
                    },
                },
            },
        },
    },

    -- Upstream builds static Go binaries; Linux ELFs have no dynamic section and
    -- Windows PE executables import only kernel32.dll, so no runtime deps are needed.
    xpm = {
        linux = {
            source = "https://github.com/carapace-sh/carapace-bin/releases/download/v${version}/carapace-bin_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.8.5" },
            ["1.8.5"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "e0543a02199ecec90fc4f0dc2c5bd52bdc995b72a9f3c4788f82b13d62669436",
                    aarch64 = "20e535215f9eeeb8257b3a2d5e9be909e676ca8bdb54cf2b26c03542337fe3c2",
                },
            },
        },
        macosx = {
            source = "https://github.com/carapace-sh/carapace-bin/releases/download/v${version}/carapace-bin_${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.8.5" },
            ["1.8.5"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "0c31620c56d1814e4a433a8403e3ff0e12f9c09ef6fbe3a937aca9e2ada973e7",
                    aarch64 = "570917704105be2a2bb0f3d436bf13f772a151ddeb6d644767caba932598a28f",
                },
            },
        },
        windows = {
            source = "https://github.com/carapace-sh/carapace-bin/releases/download/v${version}/carapace-bin_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "1.8.5" },
            ["1.8.5"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "d8886fddfbd679d0acc9086abc77556649f3170f339bae0b91d3f591af19ec9e",
                    aarch64 = "0cfa75fe01e44f77dfa8052720ac93b0d66fa6ab4dfb4036d3db5e42f1f41d82",
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

local function required_files(exe)
    return { exe, "LICENSE", "README.md" }
end

function installed()
    return payload.present(required_files("carapace"))
        or payload.present(required_files("carapace.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("carapace: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local is_win = normalized:match("%.zip$") ~= nil

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if is_win then
        payload.unpack{}
    else
        if not os.isfile(archive) then
            error("carapace: archive not found: " .. archive)
        end
        system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        if os.isfile(dir .. "/carapace") then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/carapace"))
        end
    end

    payload.require(required_files(is_win and "carapace.exe" or "carapace"))
    return true
end

function config()
    xvm.add("carapace", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("carapace")
    return true
end
