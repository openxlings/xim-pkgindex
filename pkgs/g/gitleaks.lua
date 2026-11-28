-- Gitleaks - SAST tool for detecting and preventing hardcoded secrets in git repos (gitleaks/gitleaks).
--
-- Verified 2026-11-26 against upstream GitHub release v8.30.1 and
-- `gitleaks_8.30.1_checksums.txt`: every SHA256 below matched both the upstream
-- checksums file and the downloaded release archive bytes:
--   linux/x86_64    gitleaks_8.30.1_linux_x64.tar.gz     (static Go ELF, no .dynamic section)
--   linux/aarch64   gitleaks_8.30.1_linux_arm64.tar.gz   (static Go ELF, no .dynamic section)
--   macosx/x86_64   gitleaks_8.30.1_darwin_x64.tar.gz
--   macosx/aarch64  gitleaks_8.30.1_darwin_arm64.tar.gz
--   windows/x86_64  gitleaks_8.30.1_windows_x64.zip    (PE32+ x86-64, imports kernel32.dll only)
--   windows/aarch64 gitleaks_8.30.1_windows_arm64.zip  (PE32+ ARM64, imports kernel32.dll only)
--
-- All six archives are flat at root (`gitleaks`/`gitleaks.exe`, `LICENSE`,
-- `README.md` with no top-level wrapper directory).
-- `install()` extracts directly from `pkginfo.install_file()` into a clean
-- `install_dir()` so shared `runtimedir` contents from other flat archives
-- cannot leak into gitleaks's payload.

package = {
    spec = "2",

    name = "gitleaks",
    description = "Find secrets with Gitleaks - SAST tool for detecting hardcoded secrets like passwords, API keys, and tokens",
    homepage = "https://gitleaks.io",
    authors = {"Zachary Rice"},
    maintainers = {"https://github.com/gitleaks/gitleaks/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/gitleaks/gitleaks",
    docs = "https://github.com/gitleaks/gitleaks#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"security", "scanner", "git", "devops", "cli"},
    keywords = {"gitleaks", "secrets", "security", "scanner", "git", "sast"},

    programs = {"gitleaks"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/gitleaks/gitleaks/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/gitleaks/gitleaks/releases/download/${tag}/gitleaks_${version}_linux_x64.tar.gz",
                            aarch64 = "https://github.com/gitleaks/gitleaks/releases/download/${tag}/gitleaks_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/gitleaks/gitleaks/releases/download/${tag}/gitleaks_${version}_darwin_x64.tar.gz",
                            aarch64 = "https://github.com/gitleaks/gitleaks/releases/download/${tag}/gitleaks_${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/gitleaks/gitleaks/releases/download/${tag}/gitleaks_${version}_windows_x64.zip",
                            aarch64 = "https://github.com/gitleaks/gitleaks/releases/download/${tag}/gitleaks_${version}_windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/gitleaks/gitleaks/releases/download/v${version}/gitleaks_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "8.30.1" },
            ["8.30.1"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb",
                    aarch64 = "e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080",
                },
            },
        },
        macosx = {
            source = "https://github.com/gitleaks/gitleaks/releases/download/v${version}/gitleaks_${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "8.30.1" },
            ["8.30.1"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "dfe101a4db2255fc85120ac7f3d25e4342c3c20cf749f2c20a18081af1952709",
                    aarch64 = "b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5",
                },
            },
        },
        windows = {
            source = "https://github.com/gitleaks/gitleaks/releases/download/v${version}/gitleaks_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "8.30.1" },
            ["8.30.1"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "d29144deff3a68aa93ced33dddf84b7fdc26070add4aa0f4513094c8332afc4e",
                    aarch64 = "b95f5e4f5c425cedca7ee203d9afd29597e692c4924a12ed42f970537c72cc0f",
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
    return payload.present(required_files("gitleaks"))
        or payload.present(required_files("gitleaks.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("gitleaks: install_file is empty")
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
            error("gitleaks: archive not found: " .. archive)
        end
        system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        if os.isfile(dir .. "/gitleaks") then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/gitleaks"))
        end
    end

    payload.require(required_files(is_win and "gitleaks.exe" or "gitleaks"))
    return true
end

function config()
    xvm.add("gitleaks", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("gitleaks")
    return true
end
