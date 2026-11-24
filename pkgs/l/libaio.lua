-- libaio - Linux kernel asynchronous I/O access library (libaio.so.1).
--
-- Source: Debian archive snapshot of upstream libaio 0.3.113 tarball (permanent
-- snapshot.debian.org URL). Built inside the subos against xim:glibc using
-- xim:gcc and xim:make, sealed with selfcontain.seal(dir).
--
-- Manual maintenance: upstream pagure.io archives are not on GitHub releases
-- and Debian snapshot URLs are fixed immutable archives.
package = {
    spec = "2",

    homepage = "https://pagure.io/libaio",
    name = "libaio",
    description = "Linux kernel asynchronous I/O access library (libaio.so.1)",

    licenses = {"LGPL-2.1-or-later"},
    repo = "https://pagure.io/libaio",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"system", "lib"},
    keywords = {"libaio", "aio", "linux", "io", "lib"},

    xvm_enable = true,

    xpm = {
        linux = {
            deps = {
                runtime = { "xim:glibc" },
                build = { "xim:gcc@16.2.0", "xim:make@4.3" },
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "0.3.113" },
            ["0.3.113"] = {
                url = "https://snapshot.debian.org/archive/debian/20240101T000000Z/pool/main/liba/libaio/libaio_0.3.113.orig.tar.gz",
                sha256 = "2c44d1c5fd0d43752287c9ae1eb9c023f04ef848ea8d4aafa46e9aedb678200b",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

local function _build_dep_dir(name)
    if type(pkginfo.build_dep) == "function" then
        local bd = pkginfo.build_dep(name)
        if bd and bd.path and os.isdir(bd.path) then
            return bd.path
        end
    end
    return nil
end

function install()
    local dir = pkginfo.install_dir()
    local archive = tostring(pkginfo.install_file())
    local parent = path.directory(archive)
    local srcdir = path.join(parent, "libaio-" .. pkginfo.version())
    local src_sub = path.join(srcdir, "src")

    if not os.isdir(src_sub) then
        os.mkdir(srcdir)
        system.exec(string.format('tar -xf "%s" -C "%s"', archive, parent))
    end
    if not os.isdir(src_sub) then
        raise("libaio source directory not found: " .. src_sub)
    end

    local gcc_dir = assert(_build_dep_dir("gcc"), "missing xim:gcc build dependency")
    local make_dir = assert(_build_dep_dir("make"), "missing xim:make build dependency")
    local gcc_bin = path.join(gcc_dir, "bin")
    local make_bin = path.join(make_dir, "bin")
    local subos_bin = system.bindir()
    local build_path = table.concat({ make_bin, gcc_bin, subos_bin, "/usr/bin", "/bin" }, ":")

    local make_exe = path.join(make_bin, "make")
    local cc_exe = path.join(gcc_bin, "gcc")
    local ar_exe = path.join(gcc_bin, "gcc-ar")
    local ranlib_exe = path.join(gcc_bin, "gcc-ranlib")
    local sysroot_dir = system.subos_sysrootdir()

    local function shq(s)
        return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
    end
    local cc_with_sysroot = shq(cc_exe) .. " --sysroot=" .. shq(sysroot_dir)

    os.tryrm(dir)
    os.mkdir(dir)

    local env_prefix = "env PATH=" .. shq(build_path) .. " "
    local cmd = env_prefix .. shq(make_exe) .. " -C " .. shq(src_sub) .. " clean && "
        .. env_prefix .. shq(make_exe) .. " -C " .. shq(src_sub)
        .. " CC=" .. shq(cc_with_sysroot)
        .. " AR=" .. shq(ar_exe)
        .. " RANLIB=" .. shq(ranlib_exe)
        .. " prefix=" .. shq(dir)
        .. " install"
    system.exec(cmd)

    os.tryrm(path.join(dir, "lib", "libaio.a"))
    selfcontain.seal(dir)
    return os.isfile(path.join(dir, "lib", "libaio.so.1"))
end

function config()
    local dir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()
    xvm.add(package.name, { type = "group" })
    sysroot.declare_libs(dir, "lib", binding, pkginfo.version())
    sysroot.declare_headers(dir, "include", "usr/include", binding)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
