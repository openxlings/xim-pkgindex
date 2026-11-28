-- gojq - Pure Go implementation of jq (itchyny/gojq).
--
-- Verified 2026-11-26 against upstream GitHub release v0.12.20 (`itchyny/gojq`):
-- every SHA256 below was verified locally against all 6 downloaded release
-- archives. All six archives pack a single top-level directory matching the
-- archive stem (`gojq_v0.12.20_<os>_<arch>/`) containing `gojq` (or `gojq.exe`),
-- `LICENSE`, `README.md`, `CHANGELOG.md`, `CREDITS`, and `_gojq`.
--
-- Note on archive formats: Linux ships `.tar.gz`, while both macOS and Windows
-- ship `.zip`, so Windows detection must inspect the path/host environment and
-- never assume `.zip` implies Windows.
--
-- Linux ELF inspection (v0.12.20, readelf -d / ldd):
--   x86_64:  statically linked Go ELF64 executable, no .dynamic section
--   aarch64: statically linked Go ELF64 executable, no .dynamic section
-- Windows PE inspection (v0.12.20, PE32+ import table):
--   x86_64 (0x8664) & aarch64 (0xaa64): PE32+ console executables importing
--   only `kernel32.dll` (no VCRUNTIME140.dll / MSVCP140.dll; zero runtime deps).
-- macOS Mach-O inspection (v0.12.20):
--   x86_64 & aarch64: Mach-O 64-bit executables.

package = {
    spec = "2",

    name = "gojq",
    description = "Pure Go implementation of jq",
    homepage = "https://github.com/itchyny/gojq",
    authors = {"itchyny"},
    maintainers = {"itchyny"},
    licenses = {"MIT"},
    repo = "https://github.com/itchyny/gojq",
    docs = "https://github.com/itchyny/gojq#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "json", "yaml", "tools"},
    keywords = {"gojq", "jq", "json", "yaml", "cli", "query", "go"},

    programs = {"gojq"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/itchyny/gojq/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/itchyny/gojq/releases/download/${tag}/gojq_${tag}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/itchyny/gojq/releases/download/${tag}/gojq_${tag}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/itchyny/gojq/releases/download/${tag}/gojq_${tag}_darwin_amd64.zip",
                            aarch64 = "https://github.com/itchyny/gojq/releases/download/${tag}/gojq_${tag}_darwin_arm64.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/itchyny/gojq/releases/download/${tag}/gojq_${tag}_windows_amd64.zip",
                            aarch64 = "https://github.com/itchyny/gojq/releases/download/${tag}/gojq_${tag}_windows_arm64.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/itchyny/gojq/releases/download/v${version}/gojq_v${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.12.20" },
            ["0.12.20"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "92ce2328ce3099532d2b23abfa25a348ecdc48caa584d821feab563f7df4a856",
                    aarch64 = "14384db99511f57f0dcb35c7b825f8afd5407f9c203631aad4dd163af1856c35",
                },
            },
        },
        macosx = {
            source = "https://github.com/itchyny/gojq/releases/download/v${version}/gojq_v${version}_darwin_${arch_alias}.zip",
            ["latest"] = { ref = "0.12.20" },
            ["0.12.20"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "142a0c2f17802ca9a290ca8498adfcf5ec19d8c14b13303c9329511e70dae5bc",
                    aarch64 = "54be17aae49787bb92759bb8662b80f66b9655d42fe3b9e4c39a0c3587962afd",
                },
            },
        },
        windows = {
            source = "https://github.com/itchyny/gojq/releases/download/v${version}/gojq_v${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "0.12.20" },
            ["0.12.20"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "fa418a4a97422d10e4f65f093ea4c35eab239f9c0957810d4f4fc1c4253fbf7c",
                    aarch64 = "823e1ae11ba4638be8c2c21a60440cafec640e4d028c4ad4eeed06def5556769",
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
        return payload.present({ "gojq", "LICENSE" })
            or payload.present({ "gojq.exe", "LICENSE" })
    end
    local dir = pkginfo.install_dir()
    return (os.isfile(dir .. "/gojq") or os.isfile(dir .. "/gojq.exe"))
        and os.isfile(dir .. "/LICENSE")
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("gojq: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local filename = normalized:match("([^/]+)$") or ""
    local stem = filename:gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = _is_windows(normalized, dir)
    local exe = is_win and "gojq.exe" or "gojq"
    local pre_extracted = parent .. "/" .. stem

    if is_win or os.isdir(pre_extracted) then
        if type(payload.unpack) == "function" then
            payload.unpack{ extracted = stem, strip = 1 }
        elseif os.isdir(pre_extracted) then
            os.tryrm(dir)
            local dst_parent = dir:match("^(.*)/[^/]+$")
            if dst_parent then fs.mkdir_p(dst_parent) end
            os.mv(pre_extracted, dir)
        else
            error("gojq: pre-extracted directory missing and payload.unpack unavailable")
        end
    elseif os.isfile(archive) then
        os.tryrm(dir)
        if normalized:match("%.zip$") then
            local stage = dir .. ".unpack"
            os.tryrm(stage)
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
            fs.mkdir_p(dir)
            system.exec(string.format('tar -xzf "%s" --strip-components=1 -C "%s"', archive, dir))
        end
    else
        error("gojq: archive or extracted directory (" .. stem .. ") not found in " .. parent)
    end

    if not is_win and os.isfile(dir .. "/gojq") then
        system.exec(string.format('chmod +x "%s"', dir .. "/gojq"))
    end

    if type(payload.require) == "function" then
        payload.require({ exe, "LICENSE" })
    end
    if not os.isfile(dir .. "/" .. exe) or not os.isfile(dir .. "/LICENSE") then
        error("gojq: required payload files missing in " .. dir)
    end
    return true
end

function config()
    xvm.add("gojq", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("gojq")
    return true
end
