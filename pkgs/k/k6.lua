-- k6: A modern load testing tool, using Go and JavaScript.
--
-- Verified 2026-11-25 against upstream grafana/k6 release v2.4.0:
--   * Every SHA256 below was verified against `k6-v2.4.0-checksums.txt` and by
--     downloading and hashing each published archive.
--   * All five published archives pack a single top-level directory matching
--     the archive stem (`k6-v2.4.0-<os>-<arch>/`) containing only `k6` (POSIX)
--     or `k6.exe` (Windows).
--   * Linux ELF inspection (`readelf -d`, `ldd` on linux-amd64 and linux-arm64):
--     statically linked Go executables with no dynamic section and zero
--     DT_NEEDED entries, so no `xim:glibc` runtime dep is declared.
--   * Windows PE inspection (`k6-v2.4.0-windows-amd64/k6.exe`): imports only
--     `kernel32.dll` (no `VCRUNTIME140.dll`), so no `xim:vcruntime` dep is
--     needed. Upstream publishes no `windows-arm64` archive.
package = {
    spec = "2",

    name = "k6",
    description = "A modern load testing tool, using Go and JavaScript",
    homepage = "https://grafana.com/oss/k6/",
    authors = {"Grafana Labs"},
    maintainers = {"https://github.com/grafana/k6/graphs/contributors"},
    licenses = {"AGPL-3.0"},
    repo = "https://github.com/grafana/k6",
    docs = "https://grafana.com/docs/k6/latest/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"testing", "performance", "cli", "tools"},
    keywords = {"k6", "load-testing", "performance", "benchmark", "javascript", "grafana"},

    programs = {"k6"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/grafana/k6/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/grafana/k6/releases/download/${tag}/k6-v${version}-linux-amd64.tar.gz",
                            aarch64 = "https://github.com/grafana/k6/releases/download/${tag}/k6-v${version}-linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/grafana/k6/releases/download/${tag}/k6-v${version}-macos-amd64.zip",
                            aarch64 = "https://github.com/grafana/k6/releases/download/${tag}/k6-v${version}-macos-arm64.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/grafana/k6/releases/download/${tag}/k6-v${version}-windows-amd64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/grafana/k6/releases/download/v${version}/k6-v${version}-linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.4.0" },
            ["2.4.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "5a5ecf23529ccf93135bc7e5b0c1cd5126ecf5f2672e22eed1556a0ab74abb87",
                    aarch64 = "7bb415f59d81ad649a86f6da6b3e1bd2e4e64e84909deef13e9bca70608abccb",
                },
            },
        },
        macosx = {
            source = "https://github.com/grafana/k6/releases/download/v${version}/k6-v${version}-macos-${arch_alias}.zip",
            ["latest"] = { ref = "2.4.0" },
            ["2.4.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "e4ab42bf4546fb13d54008dee1d018a37ff74f74536da27496c12cc1dfedfd59",
                    aarch64 = "5715745adf4e5ebc92965b26b7785e54e685a370466448cb587b383330a24f20",
                },
            },
        },
        windows = {
            -- Upstream v2.4.0 publishes only windows-amd64 (no windows-arm64).
            ["latest"] = { ref = "2.4.0" },
            ["2.4.0"] = {
                x86_64 = {
                    url = "https://github.com/grafana/k6/releases/download/v2.4.0/k6-v2.4.0-windows-amd64.zip",
                    sha256 = "aaa90b3afc336faf90172c7addf45c4f41305f6f188e3d564f79466e80ac68e3",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

function installed()
    return payload.present({ "k6" }) or payload.present({ "k6.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local normalized = archive:gsub("\\", "/")
    local filename = normalized:match("([^/]+)$") or ""
    local is_win = filename:match("%-windows%-") ~= nil
    local stem = filename:gsub("%.tar%.gz$", ""):gsub("%.zip$", "")

    payload.unpack{
        extracted = stem ~= "" and { stem } or nil,
        strip = 1,
    }
    payload.require({ is_win and "k6.exe" or "k6" })
    return true
end

function config()
    xvm.add("k6", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("k6")
    return true
end
