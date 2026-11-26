-- typos: source code spell checker written in Rust (crate-ci/typos).
--
-- Verified against official upstream release `crate-ci/typos` v1.52.2
-- (published 2026-11-11); upstream publishes no .sha256 sidecar files, so
-- digests were computed from locally downloaded bytes and confirmed against a
-- second independent download.
--
-- Supported platforms & architectures (official prebuilt binaries only):
--   * linux/x86_64  : typos-v1.52.2-x86_64-unknown-linux-musl.tar.gz
--                     Flat archive at root (`./typos`, `./README.md`, `./doc/`,
--                     `./LICENSE-MIT`, `./LICENSE-APACHE`).
--                     `static-pie linked` ELF with no `.interp` and zero
--                     DT_NEEDED entries (no glibc or gcc-runtime dep needed).
--   * linux/aarch64 : typos-v1.52.2-aarch64-unknown-linux-musl.tar.gz
--                     Flat archive at root. `statically linked` ELF with no
--                     `.interp`, no dynamic section, and zero DT_NEEDED entries.
--   * macosx/x86_64 : typos-v1.52.2-x86_64-apple-darwin.tar.gz
--                     Flat archive at root (Mach-O 64-bit x86_64 executable).
--   * macosx/aarch64: typos-v1.52.2-aarch64-apple-darwin.tar.gz
--                     Flat archive at root (Mach-O 64-bit arm64 executable).
--   * windows/x86_64: typos-v1.52.2-x86_64-pc-windows-msvc.zip
--                     Flat zip at root (`typos.exe`, `README.md`, `doc/`,
--                     `LICENSE-MIT`, `LICENSE-APACHE`). Statically links MSVC
--                     CRT (imports only Windows OS system DLLs: kernel32.dll,
--                     api-ms-win-core-synch-l1-2-0.dll, ntdll.dll, userenv.dll,
--                     advapi32.dll, oleaut32.dll, bcryptprimitives.dll; no
--                     `VCRUNTIME140.dll`, so no `xim:vcruntime` dep).
--
-- Omitted platforms / architectures:
--   * windows/aarch64: upstream publishes typos-v1.52.2-aarch64-pc-windows-msvc.zip,
--                      but PE inspection shows it dynamically imports
--                      `VCRUNTIME140.dll` and `api-ms-win-crt-*-l1-1-0.dll`.
--                      `xim:vcruntime` currently ships `x86_64` DLLs only, so
--                      Windows ARM64 waits for `xim:vcruntime` ARM64 support.

package = {
    spec = "2",

    name = "typos",
    description = "Source code spell checker",
    homepage = "https://github.com/crate-ci/typos",
    maintainers = {"crate-ci"},
    licenses = {"MIT", "Apache-2.0"},
    repo = "https://github.com/crate-ci/typos",
    docs = "https://github.com/crate-ci/typos/blob/master/doc/reference.md",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "linter", "spellcheck", "tools"},
    keywords = {"typos", "spellcheck", "linter", "rust", "cli"},

    programs = {"typos"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/crate-ci/typos/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/crate-ci/typos/releases/download/${tag}/typos-${tag}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/crate-ci/typos/releases/download/${tag}/typos-${tag}-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/crate-ci/typos/releases/download/${tag}/typos-${tag}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/crate-ci/typos/releases/download/${tag}/typos-${tag}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/crate-ci/typos/releases/download/${tag}/typos-${tag}-x86_64-pc-windows-msvc.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "1.52.2" },
            ["1.52.2"] = {
                x86_64 = {
                    url = "https://github.com/crate-ci/typos/releases/download/v1.52.2/typos-v1.52.2-x86_64-unknown-linux-musl.tar.gz",
                    sha256 = "3b13d1291281d39d01822e54035636487a7a0f228e70097899b1e33aeb0e7e93",
                },
                aarch64 = {
                    url = "https://github.com/crate-ci/typos/releases/download/v1.52.2/typos-v1.52.2-aarch64-unknown-linux-musl.tar.gz",
                    sha256 = "f2f54b567f5f4688f000f1bf85c585ee22cce3b55befc9418bcdd4c5adc16595",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "1.52.2" },
            ["1.52.2"] = {
                x86_64 = {
                    url = "https://github.com/crate-ci/typos/releases/download/v1.52.2/typos-v1.52.2-x86_64-apple-darwin.tar.gz",
                    sha256 = "2c1e5cd3be644005d27543d7d83a32dbba36eb285bc12678818709938a63a988",
                },
                aarch64 = {
                    url = "https://github.com/crate-ci/typos/releases/download/v1.52.2/typos-v1.52.2-aarch64-apple-darwin.tar.gz",
                    sha256 = "b8e7b8b81f28cc808fd763b6d935536e15ba1ef72613bbb6d628b58a891da7ef",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "1.52.2" },
            ["1.52.2"] = {
                x86_64 = {
                    url = "https://github.com/crate-ci/typos/releases/download/v1.52.2/typos-v1.52.2-x86_64-pc-windows-msvc.zip",
                    sha256 = "ab79036832cea0f2a21aa947731d39512250cc0f7a6a2f6add26262738a8cc11",
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
import("xim.pkgindex.winpath")

function installed()
    return payload.present({ "typos" }) or payload.present({ "typos.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("typos: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local download_dir = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "typos.exe" or "typos"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if os.isfile(archive) then
        -- All upstream archives are flat at root; extract directly into
        -- install_dir so files never mingle with unrelated payloads in runtimedir.
        if is_win then
            local sysroot = winpath.native(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
            local systar = sysroot .. "\\System32\\tar.exe"
            -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
            system.exec(string.format('%s -xf "%s" -C "%s"', systar, winpath.native(archive), winpath.native(dir)))
        else
            system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        end
    elseif os.isfile(download_dir .. "/" .. exe) then
        os.mv(download_dir .. "/" .. exe, dir .. "/" .. exe)
        for _, extra in ipairs({ "LICENSE-MIT", "LICENSE-APACHE", "README.md" }) do
            if os.isfile(download_dir .. "/" .. extra) then
                os.mv(download_dir .. "/" .. extra, dir .. "/" .. extra)
            end
        end
    else
        error("typos: neither archive (" .. archive .. ") nor extracted binary (" .. download_dir .. "/" .. exe .. ") exists")
    end

    if not is_win and os.isfile(dir .. "/" .. exe) then
        system.exec(string.format([[chmod +x "%s"]], dir .. "/" .. exe))
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("typos", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("typos")
    return true
end
