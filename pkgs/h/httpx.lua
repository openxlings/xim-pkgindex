-- httpx - Fast and multi-purpose HTTP toolkit written in Go (projectdiscovery/httpx).
--
-- Verified 2026-11-26 against upstream GitHub release v1.12.0 and
-- `httpx_1.12.0_checksums.txt`: every SHA-256 below matched the upstream
-- checksums file, GitHub release asset digests, and downloaded archive bytes:
--   linux/x86_64    httpx_1.12.0_linux_amd64.zip     (static Go ELF, no .dynamic section)
--   linux/aarch64   httpx_1.12.0_linux_arm64.zip     (static Go ELF, no .dynamic section)
--   macosx/x86_64   httpx_1.12.0_macOS_amd64.zip     (Mach-O 64-bit x86_64 executable)
--   macosx/aarch64  httpx_1.12.0_macOS_arm64.zip     (Mach-O 64-bit arm64 executable)
--   windows/x86_64  httpx_1.12.0_windows_amd64.zip   (PE32+ x86-64 CUI, imports kernel32.dll only)
--
-- Upstream also publishes 32-bit x86 (`linux_386`, `windows_386`) and ARMv6/7
-- (`linux_arm`) builds, which are outside `archs`, and publishes no Windows
-- ARM64 archive. All five supported archives are flat `.zip` files at root
-- (`httpx` / `httpx.exe`, `LICENSE.md`, `README.md` with no wrapper directory).
-- `install()` extracts directly from `pkginfo.install_file()` into a clean
-- `pkginfo.install_dir()` so shared `runtimedir` contents from other flat
-- archives cannot leak into httpx's payload.

package = {
    spec = "2",

    name = "httpx",
    description = "Fast and multi-purpose HTTP toolkit written in Go",
    homepage = "https://docs.projectdiscovery.io/tools/httpx/",
    authors = {"ProjectDiscovery"},
    maintainers = {"https://github.com/projectdiscovery/httpx/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/projectdiscovery/httpx",
    docs = "https://docs.projectdiscovery.io/tools/httpx/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"http", "security", "network", "cli", "tools"},
    keywords = {"httpx", "http", "probing", "recon", "security", "cli", "go"},

    programs = {"httpx"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/projectdiscovery/httpx/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/projectdiscovery/httpx/releases/download/${tag}/httpx_${version}_linux_amd64.zip",
                            aarch64 = "https://github.com/projectdiscovery/httpx/releases/download/${tag}/httpx_${version}_linux_arm64.zip",
                        },
                        macosx = {
                            x86_64 = "https://github.com/projectdiscovery/httpx/releases/download/${tag}/httpx_${version}_macOS_amd64.zip",
                            aarch64 = "https://github.com/projectdiscovery/httpx/releases/download/${tag}/httpx_${version}_macOS_arm64.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/projectdiscovery/httpx/releases/download/${tag}/httpx_${version}_windows_amd64.zip",
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
            source = "https://github.com/projectdiscovery/httpx/releases/download/v${version}/httpx_${version}_linux_${arch_alias}.zip",
            ["latest"] = { ref = "1.12.0" },
            ["1.12.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "9d8439e8b6c9aa7d1e2314817a392e00d5178da3af5652f7475f88868f418f76",
                    aarch64 = "fd7b123c1dfbc3d69f19f524e4eebcd6ec06b9a6cbd56813c76f11645197331e",
                },
            },
        },
        macosx = {
            source = "https://github.com/projectdiscovery/httpx/releases/download/v${version}/httpx_${version}_macOS_${arch_alias}.zip",
            ["latest"] = { ref = "1.12.0" },
            ["1.12.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "16760b5e2122b66f57b9fbdb59f564b1181507c093d6a36066f40e5de38e8fa9",
                    aarch64 = "21d60328b383dba8a9fe249ac76b12edda4ec2e52a9cb21876c0a79123675569",
                },
            },
        },
        windows = {
            source = "https://github.com/projectdiscovery/httpx/releases/download/v${version}/httpx_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "1.12.0" },
            ["1.12.0"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "14d8ccaa2d95ce9365162682f1a2ba3f14d2000bb4bfb0924af65ec5163ae021",
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
    return payload.present(required_files("httpx"))
        or payload.present(required_files("httpx.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("httpx: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = is_windows()
    local exe = is_win and "httpx.exe" or "httpx"

    os.tryrm(dir)

    if is_win then
        if os.isfile(archive) then
            payload.unpack{}
        elseif os.isfile(parent .. "/" .. exe) then
            fs.mkdir_p(dir)
            for _, f in ipairs(required_files(exe)) do
                if os.isfile(parent .. "/" .. f) then
                    os.mv(parent .. "/" .. f, dir .. "/" .. f)
                end
            end
        else
            error("httpx: neither archive (" .. archive .. ") nor extracted binary (" .. parent .. "/" .. exe .. ") exists")
        end
    else
        fs.mkdir_p(dir)
        if os.isfile(archive) then
            shell.exec({ "unzip", "-q", "-o", archive, "-d", dir })
        elseif os.isfile(parent .. "/" .. exe) then
            for _, f in ipairs(required_files(exe)) do
                if os.isfile(parent .. "/" .. f) then
                    os.mv(parent .. "/" .. f, dir .. "/" .. f)
                end
            end
        else
            error("httpx: neither archive (" .. archive .. ") nor extracted binary (" .. parent .. "/" .. exe .. ") exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            shell.exec({ "chmod", "+x", dir .. "/" .. exe })
        end
    end

    payload.require(required_files(exe))
    return true
end

function config()
    xvm.add("httpx", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("httpx")
    return true
end
