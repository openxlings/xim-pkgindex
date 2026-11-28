-- Prometheus metrics server and promtool, using the unmodified upstream
-- archives. Each target contains one prometheus-<version>.<os>-<arch>/
-- directory; retain LICENSE, NOTICE and the example prometheus.yml.
--
-- Install only the payload and xvm routes. Do not start a server, install a
-- service, select a listening address, or write configuration/data outside
-- the package directory. Users choose their own config and TSDB locations.
-- SHA256 values come from upstream v3.16.0/sha256sums.txt.
package = {
    spec = "2",

    name = "prometheus",
    description = "Monitoring system and time series database with the promtool validation CLI",
    homepage = "https://prometheus.io",
    authors = {"The Prometheus Authors"},
    maintainers = {"https://github.com/prometheus/prometheus/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/prometheus/prometheus",
    docs = "https://prometheus.io/docs/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"monitoring", "database", "server", "tools"},
    keywords = {"prometheus", "promtool", "metrics", "promql", "monitoring", "tsdb"},

    programs = {"prometheus", "promtool"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/prometheus/prometheus/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/prometheus/prometheus/releases/download/${tag}/prometheus-${version}.linux-amd64.tar.gz",
                            aarch64 = "https://github.com/prometheus/prometheus/releases/download/${tag}/prometheus-${version}.linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/prometheus/prometheus/releases/download/${tag}/prometheus-${version}.darwin-amd64.tar.gz",
                            aarch64 = "https://github.com/prometheus/prometheus/releases/download/${tag}/prometheus-${version}.darwin-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/prometheus/prometheus/releases/download/${tag}/prometheus-${version}.windows-amd64.zip",
                            aarch64 = "https://github.com/prometheus/prometheus/releases/download/${tag}/prometheus-${version}.windows-arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/prometheus/prometheus/releases/download/v${version}/prometheus-${version}.linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "3.16.0" },
            ["3.16.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "68727009472a2c02e1ff7f062fd5b3e637285bffc8fc2d340c76fb449d6e0f34",
                    aarch64 = "fd8571b8162f4020232d886f17340bcf92e1722985ae3b4c1d096157826c0fbe",
                },
            },
        },
        macosx = {
            source = "https://github.com/prometheus/prometheus/releases/download/v${version}/prometheus-${version}.darwin-${arch_alias}.tar.gz",
            ["latest"] = { ref = "3.16.0" },
            ["3.16.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "998fb3301c1d77452bdfc481f61353e2e4a3b16c97a6b725c2b7beee5464c8c2",
                    aarch64 = "f7c71b553316f822bdd860a3ea527ebefb2f8e944e5b7dfd419ae2653cf3ba01",
                },
            },
        },
        windows = {
            source = "https://github.com/prometheus/prometheus/releases/download/v${version}/prometheus-${version}.windows-${arch_alias}.zip",
            ["latest"] = { ref = "3.16.0" },
            ["3.16.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "89c03c2f24400fb58668440b6d7226f68564acda27d657e77acfbda42be32cb3",
                    aarch64 = "0c15ccc34d94f7eb01a050e51f535c10c53dfc2a2e4e5e1463cdf2019b1c79f8",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function required_files(ext)
    return { "prometheus" .. ext, "promtool" .. ext, "LICENSE", "NOTICE", "prometheus.yml" }
end

function installed()
    return payload.present(required_files("")) or payload.present(required_files(".exe"))
end

function install()
    local prefix = "prometheus-" .. pkginfo.version() .. "."
    payload.unpack{
        extracted = {
            prefix .. "linux-amd64", prefix .. "linux-arm64",
            prefix .. "darwin-amd64", prefix .. "darwin-arm64",
            prefix .. "windows-amd64", prefix .. "windows-arm64",
        },
        strip = 1,
    }
    local ext = tostring(pkginfo.install_file()):match("%.zip$") and ".exe" or ""
    payload.require(required_files(ext))
    return true
end

function config()
    local bindir = pkginfo.install_dir()
    xvm.add("prometheus", { bindir = bindir })
    xvm.add("promtool", { bindir = bindir, binding = "prometheus@" .. pkginfo.version() })
    return true
end

function uninstall()
    xvm.remove("promtool")
    xvm.remove("prometheus")
    return true
end
