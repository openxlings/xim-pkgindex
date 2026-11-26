-- skaffold — Easy and Repeatable Kubernetes Development (GoogleContainerTools/skaffold).
--
-- Distribution: upstream publishes standalone raw single-file binaries on
-- GitHub Releases (no archive container). xlings skips auto-extract for
-- unarchived binaries and passes the downloaded file via pkginfo.install_file(),
-- which install() moves to `<install_dir>/skaffold` on POSIX or
-- `<install_dir>/skaffold.exe` on Windows.
--
-- Verified against GoogleContainerTools/skaffold release v2.25.0 (SHA-256 matched
-- upstream `*.sha256` sidecars, GitHub release digests, and downloaded bytes):
--   linux/x86_64    skaffold-linux-amd64        (ELF64 static, readelf -d: no dynamic section, ldd: not dynamic)
--   linux/aarch64   skaffold-linux-arm64        (ELF64 static, readelf -d: no dynamic section, ldd: not dynamic)
--   macosx/x86_64   skaffold-darwin-amd64       (Mach-O 64-bit x86_64)
--   macosx/aarch64  skaffold-darwin-arm64       (Mach-O 64-bit arm64)
--   windows/x86_64  skaffold-windows-amd64.exe  (PE32+ console x86-64, imports kernel32.dll only; no windows-arm64 asset upstream)

package = {
    spec = "2",

    name = "skaffold",
    description = "Easy and Repeatable Kubernetes Development",
    homepage = "https://skaffold.dev/",
    authors = {"The Skaffold Authors"},
    maintainers = {"GoogleContainerTools"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/GoogleContainerTools/skaffold",
    docs = "https://skaffold.dev/docs/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"kubernetes", "k8s", "containers", "cli", "devops", "tools"},
    keywords = {"skaffold", "kubernetes", "k8s", "docker", "containers", "cicd", "cli"},

    programs = {"skaffold"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/GoogleContainerTools/skaffold/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/GoogleContainerTools/skaffold/releases/download/${tag}/skaffold-linux-amd64",
                            aarch64 = "https://github.com/GoogleContainerTools/skaffold/releases/download/${tag}/skaffold-linux-arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/GoogleContainerTools/skaffold/releases/download/${tag}/skaffold-darwin-amd64",
                            aarch64 = "https://github.com/GoogleContainerTools/skaffold/releases/download/${tag}/skaffold-darwin-arm64",
                        },
                        windows = {
                            x86_64 = "https://github.com/GoogleContainerTools/skaffold/releases/download/${tag}/skaffold-windows-amd64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/GoogleContainerTools/skaffold/releases/download/v${version}/skaffold-linux-${arch_alias}",
            ["latest"] = { ref = "2.25.0" },
            ["2.25.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "42b9e2e3246c19b78fcc53dd60cc7ded1da8704293886b909a2a02b9bef34d20",
                    aarch64 = "416f5fed2009c2b4adc62ae887ee5fc19ff08cc8a0250b81d8682d55626a75fd",
                },
            },
        },
        macosx = {
            source = "https://github.com/GoogleContainerTools/skaffold/releases/download/v${version}/skaffold-darwin-${arch_alias}",
            ["latest"] = { ref = "2.25.0" },
            ["2.25.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "91facde91ba713328adb408be1949f538a5a5dcaee6a3b93725a2c5703bbbb5d",
                    aarch64 = "9adda767c94806827bcb22f2f7a9077bbde6b481331e891f9a7191e2f225dd27",
                },
            },
        },
        windows = {
            -- Upstream publishes only skaffold-windows-amd64.exe (no windows-arm64 asset).
            source = "https://github.com/GoogleContainerTools/skaffold/releases/download/v${version}/skaffold-windows-${arch_alias}.exe",
            ["latest"] = { ref = "2.25.0" },
            ["2.25.0"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "4ca20b716f4756b0f5e2a06b13bf9cb189ebc8e6978665f274f8fd23fbcf47d6",
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
    if base:match("%.exe$") or base:match("^skaffold%-windows") then
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
    return os.isfile(dir .. "/skaffold") or os.isfile(dir .. "/skaffold.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src, dir)
    local target = dir .. (is_win and "/skaffold.exe" or "/skaffold")

    if not os.isfile(src) then
        error("skaffold: downloaded binary not found at " .. tostring(src))
    end

    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(src, target)
    if not is_win then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("skaffold: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("skaffold", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("skaffold")
    return true
end
