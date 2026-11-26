-- git-lfs - Git extension for versioning large files (git-lfs/git-lfs).
--
-- Verified 2026-11-26 against upstream GitHub release v3.8.1 (`git-lfs/git-lfs`):
-- every SHA256 below matched both upstream `sha256sums.asc`, GitHub release
-- digests, and locally downloaded bytes across all 6 assets.
-- All six archives pack a single top-level directory `git-lfs-3.8.1/`
-- (`git-lfs-${version}/`) containing `git-lfs` (or `git-lfs.exe` on Windows),
-- `README.md`, `CHANGELOG.md`, `man/`, and `install.sh` (Unix only).
--
-- Note on archive formats: Linux ships `.tar.gz`, while both macOS and Windows
-- ship `.zip`, so Windows detection must inspect the path/host environment and
-- never assume `.zip` implies Windows.
--
-- Linux ELF inspection (v3.8.1, readelf -d / ldd):
--   x86_64:  statically linked Go ELF64 executable, no .dynamic section
--   aarch64: statically linked Go ELF64 executable, no .dynamic section
-- Windows PE inspection (v3.8.1, PE32+ import table):
--   x86_64 (0x8664) & aarch64 (0xaa64): PE32+ console executables importing
--   only `kernel32.dll` (zero runtime dependencies).
-- macOS Mach-O inspection (v3.8.1):
--   x86_64 & aarch64: Mach-O 64-bit executables.

package = {
    spec = "2",

    name = "git-lfs",
    description = "Git extension for versioning large files",
    homepage = "https://git-lfs.com",
    authors = {"GitHub, Inc. and Git LFS contributors"},
    maintainers = {"Git LFS"},
    licenses = {"MIT"},
    repo = "https://github.com/git-lfs/git-lfs",
    docs = "https://git-lfs.com",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"git", "vcs", "cli", "tools"},
    keywords = {"git-lfs", "git", "lfs", "large-files", "vcs", "go"},

    programs = {"git-lfs"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/git-lfs/git-lfs/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/git-lfs/git-lfs/releases/download/${tag}/git-lfs-linux-amd64-${tag}.tar.gz",
                            aarch64 = "https://github.com/git-lfs/git-lfs/releases/download/${tag}/git-lfs-linux-arm64-${tag}.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/git-lfs/git-lfs/releases/download/${tag}/git-lfs-darwin-amd64-${tag}.zip",
                            aarch64 = "https://github.com/git-lfs/git-lfs/releases/download/${tag}/git-lfs-darwin-arm64-${tag}.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/git-lfs/git-lfs/releases/download/${tag}/git-lfs-windows-amd64-${tag}.zip",
                            aarch64 = "https://github.com/git-lfs/git-lfs/releases/download/${tag}/git-lfs-windows-arm64-${tag}.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/git-lfs/git-lfs/releases/download/v${version}/git-lfs-linux-${arch_alias}-v${version}.tar.gz",
            ["latest"] = { ref = "3.8.1" },
            ["3.8.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "e72cf723a4a660438862282e8aecf3885fc8123e88bfcad534cf6b941a354b75",
                    aarch64 = "67895dd77b63329796bc5efdd47b57f218e1f7b98717ebaf936a8238dbcaec0f",
                },
            },
        },
        macosx = {
            source = "https://github.com/git-lfs/git-lfs/releases/download/v${version}/git-lfs-darwin-${arch_alias}-v${version}.zip",
            ["latest"] = { ref = "3.8.1" },
            ["3.8.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "4292b3518e717e53c20a6c2c0696e2069a21e97500ad14b80b06bd52de8f3b72",
                    aarch64 = "0ba10e897e0496412cd86eacaed4ed554c97ddc29bc5c709d28faa5eaaa2222c",
                },
            },
        },
        windows = {
            source = "https://github.com/git-lfs/git-lfs/releases/download/v${version}/git-lfs-windows-${arch_alias}-v${version}.zip",
            ["latest"] = { ref = "3.8.1" },
            ["3.8.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "5bb771c12b3dacc535e912d0270a010c209d4da2e63819c5918e3547c2defed9",
                    aarch64 = "7e70990e339efab3e793affb919355b548c9a41c5b6bb52d90267bcb84ba4784",
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

local function _is_windows(normalized, dir)
    return normalized:match("windows") ~= nil
        or os.getenv("OS") == "Windows_NT"
        or tostring(dir):match("^[A-Za-z]:") ~= nil
end

function installed()
    if type(payload.present) == "function" then
        return payload.present({ "git-lfs", "README.md" })
            or payload.present({ "git-lfs.exe", "README.md" })
    end
    local dir = pkginfo.install_dir()
    return (os.isfile(dir .. "/git-lfs") or os.isfile(dir .. "/git-lfs.exe"))
        and os.isfile(dir .. "/README.md")
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("git-lfs: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local ver = tostring(pkginfo.version() or "")
    local extracted_name = ver ~= "" and ("git-lfs-" .. ver) or "git-lfs"
    local is_win = _is_windows(normalized, dir)
    local exe = is_win and "git-lfs.exe" or "git-lfs"
    local pre_extracted = parent .. "/" .. extracted_name

    if is_win or os.isdir(pre_extracted) then
        if type(payload.unpack) == "function" then
            payload.unpack{ extracted = extracted_name, strip = 1 }
        elseif os.isdir(pre_extracted) then
            os.tryrm(dir)
            local dst_parent = dir:match("^(.*)/[^/]+$")
            if dst_parent then fs.mkdir_p(dst_parent) end
            os.mv(pre_extracted, dir)
        else
            error("git-lfs: pre-extracted directory missing and payload.unpack unavailable")
        end
    elseif os.isfile(archive) then
        os.tryrm(dir)
        if normalized:match("%.zip$") then
            local stage = dir .. ".unpack"
            os.tryrm(stage)
            fs.mkdir_p(stage)
            local ok = pcall(system.exec, string.format('unzip -q -o "%s" -d "%s"', archive, stage))
            local extracted = stage .. "/" .. extracted_name
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
            fs.mkdir_p(dir)
            system.exec(string.format('tar -xzf "%s" --strip-components=1 -C "%s"', archive, dir))
        end
    else
        error("git-lfs: archive or extracted directory (" .. extracted_name .. ") not found in " .. parent)
    end

    if not is_win and os.isfile(dir .. "/git-lfs") then
        system.exec(string.format('chmod +x "%s"', dir .. "/git-lfs"))
    end

    if type(payload.require) == "function" then
        payload.require({ exe, "README.md" })
    end
    if not os.isfile(dir .. "/" .. exe) or not os.isfile(dir .. "/README.md") then
        error("git-lfs: required payload files missing in " .. dir)
    end
    return true
end

function config()
    xvm.add("git-lfs", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("git-lfs")
    return true
end
