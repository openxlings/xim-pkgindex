-- Nuclei - Fast and customizable vulnerability scanner based on simple YAML-based DSL (projectdiscovery/nuclei).
--
-- Verified 2026-11-26 against upstream GitHub release v3.11.1 and
-- `nuclei_3.11.1_checksums.txt`: every SHA-256 below matched the upstream
-- checksums file, GitHub release asset digests, and downloaded archive bytes:
--   linux/x86_64    nuclei_3.11.1_linux_amd64.zip    (static Go ELF, no .dynamic section)
--   linux/aarch64   nuclei_3.11.1_linux_arm64.zip    (static Go ELF, no .dynamic section)
--   macosx/x86_64   nuclei_3.11.1_macOS_amd64.zip    (Mach-O 64-bit x86_64)
--   macosx/aarch64  nuclei_3.11.1_macOS_arm64.zip    (Mach-O 64-bit arm64)
--   windows/x86_64  nuclei_3.11.1_windows_amd64.zip  (PE32+ x86-64 CUI, imports kernel32.dll only)
--
-- Upstream also publishes 32-bit x86 (`linux_386`, `windows_386`) and 32-bit
-- ARM (`linux_arm`) builds, which are outside `archs`, and does not publish a
-- `windows/aarch64` build. All five supported archives are flat `.zip` files
-- (`nuclei` / `nuclei.exe`, `LICENSE.md`, `README.md`, and localized `README_*.md`
-- with no wrapper directory). `install()` extracts directly from
-- `pkginfo.install_file()` into a clean `pkginfo.install_dir()` so shared
-- `runtimedir` contents from other flat archives cannot leak into nuclei's payload.

package = {
    spec = "2",

    name = "nuclei",
    description = "Fast and customizable vulnerability scanner based on simple YAML-based DSL",
    homepage = "https://docs.projectdiscovery.io/tools/nuclei/overview",
    authors = {"ProjectDiscovery, Inc."},
    maintainers = {"https://github.com/projectdiscovery/nuclei/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/projectdiscovery/nuclei",
    docs = "https://docs.projectdiscovery.io/tools/nuclei/overview",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"security", "scanner", "cli", "tools"},
    keywords = {"nuclei", "security", "scanner", "vulnerability", "yaml", "cli", "go"},

    programs = {"nuclei"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/projectdiscovery/nuclei/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/projectdiscovery/nuclei/releases/download/${tag}/nuclei_${version}_linux_amd64.zip",
                            aarch64 = "https://github.com/projectdiscovery/nuclei/releases/download/${tag}/nuclei_${version}_linux_arm64.zip",
                        },
                        macosx = {
                            x86_64 = "https://github.com/projectdiscovery/nuclei/releases/download/${tag}/nuclei_${version}_macOS_amd64.zip",
                            aarch64 = "https://github.com/projectdiscovery/nuclei/releases/download/${tag}/nuclei_${version}_macOS_arm64.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/projectdiscovery/nuclei/releases/download/${tag}/nuclei_${version}_windows_amd64.zip",
                        },
                    },
                },
            },
        },
    },

    -- Upstream builds static Go binaries; Linux ELFs have no dynamic section and
    -- Windows PE executable imports only kernel32.dll, so no runtime deps are needed.
    xpm = {
        linux = {
            source = "https://github.com/projectdiscovery/nuclei/releases/download/v${version}/nuclei_${version}_linux_${arch_alias}.zip",
            ["latest"] = { ref = "3.11.1" },
            ["3.11.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "ea63d4ae232808cd7c6bc00d0142428e231fab59dae01042246097d195835ab6",
                    aarch64 = "8044e3d9768ba0a744b2872c1a87e813006f013da97ca9f50f7661a4203bec07",
                },
            },
        },
        macosx = {
            source = "https://github.com/projectdiscovery/nuclei/releases/download/v${version}/nuclei_${version}_macOS_${arch_alias}.zip",
            ["latest"] = { ref = "3.11.1" },
            ["3.11.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "75c47ce11e9dbd4288a1c895ed85e3c4df9f4acb8237d6d178da6dccd1628f2a",
                    aarch64 = "7d7e291addd1fc29a9bf8d089afe878a9799b20229cbea2fb1693fc40fd4c5f0",
                },
            },
        },
        windows = {
            source = "https://github.com/projectdiscovery/nuclei/releases/download/v${version}/nuclei_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "3.11.1" },
            ["3.11.1"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "bb6cb9ff8939b753f6fcab06fd30a15f5bc61d8382a597871334c007a85ff9d2",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.shell")

local function required_files(exe)
    return { exe, "LICENSE.md", "README.md" }
end

local function is_windows()
    if os.getenv("OS") == "Windows_NT" then return true end
    local dir = tostring(pkginfo.install_dir() or "")
    if dir:match("^[A-Za-z]:") or dir:find("\\", 1, true) then return true end
    local archive = tostring(pkginfo.install_file() or "")
    return archive:match("windows") ~= nil
end

function installed()
    return payload.present(required_files("nuclei"))
        or payload.present(required_files("nuclei.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("nuclei: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = is_windows()
    local exe = is_win and "nuclei.exe" or "nuclei"
    local req = required_files(exe)

    os.tryrm(dir)

    if is_win then
        if os.isfile(archive) then
            payload.unpack{}
        elseif os.isfile(parent .. "/" .. exe) then
            fs.mkdir_p(dir)
            for _, f in ipairs(req) do
                if os.isfile(parent .. "/" .. f) then
                    os.mv(parent .. "/" .. f, dir .. "/" .. f)
                end
            end
        else
            error("nuclei: neither archive (" .. archive .. ") nor extracted binary (" .. parent .. "/" .. exe .. ") exists")
        end
    else
        fs.mkdir_p(dir)
        if os.isfile(archive) then
            shell.exec({ "unzip", "-q", "-o", archive, "-d", dir })
        elseif os.isfile(parent .. "/" .. exe) then
            for _, f in ipairs(req) do
                if os.isfile(parent .. "/" .. f) then
                    os.mv(parent .. "/" .. f, dir .. "/" .. f)
                end
            end
        else
            error("nuclei: neither archive (" .. archive .. ") nor extracted binary (" .. parent .. "/" .. exe .. ") exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            shell.exec({ "chmod", "+x", dir .. "/" .. exe })
        end
    end

    payload.require(req)
    return true
end

function config()
    xvm.add("nuclei", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("nuclei")
    return true
end
