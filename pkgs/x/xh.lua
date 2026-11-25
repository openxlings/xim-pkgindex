-- xh - friendly and fast tool for sending HTTP requests.
--
-- Platform and architecture coverage (verified against ducaale/xh v0.26.3):
--   linux    x86_64   static-pie linked musl ELF (`xh` inside `xh-v<ver>-x86_64-unknown-linux-musl/`)
--   linux    aarch64  statically linked musl ELF (`xh` inside `xh-v<ver>-aarch64-unknown-linux-musl/`)
--   macosx   x86_64   Mach-O 64-bit x86_64 executable (`xh` inside `xh-v<ver>-x86_64-apple-darwin/`)
--   macosx   aarch64  Mach-O 64-bit arm64 executable (`xh` inside `xh-v<ver>-aarch64-apple-darwin/`)
--   windows  x86_64   PE32+ x86-64 executable (`xh.exe` inside `xh-v<ver>-x86_64-pc-windows-msvc/`,
--                     links only standard Windows system DLLs; no VCRUNTIME140.dll import)
--
-- Upstream also publishes arm-unknown-linux-gnueabihf (32-bit ARM), which is
-- outside `archs`, and publishes no Windows ARM64 archive.

package = {
    spec = "2",

    name = "xh",
    description = "Friendly and fast tool for sending HTTP requests",
    homepage = "https://github.com/ducaale/xh",
    authors = {"ducaale"},
    maintainers = {"ducaale"},
    licenses = {"MIT"},
    repo = "https://github.com/ducaale/xh",
    docs = "https://github.com/ducaale/xh#readme",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "http", "network", "tools"},
    keywords = {"xh", "http", "httpie", "curl", "rust", "cli"},

    programs = {"xh"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/ducaale/xh/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/ducaale/xh/releases/download/${tag}/xh-v${version}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/ducaale/xh/releases/download/${tag}/xh-v${version}-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/ducaale/xh/releases/download/${tag}/xh-v${version}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/ducaale/xh/releases/download/${tag}/xh-v${version}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/ducaale/xh/releases/download/${tag}/xh-v${version}-x86_64-pc-windows-msvc.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "0.26.3" },
            ["0.26.3"] = {
                x86_64 = {
                    url = "https://github.com/ducaale/xh/releases/download/v0.26.3/xh-v0.26.3-x86_64-unknown-linux-musl.tar.gz",
                    sha256 = "cbbf53bd76007d57d95e4bed8ba7fb3b7fcec22af4bdfc1ff119cd5de351e74f",
                },
                aarch64 = {
                    url = "https://github.com/ducaale/xh/releases/download/v0.26.3/xh-v0.26.3-aarch64-unknown-linux-musl.tar.gz",
                    sha256 = "a45d8cb6c234c6850f9fc2395fc3544ab7691fb511237f00179aedba1bcd525e",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "0.26.3" },
            ["0.26.3"] = {
                x86_64 = {
                    url = "https://github.com/ducaale/xh/releases/download/v0.26.3/xh-v0.26.3-x86_64-apple-darwin.tar.gz",
                    sha256 = "b1c07e42238485bdcbed0982766f58b4daa631f0a33870100054ef5fbb4a3c4b",
                },
                aarch64 = {
                    url = "https://github.com/ducaale/xh/releases/download/v0.26.3/xh-v0.26.3-aarch64-apple-darwin.tar.gz",
                    sha256 = "50d61bd755942752b054297a1612ec191654f137f8939673cda83c686cb5b0f2",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "0.26.3" },
            ["0.26.3"] = {
                x86_64 = {
                    url = "https://github.com/ducaale/xh/releases/download/v0.26.3/xh-v0.26.3-x86_64-pc-windows-msvc.zip",
                    sha256 = "23d92fd78ff6a93c4e1c4de3a6b614bb8a31999acb441793630bcc37f9cd6c45",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

-- Upstream archives extract into `xh-v<ver>-<target>/` with `xh` (or `xh.exe`),
-- LICENSE, README.md, completions/, and doc/.
function installed()
    return payload.present({ "xh" }) or payload.present({ "xh.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("xh: install_file is empty")
    end

    local normalized = archive:gsub("\\", "/")
    local stem = (normalized:match("([^/]+)$") or ""):gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil

    payload.unpack{ extracted = stem, strip = 1 }
    payload.require({ is_win and "xh.exe" or "xh" })
    return true
end

function config()
    xvm.add("xh", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("xh")
    return true
end
