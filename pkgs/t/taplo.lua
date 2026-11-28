-- taplo -- A TOML toolkit written in Rust (tamasfe/taplo).
--
-- Verified against official upstream GitHub release `tamasfe/taplo` 0.10.0
-- (tag `0.10.0`, published 2025-05-23). All SHA-256 digests below were
-- computed from the downloaded release assets:
--   * linux/x86_64    `taplo-linux-x86_64.gz`
--                     (gzip-compressed single static-pie ELF binary;
--                     `ldd` reports `statically linked`, zero DT_NEEDED entries,
--                     no PT_INTERP).
--   * linux/aarch64   `taplo-linux-aarch64.gz`
--                     (gzip-compressed single static ELF binary;
--                     no `.dynamic` section, no PT_INTERP, zero DT_NEEDED).
--   * macosx/x86_64   `taplo-darwin-x86_64.gz`
--                     (gzip-compressed Mach-O 64-bit x86_64 executable).
--   * macosx/aarch64  `taplo-darwin-aarch64.gz`
--                     (gzip-compressed Mach-O 64-bit arm64 executable).
--   * windows/x86_64  `taplo-windows-x86_64.zip`
--                     (flat zip containing `taplo.exe`; PE32+ console
--                     executable importing only Windows OS DLLs, no VCRUNTIME140.dll).
--   * windows/aarch64 `taplo-windows-aarch64.zip`
--                     (flat zip containing `taplo.exe`; PE32+ ARM64 console
--                     executable importing only Windows OS DLLs, no VCRUNTIME140.dll).
--
-- Note on autoupdate tags: Taplo CLI releases use bare semver tags (`0.10.0`,
-- `0.9.3`, ...), whereas older crate/npm tags such as `release-taplo-0.13.0`
-- carry no CLI assets. `extensions.autoupdate` uses `${tag}` directly and
-- requires all 6 platform/arch assets.

package = {
    spec = "2",

    name = "taplo",
    description = "A TOML toolkit written in Rust",
    homepage = "https://taplo.tamasfe.dev",
    authors = {"tamasfe"},
    maintainers = {"tamasfe"},
    licenses = {"MIT"},
    repo = "https://github.com/tamasfe/taplo",
    docs = "https://taplo.tamasfe.dev",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"toml", "cli", "formatter", "linter", "lsp", "tools"},
    keywords = {"taplo", "toml", "format", "lint", "lsp", "cli", "rust"},

    programs = {"taplo"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/tamasfe/taplo/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/tamasfe/taplo/releases/download/${tag}/taplo-linux-x86_64.gz",
                            aarch64 = "https://github.com/tamasfe/taplo/releases/download/${tag}/taplo-linux-aarch64.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/tamasfe/taplo/releases/download/${tag}/taplo-darwin-x86_64.gz",
                            aarch64 = "https://github.com/tamasfe/taplo/releases/download/${tag}/taplo-darwin-aarch64.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/tamasfe/taplo/releases/download/${tag}/taplo-windows-x86_64.zip",
                            aarch64 = "https://github.com/tamasfe/taplo/releases/download/${tag}/taplo-windows-aarch64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/tamasfe/taplo/releases/download/${version}/taplo-linux-${arch}.gz",
            ["latest"] = { ref = "0.10.0" },
            ["0.10.0"] = {
                sha256 = {
                    x86_64 = "8fe196b894ccf9072f98d4e1013a180306e17d244830b03986ee5e8eabeb6156",
                    aarch64 = "033681d01eec8376c3fd38fa3703c79316f5e14bb013d859943b60a07bccdcc3",
                },
            },
        },
        macosx = {
            source = "https://github.com/tamasfe/taplo/releases/download/${version}/taplo-darwin-${arch}.gz",
            ["latest"] = { ref = "0.10.0" },
            ["0.10.0"] = {
                sha256 = {
                    x86_64 = "898122cde3a0b1cd1cbc2d52d3624f23338218c91b5ddb71518236a4c2c10ef2",
                    aarch64 = "713734314c3e71894b9e77513c5349835eefbd52908445a0d73b0c7dc469347d",
                },
            },
        },
        windows = {
            source = "https://github.com/tamasfe/taplo/releases/download/${version}/taplo-windows-${arch}.zip",
            ["latest"] = { ref = "0.10.0" },
            ["0.10.0"] = {
                sha256 = {
                    x86_64 = "1615eed140039bd58e7089109883b1c434de5d6de8f64a993e6e8c80ca57bdf9",
                    aarch64 = "65a50c5d3b78f6014e6bc6d64eb6dc1d4992bc236589c9bb29e5609fc3454674",
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

local function _is_windows_payload(normalized, dir)
    if normalized:lower():match("%.zip$") ~= nil then return true end
    if normalized:match("_windows_") ~= nil or normalized:match("%-windows%-") ~= nil then
        return true
    end
    if os.getenv("OS") == "Windows_NT" then return true end
    local d = tostring(dir or "")
    return d:match("^[A-Za-z]:") ~= nil or d:find("\\", 1, true) ~= nil
end

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/taplo") or os.isfile(dir .. "/taplo.exe")
end

function install()
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local filename = normalized:match("([^/]+)$") or ""

    if _is_windows_payload(normalized, dir) then
        local target_exe = dir .. "/taplo.exe"
        if not os.isfile(archive) and os.isfile(parent .. "/taplo.exe") then
            os.tryrm(dir)
            fs.mkdir_p(dir)
            os.mv(parent .. "/taplo.exe", target_exe)
        else
            payload.unpack{}
        end
        if not os.isfile(target_exe) then
            error(string.format("taplo: executable missing after install at %s", target_exe))
        end
        return true
    end

    local stem = filename:gsub("%.gz$", "")
    local target = dir .. "/taplo"
    os.tryrm(dir)
    fs.mkdir_p(dir)

    if os.isfile(parent .. "/" .. stem) then
        os.mv(parent .. "/" .. stem, target)
    elseif os.isfile(parent .. "/taplo") then
        os.mv(parent .. "/taplo", target)
    elseif os.isfile(archive) and normalized:lower():match("%.gz$") then
        system.exec(string.format('gzip -dc "%s" > "%s"', archive, target))
    else
        error(string.format("taplo: expected .gz payload or extracted binary in %s (got %s)",
                            parent, archive))
    end

    if not os.isfile(target) then
        error(string.format("taplo: failed to materialize binary at %s", target))
    end
    system.exec(string.format('chmod +x "%s"', target))
    return true
end

function config()
    xvm.add("taplo", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("taplo")
    return true
end
