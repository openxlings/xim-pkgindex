-- Official portable assets from ouch-org/ouch 0.8.3. Linux uses the
-- statically linked musl builds; sigstore sidecars and GNU-linked variants
-- are intentionally not advertised.
-- The shipped binary enables upstream's default bzip3 (LGPL-3.0-only) and
-- UnRAR support; UnRAR's own license permits redistribution with its stated
-- restriction on creating RAR-compatible archivers.
package = {
    spec = "2",
    name = "ouch",
    description = "A command-line utility for easily compressing and decompressing files and directories",
    homepage = "https://github.com/ouch-org/ouch",
    authors = {"João Marcos", "Vinícius Rodrigues Miguel and contributors"},
    maintainers = {"ouch-org"},
    licenses = {"MIT", "LGPL-3.0-only", "LicenseRef-UnRAR"},
    repo = "https://github.com/ouch-org/ouch",
    docs = "https://github.com/ouch-org/ouch#readme",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tools", "compression"},
    keywords = {"ouch", "compression", "decompression", "archive"},
    programs = {"ouch"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/ouch-org/ouch/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/ouch-org/ouch/releases/download/${version}/ouch-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/ouch-org/ouch/releases/download/${version}/ouch-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/ouch-org/ouch/releases/download/${version}/ouch-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/ouch-org/ouch/releases/download/${version}/ouch-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/ouch-org/ouch/releases/download/${version}/ouch-x86_64-pc-windows-msvc.zip",
                            aarch64 = "https://github.com/ouch-org/ouch/releases/download/${version}/ouch-aarch64-pc-windows-msvc.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/ouch-org/ouch/releases/download/${version}/ouch-${arch}-unknown-linux-musl.tar.gz",
            ["latest"] = { ref = "0.8.3" },
            ["0.8.3"] = {
                sha256 = {
                    x86_64 = "eaab9b997a823f584557ac5f85205105ae577a4c4fbd23926b686469cfa19881",
                    aarch64 = "4619158de69e65e8d23147c3d8b46b116feb0259c8a1704df7d792394c2b5847",
                },
            },
        },
        macosx = {
            source = "https://github.com/ouch-org/ouch/releases/download/${version}/ouch-${arch}-apple-darwin.tar.gz",
            ["latest"] = { ref = "0.8.3" },
            ["0.8.3"] = {
                sha256 = {
                    x86_64 = "c97188f4c09fb959ea0d3117781ae524431b62fcd8f1b8d19323550773cd438a",
                    aarch64 = "969c1bd9105b5033cc9cac0a37c011d23482948d681b43f97c6f79311f3263d0",
                },
            },
        },
        windows = {
            source = "https://github.com/ouch-org/ouch/releases/download/${version}/ouch-${arch}-pc-windows-msvc.zip",
            ["latest"] = { ref = "0.8.3" },
            ["0.8.3"] = {
                sha256 = {
                    x86_64 = "6383a95987894412d5c9c4172e3d1d87c86aa322acb2b7ffcad42f492abc5dfe",
                    aarch64 = "2ffacd22c03a5a73cf4084ef8d70f13788268dfa7148242ad9fc5002e167c4c7",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function executable_name()
    return os.getenv("OS") == "Windows_NT" and "ouch.exe" or "ouch"
end

local function required_files()
    return { executable_name(), "LICENSE", "README.md" }
end

function installed()
    return payload.present(required_files())
end

function install()
    local archive = tostring(pkginfo.install_file() or ""):gsub("\\", "/")
    local basename = archive:match("([^/]+)$") or ""
    local extracted = basename:gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    if extracted == basename then
        error("ouch: unsupported release archive " .. archive)
    end

    payload.unpack({ extracted = extracted, strip = 1 })
    payload.require(required_files())
    return true
end

function config()
    xvm.add("ouch", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("ouch")
    return true
end
