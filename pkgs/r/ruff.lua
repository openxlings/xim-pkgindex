-- ruff: an extremely fast Python linter and code formatter, written in Rust.
--
-- Verified against official upstream release `astral-sh/ruff` 0.17.6
-- (published 2026-11-19); all SHA-256 digests match upstream `.sha256` /
-- `sha256.sum` files and locally downloaded archives.
--
-- Supported platforms & architectures (official prebuilt binaries only):
--   * linux/x86_64  : ruff-x86_64-unknown-linux-musl.tar.gz
--                     Encloses `ruff-x86_64-unknown-linux-musl/ruff`.
--                     `static-pie linked` ELF with no `.interp` and zero
--                     DT_NEEDED entries (no glibc or gcc-runtime dep needed).
--   * linux/aarch64 : ruff-aarch64-unknown-linux-musl.tar.gz
--                     Encloses `ruff-aarch64-unknown-linux-musl/ruff`.
--                     `statically linked` ELF with no `.interp`, no dynamic
--                     section, and zero DT_NEEDED entries.
--   * macosx/x86_64 : ruff-x86_64-apple-darwin.tar.gz
--                     Encloses `ruff-x86_64-apple-darwin/ruff` (Mach-O x86_64).
--   * macosx/aarch64: ruff-aarch64-apple-darwin.tar.gz
--                     Encloses `ruff-aarch64-apple-darwin/ruff` (Mach-O arm64).
--   * windows/x86_64: ruff-x86_64-pc-windows-msvc.zip
--                     Flat zip containing `ruff.exe` directly at the root.
--                     Statically links MSVC CRT (imports only Windows OS system
--                     DLLs; no `VCRUNTIME140.dll`, so no `xim:vcruntime` dep).
--   * windows/aarch64: ruff-aarch64-pc-windows-msvc.zip
--                     Flat zip containing `ruff.exe` directly at the root.
--                     Statically links MSVC CRT (imports only Windows OS system
--                     DLLs; no `VCRUNTIME140.dll`, so no `xim:vcruntime` dep).

package = {
    spec = "2",

    name = "ruff",
    description = "An extremely fast Python linter and code formatter, written in Rust",
    homepage = "https://docs.astral.sh/ruff",
    authors = {"Astral"},
    maintainers = {"Astral"},
    licenses = {"MIT"},
    repo = "https://github.com/astral-sh/ruff",
    docs = "https://docs.astral.sh/ruff",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"python", "linter", "formatter", "tools"},
    keywords = {"ruff", "python", "linter", "formatter", "rust", "astral"},

    programs = {"ruff"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/astral-sh/ruff/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/astral-sh/ruff/releases/download/${tag}/ruff-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/astral-sh/ruff/releases/download/${tag}/ruff-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/astral-sh/ruff/releases/download/${tag}/ruff-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/astral-sh/ruff/releases/download/${tag}/ruff-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/astral-sh/ruff/releases/download/${tag}/ruff-x86_64-pc-windows-msvc.zip",
                            aarch64 = "https://github.com/astral-sh/ruff/releases/download/${tag}/ruff-aarch64-pc-windows-msvc.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "0.17.6" },
            ["0.17.6"] = {
                x86_64 = {
                    url = "https://github.com/astral-sh/ruff/releases/download/0.17.6/ruff-x86_64-unknown-linux-musl.tar.gz",
                    sha256 = "3c8d5a4264558df8b1587ce32409b658069b6a1ef5bfe4d279431eb1db62a183",
                },
                aarch64 = {
                    url = "https://github.com/astral-sh/ruff/releases/download/0.17.6/ruff-aarch64-unknown-linux-musl.tar.gz",
                    sha256 = "dc96feed20df78c9498106cd2483e710a4db8b00b13a75954b2a37bc9f61e65c",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "0.17.6" },
            ["0.17.6"] = {
                x86_64 = {
                    url = "https://github.com/astral-sh/ruff/releases/download/0.17.6/ruff-x86_64-apple-darwin.tar.gz",
                    sha256 = "5e554db9c2663e1b84911446cab0a9fd4aa6d9a14dc751a4869d2f92209dcb70",
                },
                aarch64 = {
                    url = "https://github.com/astral-sh/ruff/releases/download/0.17.6/ruff-aarch64-apple-darwin.tar.gz",
                    sha256 = "72a886253072cd1bb6a5978a33a5a7add848ee315a8b0f1589f164a11c26328d",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "0.17.6" },
            ["0.17.6"] = {
                x86_64 = {
                    url = "https://github.com/astral-sh/ruff/releases/download/0.17.6/ruff-x86_64-pc-windows-msvc.zip",
                    sha256 = "00c5d5793d308e8575b16b7303527110dd49bd02d46db0a8668b0eefdca14c2e",
                },
                aarch64 = {
                    url = "https://github.com/astral-sh/ruff/releases/download/0.17.6/ruff-aarch64-pc-windows-msvc.zip",
                    sha256 = "fdb5146498cd30b7af288c8becab610a30aa7d300d899927347f49e99766dd85",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

function installed()
    return payload.present({ "ruff" }) or payload.present({ "ruff.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local normalized = archive:gsub("\\", "/")
    local stem = (normalized:match("([^/]+)$") or ""):gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil

    if is_win then
        payload.unpack{}
        payload.require({ "ruff.exe" })
    else
        payload.unpack{ extracted = stem }
        payload.require({ "ruff" })
    end
    return true
end

function config()
    xvm.add("ruff", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("ruff")
    return true
end
