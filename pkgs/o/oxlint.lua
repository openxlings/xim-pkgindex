-- oxlint — fast JavaScript and TypeScript linter written in Rust (oxc-project/oxc).
--
-- Distribution: upstream publishes flat single-binary archives under monorepo
-- release tags `oxlint_v<version>` (alongside `oxfmt_v*` and `crates_v*`).
-- Each archive contains a single target-triple executable directly at the root
-- with no enclosing directory (`oxlint-<triple>` on POSIX,
-- `oxlint-<triple>.exe` on Windows), so install() renames it to `oxlint` /
-- `oxlint.exe`.
--
-- Verified against oxc-project/oxc release oxlint_v1.95.0:
--   linux/x86_64    oxlint-x86_64-unknown-linux-musl.tar.gz   (static-pie ELF, zero DT_NEEDED)
--   linux/aarch64   oxlint-aarch64-unknown-linux-musl.tar.gz  (statically linked ELF, no .dynamic section)
--   macosx/x86_64   oxlint-x86_64-apple-darwin.tar.gz         (Mach-O 64-bit x86_64)
--   macosx/aarch64  oxlint-aarch64-apple-darwin.tar.gz        (Mach-O 64-bit arm64)
--   windows/x86_64  oxlint-x86_64-pc-windows-msvc.zip         (PE32+ console x86_64, OS/UCRT DLLs only)
--   windows/aarch64 oxlint-aarch64-pc-windows-msvc.zip        (PE32+ console ARM64, OS/UCRT DLLs only)
--
-- Linux uses the official `-musl` static binaries so no `xim:glibc` or
-- `xim:gcc-runtime` dependency is needed. Windows binaries import only Windows
-- OS and UCRT DLLs (`kernel32.dll`, `ntdll.dll`, `advapi32.dll`,
-- `bcryptprimitives.dll`, `userenv.dll`, `api-ms-win-core-synch-l1-2-0.dll`,
-- `api-ms-win-crt-*-l1-1-0.dll`), with no `VCRUNTIME140.dll`, so no
-- `xim:vcruntime` dependency is required.

package = {
    spec = "2",

    name = "oxlint",
    description = "Fast JavaScript and TypeScript linter written in Rust",
    homepage = "https://oxc.rs",
    authors = {"Oxc Contributors"},
    maintainers = {"Oxc Contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/oxc-project/oxc",
    docs = "https://oxc.rs/docs/guide/usage/linter",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "linter", "tools"},
    keywords = {"oxlint", "oxc", "linter", "javascript", "typescript", "rust"},

    programs = {"oxlint"},
    xvm_enable = true,

    -- Monorepo tag `oxlint_v${version}` isolates oxlint from oxfmt_v*/crates_v*.
    extensions = {
        autoupdate = {
            source = "https://github.com/oxc-project/oxc/releases",
            tag = "oxlint_v${version}",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/oxc-project/oxc/releases/download/${tag}/oxlint-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/oxc-project/oxc/releases/download/${tag}/oxlint-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/oxc-project/oxc/releases/download/${tag}/oxlint-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/oxc-project/oxc/releases/download/${tag}/oxlint-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/oxc-project/oxc/releases/download/${tag}/oxlint-x86_64-pc-windows-msvc.zip",
                            aarch64 = "https://github.com/oxc-project/oxc/releases/download/${tag}/oxlint-aarch64-pc-windows-msvc.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/oxc-project/oxc/releases/download/oxlint_v${version}/oxlint-${arch}-unknown-linux-musl.tar.gz",
            ["latest"] = { ref = "1.95.0" },
            ["1.95.0"] = {
                sha256 = {
                    x86_64 = "7354b50c48a98c9f64efb55adf50e81ab7f0a477f2c5f95b92222dc2db5d213c",
                    aarch64 = "8358d8a2edfa7b38c37750af037c870afcec6f5fb2f6ae63283727e24a52ff7e",
                },
            },
        },
        macosx = {
            source = "https://github.com/oxc-project/oxc/releases/download/oxlint_v${version}/oxlint-${arch}-apple-darwin.tar.gz",
            ["latest"] = { ref = "1.95.0" },
            ["1.95.0"] = {
                sha256 = {
                    x86_64 = "1863cd8fca56e958fc5ecdc3468b4f30562e0bd677701b3b0a2922b4305986e8",
                    aarch64 = "a08b6a75a95ef77ee6d7bd9e74f903539fb78e856ce58f4f39b6ea2353a4599f",
                },
            },
        },
        windows = {
            source = "https://github.com/oxc-project/oxc/releases/download/oxlint_v${version}/oxlint-${arch}-pc-windows-msvc.zip",
            ["latest"] = { ref = "1.95.0" },
            ["1.95.0"] = {
                sha256 = {
                    x86_64 = "8a0e8384ee8ff23892ff878dead150c8632fb447ca905e95aed2c5e6684ab921",
                    aarch64 = "ce39668453df1999d126fcca999b4573601677a24eb25eed5f58d97bbfaa8d0f",
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
    return payload.present({ "oxlint" }) or payload.present({ "oxlint.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("oxlint: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local fname = normalized:match("([^/]+)$") or ""
    local stem = fname:gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    if stem == "" or stem == fname then
        error("oxlint: unexpected archive filename: " .. archive)
    end

    local is_win = normalized:match("%.zip$") ~= nil
    local extracted_bin = is_win and (stem .. ".exe") or stem
    local target_bin = is_win and "oxlint.exe" or "oxlint"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    -- Upstream archives are flat (no enclosing directory) and carry a
    -- target-triple executable name. Extract directly into install_dir so
    -- shared download directories cannot mix flat files, then rename to
    -- `oxlint` / `oxlint.exe`.
    if is_win then
        if os.isfile(archive) then
            payload.unpack{}
        elseif os.isfile(parent .. "/" .. extracted_bin) then
            os.mv(parent .. "/" .. extracted_bin, dir .. "/" .. target_bin)
        else
            error("oxlint: neither archive (" .. archive .. ") nor extracted binary (" .. parent .. "/" .. extracted_bin .. ") exists")
        end
    else
        if os.isfile(archive) then
            system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        elseif os.isfile(parent .. "/" .. extracted_bin) then
            os.mv(parent .. "/" .. extracted_bin, dir .. "/" .. target_bin)
        else
            error("oxlint: neither archive (" .. archive .. ") nor extracted binary (" .. parent .. "/" .. extracted_bin .. ") exists")
        end
    end

    if os.isfile(dir .. "/" .. extracted_bin) then
        os.mv(dir .. "/" .. extracted_bin, dir .. "/" .. target_bin)
    end
    if not is_win and os.isfile(dir .. "/" .. target_bin) then
        system.exec(string.format([[chmod +x "%s"]], dir .. "/" .. target_bin))
    end

    payload.require({ target_bin })
    return true
end

function config()
    xvm.add("oxlint", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("oxlint")
    return true
end
