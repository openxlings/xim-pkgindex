-- bottom -- A customizable cross-platform graphical process/system monitor (binary: `btm`).
--
-- Verified 2026-11-26 against upstream GitHub release ClementTsang/bottom 0.15.0:
-- every SHA256 below matches the GitHub release asset digest and locally
-- downloaded archives. All archives are flat (no top-level wrapper dir) and
-- contain `btm` (or `btm.exe`) plus `completion/`.
--
-- Linking & platform coverage:
--   * linux/x86_64    : bottom_x86_64-unknown-linux-musl.tar.gz
--                       static-pie ELF with zero DT_NEEDED entries (`ldd`: statically linked).
--   * linux/aarch64   : bottom_aarch64-unknown-linux-musl.tar.gz
--                       statically linked ELF with no dynamic section (`ldd`: not a dynamic executable).
--     (Official `-gnu` builds dynamically link libgcc_s.so.1, libm.so.6, libc.so.6;
--      `-musl` requires zero runtime deps.)
--   * macosx/x86_64   : bottom_x86_64-apple-darwin.tar.gz (Mach-O 64-bit x86_64)
--   * macosx/aarch64  : bottom_aarch64-apple-darwin.tar.gz (Mach-O 64-bit arm64)
--   * windows/x86_64  : bottom_x86_64-pc-windows-msvc.zip
--                       PE32+ x86-64 imports only Windows OS DLLs (`kernel32.dll`,
--                       `api-ms-win-core-synch-l1-2-0.dll`, `shell32.dll`, `combase.dll`,
--                       `ntdll.dll`, `ole32.dll`, `oleaut32.dll`, `setupapi.dll`,
--                       `advapi32.dll`, `powrprof.dll`, `iphlpapi.dll`, `netapi32.dll`,
--                       `secur32.dll`, `pdh.dll`, `psapi.dll`, `bcryptprimitives.dll`,
--                       `USER32.dll`); no `VCRUNTIME140.dll` or delay-load imports.
--   * windows/aarch64 : omitted (`bottom_aarch64-pc-windows-msvc.zip` imports
--                       `VCRUNTIME140.dll` while `xim:vcruntime` currently ships x86_64
--                       only; `bottom_aarch64-pc-windows-gnullvm.zip` imports `libunwind.dll`).

package = {
    spec = "2",

    name = "bottom",
    description = "Yet another cross-platform graphical process/system monitor",
    homepage = "https://bottom.pages.dev",
    authors = {"Clement Tsang"},
    maintainers = {"https://github.com/ClementTsang/bottom/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/ClementTsang/bottom",
    docs = "https://bottom.pages.dev/stable/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "monitor", "system", "tools"},
    keywords = {"bottom", "btm", "htop", "top", "monitor", "system", "rust"},

    programs = {"btm"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/ClementTsang/bottom/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/ClementTsang/bottom/releases/download/${tag}/bottom_x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/ClementTsang/bottom/releases/download/${tag}/bottom_aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/ClementTsang/bottom/releases/download/${tag}/bottom_x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/ClementTsang/bottom/releases/download/${tag}/bottom_aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/ClementTsang/bottom/releases/download/${tag}/bottom_x86_64-pc-windows-msvc.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/ClementTsang/bottom/releases/download/${version}/bottom_${arch_alias}-unknown-linux-musl.${ext}",
            ["latest"] = { ref = "0.15.0" },
            ["0.15.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "aarch64" },
                sha256 = {
                    x86_64 = "c66d6a0148102f107800919cd0ff6cce8767ae998f3c954b72e37a7f769e3ae2",
                    aarch64 = "78e03e96d02e946be1f94066cd78f1adc3bb8c0db5f53fdf24d70a3ab351e05c",
                },
            },
        },
        macosx = {
            source = "https://github.com/ClementTsang/bottom/releases/download/${version}/bottom_${arch_alias}-apple-darwin.${ext}",
            ["latest"] = { ref = "0.15.0" },
            ["0.15.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "aarch64" },
                sha256 = {
                    x86_64 = "6a7f5e32fc2c272256ad5c77aa8aaede02e1e86cf3ba4715acb894d3d6d5b361",
                    aarch64 = "6d83c9eba811dd139392fa5b04baa75225c6aa120dad36a070e636660db023fd",
                },
            },
        },
        windows = {
            source = "https://github.com/ClementTsang/bottom/releases/download/${version}/bottom_${arch_alias}-pc-windows-msvc.${ext}",
            ["latest"] = { ref = "0.15.0" },
            ["0.15.0"] = {
                arch_alias = { x86_64 = "x86_64" },
                sha256 = {
                    x86_64 = "aeff72e355116516d2583f34348e31f60c5899e394a08eeda79a2bdb361e27bd",
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
    return payload.present({ "btm" }) or payload.present({ "btm.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("bottom: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = is_windows()
    local exe = is_win and "btm.exe" or "btm"

    os.tryrm(dir)

    -- Archives are flat (no top-level wrapper directory): unpack straight from
    -- the archive into install_dir so files from unrelated flat archives in
    -- the shared runtime download directory are never pulled in.
    if is_win then
        payload.unpack{}
    elseif os.isfile(archive) then
        fs.mkdir_p(dir)
        shell.exec({ "tar", "-xzf", archive, "-C", dir })
        shell.exec({ "chmod", "+x", dir .. "/" .. exe })
    elseif os.isfile(parent .. "/" .. exe) then
        fs.mkdir_p(dir)
        os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        shell.exec({ "chmod", "+x", dir .. "/" .. exe })
    else
        error("bottom: archive not found at " .. archive .. " and no extracted " .. exe .. " in " .. parent)
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("btm", { bindir = pkginfo.install_dir() })
    -- Group placeholder: the binary is `btm`, while the package name is
    -- `bottom`. Registering `package.name` with `type = "group"` lets
    -- `xvm info bottom` and `xlings remove` locate the package without
    -- creating an orphan `bottom` shim in `bin/`.
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove("btm")
    xvm.remove(package.name)
    return true
end
