package = {
    spec = "1",
    homepage = "https://gcc.gnu.org",

    name = "x86_64-linux-musl-gcc",
    description = "GCC cross toolchain targeting x86_64-linux-musl (musl, fully static ELF)",
    maintainers = {"mcpp-community"},
    licenses = {"GPL-3.0-with-GCC-exception"},
    repo = "https://github.com/gcc-mirror/gcc",
    docs = "https://gcc.gnu.org/wiki",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"compiler", "toolchain", "gcc", "musl", "cross"},
    keywords = {"gcc", "g++", "musl", "cross", "linux", "static", "compiler"},

    xvm_enable = true,

    -- Toolchains that PRODUCE x86_64-linux-musl, named by what they build FOR.
    -- One package, one identity, one asset per host — "cross" is not part of
    -- the name, it is just the host != target relation.
    --
    --   windows host → canadian cross, build=x86_64-linux-gnu /
    --                  host=x86_64-w64-mingw32 / target=x86_64-linux-musl.
    --                  The frontend `x86_64-linux-musl-g++.exe` is a Windows PE
    --                  that emits Linux ELF. This is what lets a Windows machine
    --                  produce a fully static, portable Linux binary with no WSL,
    --                  no container, and nothing installed system-wide.
    --
    -- A linux-host asset belongs here too (an aarch64 Linux host cross-building
    -- for x86_64); it is simply not published yet — x86_64 Linux hosts resolve
    -- this target to the NATIVE `musl-gcc` package instead, so nothing needs it
    -- today. Add a `linux = { ... }` block when that asset ships; mcpp already
    -- asks for this exact package name on such a host.
    --
    -- Mirrored at xlings-res/x86_64-linux-musl-gcc (GLOBAL → github, CN → gitcode):
    --   x86_64-linux-musl-gcc-<ver>-windows-x86_64.zip
    --   └── x86_64-linux-musl-gcc-<ver>-windows-x86_64/  (bin/, include/, lib/, libexec/)
    --
    -- Self-contained: own binutils, musl libc, libstdc++ (with bits/std.cc, so
    -- `import std` works). No deps — in particular NOT patchelf: that dep exists
    -- on the linux-hosted `musl-gcc` package to rewrite PT_INTERP on ELF
    -- frontends, and a PE frontend has no interpreter to rewrite.
    --
    -- Layout note: because the canadian build sets SYSROOT=/, the target tree
    -- lands at the prefix root (include/, lib/) rather than under
    -- <prefix>/x86_64-linux-musl/. That is the NATIVE layout, and it is the one
    -- mcpp probes first.
    --
    -- See mcpp .agents/docs/2026-08-03-windows-host-linux-cross-design.md.
    xpm = {
        windows = {
            ["latest"] = { ref = "16.1.0" },
            ["16.1.0"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "6dbf2ab46175e98b1d44d9f6f837e0f311cdbe8cddaba91f5f9d3b22cb9c58a7",
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

-- Windows host: enumerate with `dir /b` (`ls` does not exist here).
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
    -- Asset layout: x86_64-linux-musl-gcc-<ver>-windows-x86_64/ at archive top level.
    local inner = "x86_64-linux-musl-gcc-" .. pkginfo.version() .. "-windows-x86_64"
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
