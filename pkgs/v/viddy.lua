-- viddy -- A modern watch command (sachaos/viddy).
--
-- Verified 2026-11-26 against upstream GitHub release sachaos/viddy v1.3.1:
-- every SHA256 below matches the upstream `.sha256` sidecar file and locally
-- downloaded archives. All archives are flat `.tar.gz` (no top-level wrapper
-- dir) containing only `viddy` (POSIX) or `viddy.exe` (Windows).
--
-- Linking & platform coverage:
--   * linux/x86_64    : viddy-v1.3.1-linux-x86_64.tar.gz
--                       static-pie musl ELF with zero DT_NEEDED entries
--                       (`ldd`: statically linked; no symbol version info).
--   * linux/aarch64   : viddy-v1.3.1-linux-arm64.tar.gz
--                       statically linked ELF with no dynamic section
--                       (`readelf -d`: no dynamic section; no version info).
--                       Zero runtime deps declared on Linux.
--   * macosx/x86_64   : viddy-v1.3.1-macos-x86_64.tar.gz (Mach-O 64-bit x86_64)
--   * macosx/aarch64  : viddy-v1.3.1-macos-arm64.tar.gz (Mach-O 64-bit arm64)
--   * windows/x86_64  : viddy-v1.3.1-windows-x86_64.tar.gz
--                       PE32+ CUI executable; imports `VCRUNTIME140.dll` and
--                       Windows UCRT/OS DLLs, so `xim:vcruntime` is declared as
--                       a runtime dep and its DLLs are copied app-local beside
--                       `viddy.exe`. Note Windows ships `.tar.gz` (not `.zip`),
--                       so `install()` unpacks via `%SystemRoot%\System32\tar.exe`.
--   * windows/aarch64 : omitted — upstream v1.3.1 publishes no Windows ARM64 asset
--                       (and `xim:vcruntime` currently ships x86_64 only).
--
-- Note on `programs = {"viddy"}`: `viddy /?` treats `/?` as the command to
-- watch and enters the interactive TUI rather than printing help and exiting;
-- `windows-test.ps1` handles this automatically by falling back to `--version`
-- (which prints version info and exits 0).

package = {
    spec = "2",

    name = "viddy",
    description = "A modern watch command with time machine and pager",
    homepage = "https://github.com/sachaos/viddy",
    authors = {"Takumasa Sakao"},
    maintainers = {"https://github.com/sachaos/viddy/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/sachaos/viddy",
    docs = "https://github.com/sachaos/viddy#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "tui", "watch", "tools"},
    keywords = {"viddy", "watch", "tui", "time-machine", "rust"},

    programs = {"viddy"},
    xvm_enable = true,

    -- Verified upstream GitHub release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/sachaos/viddy/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/sachaos/viddy/releases/download/${tag}/viddy-${tag}-linux-x86_64.tar.gz",
                            aarch64 = "https://github.com/sachaos/viddy/releases/download/${tag}/viddy-${tag}-linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/sachaos/viddy/releases/download/${tag}/viddy-${tag}-macos-x86_64.tar.gz",
                            aarch64 = "https://github.com/sachaos/viddy/releases/download/${tag}/viddy-${tag}-macos-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/sachaos/viddy/releases/download/${tag}/viddy-${tag}-windows-x86_64.tar.gz",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/sachaos/viddy/releases/download/v${version}/viddy-v${version}-linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.3.1" },
            ["1.3.1"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "c0406da6c19bbfbf0381a1a54cf7098a97372c15e5d64bed38e4b8be53e8455e",
                    aarch64 = "4bf88aa5443b09a49e8af55c1e92ff6148486856703b8f886e1984b0e541af4d",
                },
            },
        },
        macosx = {
            source = "https://github.com/sachaos/viddy/releases/download/v${version}/viddy-v${version}-macos-${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.3.1" },
            ["1.3.1"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "fe3afac2154cdc6432449d1cf526744389f8686bd9b240f146e632aa532205ad",
                    aarch64 = "46e9f219299e6a012075b46191fed21663bd916cea95f1e419b787a87ddd48bf",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            source = "https://github.com/sachaos/viddy/releases/download/v${version}/viddy-v${version}-windows-${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.3.1" },
            ["1.3.1"] = {
                arch_alias = { x86_64 = "x86_64" },
                sha256 = {
                    x86_64 = "b77c34a18d10fb3c9338ef292a59de00f3d695aa423fd3b6ff617ef6840e2a70",
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
import("xim.pkgindex.shell")
import("xim.pkgindex.winpath")

local function is_windows()
    if os.getenv("OS") == "Windows_NT" then return true end
    local dir = tostring(pkginfo.install_dir() or "")
    if dir:match("^[A-Za-z]:") or dir:find("\\", 1, true) then return true end
    local archive = tostring(pkginfo.install_file() or "")
    return archive:match("windows") ~= nil
end

function installed()
    return payload.present({ "viddy" })
        or payload.present({ "viddy.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("viddy: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = is_windows()
    local exe = is_win and "viddy.exe" or "viddy"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    -- Archives are flat `.tar.gz` (no enclosing wrapper dir): unpack directly
    -- into `install_dir` so unrelated files in the shared download cache
    -- never leak into the payload. On Windows, `libs/payload.lua` only unpacks
    -- `.zip`, so call `%SystemRoot%\System32\tar.exe` directly.
    if os.isfile(archive) then
        if is_win then
            local sysroot = winpath.native(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
            local systar = sysroot .. "\\System32\\tar.exe"
            -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
            system.exec(string.format('%s -xf "%s" -C "%s"',
                                      systar, winpath.native(archive), winpath.native(dir)))
        else
            shell.exec({ "tar", "-xzf", archive, "-C", dir })
            shell.exec({ "chmod", "+x", dir .. "/" .. exe })
        end
    elseif os.isfile(parent .. "/" .. exe) then
        os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        if not is_win then
            shell.exec({ "chmod", "+x", dir .. "/" .. exe })
        end
    else
        error("viddy: archive not found at " .. archive .. " and no extracted " .. exe .. " in " .. parent)
    end

    if is_win then
        if not pkginfo.dep_install_dir then
            error("viddy: xim:vcruntime runtime dep lookup is unavailable")
        end
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "viddy: xim:vcruntime payload directory is missing")
        local copied = 0
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir)
            copied = copied + 1
        end
        if copied == 0 then
            error("viddy: no CRT DLLs found in " .. crt .. "/bin")
        end
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("viddy", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("viddy")
    return true
end
