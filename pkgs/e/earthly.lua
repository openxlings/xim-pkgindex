-- earthly — Super simple build framework with fast, repeatable builds (earthly/earthly).
--
-- Distribution: upstream publishes standalone raw single-file binaries on
-- GitHub Releases (no archive container). xlings skips auto-extract for
-- unarchived binaries and passes the downloaded file via pkginfo.install_file(),
-- which install() moves to `<install_dir>/earthly` on POSIX or
-- `<install_dir>/earthly.exe` on Windows.
--
-- Verified against earthly/earthly release v0.8.16 (SHA-256 matched upstream
-- `checksum.asc`, GitHub release digests, and downloaded bytes):
--   linux/x86_64    earthly-linux-amd64        (ELF64 static, readelf -d: no dynamic section, ldd: not dynamic)
--   linux/aarch64   earthly-linux-arm64        (ELF64 static, readelf -d: no dynamic section)
--   macosx/x86_64   earthly-darwin-amd64       (Mach-O 64-bit x86_64)
--   macosx/aarch64  earthly-darwin-arm64       (Mach-O 64-bit arm64)
--   windows/x86_64  earthly-windows-amd64.exe  (PE32+ console x86-64, imports kernel32.dll only; no windows-arm64 asset upstream)

package = {
    spec = "2",

    name = "earthly",
    description = "Super simple build framework with fast, repeatable builds",
    homepage = "https://earthly.dev",
    authors = {"Earthly Technologies"},
    maintainers = {"earthly"},
    licenses = {"MPL-2.0"},
    repo = "https://github.com/earthly/earthly",
    docs = "https://docs.earthly.dev/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"build", "containers", "cicd", "cli", "devops", "tools"},
    keywords = {"earthly", "earthfile", "build", "docker", "containers", "cicd", "cli"},

    programs = {"earthly"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/earthly/earthly/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/earthly/earthly/releases/download/${tag}/earthly-linux-amd64",
                            aarch64 = "https://github.com/earthly/earthly/releases/download/${tag}/earthly-linux-arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/earthly/earthly/releases/download/${tag}/earthly-darwin-amd64",
                            aarch64 = "https://github.com/earthly/earthly/releases/download/${tag}/earthly-darwin-arm64",
                        },
                        windows = {
                            x86_64 = "https://github.com/earthly/earthly/releases/download/${tag}/earthly-windows-amd64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/earthly/earthly/releases/download/v${version}/earthly-linux-${arch_alias}",
            ["latest"] = { ref = "0.8.16" },
            ["0.8.16"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "3ef3163c81bdd10e28ab31cd96e35c1856d97478c8ce7f20954b8bea7a598404",
                    aarch64 = "dfdc3957f24754d66cea0c19a46bb542941132c9ccc81df7d71009ed79be54e8",
                },
            },
        },
        macosx = {
            source = "https://github.com/earthly/earthly/releases/download/v${version}/earthly-darwin-${arch_alias}",
            ["latest"] = { ref = "0.8.16" },
            ["0.8.16"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "1592cb497256577a76dda4e827010876eeeec05e76e3a203f60a68c71a80fc3a",
                    aarch64 = "4ac88e47414778f0a5af0f59637148c9b0eabc7c77cd77890e6cd99e3040a2b4",
                },
            },
        },
        windows = {
            -- Upstream publishes only earthly-windows-amd64.exe (no windows-arm64 asset).
            source = "https://github.com/earthly/earthly/releases/download/v${version}/earthly-windows-${arch_alias}.exe",
            ["latest"] = { ref = "0.8.16" },
            ["0.8.16"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "30672f3a3ce73893b30fe47e6e9b0aeed67bd596a156c10762ea7fce3db5d934",
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
    if base:match("%.exe$") or base:match("^earthly%-windows") then
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
    return os.isfile(dir .. "/earthly") or os.isfile(dir .. "/earthly.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src, dir)
    local target = dir .. (is_win and "/earthly.exe" or "/earthly")

    if not os.isfile(src) then
        error("earthly: downloaded binary not found at " .. tostring(src))
    end

    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(src, target)
    if not is_win then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("earthly: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("earthly", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("earthly")
    return true
end
