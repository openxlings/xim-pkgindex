-- container-structure-test — Validate the structure of your container images (GoogleContainerTools/container-structure-test).
--
-- Distribution: upstream publishes standalone raw single-file binaries on
-- GitHub Releases (no archive container). xlings skips auto-extract for
-- unarchived binaries and passes the downloaded file via pkginfo.install_file(),
-- which install() moves to `<install_dir>/container-structure-test` on POSIX or
-- `<install_dir>/container-structure-test.exe` on Windows.
--
-- Verified against GoogleContainerTools/container-structure-test release v1.22.1
-- (SHA-256 matched upstream `checksums.txt`, GitHub release digests, and downloaded bytes):
--   linux/x86_64    container-structure-test-linux-amd64        (ELF64 static, readelf -d: no dynamic section, ldd: not a dynamic executable)
--   linux/aarch64   container-structure-test-linux-arm64        (ELF64 static, readelf -d: no dynamic section)
--   macosx/x86_64   container-structure-test-darwin-amd64       (Mach-O 64-bit x86_64)
--   macosx/aarch64  container-structure-test-darwin-arm64       (Mach-O 64-bit arm64)
--   windows/x86_64  container-structure-test-windows-amd64.exe  (PE32+ console x86-64, imports kernel32.dll only; no windows-arm64 asset upstream)

package = {
    spec = "2",

    name = "container-structure-test",
    description = "Validate the structure of your container images",
    homepage = "https://github.com/GoogleContainerTools/container-structure-test",
    authors = {"GoogleContainerTools"},
    maintainers = {"GoogleContainerTools"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/GoogleContainerTools/container-structure-test",
    docs = "https://github.com/GoogleContainerTools/container-structure-test#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"containers", "testing", "docker", "cli", "devops", "tools"},
    keywords = {"container-structure-test", "containers", "docker", "testing", "ci", "cli"},

    programs = {"container-structure-test"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/GoogleContainerTools/container-structure-test/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/GoogleContainerTools/container-structure-test/releases/download/${tag}/container-structure-test-linux-amd64",
                            aarch64 = "https://github.com/GoogleContainerTools/container-structure-test/releases/download/${tag}/container-structure-test-linux-arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/GoogleContainerTools/container-structure-test/releases/download/${tag}/container-structure-test-darwin-amd64",
                            aarch64 = "https://github.com/GoogleContainerTools/container-structure-test/releases/download/${tag}/container-structure-test-darwin-arm64",
                        },
                        windows = {
                            x86_64 = "https://github.com/GoogleContainerTools/container-structure-test/releases/download/${tag}/container-structure-test-windows-amd64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/GoogleContainerTools/container-structure-test/releases/download/v${version}/container-structure-test-linux-${arch_alias}",
            ["latest"] = { ref = "1.22.1" },
            ["1.22.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "fa35e89512a8978585f76cf41397956d2e3a30c62c2ad3fb857b1597074d14ca",
                    aarch64 = "801826ed107222120eb6df8c143b7de752cfebbe3aebfeea576e7098486917c2",
                },
            },
        },
        macosx = {
            source = "https://github.com/GoogleContainerTools/container-structure-test/releases/download/v${version}/container-structure-test-darwin-${arch_alias}",
            ["latest"] = { ref = "1.22.1" },
            ["1.22.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "1ca7265ed9061785a39cda83d5a8104c769bbf432dab40a269596ea6f1a13c45",
                    aarch64 = "ba00172029ecec3afda7fd93a5eee7cdaef710196df7103689da3386eba56b0a",
                },
            },
        },
        windows = {
            -- Upstream publishes only container-structure-test-windows-amd64.exe (no windows-arm64 asset).
            source = "https://github.com/GoogleContainerTools/container-structure-test/releases/download/v${version}/container-structure-test-windows-${arch_alias}.exe",
            ["latest"] = { ref = "1.22.1" },
            ["1.22.1"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "91d30f3cea928024663b04de9e66ef4d0fc17b2e5d00fdee268b1fe5daac1260",
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
    if base:match("%.exe$") or base:match("^container%-structure%-test%-windows") then
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
    return os.isfile(dir .. "/container-structure-test") or os.isfile(dir .. "/container-structure-test.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src, dir)
    local target = dir .. (is_win and "/container-structure-test.exe" or "/container-structure-test")

    if not os.isfile(src) then
        error("container-structure-test: downloaded binary not found at " .. tostring(src))
    end

    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(src, target)
    if not is_win then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("container-structure-test: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("container-structure-test", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("container-structure-test")
    return true
end
