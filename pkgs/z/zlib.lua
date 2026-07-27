package = {
    spec = "1",
    homepage = "https://zlib.net",

    name = "zlib",
    description = "A massively spiffy yet delicately unobtrusive compression library",
    maintainers = {"Jean-loup Gailly", "Mark Adler"},
    licenses = {"Zlib"},
    repo = "https://github.com/madler/zlib",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"compression", "library"},
    keywords = {"zlib", "compression", "lib"},

    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "1.3.1" },
            ["1.3.1"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/zlib/releases/download/1.3.1/zlib-1.3.1-linux-x86_64.tar.gz",
                    CN = "https://gitcode.com/xlings-res/zlib/releases/download/1.3.1/zlib-1.3.1-linux-x86_64.tar.gz",
                },
                sha256 = "bd66d75485ca9d9a949ba5b99733c8ded759a464d1c6172ae26b8a2e176a0e75",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

local libs = {
    "libz.so", "libz.so.1",
}

function install()
    local srcdir = "zlib-" .. pkginfo.version() .. "-linux-x86_64"
    os.tryrm(pkginfo.install_dir())
    os.mv(srcdir, pkginfo.install_dir())
    return true
end

function config()
    local libdir = path.join(pkginfo.install_dir(), "lib")
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    for _, lib in ipairs(libs) do
        local libpath = path.join(libdir, lib)
        if os.isfile(libpath) then
            xvm.add(lib, {
                type = "lib",
                bindir = libdir,
                filename = lib,
                alias = lib,
                binding = binding,
            })
        end
    end

    -- Headers, so other packages can find them.
    --
    -- Capability probe, not a version check: xvm.files exists only on a
    -- client that understands type = "files" entries, because both arrived
    -- together in libxpkg 0.0.47 and libxpkg is linked into xlings. An older
    -- client takes the else branch and behaves exactly as it did before.
    local inc_dir = path.join(pkginfo.install_dir(), "include")
    local headers = {"zlib.h", "zconf.h"}
    if os.isdir(inc_dir) then
        if xvm.files then
            -- Declared, so they follow `xlings use` instead of being
            -- whichever version happened to be installed last.
            for _, h in ipairs(headers) do
                if os.isfile(path.join(inc_dir, h)) then
                    xvm.files{
                        src = path.join("include", h),
                        dst = path.join("usr/include", h),
                        binding = binding,
                    }
                end
            end
        else
            local sys_inc = path.join(system.subos_sysrootdir(), "usr/include")
            if os.isdir(sys_inc) then
                for _, h in ipairs(headers) do
                    local src = path.join(inc_dir, h)
                    if os.isfile(src) then os.cp(src, sys_inc) end
                end
            end
        end
    end

    return true
end

function uninstall()
    xvm.remove(package.name)

    for _, lib in ipairs(libs) do
        xvm.remove(lib)
    end

    -- Only the legacy branch left untracked copies behind. Declared assets
    -- are deregistered with the release.
    if not xvm.files then
        local sys_inc = path.join(system.subos_sysrootdir(), "usr/include")
        os.tryrm(path.join(sys_inc, "zlib.h"))
        os.tryrm(path.join(sys_inc, "zconf.h"))
    end

    return true
end
