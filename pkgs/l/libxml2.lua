package = {
    spec = "1",
    homepage = "https://gitlab.gnome.org/GNOME/libxml2",

    name = "libxml2",
    description = "XML C parser and toolkit",
    maintainers = {"GNOME"},
    licenses = {"MIT"},
    repo = "https://gitlab.gnome.org/GNOME/libxml2",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"xml", "parsing", "library"},
    keywords = {"libxml2", "xml", "parser", "lib"},

    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "2.13.5" },
            ["2.13.5"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libxml2/releases/download/2.13.5/libxml2-2.13.5-linux-x86_64.tar.gz",
                    CN = "https://gitcode.com/xlings-res/libxml2/releases/download/2.13.5/libxml2-2.13.5-linux-x86_64.tar.gz",
                },
                sha256 = "f963896ed90c4599d06786f86203620e937a746a6be246065d7a3b01af2a7ed1",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local libs = {
    "libxml2.so", "libxml2.so.2",
}

function install()
    local srcdir = "libxml2-" .. pkginfo.version() .. "-linux-x86_64"
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

    -- Headers into the sysroot.
    --
    -- Capability probe, not a version check: xvm.files exists only on a
    -- client that understands type = "files" entries, because both arrived
    -- together in libxpkg 0.0.47 and libxpkg is linked into xlings. An older
    -- client takes the else branch and behaves exactly as it did before.
    local inc_dir = path.join(pkginfo.install_dir(), "include", "libxml2")
    if os.isdir(inc_dir) then
        if xvm.files then
            -- Declared, so the headers follow `xlings use` and go away with
            -- the release instead of being cleaned up by hand below.
            xvm.files{
                src = path.join("include", "libxml2"),
                dst = path.join("usr/include", "libxml2"),
                binding = binding,
            }
        else
            local sys_inc = path.join(system.subos_sysrootdir(), "usr/include")
            if os.isdir(sys_inc) then os.cp(inc_dir, sys_inc) end
        end
    end

    return true
end

function uninstall()
    xvm.remove(package.name)

    for _, lib in ipairs(libs) do
        xvm.remove(lib)
    end

    -- Only the legacy branch left an untracked copy behind; a declared
    -- asset is deregistered with the release.
    if not xvm.files then
        local sys_inc = path.join(system.subos_sysrootdir(), "usr/include")
        os.tryrm(path.join(sys_inc, "libxml2"))
    end

    return true
end
