-- k3d — Little helper to run CNCF's k3s in Docker (k3d-io/k3d).
--
-- Distribution: upstream publishes standalone raw single-file binaries on
-- GitHub Releases (no archive container). xlings skips auto-extract for
-- unarchived binaries and passes the downloaded file via pkginfo.install_file(),
-- which install() moves to `<install_dir>/k3d` on POSIX or
-- `<install_dir>/k3d.exe` on Windows.
--
-- Verified against k3d-io/k3d release v5.9.0 (SHA-256 matched upstream
-- `checksums.txt`, GitHub release digests, and downloaded bytes):
--   linux/x86_64    k3d-linux-amd64        (ELF64 static, readelf -d: no dynamic section, ldd: not dynamic)
--   linux/aarch64   k3d-linux-arm64        (ELF64 static, readelf -d: no dynamic section, ldd: not dynamic)
--   macosx/x86_64   k3d-darwin-amd64       (Mach-O 64-bit x86_64)
--   macosx/aarch64  k3d-darwin-arm64       (Mach-O 64-bit arm64)
--   windows/x86_64  k3d-windows-amd64.exe  (PE32+ console x86-64, imports kernel32.dll only; no windows-arm64 asset upstream)

package = {
    spec = "2",

    name = "k3d",
    description = "Little helper to run CNCF's k3s in Docker",
    homepage = "https://k3d.io/",
    authors = {"The k3d Authors"},
    maintainers = {"k3d-io"},
    licenses = {"MIT"},
    repo = "https://github.com/k3d-io/k3d",
    docs = "https://k3d.io/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"kubernetes", "k3s", "k8s", "containers", "cli", "devops", "tools"},
    keywords = {"k3d", "k3s", "kubernetes", "k8s", "docker", "cluster", "cli"},

    programs = {"k3d"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/k3d-io/k3d/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/k3d-io/k3d/releases/download/${tag}/k3d-linux-amd64",
                            aarch64 = "https://github.com/k3d-io/k3d/releases/download/${tag}/k3d-linux-arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/k3d-io/k3d/releases/download/${tag}/k3d-darwin-amd64",
                            aarch64 = "https://github.com/k3d-io/k3d/releases/download/${tag}/k3d-darwin-arm64",
                        },
                        windows = {
                            x86_64 = "https://github.com/k3d-io/k3d/releases/download/${tag}/k3d-windows-amd64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/k3d-io/k3d/releases/download/v${version}/k3d-linux-${arch_alias}",
            ["latest"] = { ref = "5.9.0" },
            ["5.9.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "06d8f25bc3a971c4eb29e0ff08429b180402db0f4dec838c9eac427e296800a0",
                    aarch64 = "03cde5cf23e6e8e67de5a039ecf26e5b85aca82fba3e5d13dadf904cd218a250",
                },
            },
        },
        macosx = {
            source = "https://github.com/k3d-io/k3d/releases/download/v${version}/k3d-darwin-${arch_alias}",
            ["latest"] = { ref = "5.9.0" },
            ["5.9.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "b4aabc37534f95b9c764e7823f2df923f50d57600837aa60a06266cce47db732",
                    aarch64 = "fe106541d5d0a3f18debcd4d432a16f8c0ce3e6ddc06f8fbb6f696a122313e00",
                },
            },
        },
        windows = {
            -- Upstream publishes only k3d-windows-amd64.exe (no windows-arm64 asset).
            source = "https://github.com/k3d-io/k3d/releases/download/v${version}/k3d-windows-${arch_alias}.exe",
            ["latest"] = { ref = "5.9.0" },
            ["5.9.0"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "49d0b9c796f5b8ba6f58a1dd5469e8b7b34bf9b6ce9078633eedb2789680a034",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local function _is_windows_payload(file, dir)
    local base = (tostring(file or ""):gsub("\\", "/"):match("([^/]+)$") or ""):lower()
    if base:match("%.exe$") or base:match("^k3d%-windows") then
        return true
    end
    if os.getenv("OS") == "Windows_NT" then
        return true
    end
    local d = tostring(dir or "")
    return d:match("^[A-Za-z]:") ~= nil or d:find("\\", 1, true) ~= nil
end

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/k3d") or os.isfile(dir .. "/k3d.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src, dir)
    local target = dir .. (is_win and "/k3d.exe" or "/k3d")

    if not os.isfile(src) then
        error("k3d: downloaded binary not found at " .. tostring(src))
    end

    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(src, target)
    if not is_win then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("k3d: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("k3d", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("k3d")
    return true
end
