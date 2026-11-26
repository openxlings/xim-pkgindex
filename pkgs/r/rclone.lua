-- Rclone - Rsync for cloud storage.
--
-- Verified 2026-11-26 against upstream GitHub release v1.76.0 (rclone/rclone):
-- every SHA256 below was verified against both upstream `SHA256SUMS` and the
-- downloaded archives. All six archives pack a single top-level directory
-- matching the archive stem (`rclone-v1.76.0-<os>-<arch>/`) containing
-- `rclone` (or `rclone.exe`), `rclone.1`, `README.txt`, `README.html`, and
-- `git-log.txt`.
--
-- Linux ELF inspection (v1.76.0, readelf -d / ldd):
--   x86_64:  statically linked Go ELF64 executable, no .dynamic section
--   aarch64: statically linked Go ELF64 executable, no .dynamic section
-- Windows PE inspection (v1.76.0, PE32+ import table):
--   x86_64 (0x8664) & aarch64 (0xaa64): imports only `kernel32.dll`
--   (no VCRUNTIME140.dll / MSVCP140.dll, so no `xim:vcruntime` dep).
package = {
    spec = "2",

    name = "rclone",
    description = "Rsync for cloud storage",
    homepage = "https://rclone.org",
    authors = {"Nick Craig-Wood"},
    maintainers = {"https://github.com/rclone/rclone/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/rclone/rclone",
    docs = "https://rclone.org/docs/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cloud", "storage", "sync", "cli", "tools"},
    keywords = {"rclone", "cloud", "sync", "s3", "storage", "backup"},

    programs = {"rclone"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/rclone/rclone/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/rclone/rclone/releases/download/${tag}/rclone-v${version}-linux-amd64.zip",
                            aarch64 = "https://github.com/rclone/rclone/releases/download/${tag}/rclone-v${version}-linux-arm64.zip",
                        },
                        macosx = {
                            x86_64 = "https://github.com/rclone/rclone/releases/download/${tag}/rclone-v${version}-osx-amd64.zip",
                            aarch64 = "https://github.com/rclone/rclone/releases/download/${tag}/rclone-v${version}-osx-arm64.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/rclone/rclone/releases/download/${tag}/rclone-v${version}-windows-amd64.zip",
                            aarch64 = "https://github.com/rclone/rclone/releases/download/${tag}/rclone-v${version}-windows-arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/rclone/rclone/releases/download/v${version}/rclone-v${version}-linux-${arch_alias}.zip",
            ["latest"] = { ref = "1.76.0" },
            ["1.76.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "b00f00b3266c3764413afe599d3ec316f6f43b3e0ea8a0bc1d186d2133e46df7",
                    aarch64 = "ee169016675e23a69d77240565133ff7dbc9b33d16fa8f7053d4af39f1eaeb78",
                },
            },
        },
        macosx = {
            source = "https://github.com/rclone/rclone/releases/download/v${version}/rclone-v${version}-osx-${arch_alias}.zip",
            ["latest"] = { ref = "1.76.0" },
            ["1.76.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "4f5835733d52b818340f97b1fc0348a70461534d123363a183ca2b660219595a",
                    aarch64 = "e72dc90b70f4947a7b72b61bde4a4fbba5777b2874fb448951ffdde67ebd0ab7",
                },
            },
        },
        windows = {
            source = "https://github.com/rclone/rclone/releases/download/v${version}/rclone-v${version}-windows-${arch_alias}.zip",
            ["latest"] = { ref = "1.76.0" },
            ["1.76.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "8b4fd2737ade4e70c057ef4a49deb7cffe94b0fb9d7587c189d149823f21a1dc",
                    aarch64 = "c406c8a69a5a408e50624aa990fbb0a6266b3a4e83782a94de3cb96f50f86f10",
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
    return payload.present({ "rclone", "rclone.1" })
        or payload.present({ "rclone.exe", "rclone.1" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("rclone: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local filename = normalized:match("([^/]+)$") or ""
    local stem = filename:gsub("%.zip$", "")
    -- All platforms ship `.zip` archives; detect Windows by path, never by `.zip`.
    local is_win = normalized:match("windows") ~= nil
        or os.getenv("OS") == "Windows_NT"
        or tostring(dir):match("^[A-Za-z]:") ~= nil
    local exe = is_win and "rclone.exe" or "rclone"

    if is_win or os.isdir(parent .. "/" .. stem) then
        payload.unpack{ extracted = stem, strip = 1 }
    elseif os.isfile(archive) then
        local stage = dir .. ".unpack"
        os.tryrm(stage)
        os.tryrm(dir)
        fs.mkdir_p(stage)
        local ok = pcall(system.exec, string.format('unzip -q -o "%s" -d "%s"', archive, stage))
        local extracted = stage .. "/" .. stem
        if ok and os.isdir(extracted) then
            local dst_parent = dir:match("^(.*)/[^/]+$")
            if dst_parent then fs.mkdir_p(dst_parent) end
            os.mv(extracted, dir)
            os.tryrm(stage)
        else
            os.tryrm(stage)
            fs.mkdir_p(dir)
            system.exec(string.format('tar -xf "%s" --strip-components=1 -C "%s"', archive, dir))
        end
    else
        error("rclone: archive or extracted directory (" .. stem .. ") not found in " .. parent)
    end

    if not is_win and os.isfile(dir .. "/rclone") then
        system.exec(string.format('chmod +x "%s"', dir .. "/rclone"))
    end

    payload.require({ exe, "rclone.1" })
    return true
end

function config()
    xvm.add("rclone", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("rclone")
    return true
end
