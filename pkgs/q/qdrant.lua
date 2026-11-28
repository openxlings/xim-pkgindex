-- Qdrant - high-performance, massive-scale vector database and vector search engine (qdrant/qdrant).
--
-- Verified 2026-11-26 against upstream GitHub release v1.20.2 (`qdrant/qdrant`):
--   * linux/x86_64    : qdrant-x86_64-unknown-linux-musl.tar.gz
--                       `static-pie linked` musl ELF (`readelf -d`: zero DT_NEEDED
--                       entries, no PT_INTERP; `ldd`: `statically linked`).
--   * linux/aarch64   : qdrant-aarch64-unknown-linux-musl.tar.gz
--                       `statically linked` musl ELF (`readelf -d`: no dynamic
--                       section, no PT_INTERP).
--     -> Zero glibc or gcc-runtime dependencies on Linux.
--   * macosx/x86_64   : qdrant-x86_64-apple-darwin.tar.gz (Mach-O 64-bit x86_64)
--   * macosx/aarch64  : qdrant-aarch64-apple-darwin.tar.gz (Mach-O 64-bit arm64)
--   * windows/x86_64  : qdrant-x86_64-pc-windows-msvc.zip
--                       PE32+ CUI `qdrant.exe` importing `VCRUNTIME140.dll` and
--                       UCRT/Windows system DLLs, so `xim:vcruntime` DLLs are
--                       copied app-local beside `qdrant.exe`.
--   * windows/aarch64 : omitted — upstream v1.20.2 publishes no Windows ARM64 asset.
--
-- Archive layout: every upstream archive is flat at root (`qdrant` on POSIX,
-- `qdrant.exe` on Windows). `install()` unpacks directly into `pkginfo.install_dir()`
-- so unrelated files in a shared runtime download directory cannot leak in.

package = {
    spec = "2",

    name = "qdrant",
    description = "High-performance, massive-scale vector database and vector search engine",
    homepage = "https://qdrant.tech",
    authors = {"Qdrant"},
    maintainers = {"https://github.com/qdrant/qdrant/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/qdrant/qdrant",
    docs = "https://qdrant.tech/documentation/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"database", "ai", "vector", "search", "server"},
    keywords = {"qdrant", "vector-database", "vector-search", "embeddings", "ai", "rag", "rust"},

    programs = {"qdrant"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/qdrant/qdrant/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/qdrant/qdrant/releases/download/${tag}/qdrant-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/qdrant/qdrant/releases/download/${tag}/qdrant-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/qdrant/qdrant/releases/download/${tag}/qdrant-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/qdrant/qdrant/releases/download/${tag}/qdrant-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/qdrant/qdrant/releases/download/${tag}/qdrant-x86_64-pc-windows-msvc.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/qdrant/qdrant/releases/download/v${version}/qdrant-${arch}-unknown-linux-musl.tar.gz",
            ["latest"] = { ref = "1.20.2" },
            ["1.20.2"] = {
                sha256 = {
                    x86_64 = "7c3e956b97830a9faa6391540330380c2fa4aa2f92df99bd8d1880a703b922af",
                    aarch64 = "c0c16a08440213b89facfbd2dd3cf4cd6fa222c1260b057a0ea77b41a75774c0",
                },
            },
        },
        macosx = {
            source = "https://github.com/qdrant/qdrant/releases/download/v${version}/qdrant-${arch}-apple-darwin.tar.gz",
            ["latest"] = { ref = "1.20.2" },
            ["1.20.2"] = {
                sha256 = {
                    x86_64 = "73a6538ccccb892ec2c6fa3431faf1e73fba7eb2179079adbd0c65ae4c55bf6a",
                    aarch64 = "385b244e6283968b2be926358541b5bc19b9ada7ea9586e900684388bc912d5f",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            source = "https://github.com/qdrant/qdrant/releases/download/v${version}/qdrant-${arch}-pc-windows-msvc.zip",
            ["latest"] = { ref = "1.20.2" },
            ["1.20.2"] = {
                sha256 = {
                    x86_64 = "7a5290b9ef1b204b250a1626ddafec580647ba3cc62ba1630b3a8efdc2718b32",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

function installed()
    return payload.present({ "qdrant" })
        or payload.present({ "qdrant.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("qdrant: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "qdrant.exe" or "qdrant"

    os.tryrm(dir)

    if is_win then
        payload.unpack{}
        if not pkginfo.dep_install_dir then
            error("qdrant: xim:vcruntime runtime dep lookup is unavailable")
        end
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "qdrant: xim:vcruntime payload directory is missing")
        local copied = 0
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir)
            copied = copied + 1
        end
        if copied == 0 then
            error("qdrant: no CRT DLLs found in " .. crt .. "/bin")
        end
    elseif os.isfile(archive) then
        fs.mkdir_p(dir)
        system.exec(string.format('tar -xzf "%s" -C "%s"', normalized, dir))
    elseif os.isfile(parent .. "/" .. exe) then
        fs.mkdir_p(dir)
        os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
    else
        error("qdrant: archive not found at " .. archive .. " and no extracted " .. exe .. " in " .. parent)
    end

    if not is_win and os.isfile(dir .. "/" .. exe) then
        system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe))
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("qdrant", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("qdrant")
    return true
end
