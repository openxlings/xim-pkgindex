-- kind — Kubernetes IN Docker: local Kubernetes clusters using Docker container 'nodes' (kubernetes-sigs/kind).
--
-- Distribution: upstream publishes standalone raw single-file binaries on
-- GitHub Releases (no archive container). Note that `kind-windows-amd64`
-- lacks a `.exe` suffix in its upstream asset filename; `install()` detects
-- the Windows payload/target and installs it as `<install_dir>/kind.exe` on
-- Windows (and `<install_dir>/kind` with executable permissions on POSIX).
--
-- Verified against kubernetes-sigs/kind release v0.33.0 (SHA-256 matched
-- upstream `*.sha256sum`, GitHub release digests, and downloaded bytes):
--   linux/x86_64    kind-linux-amd64    (ELF64 static, readelf -d: no dynamic section, ldd: not dynamic)
--   linux/aarch64   kind-linux-arm64    (ELF64 static, readelf -d: no dynamic section, ldd: not dynamic)
--   macosx/x86_64   kind-darwin-amd64   (Mach-O 64-bit x86_64)
--   macosx/aarch64  kind-darwin-arm64   (Mach-O 64-bit arm64)
--   windows/x86_64  kind-windows-amd64  (PE32+ console x86-64, imports kernel32.dll only; no windows-arm64 asset upstream)

package = {
    spec = "2",

    name = "kind",
    description = "Run local Kubernetes clusters using Docker container 'nodes'",
    homepage = "https://kind.sigs.k8s.io/",
    authors = {"Kubernetes Authors"},
    maintainers = {"kubernetes-sigs"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/kubernetes-sigs/kind",
    docs = "https://kind.sigs.k8s.io/docs/user/quick-start/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"kubernetes", "k8s", "containers", "cli", "devops", "tools"},
    keywords = {"kind", "kubernetes", "k8s", "docker", "cluster", "local", "cli"},

    programs = {"kind"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/kubernetes-sigs/kind/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/kubernetes-sigs/kind/releases/download/${tag}/kind-linux-amd64",
                            aarch64 = "https://github.com/kubernetes-sigs/kind/releases/download/${tag}/kind-linux-arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/kubernetes-sigs/kind/releases/download/${tag}/kind-darwin-amd64",
                            aarch64 = "https://github.com/kubernetes-sigs/kind/releases/download/${tag}/kind-darwin-arm64",
                        },
                        windows = {
                            x86_64 = "https://github.com/kubernetes-sigs/kind/releases/download/${tag}/kind-windows-amd64",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/kubernetes-sigs/kind/releases/download/v${version}/kind-linux-${arch_alias}",
            ["latest"] = { ref = "0.33.0" },
            ["0.33.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "aee6151561422756b764a4ae28e7f44cda5af5a9eead3cc9985112b1de8d8e0d",
                    aarch64 = "20022bee6cfcd5086cb7234d218e3454e6090022f2a8f55d1fa7fcf42c3867a2",
                },
            },
        },
        macosx = {
            source = "https://github.com/kubernetes-sigs/kind/releases/download/v${version}/kind-darwin-${arch_alias}",
            ["latest"] = { ref = "0.33.0" },
            ["0.33.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "5a99f26f57246dc9319dd294803313197a0f34d33c525b3ea8b655db5916ece0",
                    aarch64 = "0c8c7dbe5e23594a198b786c4bc13dacc101fa6196b0cb0b23a1ca44e61f4b4f",
                },
            },
        },
        windows = {
            -- Upstream publishes only kind-windows-amd64 (without .exe suffix; no windows-arm64 asset).
            source = "https://github.com/kubernetes-sigs/kind/releases/download/v${version}/kind-windows-${arch_alias}",
            ["latest"] = { ref = "0.33.0" },
            ["0.33.0"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "4b22adaa135368c5a465d56bbd8e520cbea87272a06ca00b6078e7b81515c9fc",
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
    if base:match("%.exe$") or base:match("^kind%-windows") then
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
    return os.isfile(dir .. "/kind") or os.isfile(dir .. "/kind.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src, dir)
    local target = dir .. (is_win and "/kind.exe" or "/kind")

    if not os.isfile(src) then
        error("kind: downloaded binary not found at " .. tostring(src))
    end

    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(src, target)
    if not is_win then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("kind: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("kind", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("kind")
    return true
end
