-- lychee: fast, async, stream-based link checker written in Rust.
--
-- Official prebuilt archives verified against lycheeverse/lychee release
-- `lychee-v0.24.2` (each asset's `.sha256` sidecar, GitHub release digest, and
-- computed `sha256sum` match):
--   * linux/x86_64   : lychee-x86_64-unknown-linux-musl.tar.gz
--                      static-pie musl ELF (`readelf -d`: zero DT_NEEDED entries,
--                      no PT_INTERP; `ldd`: "statically linked").
--   * linux/aarch64  : lychee-aarch64-unknown-linux-musl.tar.gz
--                      statically linked musl ELF (no dynamic section or PT_INTERP;
--                      `ldd`: "not a dynamic executable").
--     -> No `xim:glibc` or `xim:gcc-runtime` dependency on Linux.
--   * macosx/x86_64  : lychee-x86_64-apple-darwin.tar.gz (Mach-O 64-bit x86_64)
--   * macosx/aarch64 : lychee-aarch64-apple-darwin.tar.gz (Mach-O 64-bit arm64)
--   * windows/x86_64 : lychee-x86_64-pc-windows-msvc.zip
--                      PE32+ x86-64 imports `VCRUNTIME140.dll` and Windows
--                      UCRT/system DLLs, so `xpm.windows.deps.runtime` declares
--                      `xim:vcruntime` and `install()` copies its DLLs app-local
--                      beside `lychee.exe`. Upstream publishes no Windows ARM64
--                      release asset.
--
-- Every upstream archive encloses its payload in `<archive-stem>/` containing
-- `lychee` (or `lychee.exe`), `README.md`, `docs/`, and `complete/`.

package = {
    spec = "2",

    name = "lychee",
    description = "Fast, async, stream-based link checker written in Rust",
    homepage = "https://lychee.cli.rs",
    authors = {"Matthias Endler", "Thomas Zahner"},
    maintainers = {"https://github.com/lycheeverse/lychee/graphs/contributors"},
    licenses = {"MIT", "Apache-2.0"},
    repo = "https://github.com/lycheeverse/lychee",
    docs = "https://lychee.cli.rs/",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "linter", "markdown", "validator", "tools"},
    keywords = {"lychee", "link-checker", "markdown", "html", "urls", "cli", "rust"},

    programs = {"lychee"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/lycheeverse/lychee/releases",
            tag = "lychee-v${version}",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/lycheeverse/lychee/releases/download/${tag}/lychee-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/lycheeverse/lychee/releases/download/${tag}/lychee-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/lycheeverse/lychee/releases/download/${tag}/lychee-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/lycheeverse/lychee/releases/download/${tag}/lychee-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/lycheeverse/lychee/releases/download/${tag}/lychee-x86_64-pc-windows-msvc.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/lycheeverse/lychee/releases/download/lychee-v${version}/lychee-${arch}-unknown-linux-musl.${ext}",
            ["latest"] = { ref = "0.24.2" },
            ["0.24.2"] = {
                sha256 = {
                    x86_64 = "73657a111819a30c47c08352896796f23d64e4eb2b3ed39b6d32149241566fc5",
                    aarch64 = "5d0b0e3aeab240f41920c633a6eaf97599be6eedda034b36e858ede7dba5e535",
                },
            },
        },
        macosx = {
            source = "https://github.com/lycheeverse/lychee/releases/download/lychee-v${version}/lychee-${arch}-apple-darwin.${ext}",
            ["latest"] = { ref = "0.24.2" },
            ["0.24.2"] = {
                sha256 = {
                    x86_64 = "887503a9cff667d322b8d0892b40bf49976eb9507af8483220a3706cdad55978",
                    aarch64 = "c9d3740ea2d891854d37116c9fba840f37b6e7c89d330e7db84ac333631c4977",
                },
            },
        },
        windows = {
            source = "https://github.com/lycheeverse/lychee/releases/download/lychee-v${version}/lychee-${arch}-pc-windows-msvc.${ext}",
            deps = {
                runtime = { "xim:vcruntime" },
            },
            ["latest"] = { ref = "0.24.2" },
            ["0.24.2"] = {
                sha256 = {
                    x86_64 = "32975d1493ee1a975d6bb41e4fb56fe419cb442ded628bb772ba2e614acfacad",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.shell")

function installed()
    return payload.present({ "lychee" }) or payload.present({ "lychee.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("lychee: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local stem = (normalized:match("([^/]+)$") or ""):gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil

    if not is_win and normalized:match("%.tar%.gz$") and not os.isdir(parent .. "/" .. stem) and os.isfile(archive) then
        shell.exec({ "tar", "-xzf", archive, "-C", parent })
    end

    payload.unpack{ extracted = stem, strip = 1 }

    if not is_win and os.isfile(dir .. "/lychee") then
        shell.exec({ "chmod", "+x", dir .. "/lychee" })
    end

    if is_win then
        if not pkginfo.dep_install_dir then
            error("lychee: xim:vcruntime runtime dep lookup is unavailable")
        end
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "lychee: xim:vcruntime payload directory is missing")
        local dlls = fs.files(crt .. "/bin") or {}
        if #dlls == 0 then
            error("lychee: xim:vcruntime/bin contains no DLLs at " .. crt)
        end
        for _, dll in ipairs(dlls) do
            os.cp(dll, dir)
        end
    end

    payload.require({ is_win and "lychee.exe" or "lychee" })
    return true
end

function config()
    xvm.add("lychee", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("lychee")
    return true
end
