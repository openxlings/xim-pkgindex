-- trippy -- A network diagnostic tool combining traceroute and ping (binary: `trip`).
--
-- Verified 2026-11-26 against upstream GitHub release `fujiapple852/trippy` `0.13.0`:
-- every SHA256 below was computed locally from the downloaded release archives.
-- Every archive encloses its single binary inside `<archive-stem>/` (`trip` on
-- POSIX, `trip.exe` on Windows).
--
-- Linking & platform coverage:
--   * linux/x86_64    : trippy-0.13.0-x86_64-unknown-linux-musl.tar.gz
--                       static-pie ELF (`readelf -d`: zero DT_NEEDED entries,
--                       `ldd`: statically linked).
--   * linux/aarch64   : trippy-0.13.0-aarch64-unknown-linux-musl.tar.gz
--                       statically linked ELF (no dynamic section, no PT_INTERP).
--     -> Zero runtime dependencies on Linux.
--   * macosx/x86_64   : trippy-0.13.0-x86_64-apple-darwin.tar.gz (Mach-O 64-bit x86_64)
--   * macosx/aarch64  : trippy-0.13.0-aarch64-apple-darwin.tar.gz (Mach-O 64-bit arm64)
--   * windows/x86_64  : trippy-0.13.0-x86_64-pc-windows-msvc.zip
--                       PE32+ x86-64 importing `VCRUNTIME140.dll`, UCRT API sets,
--                       and Windows OS DLLs (`kernel32.dll`, `IPHLPAPI.DLL`,
--                       `ws2_32.dll`, `user32.dll`, `advapi32.dll`, `ntdll.dll`,
--                       `bcrypt.dll`, `bcryptprimitives.dll`, `shell32.dll`,
--                       `ole32.dll`), so `xim:vcruntime` DLLs are copied app-local
--                       beside `trip.exe`.
--   * windows/aarch64 : omitted (`trippy-0.13.0-aarch64-pc-windows-msvc.zip`
--                       also imports `VCRUNTIME140.dll`, while `xim:vcruntime`
--                       currently ships `x86_64` only).

package = {
    spec = "2",

    name = "trippy",
    description = "A network diagnostic tool combining traceroute and ping",
    homepage = "https://trippy.rs",
    authors = {"FujiApple"},
    maintainers = {"https://github.com/fujiapple852/trippy/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/fujiapple852/trippy",
    docs = "https://trippy.rs",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"network", "cli", "tui", "diagnostics", "tools"},
    keywords = {"trippy", "trip", "traceroute", "ping", "mtr", "network", "diagnostics", "rust"},

    programs = {"trip"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/fujiapple852/trippy/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/fujiapple852/trippy/releases/download/${tag}/trippy-${version}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/fujiapple852/trippy/releases/download/${tag}/trippy-${version}-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/fujiapple852/trippy/releases/download/${tag}/trippy-${version}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/fujiapple852/trippy/releases/download/${tag}/trippy-${version}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/fujiapple852/trippy/releases/download/${tag}/trippy-${version}-x86_64-pc-windows-msvc.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/fujiapple852/trippy/releases/download/${version}/trippy-${version}-${arch}-unknown-linux-musl.${ext}",
            ["latest"] = { ref = "0.13.0" },
            ["0.13.0"] = {
                sha256 = {
                    x86_64 = "aa2b7b2a0773f3cc04da691100419049950b690fe3736d25e24ac955b63d6056",
                    aarch64 = "73af939aa94e9e0f07cac2b3c8177e02a6b1c3be88299d85988e02be81ae7004",
                },
            },
        },
        macosx = {
            source = "https://github.com/fujiapple852/trippy/releases/download/${version}/trippy-${version}-${arch}-apple-darwin.${ext}",
            ["latest"] = { ref = "0.13.0" },
            ["0.13.0"] = {
                sha256 = {
                    x86_64 = "26e7000df77a52fd8462040ebee1ebde9ada2e8d853b97838321b484928d9ea3",
                    aarch64 = "5bb2c22822a8d301bd462dc35bec865b9eae1737e9180406b6eacdd46d44adf2",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            source = "https://github.com/fujiapple852/trippy/releases/download/${version}/trippy-${version}-${arch}-pc-windows-msvc.${ext}",
            -- Windows ARM64 imports VCRUNTIME140.dll and awaits `xim:vcruntime` ARM64 CRT support.
            ["latest"] = { ref = "0.13.0" },
            ["0.13.0"] = {
                sha256 = {
                    x86_64 = "74a184434d96eec6c7f8e4b467147c40fa8841fa3722a3ddf51267208fcbbbe6",
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

function installed()
    return payload.present({ "trip" }) or payload.present({ "trip.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("trippy: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local stem = (normalized:match("([^/]+)$") or ""):gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil

    if not is_win and normalized:match("%.tar%.gz$") and not os.isdir(parent .. "/" .. stem) and os.isfile(archive) then
        shell.exec({ "tar", "-xzf", archive, "-C", parent })
    end

    payload.unpack{ extracted = stem, strip = 1 }

    if not is_win and os.isfile(dir .. "/trip") then
        shell.exec({ "chmod", "+x", dir .. "/trip" })
    end

    if is_win then
        if not pkginfo.dep_install_dir then
            error("trippy: xim:vcruntime runtime dep lookup is unavailable")
        end
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "trippy: xim:vcruntime payload directory is missing")
        local dlls = fs.files(crt .. "/bin") or {}
        if #dlls == 0 then
            error("trippy: no CRT DLLs found in " .. crt .. "/bin")
        end
        for _, dll in ipairs(dlls) do
            os.cp(dll, dir)
        end
    end

    payload.require({ is_win and "trip.exe" or "trip" })
    return true
end

function config()
    xvm.add("trip", { bindir = pkginfo.install_dir() })
    -- Group placeholder: the binary is `trip`, while the package name is
    -- `trippy`. Registering `package.name` with `type = "group"` lets
    -- `xvm info trippy` and `xlings remove` locate the package without
    -- creating an orphan `trippy` shim in `bin/`.
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove("trip")
    xvm.remove(package.name)
    return true
end
