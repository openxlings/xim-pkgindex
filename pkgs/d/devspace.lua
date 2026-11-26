-- devspace — The Fastest Developer Tool for Kubernetes (devspace-sh/devspace).
--
-- Distribution: upstream publishes standalone raw single-file binaries on
-- GitHub Releases (no archive container). xlings skips auto-extract for
-- unarchived binaries and passes the downloaded file via pkginfo.install_file(),
-- which install() moves to `<install_dir>/devspace` on POSIX or
-- `<install_dir>/devspace.exe` on Windows.
--
-- Verified against devspace-sh/devspace release v6.3.21 (SHA-256 matched
-- upstream `*.sha256` sidecars, GitHub release digests, and downloaded bytes):
--   linux/x86_64    devspace-linux-amd64        (ELF64 static, readelf -d: no dynamic section, ldd: not dynamic)
--   linux/aarch64   devspace-linux-arm64        (ELF64 static, readelf -d: no dynamic section, ldd: not dynamic)
--   macosx/x86_64   devspace-darwin-amd64       (Mach-O 64-bit x86_64)
--   macosx/aarch64  devspace-darwin-arm64       (Mach-O 64-bit arm64)
--   windows/x86_64  devspace-windows-amd64.exe  (PE32+ console x86-64, imports kernel32.dll only; no windows-arm64 asset upstream)

package = {
    spec = "2",

    name = "devspace",
    description = "The Fastest Developer Tool for Kubernetes",
    homepage = "https://devspace.sh/",
    authors = {"The DevSpace Authors"},
    maintainers = {"devspace-sh"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/devspace-sh/devspace",
    docs = "https://www.devspace.sh/docs/getting-started/installation",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"kubernetes", "k8s", "containers", "cli", "devops", "tools"},
    keywords = {"devspace", "kubernetes", "k8s", "docker", "containers", "cicd", "cli"},

    programs = {"devspace"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/devspace-sh/devspace/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/devspace-sh/devspace/releases/download/${tag}/devspace-linux-amd64",
                            aarch64 = "https://github.com/devspace-sh/devspace/releases/download/${tag}/devspace-linux-arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/devspace-sh/devspace/releases/download/${tag}/devspace-darwin-amd64",
                            aarch64 = "https://github.com/devspace-sh/devspace/releases/download/${tag}/devspace-darwin-arm64",
                        },
                        windows = {
                            x86_64 = "https://github.com/devspace-sh/devspace/releases/download/${tag}/devspace-windows-amd64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/devspace-sh/devspace/releases/download/v${version}/devspace-linux-${arch_alias}",
            ["latest"] = { ref = "6.3.21" },
            ["6.3.21"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "9720a6c87a2465f6d73b4db5a908e15e1971158443b5de9162d94aa5f87f79f0",
                    aarch64 = "8652285a22f079d4bfeda37a2f1089d56e64a34a76d32537dfb20a7cd6e69fcb",
                },
            },
        },
        macosx = {
            source = "https://github.com/devspace-sh/devspace/releases/download/v${version}/devspace-darwin-${arch_alias}",
            ["latest"] = { ref = "6.3.21" },
            ["6.3.21"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "47ba9e4c78c1dbcd4139b385c23021614597faaad79a929054beb7de4a559ae7",
                    aarch64 = "0cfb2ca74ece2e9e8c2a60bd8d02e8fb7620411917b97689f2f1a39314c2ba0a",
                },
            },
        },
        windows = {
            -- Upstream publishes only devspace-windows-amd64.exe (no windows-arm64 asset).
            source = "https://github.com/devspace-sh/devspace/releases/download/v${version}/devspace-windows-${arch_alias}.exe",
            ["latest"] = { ref = "6.3.21" },
            ["6.3.21"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "05c604fd02c2d9169659073bbef12f90da68d7211de743c7c93920f74d07f3a6",
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
    if base:match("%.exe$") or base:match("^devspace%-windows") then
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
    return os.isfile(dir .. "/devspace") or os.isfile(dir .. "/devspace.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src, dir)
    local target = dir .. (is_win and "/devspace.exe" or "/devspace")

    if not os.isfile(src) then
        error("devspace: downloaded binary not found at " .. tostring(src))
    end

    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(src, target)
    if not is_win then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("devspace: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("devspace", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("devspace")
    return true
end
