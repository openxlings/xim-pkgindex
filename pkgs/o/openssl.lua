package = {
    spec = "1",
    homepage = "https://www.openssl.org",
    name = "openssl",
    description = "TLS/SSL and cryptography toolkit",
    authors = {"The OpenSSL Project"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/openssl/openssl",

    type = "package",
    archs = { "x86_64" },
    status = "stable",
    categories = { "crypto", "tls", "ssl", "library" },
    keywords = { "openssl", "libssl", "libcrypto", "tls", "ssl", "https" },

    programs = {
        "openssl", "c_rehash"
    },

    xvm_enable = true,

    xpm = {
        linux = {
            deps = { "xim:glibc@2.39" },
            ["latest"] = { ref = "3.1.5" },
            ["3.1.5"] = "XLINGS_RES",
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")
import("xim.pkgindex.sysroot")
-- elfpatch import removed: predicate-driven auto-patch (post 2026-05-02
-- design) reads glibc.lua's exports.runtime.loader and rewrites our
-- INTERP / RPATH automatically. No install-hook elfpatch call needed.

local libs = {
    "libcrypto.so", "libcrypto.so.3", "libcrypto.a",
    "libssl.so",    "libssl.so.3",    "libssl.a"
}

-- list files matching a glob pattern (standard Lua, replaces xmake os.files)
local function list_files(pattern)
    local result = {}
    local f = io.popen('ls -d ' .. pattern .. ' 2>/dev/null')
    if f then
        for line in f:lines() do
            local clean = line:gsub("[\r\n]+$", "")
            if clean ~= "" and os.isfile(clean) then
                table.insert(result, clean)
            end
        end
        f:close()
    end
    return result
end

local xpkg_binding_tree = package.name .. "-binding-tree"

local function get_sys_usr_includedir()
    return path.join(system.subos_sysrootdir(), "usr/include")
end

function install()
    local openssl_dir = pkginfo.install_file()
        :replace(".zip", "")
        :replace(".tar.gz", "")
    os.tryrm(pkginfo.install_dir())
    os.mv(openssl_dir, pkginfo.install_dir())

    return true
end

function config()
    local binding_tree_version_tag = xpkg_binding_tree .. "@" .. pkginfo.version()
    xvm.add(xpkg_binding_tree)

    local bindir = path.join(pkginfo.install_dir(), "bin")
    local libdir = path.join(pkginfo.install_dir(), "lib64")
    local includedir = path.join(pkginfo.install_dir(), "include")

    log.debug("Registering CLI programs...")
    for _, prog in ipairs(package.programs) do
        xvm.add(prog, {
            bindir = bindir,
            binding = binding_tree_version_tag,
        })
    end

    log.debug("Registering libraries...")
    local config = {
        type = "lib",
        version = package.name .. "-" .. pkginfo.version(),
        bindir = libdir,
        binding = binding_tree_version_tag,
    }

    for _, lib in ipairs(libs) do
        config.alias = lib
        config.filename = lib
        xvm.add(lib, config)
    end

    log.debug("Linking headers into subos sysroot ...")
    if os.isdir(includedir) then
        -- Capability probe, not a version check: xvm.files exists only on a
        -- client that understands type = "files" entries, because both
        -- arrived together in libxpkg 0.0.47 and libxpkg is linked into
        -- xlings. An older client takes the branch below and behaves exactly
        -- as it did before this migration.
        if xvm.files then
            -- Declared, so the headers follow `xlings use` and are removed
            -- with the release. Enumerated the same way uninstall() does,
            -- because install_headers links top-level entries, not a tree.
            for _, subdir in ipairs(os.dirs(path.join(includedir, "*"))) do
                local name = path.filename(subdir)
                xvm.files{
                    src = path.join("include", name),
                    dst = path.join("usr/include", name),
                    binding = binding_tree_version_tag,
                }
            end
            for _, file in ipairs(list_files(path.join(includedir, "*.h"))) do
                local name = path.filename(file)
                xvm.files{
                    src = path.join("include", name),
                    dst = path.join("usr/include", name),
                    binding = binding_tree_version_tag,
                }
            end
        else
            sysroot.install_headers(includedir, get_sys_usr_includedir())
        end
    end

    -- No xvm.add(package.name) here: "openssl" is in package.programs, so
    -- the loop above already registered it -- with a bindir, which this
    -- one lacked. Registering the same name and version twice is refused
    -- since 0.4.70 (xvm-duplicate-registration), which made this package
    -- uninstallable; 0.4.69 accepted it and silently kept the second,
    -- bindir-less registration.
    return true
end

function uninstall()
    xvm.remove(package.name)

    for _, prog in ipairs(package.programs) do
        xvm.remove(prog)
    end

    for _, lib in ipairs(libs) do
        xvm.remove(lib, package.name .. "-" .. pkginfo.version())
    end

    -- Only the legacy branch placed untracked copies. Declared assets are
    -- deregistered with the release, so cleaning them here would be a second
    -- owner for the same files.
    local includedir = path.join(pkginfo.install_dir(), "include")
    if not xvm.files and os.isdir(includedir) then
        local sys_includedir = get_sys_usr_includedir()
        local subdirs = os.dirs(path.join(includedir, "*"))
        for _, subdir in ipairs(subdirs) do
            os.tryrm(path.join(sys_includedir, path.filename(subdir)))
        end

        for _, file in ipairs(list_files(path.join(includedir, "*.h"))) do
            os.tryrm(path.join(sys_includedir, path.filename(file)))
        end
    end

    xvm.remove(xpkg_binding_tree)
    return true
end
