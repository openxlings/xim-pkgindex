-- dust -- A more intuitive version of du in Rust.
--
-- Verified against upstream GitHub release bootandy/dust v1.2.8:
--   Every SHA256 below matches the GitHub release asset digests and was
--   verified locally with sha256sum on the downloaded archives.
--   All archives contain a single top-level directory `dust-v<ver>-<target>/`
--   holding `dust` (or `dust.exe`), `LICENSE`, and `README.md`.
--   * linux/x86_64   : dust-v1.2.8-x86_64-unknown-linux-musl.tar.gz
--                      static-pie ELF (no PT_INTERP, zero DT_NEEDED; ldd: "statically linked")
--   * linux/aarch64  : dust-v1.2.8-aarch64-unknown-linux-musl.tar.gz
--                      statically linked ELF (no .dynamic section, no DT_NEEDED)
--   * macosx/x86_64  : dust-v1.2.8-x86_64-apple-darwin.tar.gz
--   * macosx/aarch64 : dust-v1.2.8-aarch64-apple-darwin.tar.gz
--   * windows/x86_64 : dust-v1.2.8-x86_64-pc-windows-msvc.zip
--                      PE32+ x86_64 importing VCRUNTIME140.dll and UCRT API sets,
--                      so `xim:vcruntime` DLLs are copied app-local beside dust.exe.
--   * windows/aarch64: omitted (`dust-v1.2.8-aarch64-pc-windows-msvc.zip` also imports
--                      VCRUNTIME140.dll while `xim:vcruntime` currently covers `x86_64` only).

package = {
    spec = "2",

    name = "dust",
    description = "A more intuitive version of du in rust",
    homepage = "https://github.com/bootandy/dust",
    authors = {"bootandy"},
    maintainers = {"https://github.com/bootandy/dust/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/bootandy/dust",
    docs = "https://github.com/bootandy/dust#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "filesystem", "disk-usage", "tools"},
    keywords = {"dust", "du", "disk-usage", "filesystem", "rust"},

    programs = {"dust"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/bootandy/dust/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/bootandy/dust/releases/download/${tag}/dust-v${version}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/bootandy/dust/releases/download/${tag}/dust-v${version}-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/bootandy/dust/releases/download/${tag}/dust-v${version}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/bootandy/dust/releases/download/${tag}/dust-v${version}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/bootandy/dust/releases/download/${tag}/dust-v${version}-x86_64-pc-windows-msvc.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/bootandy/dust/releases/download/v${version}/dust-v${version}-${arch}-unknown-linux-musl.tar.gz",
            ["latest"] = { ref = "1.2.8" },
            ["1.2.8"] = {
                sha256 = {
                    x86_64 = "4480bb9a3936f23cd9a1d5681618821f7f431ae47af0794be99f2baa5a88a60f",
                    aarch64 = "02140655d64a490e1b1486ae4b55ff797c2e69666e1993cc3c42a2885e169d3c",
                },
            },
        },
        macosx = {
            source = "https://github.com/bootandy/dust/releases/download/v${version}/dust-v${version}-${arch}-apple-darwin.tar.gz",
            ["latest"] = { ref = "1.2.8" },
            ["1.2.8"] = {
                sha256 = {
                    x86_64 = "e875ace7b7b5aa06467375c5d297110005c48a9f16c8a38c43981f14d325372f",
                    aarch64 = "829b1223d968ec84b7e0f2374971f77a9b7443d99a7dfbbaa68bc374a0fe8a93",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            source = "https://github.com/bootandy/dust/releases/download/v${version}/dust-v${version}-${arch}-pc-windows-msvc.zip",
            ["latest"] = { ref = "1.2.8" },
            ["1.2.8"] = {
                sha256 = {
                    x86_64 = "adfbdab0765c72e5e3a8c43ae9e92f4076cdb30c6364b68817301fb85fe44ecd",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

function installed()
    return payload.present({ "dust", "LICENSE" })
        or payload.present({ "dust.exe", "LICENSE" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("dust: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local stem = (normalized:match("([^/]+)$") or ""):gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil or os.getenv("OS") == "Windows_NT"

    payload.unpack{ extracted = stem, strip = 1 }

    if is_win then
        if not pkginfo.dep_install_dir then
            error("dust: xim:vcruntime runtime dep lookup is unavailable")
        end
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "dust: xim:vcruntime payload directory is missing")
        local copied = 0
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir)
            copied = copied + 1
        end
        if copied == 0 then
            error("dust: no CRT DLLs found in " .. crt .. "/bin")
        end
    end

    payload.require({ is_win and "dust.exe" or "dust", "LICENSE" })
    return true
end

function config()
    xvm.add("dust", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("dust")
    return true
end
