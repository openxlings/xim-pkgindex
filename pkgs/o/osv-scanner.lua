-- osv-scanner — Vulnerability scanner written in Go using the OSV database (google/osv-scanner).
--
-- Distribution: upstream publishes raw single-file binaries on GitHub Releases
-- (no archive container). All 6 supported asset basenames are distinct across
-- platforms and architectures.
--
-- Verified against google/osv-scanner release v2.7.1 (SHA-256 matched upstream
-- osv-scanner_SHA256SUMS, GitHub release digests, and downloaded bytes):
--   linux/x86_64    osv-scanner_linux_amd64        (ELF64 static, readelf -d: no dynamic section, ldd: not a dynamic executable)
--   linux/aarch64   osv-scanner_linux_arm64        (ELF64 static, readelf -d: no dynamic section)
--   macosx/x86_64   osv-scanner_darwin_amd64       (Mach-O 64-bit x86_64)
--   macosx/aarch64  osv-scanner_darwin_arm64       (Mach-O 64-bit arm64)
--   windows/x86_64  osv-scanner_windows_amd64.exe  (PE32+ console x86-64, imports kernel32.dll only)
--   windows/aarch64 osv-scanner_windows_arm64.exe  (PE32+ console ARM64, imports kernel32.dll only)

package = {
    spec = "2",

    name = "osv-scanner",
    description = "Vulnerability scanner written in Go which uses the data provided by https://osv.dev",
    homepage = "https://google.github.io/osv-scanner/",
    authors = {"Google"},
    maintainers = {"Google"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/google/osv-scanner",
    docs = "https://google.github.io/osv-scanner/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"security", "scanner", "cli", "tools"},
    keywords = {"osv-scanner", "osv", "vulnerability", "scanner", "security", "sbom", "go"},

    programs = {"osv-scanner"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/google/osv-scanner/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/google/osv-scanner/releases/download/${tag}/osv-scanner_linux_amd64",
                            aarch64 = "https://github.com/google/osv-scanner/releases/download/${tag}/osv-scanner_linux_arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/google/osv-scanner/releases/download/${tag}/osv-scanner_darwin_amd64",
                            aarch64 = "https://github.com/google/osv-scanner/releases/download/${tag}/osv-scanner_darwin_arm64",
                        },
                        windows = {
                            x86_64 = "https://github.com/google/osv-scanner/releases/download/${tag}/osv-scanner_windows_amd64.exe",
                            aarch64 = "https://github.com/google/osv-scanner/releases/download/${tag}/osv-scanner_windows_arm64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/google/osv-scanner/releases/download/v${version}/osv-scanner_linux_${arch_alias}",
            ["latest"] = { ref = "2.7.1" },
            ["2.7.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "fb7dab19a8bd9bbe5c3189f09d4b7ee1820c9553a23bac202648a56efd2f6ee8",
                    aarch64 = "983d22fbad9724514e3fcc6acc83b5fa64c5ffa6b0d9f510028f22c1b223ff81",
                },
            },
        },
        macosx = {
            source = "https://github.com/google/osv-scanner/releases/download/v${version}/osv-scanner_darwin_${arch_alias}",
            ["latest"] = { ref = "2.7.1" },
            ["2.7.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "b8420d5485ba792626315f1bf9a5a2046e971d38eea75bf9090c38852dbc3b1b",
                    aarch64 = "b22c02877a811c8f78956e8643efa554932b7378f590d13f8e97d4e9448a29f3",
                },
            },
        },
        windows = {
            source = "https://github.com/google/osv-scanner/releases/download/v${version}/osv-scanner_windows_${arch_alias}.exe",
            ["latest"] = { ref = "2.7.1" },
            ["2.7.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "7121dcf420aefbbf89a7f0050c4d3094e079ff93afd334dfc96f16b02ec85800",
                    aarch64 = "5f3998b55c9268f8468502bbcb60645038fd5b145ee5e685e6ae2a32e923afc7",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local function _is_windows_payload(file)
    return tostring(file):lower():match("%.exe$") ~= nil
end

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/osv-scanner") or os.isfile(dir .. "/osv-scanner.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src)
    local target = dir .. (is_win and "/osv-scanner.exe" or "/osv-scanner")

    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(src, target)
    if not is_win then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("osv-scanner: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("osv-scanner", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("osv-scanner")
    return true
end
