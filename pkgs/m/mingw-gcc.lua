package = {
    spec = "1",
    homepage = "https://winlibs.com",

    name = "mingw-gcc",
    description = "MinGW-w64 GCC for Windows (winlibs standalone build, UCRT runtime)",
    maintainers = {"winlibs (Brecht Sanders)"},
    licenses = {"GPL-3.0-with-GCC-exception"},
    repo = "https://github.com/brechtsanders/winlibs_mingw",
    docs = "https://winlibs.com",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"compiler", "toolchain", "gcc", "mingw"},
    keywords = {"gcc", "g++", "mingw", "mingw-w64", "windows", "compiler"},

    xvm_enable = true,

    -- Mirrored at xlings-res/mingw-gcc (GLOBAL → github, CN → gitcode).
    -- Byte content is the upstream winlibs archive (POSIX threads, SEH,
    -- UCRT); only the top-level dir and archive name are renamed to the
    -- xlings-res convention:
    --   mingw-gcc-<ver>-windows-x86_64.zip
    --   └── mingw-gcc-<ver>-windows-x86_64/  (winlibs mingw64/)
    -- Self-contained: own binutils, CRT import libs and libstdc++
    -- (include/c++/<ver>/bits/std.cc → `import std` works). No deps.
    xpm = {
        windows = {
            ["latest"] = { ref = "16.1.0" },
            ["16.1.0"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "cfe6cd70eecc5c93f628ee1436545b3782a2ac17cac0fe5c4836b99185abe14f",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

local function is_registerable_bin(pathname)
    local name = path.filename(pathname)
    if name == nil or name == "" then
        return false
    end
    -- Only register executables; skip DLLs living in bin/.
    if name:sub(-4) == ".dll" then
        return false
    end
    return os.isfile(pathname)
end

local function collect_bin_apps(bindir)
    local apps = {}
    local f = io.popen('dir /b "' .. bindir .. '" 2>nul')
    if f then
        for name in f:lines() do
            local clean = name:gsub("[\r\n]+$", "")
            if clean ~= "" then
                local filepath = path.join(bindir, clean)
                if is_registerable_bin(filepath) then
                    table.insert(apps, clean)
                end
            end
        end
        f:close()
    end
    table.sort(apps)
    return apps
end

function install()
    -- Asset layout: mingw-gcc-<ver>-windows-x86_64/ at archive top level.
    local inner = "mingw-gcc-" .. pkginfo.version() .. "-windows-x86_64"
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
