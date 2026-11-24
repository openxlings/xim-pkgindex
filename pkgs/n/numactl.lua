-- numactl (libnuma) - NUMA policy library for Linux (libnuma.so.1).
--
-- Source: official upstream release tarball from github.com/numactl/numactl.
-- Built library-only (libnuma.so.1, headers, numa.pc) inside the subos against
-- xim:glibc using xim:gcc and xim:make, sealed with selfcontain.seal(dir).
package = {
    spec = "2",

    homepage = "https://github.com/numactl/numactl",
    name = "numactl",
    description = "NUMA policy library for Linux (libnuma.so.1)",

    licenses = {"LGPL-2.1-only", "GPL-2.0-only"},
    repo = "https://github.com/numactl/numactl",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"system", "lib"},
    keywords = {"numactl", "libnuma", "numa", "linux", "lib"},

    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/numactl/numactl/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = "https://github.com/numactl/numactl/releases/download/${tag}/numactl-${version}.tar.gz",
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            deps = {
                runtime = { "xim:glibc" },
                build = { "xim:gcc@16.2.0", "xim:make@4.3" },
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "2.0.19" },
            ["2.0.19"] = {
                url = "https://github.com/numactl/numactl/releases/download/v2.0.19/numactl-2.0.19.tar.gz",
                sha256 = "f2672a0381cb59196e9c246bf8bcc43d5568bc457700a697f1a1df762b9af884",
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

local function _shq(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

function install()
    local dir = pkginfo.install_dir()
    local ver = pkginfo.version()
    local archive = tostring(pkginfo.install_file())
    local parent = path.directory(archive)
    local srcdir = path.join(parent, "numactl-" .. ver)
    local build_dir = path.join(parent, "numactl-" .. ver .. "-build")
    local stage_dir = path.join(parent, "numactl-" .. ver .. "-stage")

    os.tryrm(srcdir)
    os.tryrm(build_dir)
    os.tryrm(stage_dir)
    system.exec("tar -xf " .. _shq(archive) .. " -C " .. _shq(parent))
    if not os.isdir(srcdir) then
        raise("numactl source directory not found: " .. srcdir)
    end
    os.mkdir(build_dir)
    os.mkdir(stage_dir)

    local gcc_dir = assert(_build_dep_dir("gcc"), "missing xim:gcc build dependency")
    local make_dir = assert(_build_dep_dir("make"), "missing xim:make build dependency")
    local gcc_bin = path.join(gcc_dir, "bin")
    local make_bin = path.join(make_dir, "bin")
    local subos_bin = system.bindir()
    local build_path = table.concat({ make_bin, gcc_bin, subos_bin, "/usr/bin", "/bin" }, ":")

    local make_exe = path.join(make_bin, "make")
    local gcc_exe = path.join(gcc_bin, "gcc")
    local ar_exe = path.join(gcc_bin, "gcc-ar")
    local ranlib_exe = path.join(gcc_bin, "gcc-ranlib")
    local cc_wrap = path.join(build_dir, "subos-cc")
    io.writefile(cc_wrap, "#!/bin/sh\nexec " .. _shq(gcc_exe) .. " --sysroot=" .. _shq(system.subos_sysrootdir()) .. " \"$@\"\n")
    system.exec("chmod +x " .. _shq(cc_wrap))
    local env_prefix = "env PATH=" .. _shq(build_path) .. " "

    local cmd = table.concat({
        "cd " .. _shq(build_dir),
        env_prefix .. _shq(path.join(srcdir, "configure"))
            .. " CC=" .. _shq(cc_wrap)
            .. " AR=" .. _shq(ar_exe)
            .. " RANLIB=" .. _shq(ranlib_exe)
            .. " --prefix=/usr --libdir=/usr/lib --disable-static -q",
        env_prefix .. _shq(make_exe) .. " -j4 libnuma.la numa.pc",
        env_prefix .. _shq(make_exe)
            .. " install-libLTLIBRARIES install-includeHEADERS install-pkgconfigDATA"
            .. " DESTDIR=" .. _shq(stage_dir),
    }, " && ")
    system.exec(cmd)

    os.tryrm(dir)
    os.mv(path.join(stage_dir, "usr"), dir)
    os.tryrm(path.join(dir, "lib", "libnuma.la"))
    os.tryrm(build_dir)
    os.tryrm(stage_dir)

    selfcontain.seal(dir)
    sysroot.relocate_pkgconfig(dir, "lib/pkgconfig")
    return os.isfile(path.join(dir, "lib", "libnuma.so.1"))
end

function config()
    local dir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()
    xvm.add(package.name, { type = "group" })
    sysroot.declare_libs(dir, "lib", binding, pkginfo.version())
    sysroot.declare_headers(dir, "include", "usr/include", binding)
    sysroot.declare_pkgconfig(dir, "lib/pkgconfig", binding)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
