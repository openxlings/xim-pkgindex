-- k0sctl — A bootstrapping and management tool for k0s clusters (k0sproject/k0sctl).
--
-- Distribution: upstream publishes standalone raw single-file binaries on
-- GitHub Releases (no archive container). xlings skips auto-extract for
-- unarchived binaries and passes the downloaded file via pkginfo.install_file(),
-- which install() moves to `<install_dir>/k0sctl` on POSIX or
-- `<install_dir>/k0sctl.exe` on Windows.
--
-- Verified against k0sproject/k0sctl release v0.33.1 (SHA-256 matched upstream
-- `checksums.txt` and downloaded bytes):
--   linux/x86_64    k0sctl-linux-amd64    (ELF64 static, readelf -d: no dynamic section, ldd: not dynamic)
--   linux/aarch64   k0sctl-linux-arm64    (ELF64 static, readelf -d: no dynamic section, ldd: not dynamic)
--   macosx/x86_64   k0sctl-darwin-amd64   (Mach-O 64-bit x86_64)
--   macosx/aarch64  k0sctl-darwin-arm64   (Mach-O 64-bit arm64)
--   windows/x86_64  k0sctl-win-amd64.exe  (PE32+ console x86-64, imports kernel32.dll only; no windows-arm64 asset upstream)

package = {
    spec = "2",

    name = "k0sctl",
    description = "A bootstrapping and management tool for k0s clusters",
    homepage = "https://github.com/k0sproject/k0sctl",
    authors = {"The k0sctl Authors"},
    maintainers = {"k0sproject"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/k0sproject/k0sctl",
    docs = "https://github.com/k0sproject/k0sctl#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"kubernetes", "k0s", "k8s", "cli", "devops", "tools"},
    keywords = {"k0sctl", "k0s", "kubernetes", "k8s", "cluster", "bootstrap", "cli"},

    programs = {"k0sctl"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/k0sproject/k0sctl/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/k0sproject/k0sctl/releases/download/${tag}/k0sctl-linux-amd64",
                            aarch64 = "https://github.com/k0sproject/k0sctl/releases/download/${tag}/k0sctl-linux-arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/k0sproject/k0sctl/releases/download/${tag}/k0sctl-darwin-amd64",
                            aarch64 = "https://github.com/k0sproject/k0sctl/releases/download/${tag}/k0sctl-darwin-arm64",
                        },
                        windows = {
                            x86_64 = "https://github.com/k0sproject/k0sctl/releases/download/${tag}/k0sctl-win-amd64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/k0sproject/k0sctl/releases/download/v${version}/k0sctl-linux-${arch_alias}",
            ["latest"] = { ref = "0.33.1" },
            ["0.33.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "bd5cd9125c93d8d30c33f7b2f3693fed0d74140a248d433dad74f2b7015295b5",
                    aarch64 = "3632072361f3e83dde9b34f83eea49673d3bfe84763cf361edc3aec7209231a6",
                },
            },
        },
        macosx = {
            source = "https://github.com/k0sproject/k0sctl/releases/download/v${version}/k0sctl-darwin-${arch_alias}",
            ["latest"] = { ref = "0.33.1" },
            ["0.33.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "fa696fa9102f872fc0f8bdca092b753d7cdd5fe64c5fec8f8033ec6e67a9c364",
                    aarch64 = "d5e9d8663c84e3e34fc3f3b032d7f97e372cda0ecd31b363f937b0bbed18f473",
                },
            },
        },
        windows = {
            -- Upstream publishes only k0sctl-win-amd64.exe (no windows-arm64 asset).
            source = "https://github.com/k0sproject/k0sctl/releases/download/v${version}/k0sctl-win-${arch_alias}.exe",
            ["latest"] = { ref = "0.33.1" },
            ["0.33.1"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "3c9dc070a8ab4080f497785826c4f7459fd5430fa9f57f6ec2c4e19d3e536b2e",
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
    if base:match("%.exe$") or base:match("^k0sctl%-win") then
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
    return os.isfile(dir .. "/k0sctl") or os.isfile(dir .. "/k0sctl.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src, dir)
    local target = dir .. (is_win and "/k0sctl.exe" or "/k0sctl")

    if not os.isfile(src) then
        error("k0sctl: downloaded binary not found at " .. tostring(src))
    end

    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(src, target)
    if not is_win then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("k0sctl: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("k0sctl", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("k0sctl")
    return true
end
