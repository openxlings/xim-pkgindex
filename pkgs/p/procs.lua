-- procs: a modern replacement for ps written in Rust (dalance/procs).
--
-- Official prebuilt archives verified against dalance/procs release v0.14.12:
--   * linux/x86_64  : procs-v0.14.12-x86_64-linux.zip (flat zip containing `procs`;
--                     static-pie linked ELF with no PT_INTERP and no DT_NEEDED)
--   * linux/aarch64 : procs-v0.14.12-aarch64-linux.zip (flat zip containing `procs`;
--                     statically linked ELF with no dynamic section)
--   * macosx/x86_64 : procs-v0.14.12-x86_64-mac.zip (flat zip containing `procs`;
--                     Mach-O 64-bit x86_64 executable)
--   * macosx/aarch64: procs-v0.14.12-aarch64-mac.zip (flat zip containing `procs`;
--                     Mach-O 64-bit arm64 executable)
--   * windows/x86_64: procs-v0.14.12-x86_64-windows.zip (flat zip containing `procs.exe`;
--                     PE32+ x86-64 importing VCRUNTIME140.dll + UCRT/OS DLLs, so
--                     `xim:vcruntime` is declared and copied app-local beside procs.exe)
--   * windows/aarch64: omitted; upstream does not publish a Windows ARM64 archive
--                     (and xim:vcruntime is x86_64-only).
--
-- All SHA256 digests match the GitHub release asset digests and locally computed
-- hashes on the downloaded v0.14.12 archives.

package = {
    spec = "2",

    name = "procs",
    description = "A modern replacement for ps written in Rust",
    homepage = "https://github.com/dalance/procs",
    authors = {"dalance"},
    maintainers = {"dalance"},
    licenses = {"MIT"},
    repo = "https://github.com/dalance/procs",
    docs = "https://github.com/dalance/procs#readme",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "system", "process", "tools"},
    keywords = {"procs", "ps", "process", "monitor", "rust"},

    programs = {"procs"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/dalance/procs/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/dalance/procs/releases/download/${tag}/procs-${tag}-x86_64-linux.zip",
                            aarch64 = "https://github.com/dalance/procs/releases/download/${tag}/procs-${tag}-aarch64-linux.zip",
                        },
                        macosx = {
                            x86_64 = "https://github.com/dalance/procs/releases/download/${tag}/procs-${tag}-x86_64-mac.zip",
                            aarch64 = "https://github.com/dalance/procs/releases/download/${tag}/procs-${tag}-aarch64-mac.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/dalance/procs/releases/download/${tag}/procs-${tag}-x86_64-windows.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/dalance/procs/releases/download/v${version}/procs-v${version}-${arch}-linux.zip",
            ["latest"] = { ref = "0.14.12" },
            ["0.14.12"] = {
                sha256 = {
                    x86_64 = "81964faf9d5cd0e9f399d5d0954fb6fe4d4d9f7d3cbec4507633df5a45b11713",
                    aarch64 = "74b4f82acc6fe553cbd5af20ba0baac420b42bef9bb0cbb38fef14b8317d9f91",
                },
            },
        },
        macosx = {
            source = "https://github.com/dalance/procs/releases/download/v${version}/procs-v${version}-${arch}-mac.zip",
            ["latest"] = { ref = "0.14.12" },
            ["0.14.12"] = {
                sha256 = {
                    x86_64 = "2c276f40c99051984942a5b135b74ce4bc9184984a1543dddfcf275bde71d8d4",
                    aarch64 = "20c7a33426ed7a43c3e13a48f2d1866ecc979a8ad46733f86ddc78ab7f12d49c",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            source = "https://github.com/dalance/procs/releases/download/v${version}/procs-v${version}-${arch}-windows.zip",
            ["latest"] = { ref = "0.14.12" },
            ["0.14.12"] = {
                sha256 = {
                    x86_64 = "4928c399ae78ee82f99139a5629077b8d90a58599d834584dd4e613cb60c83d0",
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

local function is_windows_target(archive, dir)
    local normalized = tostring(archive or ""):gsub("\\", "/")
    if normalized:match("%-windows%.zip$") then
        return true
    end
    if os.getenv("OS") == "Windows_NT" then
        return true
    end
    local d = tostring(dir or "")
    return d:match("^[A-Za-z]:") ~= nil or d:find("\\", 1, true) ~= nil
end

function installed()
    return payload.present({ "procs" }) or payload.present({ "procs.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("procs: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = is_windows_target(normalized, dir)
    local exe = is_win and "procs.exe" or "procs"

    -- Flat `.zip` archive across all platforms: isolate extraction into install_dir()
    -- so files never mix with other flat archives in runtimedir.
    os.tryrm(dir)
    fs.mkdir_p(dir)

    if is_win then
        if os.isfile(archive) and type(payload.unpack) == "function" then
            payload.unpack{}
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        elseif os.isfile(archive) then
            local sysroot = (os.getenv("SystemRoot") or "C:\\Windows"):gsub("/", "\\"):gsub("\\+$", "")
            local systar = sysroot .. "\\System32\\tar.exe"
            -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
            system.exec(string.format('%s -xf "%s" -C "%s"', systar, archive:gsub("/", "\\"), dir:gsub("/", "\\")))
        else
            error("procs: extracted binary (" .. exe .. ") not found in " .. parent)
        end

        if pkginfo.dep_install_dir then
            local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                               "procs: xim:vcruntime payload directory is missing")
            for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
                os.cp(dll, dir)
            end
        end
    else
        if os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        elseif os.isfile(archive) then
            system.exec(string.format('unzip -q -o "%s" -d "%s"', archive, dir))
        else
            error("procs: extracted binary (" .. exe .. ") not found in " .. parent)
        end
        if os.isfile(dir .. "/procs") then
            system.exec(string.format('chmod +x "%s"', dir .. "/procs"))
        end
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("procs", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("procs")
    return true
end
