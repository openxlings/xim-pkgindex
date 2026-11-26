-- restic - Fast, secure, efficient backup program.
--
-- Verified against official upstream GitHub release v0.20.0 (`restic/restic`).
-- Every SHA-256 digest below matches upstream `SHA256SUMS` and locally
-- downloaded release assets:
--   * linux   x86_64, aarch64   `restic_<ver>_linux_{amd64,arm64}.bz2`
--                               (bzip2-compressed single static Go ELF binary;
--                               no dynamic section, no PT_INTERP, zero
--                               DT_NEEDED entries via `readelf -d` and `ldd`,
--                               so no runtime dependencies are needed).
--   * macosx  x86_64, aarch64   `restic_<ver>_darwin_{amd64,arm64}.bz2`
--                               (bzip2-compressed Mach-O executable).
--   * windows x86_64            `restic_<ver>_windows_amd64.zip`
--                               (flat zip containing `restic_<ver>_windows_amd64.exe`;
--                               PE32+ executable importing only `kernel32.dll`,
--                               no VCRUNTIME DLL dependency; upstream publishes
--                               no `windows_arm64` asset).

package = {
    spec = "2",

    name = "restic",
    description = "Fast, secure, efficient backup program",
    homepage = "https://restic.net",
    authors = {"Alexander Neumann"},
    maintainers = {"restic"},
    licenses = {"BSD-2-Clause"},
    repo = "https://github.com/restic/restic",
    docs = "https://restic.readthedocs.io/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"backup", "cli", "security", "tools"},
    keywords = {"restic", "backup", "encryption", "snapshot", "deduplication", "cli"},

    programs = {"restic"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/restic/restic/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/restic/restic/releases/download/${tag}/restic_${version}_linux_amd64.bz2",
                            aarch64 = "https://github.com/restic/restic/releases/download/${tag}/restic_${version}_linux_arm64.bz2",
                        },
                        macosx = {
                            x86_64 = "https://github.com/restic/restic/releases/download/${tag}/restic_${version}_darwin_amd64.bz2",
                            aarch64 = "https://github.com/restic/restic/releases/download/${tag}/restic_${version}_darwin_arm64.bz2",
                        },
                        windows = {
                            x86_64 = "https://github.com/restic/restic/releases/download/${tag}/restic_${version}_windows_amd64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/restic/restic/releases/download/v${version}/restic_${version}_linux_${arch_alias}.bz2",
            ["latest"] = { ref = "0.20.0" },
            ["0.20.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "0ccd9fa7885074a24603b051e01bf9bd8b5e45d6a1791e9d9887e9e9372107f7",
                    aarch64 = "1188daded239bccb5952a01d2ad33e77a0d3dc34f9d9fc1e7fdda618d44938ef",
                },
            },
        },
        macosx = {
            source = "https://github.com/restic/restic/releases/download/v${version}/restic_${version}_darwin_${arch_alias}.bz2",
            ["latest"] = { ref = "0.20.0" },
            ["0.20.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "21f0070ef2bc6f3da2e33c070628e3e026e5237ba5fcddb1f9e0e8cabdd809d5",
                    aarch64 = "0962c515acd9fb6937a658e9d8505200f72a6a0c6a2d334c0290b8002377dfb7",
                },
            },
        },
        windows = {
            source = "https://github.com/restic/restic/releases/download/v${version}/restic_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "0.20.0" },
            ["0.20.0"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "bba9061c3dce081701ab353ec8cb73a78be73b71a538aad560f2d1067602b7fe",
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
    return payload.present({ "restic" }) or payload.present({ "restic.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local filename = normalized:match("([^/]+)$") or ""
    local is_win = normalized:lower():match("%.zip$") ~= nil
        or normalized:match("_windows_") ~= nil
        or os.getenv("OS") == "Windows_NT"

    if is_win then
        local stem = filename:gsub("%.zip$", "")
        local pre_exe = parent .. "/" .. stem .. ".exe"
        if not os.isfile(archive) and os.isfile(pre_exe) then
            os.tryrm(dir)
            fs.mkdir_p(dir)
            os.mv(pre_exe, dir .. "/restic.exe")
        else
            payload.unpack{}
            local extracted_exe = dir .. "/" .. stem .. ".exe"
            local target_exe = dir .. "/restic.exe"
            if os.isfile(extracted_exe) and not os.isfile(target_exe) then
                os.mv(extracted_exe, target_exe)
            end
        end
        payload.require({ "restic.exe" })
        return true
    end

    local stem = filename:gsub("%.bz2$", "")
    local target = dir .. "/restic"
    os.tryrm(dir)
    fs.mkdir_p(dir)

    if os.isfile(parent .. "/" .. stem) then
        os.mv(parent .. "/" .. stem, target)
    elseif os.isfile(parent .. "/restic") then
        os.mv(parent .. "/restic", target)
    elseif os.isfile(archive) and normalized:lower():match("%.bz2$") then
        system.exec(string.format('bunzip2 -c "%s" > "%s"', archive, target))
    else
        error(string.format("restic: expected .bz2 payload or extracted binary in %s (got %s)",
                            parent, archive))
    end

    if not os.isfile(target) then
        error(string.format("restic: failed to materialize binary at %s", target))
    end
    system.exec(string.format('chmod +x "%s"', target))
    payload.require({ "restic" })
    return true
end

function config()
    xvm.add("restic", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("restic")
    return true
end
