-- Dolt - Git for Data: a SQL database you can fork, clone, branch, merge, push, and pull.
--
-- Verified 2026-11-26 against upstream GitHub release v2.7.7 (`dolthub/dolt`).
-- Every SHA256 below matches both GitHub release asset digests and locally
-- computed `sha256sum` across all five downloaded archives:
--   * linux/x86_64:    dolt-linux-amd64.tar.gz   (`dolt-linux-amd64/bin/dolt`, `LICENSES`)
--                      statically linked Go ELF (`readelf -l`: no PT_INTERP;
--                      `readelf -d`: no dynamic section; `readelf -V`: no version info;
--                      `ldd`: not a dynamic executable). Zero runtime deps required.
--   * linux/aarch64:   dolt-linux-arm64.tar.gz   (`dolt-linux-arm64/bin/dolt`, `LICENSES`)
--                      statically linked Go ELF (`readelf -l`: no PT_INTERP;
--                      `readelf -d`: no dynamic section; `readelf -V`: no version info).
--                      Zero runtime deps required.
--   * macosx/x86_64:   dolt-darwin-amd64.tar.gz  (Mach-O 64-bit x86_64 executable)
--   * macosx/aarch64:  dolt-darwin-arm64.tar.gz  (Mach-O 64-bit arm64 executable)
--   * windows/x86_64:  dolt-windows-amd64.zip    (`dolt-windows-amd64/bin/dolt.exe`, `LICENSES`)
--                      PE32+ x86_64 importing only ADVAPI32.dll, KERNEL32.dll, and
--                      msvcrt.dll (no VCRUNTIME/MSVCP DLL dependency).
--                      Upstream publishes no Windows ARM64 asset.
--
-- Note: `dolt /?` exits immediately (exit 1: `Unknown Command /?`), so Windows CI's
-- program probe completes cleanly without hanging.

package = {
    spec = "2",

    name = "dolt",
    description = "Git for Data — a SQL database you can fork, clone, branch, merge, push, and pull like a Git repository",
    homepage = "https://www.dolthub.com",
    authors = {"DoltHub"},
    maintainers = {"dolthub"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/dolthub/dolt",
    docs = "https://docs.dolthub.com",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"database", "sql", "git", "cli", "tools"},
    keywords = {"dolt", "sql", "mysql", "database", "version-control", "git", "go"},

    programs = {"dolt"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/dolthub/dolt/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/dolthub/dolt/releases/download/${tag}/dolt-linux-amd64.tar.gz",
                            aarch64 = "https://github.com/dolthub/dolt/releases/download/${tag}/dolt-linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/dolthub/dolt/releases/download/${tag}/dolt-darwin-amd64.tar.gz",
                            aarch64 = "https://github.com/dolthub/dolt/releases/download/${tag}/dolt-darwin-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/dolthub/dolt/releases/download/${tag}/dolt-windows-amd64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/dolthub/dolt/releases/download/v${version}/dolt-linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.7.7" },
            ["2.7.7"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "087d3bca4f8cde61281bee451f6018bf52f567454f578a149339ef91f466bd92",
                    aarch64 = "15fb45826f3edf64aad062789e051f5769f8a04ac24a9536f4d69cd6665b19d2",
                },
            },
        },
        macosx = {
            source = "https://github.com/dolthub/dolt/releases/download/v${version}/dolt-darwin-${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.7.7" },
            ["2.7.7"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "a0395781759eff171c45aa00f77020e7090222afcda7778ce929c96368c5db08",
                    aarch64 = "4c053c9651717e5141fc94027510a65bf9053f64c5b4757d392b58644122a75c",
                },
            },
        },
        windows = {
            source = "https://github.com/dolthub/dolt/releases/download/v${version}/dolt-windows-${arch_alias}.zip",
            ["latest"] = { ref = "2.7.7" },
            ["2.7.7"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "ff365ab0f5ceaaaf5ea797069dc2cfb693aa7a610771790de54d9a6c4c613048",
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

local function top_dirs()
    return {
        "dolt-linux-amd64",
        "dolt-linux-arm64",
        "dolt-darwin-amd64",
        "dolt-darwin-arm64",
        "dolt-windows-amd64",
    }
end

local function _unpack_fallback(archive, normalized, parent, candidates, dir, is_win)
    os.tryrm(dir)
    for _, name in ipairs(candidates) do
        local src = parent .. "/" .. name
        if os.isdir(src) then
            local dst_parent = dir:match("^(.*)/[^/]+$")
            if dst_parent then fs.mkdir_p(dst_parent) end
            os.mv(src, dir)
            return
        end
    end
    if is_win and normalized:match("%.zip$") and os.isfile(archive) then
        fs.mkdir_p(dir)
        local sysroot = (os.getenv("SystemRoot") or "C:\\Windows"):gsub("/", "\\"):gsub("\\+$", "")
        local systar = sysroot .. "\\System32\\tar.exe"
        -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
        system.exec(string.format('%s -xf "%s" --strip-components=1 -C "%s"',
                                  systar, archive:gsub("/", "\\"), dir:gsub("/", "\\")))
    elseif (not is_win) and os.isfile(archive) then
        fs.mkdir_p(dir)
        system.exec(string.format('tar -xzf "%s" --strip-components=1 -C "%s"', normalized, dir))
    else
        error("dolt: neither extracted directory nor archive (" .. archive .. ") exists")
    end
end

function installed()
    if type(payload.present) == "function" then
        return payload.present({ "bin/dolt" })
            or payload.present({ "bin/dolt.exe" })
    end
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/bin/dolt") or os.isfile(dir .. "/bin/dolt.exe")
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("dolt: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local filename = normalized:match("([^/]+)$") or ""
    local stem = filename:gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil
        or normalized:match("%-windows%-") ~= nil
        or os.getenv("OS") == "Windows_NT"

    local candidates = {}
    local seen = {}
    if stem ~= "" then
        table.insert(candidates, stem)
        seen[stem] = true
    end
    for _, name in ipairs(top_dirs()) do
        if not seen[name] then
            table.insert(candidates, name)
            seen[name] = true
        end
    end

    local exe = is_win and "bin/dolt.exe" or "bin/dolt"
    if type(payload.unpack) == "function" then
        payload.unpack{
            extracted = candidates,
            strip = 1,
        }
        if not is_win then
            system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe))
        end
        payload.require({ exe })
    else
        _unpack_fallback(archive, normalized, parent, candidates, dir, is_win)
        if not is_win and os.isfile(dir .. "/" .. exe) then
            system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe))
        end
        if not os.isfile(dir .. "/" .. exe) then
            error("dolt: required executable missing at " .. dir .. "/" .. exe)
        end
    end

    return true
end

function config()
    xvm.add("dolt", { bindir = pkginfo.install_dir() .. "/bin" })
    return true
end

function uninstall()
    xvm.remove("dolt")
    return true
end
