-- libcurl - Multiprotocol file transfer shared library (libcurl.so.4).
--
-- Source: official upstream curl release tarball from github.com/curl/curl.
-- Built library-only (libcurl.so.4, include/curl/, libcurl.pc) against
-- xim:glibc, xim:openssl, and xim:zlib using xim:gcc and xim:make, with
-- optional host protocol libraries disabled so the closure stays self-contained.
--
-- Separate from pkgs/c/curl.lua, which ships a static musl CLI-only `curl` binary.
-- Manual maintenance: upstream curl tags use underscore formatting (`curl-8_23_0`).
package = {
    spec = "2",

    homepage = "https://curl.se/",
    name = "libcurl",
    description = "Multiprotocol file transfer shared library (libcurl.so.4)",

    maintainers = {"curl"},
    licenses = {"curl"},
    repo = "https://github.com/curl/curl",
    docs = "https://curl.se/libcurl/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"network", "library"},
    keywords = {"libcurl", "curl", "http", "https", "tls", "lib"},

    xvm_enable = true,

    xpm = {
        linux = {
            deps = {
                runtime = { "xim:glibc", "xim:openssl", "xim:zlib" },
                build = { "xim:gcc@16.2.0", "xim:make@4.3" },
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "8.23.0" },
            ["8.23.0"] = {
                url = "https://github.com/curl/curl/releases/download/curl-8_23_0/curl-8.23.0.tar.xz",
                sha256 = "8dadd7d2536a314f982ad05a651b713f426bf7d02cc2c76cffb9796f2218e6c5",
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

local function _strip_foreign_pc_libdirs(pc_path)
    if not os.isfile(pc_path) then return end
    local text = io.readfile(pc_path)
    if not text then return end
    local cleaned = text:gsub("(Libs%.private:[^\n]*)", function(line)
        return line:gsub("%s%-L[^%s]+", "")
    end)
    if cleaned ~= text then
        io.writefile(pc_path, cleaned)
    end
end

function install()
    local dir = pkginfo.install_dir()
    local ver = pkginfo.version()
    local archive = tostring(pkginfo.install_file())
    local parent = path.directory(archive)
    local srcdir = path.join(parent, "curl-" .. ver)
    local build_dir = path.join(parent, "curl-" .. ver .. "-build")
    local stage_dir = path.join(parent, "curl-" .. ver .. "-stage")

    os.tryrm(srcdir)
    os.tryrm(build_dir)
    os.tryrm(stage_dir)
    system.exec("tar -xf " .. _shq(archive) .. " -C " .. _shq(parent))
    if not os.isdir(srcdir) then
        raise("curl source directory not found: " .. srcdir)
    end
    os.mkdir(build_dir)
    os.mkdir(stage_dir)

    local gcc_dir = assert(_build_dep_dir("gcc"), "missing xim:gcc build dependency")
    local make_dir = assert(_build_dep_dir("make"), "missing xim:make build dependency")
    local openssl_dir = assert(pkginfo.dep_install_dir("xim:openssl"), "missing xim:openssl runtime dependency")
    local zlib_dir = assert(pkginfo.dep_install_dir("xim:zlib"), "missing xim:zlib runtime dependency")

    local openssl_libdir = path.join(openssl_dir, "lib64")
    if not os.isdir(openssl_libdir) then
        openssl_libdir = path.join(openssl_dir, "lib")
    end
    local zlib_libdir = path.join(zlib_dir, "lib")

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

    local cppflags = "-I" .. path.join(openssl_dir, "include") .. " -I" .. path.join(zlib_dir, "include")
    local ldflags = "-L" .. openssl_libdir .. " -L" .. zlib_libdir
        .. " -Wl,-rpath," .. openssl_libdir .. " -Wl,-rpath," .. zlib_libdir
    local pkg_cfg_libdir = path.join(zlib_dir, "lib", "pkgconfig")

    local env_prefix = "env PATH=" .. _shq(build_path)
        .. " PKG_CONFIG_LIBDIR=" .. _shq(pkg_cfg_libdir) .. " "

    local configure_args = table.concat({
        "CC=" .. _shq(cc_wrap),
        "AR=" .. _shq(ar_exe),
        "RANLIB=" .. _shq(ranlib_exe),
        "CPPFLAGS=" .. _shq(cppflags),
        "LDFLAGS=" .. _shq(ldflags),
        "--prefix=/usr",
        "--libdir=/usr/lib",
        "--disable-static",
        "--enable-shared",
        "--with-openssl=" .. _shq(openssl_dir),
        "--with-zlib=" .. _shq(zlib_dir),
        "--without-nghttp2",
        "--without-nghttp3",
        "--without-ngtcp2",
        "--without-quiche",
        "--without-libpsl",
        "--without-libidn2",
        "--without-brotli",
        "--without-zstd",
        "--without-libssh2",
        "--without-libgsasl",
        "--without-gssapi",
        "--without-ares",
        "--disable-ldap",
        "--disable-ldaps",
        "--disable-manual",
        "--disable-docs",
        "--with-ca-bundle=/etc/ssl/certs/ca-certificates.crt",
        "--with-ca-fallback",
        "-q",
    }, " ")

    local cmd = table.concat({
        "cd " .. _shq(build_dir),
        env_prefix .. _shq(path.join(srcdir, "configure")) .. " " .. configure_args,
        env_prefix .. _shq(make_exe) .. " -j4 -C lib libcurl.la",
        env_prefix .. _shq(make_exe) .. " -j4 -C include",
        env_prefix .. _shq(make_exe) .. " libcurl.pc",
        env_prefix .. _shq(make_exe) .. " -C lib install-libLTLIBRARIES DESTDIR=" .. _shq(stage_dir),
        env_prefix .. _shq(make_exe) .. " -C include install DESTDIR=" .. _shq(stage_dir),
        env_prefix .. _shq(make_exe) .. " install-pkgconfigDATA DESTDIR=" .. _shq(stage_dir),
    }, " && ")
    system.exec(cmd)

    os.tryrm(dir)
    os.mv(path.join(stage_dir, "usr"), dir)
    os.tryrm(path.join(dir, "lib", "libcurl.la"))
    os.tryrm(build_dir)
    os.tryrm(stage_dir)

    _strip_foreign_pc_libdirs(path.join(dir, "lib", "pkgconfig", "libcurl.pc"))
    selfcontain.seal(dir)
    sysroot.relocate_pkgconfig(dir, "lib/pkgconfig")
    return os.isfile(path.join(dir, "lib", "libcurl.so.4"))
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
