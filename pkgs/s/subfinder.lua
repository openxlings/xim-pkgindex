-- Subfinder - Fast passive subdomain discovery tool written in Go (projectdiscovery/subfinder).
--
-- Verified 2026-11-26 against upstream GitHub release v2.17.0 and
-- `subfinder_2.17.0_checksums.txt`: every SHA-256 below matched the upstream
-- checksums file and downloaded archive bytes:
--   linux/x86_64    subfinder_2.17.0_linux_amd64.zip    (static Go ELF, no .dynamic section)
--   linux/aarch64   subfinder_2.17.0_linux_arm64.zip    (static Go ELF, no .dynamic section)
--   macosx/x86_64   subfinder_2.17.0_macOS_amd64.zip    (Mach-O 64-bit x86_64 executable)
--   macosx/aarch64  subfinder_2.17.0_macOS_arm64.zip    (Mach-O 64-bit arm64 executable)
--   windows/x86_64  subfinder_2.17.0_windows_amd64.zip  (PE32+ x86-64 CUI, imports kernel32.dll only)
--   windows/aarch64 subfinder_2.17.0_windows_arm64.zip  (PE32+ ARM64 CUI, imports kernel32.dll only)
--
-- Upstream also publishes 32-bit x86 (`linux_386`, `windows_386`) and 32-bit
-- ARM (`linux_arm`) builds, which are outside `archs`. All six supported
-- archives are flat `.zip` files at root (`subfinder` / `subfinder.exe`,
-- `LICENSE.md`, `README.md` with no wrapper directory). `install()` extracts
-- directly from `pkginfo.install_file()` into a clean `pkginfo.install_dir()`
-- so shared `runtimedir` contents from other flat archives cannot leak into
-- subfinder's payload.

package = {
    spec = "2",

    name = "subfinder",
    description = "Fast passive subdomain discovery tool written in Go",
    homepage = "https://docs.projectdiscovery.io/tools/subfinder/overview",
    authors = {"ProjectDiscovery"},
    maintainers = {"https://github.com/projectdiscovery/subfinder/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/projectdiscovery/subfinder",
    docs = "https://docs.projectdiscovery.io/tools/subfinder/overview",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"security", "recon", "network", "cli", "tools"},
    keywords = {"subfinder", "subdomain", "recon", "enumeration", "osint", "security", "cli", "go"},

    programs = {"subfinder"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/projectdiscovery/subfinder/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/projectdiscovery/subfinder/releases/download/${tag}/subfinder_${version}_linux_amd64.zip",
                            aarch64 = "https://github.com/projectdiscovery/subfinder/releases/download/${tag}/subfinder_${version}_linux_arm64.zip",
                        },
                        macosx = {
                            x86_64 = "https://github.com/projectdiscovery/subfinder/releases/download/${tag}/subfinder_${version}_macOS_amd64.zip",
                            aarch64 = "https://github.com/projectdiscovery/subfinder/releases/download/${tag}/subfinder_${version}_macOS_arm64.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/projectdiscovery/subfinder/releases/download/${tag}/subfinder_${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/projectdiscovery/subfinder/releases/download/${tag}/subfinder_${version}_windows_arm64.zip",
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
            source = "https://github.com/projectdiscovery/subfinder/releases/download/v${version}/subfinder_${version}_linux_${arch_alias}.zip",
            ["latest"] = { ref = "2.17.0" },
            ["2.17.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "a39c3e5c7a26ef3c430915c4d6cbf7716a00f26769a75e9405aba796142eba37",
                    aarch64 = "24913d49dddc1d3a5e99a4a7580da5be980959b9415b96f52c4f7f4124392190",
                },
            },
        },
        macosx = {
            source = "https://github.com/projectdiscovery/subfinder/releases/download/v${version}/subfinder_${version}_macOS_${arch_alias}.zip",
            ["latest"] = { ref = "2.17.0" },
            ["2.17.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "75bf5990b409c6fd1116c81cd64fbdfd2cfd5bfb1f43542035b42344cb9fdffa",
                    aarch64 = "012d6ff91ef932ac6d1a321fb5735cf1412168d163e6adbc6cbe5fc42fe03c3b",
                },
            },
        },
        windows = {
            source = "https://github.com/projectdiscovery/subfinder/releases/download/v${version}/subfinder_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "2.17.0" },
            ["2.17.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "a3fd612928d591fb31c1e59a2e06055e364421ba32251e553073f5673a2d3103",
                    aarch64 = "579f8dc7b5bb3da01672fb8b48ba1c232002fe20d1f22d3ddf4b952790f65fe9",
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
    local filename = archive:gsub("\\", "/"):match("([^/]+)$") or ""
    return filename:match("windows") ~= nil
end

function installed()
    return payload.present(required_files("subfinder"))
        or payload.present(required_files("subfinder.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("subfinder: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = is_windows()
    local exe = is_win and "subfinder.exe" or "subfinder"
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
            error("subfinder: neither archive (" .. archive .. ") nor extracted binary (" .. parent .. "/" .. exe .. ") exists")
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
            error("subfinder: neither archive (" .. archive .. ") nor extracted binary (" .. parent .. "/" .. exe .. ") exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            shell.exec({ "chmod", "+x", dir .. "/" .. exe })
        end
    end

    payload.require(req)
    return true
end

function config()
    xvm.add("subfinder", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("subfinder")
    return true
end
