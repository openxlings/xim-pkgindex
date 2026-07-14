package = {
    spec = "1",
    homepage = "https://www.mingw-w64.org",

    name = "mingw-cross-gcc",
    description = "MinGW-w64 GCC cross toolchain (Linux host → Windows x86_64 PE, MSVCRT runtime)",
    maintainers = {"mcpp-community"},
    licenses = {"GPL-3.0-with-GCC-exception"},
    repo = "https://gcc.gnu.org",
    docs = "https://www.mingw-w64.org",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"compiler", "toolchain", "gcc", "mingw", "cross"},
    keywords = {"gcc", "g++", "mingw", "mingw-w64", "cross", "windows", "compiler"},

    xvm_enable = true,

    -- Linux-hosted cross toolchain (host ≠ target): the frontend
    -- `x86_64-w64-mingw32-g++` is an ELF Linux executable that produces Windows
    -- PE. Built from source (GCC 16.1.0 + mingw-w64 CRT, --with-default-msvcrt=msvcrt)
    -- so `import std` works — libstdc++ ships bits/std.cc under
    -- x86_64-w64-mingw32/include/c++/16/. MSVCRT (not UCRT) mirrors Rust's Tier-1
    -- `x86_64-pc-windows-gnu` and is the wine-friendly choice; a UCRT variant is
    -- a separate future triple. Mirrored at xlings-res/mingw-cross-gcc
    -- (GLOBAL → github, CN → gitcode):
    --   mingw-cross-gcc-<ver>-linux-x86_64.tar.gz
    --   └── mingw-cross-gcc-<ver>-linux-x86_64/  (bin/, x86_64-w64-mingw32/, lib/, ...)
    -- Self-contained: own binutils + CRT + libstdc++. Frontend is glibc-linked
    -- with the standard ELF interpreter, so no patchelf relocation is needed
    -- (unlike musl-gcc). No deps.
    -- See mcpp .agents/docs/2026-07-15-mingw-linux-cross-windows-design.md.
    xpm = {
        linux = {
            ["latest"] = { ref = "16.1.0" },
            ["16.1.0"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "ca93aa25d5e59e568ce81db5bcdd161ed743c2893873fd1bbee4d9bc4e3e7fa8", -- filled by publish script from the built tarball
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- Register only the cross tools (x86_64-w64-mingw32-*) plus the bare frontends.
-- These are ELF executables under bin/; enumerate with `ls` (Linux host).
local function collect_bin_apps(bindir)
    local apps = {}
    local f = io.popen('ls -1 "' .. bindir .. '" 2>/dev/null')
    if f then
        for name in f:lines() do
            local clean = name:gsub("[\r\n]+$", "")
            if clean ~= "" and os.isfile(path.join(bindir, clean)) then
                table.insert(apps, clean)
            end
        end
        f:close()
    end
    table.sort(apps)
    return apps
end

function install()
    -- Asset layout: mingw-cross-gcc-<ver>-linux-x86_64/ at archive top level.
    local inner = "mingw-cross-gcc-" .. pkginfo.version() .. "-linux-x86_64"
    os.tryrm(pkginfo.install_dir())
    os.mv(inner, pkginfo.install_dir())
    return true
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    for _, app in ipairs(collect_bin_apps(bindir)) do
        xvm.add(app, {
            bindir = bindir,
            binding = binding,
        })
    end

    return true
end

function uninstall()
    local bindir = path.join(pkginfo.install_dir(), "bin")

    xvm.remove(package.name)

    for _, app in ipairs(collect_bin_apps(bindir)) do
        xvm.remove(app)
    end

    return true
end
