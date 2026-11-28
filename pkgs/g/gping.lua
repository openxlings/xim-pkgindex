-- gping - Ping, but with a graph (orf/gping).
--
-- Platform and architecture coverage (verified 2026-11-26 against gping-v1.21.0):
--   linux    x86_64    gping-Linux-musl-x86_64.tar.gz   (static-pie ELF, zero DT_NEEDED)
--   linux    aarch64   gping-Linux-musl-arm64.tar.gz    (statically linked ELF, no .dynamic section)
--   macosx   x86_64    gping-macOS-x86_64.tar.gz        (Mach-O 64-bit x86_64)
--   macosx   aarch64   gping-macOS-arm64.tar.gz         (Mach-O 64-bit arm64)
--   windows  x86_64    gping-Windows-msvc-x86_64.zip    (PE32+ CUI; imports VCRUNTIME140.dll -> xim:vcruntime)
--   windows  aarch64   omitted: upstream publishes no Windows ARM64 release asset.
--
-- Every upstream archive is flat at root (`gping` or `gping.exe`, plus `gping.1`),
-- verified against GitHub release asset digests and locally computed SHA-256 checksums.

package = {
    spec = "2",

    name = "gping",
    description = "Ping, but with a graph",
    homepage = "https://github.com/orf/gping",
    authors = {"Tom Forbes"},
    maintainers = {"orf"},
    licenses = {"MIT"},
    repo = "https://github.com/orf/gping",
    docs = "https://github.com/orf/gping#readme",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"network", "monitoring", "cli", "tui", "tools"},
    keywords = {"gping", "ping", "graph", "network", "cli", "tui", "rust"},

    programs = {"gping"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/orf/gping/releases",
            tag = "gping-v${version}",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/orf/gping/releases/download/${tag}/gping-Linux-musl-x86_64.tar.gz",
                            aarch64 = "https://github.com/orf/gping/releases/download/${tag}/gping-Linux-musl-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/orf/gping/releases/download/${tag}/gping-macOS-x86_64.tar.gz",
                            aarch64 = "https://github.com/orf/gping/releases/download/${tag}/gping-macOS-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/orf/gping/releases/download/${tag}/gping-Windows-msvc-x86_64.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/orf/gping/releases/download/gping-v${version}/gping-Linux-musl-${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.21.0" },
            ["1.21.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "cea59e22f6faf941f054cf0925433a2e3e4e6c42dc5c778b0265279a5056aeec",
                    aarch64 = "75e485e9ae081b4478b7c9fea0585a125dd7e640334cdbdec852af6238c3f1f1",
                },
            },
        },
        macosx = {
            source = "https://github.com/orf/gping/releases/download/gping-v${version}/gping-macOS-${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.21.0" },
            ["1.21.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "d0206c60fb5e7c6a9b727968aec847a3b0eb206f1f763c6c784324288114e732",
                    aarch64 = "9061a06d93490f97b3a956e149d8ec4c9030625f764e8dbfac9b737c00bd9ea0",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            source = "https://github.com/orf/gping/releases/download/gping-v${version}/gping-Windows-msvc-${arch}.zip",
            ["latest"] = { ref = "1.21.0" },
            ["1.21.0"] = {
                sha256 = {
                    x86_64 = "0de92fab46f4de8ac63f6d3247e9426bf430fae08d231bb513987dc7ea5b331d",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.shell")

local function is_windows()
    if os.getenv("OS") == "Windows_NT" then return true end
    local dir = tostring(pkginfo.install_dir() or "")
    if dir:match("^[A-Za-z]:") or dir:find("\\", 1, true) then return true end
    local archive = tostring(pkginfo.install_file() or "")
    return archive:match("%.zip$") ~= nil
end

function installed()
    return payload.present({ "gping" })
        or payload.present({ "gping.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("gping: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = is_windows()
    local exe = is_win and "gping.exe" or "gping"

    os.tryrm(dir)

    -- Archives are flat (no enclosing directory): extract directly from
    -- install_file into a clean install_dir so unrelated files in the shared
    -- runtime download directory cannot leak into the payload.
    if is_win then
        payload.unpack{}
        if not pkginfo.dep_install_dir then
            error("gping: xim:vcruntime runtime dep lookup is unavailable")
        end
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "gping: xim:vcruntime payload directory is missing")
        local dlls = fs.files(crt .. "/bin") or {}
        if #dlls == 0 then
            error("gping: no CRT DLLs found in " .. crt .. "/bin")
        end
        for _, dll in ipairs(dlls) do
            os.cp(dll, dir)
        end
    elseif os.isfile(archive) then
        fs.mkdir_p(dir)
        shell.exec({ "tar", "-xzf", archive, "-C", dir })
        shell.exec({ "chmod", "+x", dir .. "/" .. exe })
    elseif os.isfile(parent .. "/" .. exe) then
        fs.mkdir_p(dir)
        os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        if os.isfile(parent .. "/gping.1") then
            os.mv(parent .. "/gping.1", dir .. "/gping.1")
        end
        shell.exec({ "chmod", "+x", dir .. "/" .. exe })
    else
        error("gping: archive not found at " .. archive .. " and no extracted " .. exe .. " in " .. parent)
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("gping", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("gping")
    return true
end
