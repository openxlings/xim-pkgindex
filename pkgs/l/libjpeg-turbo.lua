package = {
    spec = "2",
    homepage = "https://libjpeg-turbo.org",
    name = "libjpeg-turbo",
    description = "High-speed JPEG codec (libjpeg API/ABI compatible, SIMD-accelerated)",
    maintainers = {"libjpeg-turbo contributors"},
    licenses = {"IJG", "BSD-3-Clause", "Zlib"},
    repo = "https://github.com/libjpeg-turbo/libjpeg-turbo",
    docs = "https://libjpeg-turbo.org/Documentation",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"library", "graphics"},
    keywords = {"jpeg", "image", "codec", "lib"},
    programs = {"cjpeg", "djpeg", "jpegtran", "rdjpgcom", "tjbench", "wrjpgcom"},
    xvm_enable = true,
    xpm = {
        linux = {
            -- UPSTREAM'S OWN BINARY, not a rebuild. libjpeg-turbo publishes a
            -- signed `libjpeg-turbo-official_<version>_amd64.deb` on its
            -- release page carrying libjpeg.so.62 and libturbojpeg.so.0 --
            -- the same sonames a rebuild would produce -- plus headers, .pc
            -- and cmake config. Rebuilding it would swap upstream's toolchain
            -- for ours and gain nothing.
            --
            -- What upstream does not ship is the layout: its payload lives
            -- under /opt/libjpeg-turbo with a lib64/. `.agents/tools/graphics/
            -- repack-upstream-deb.sh` moves the tree into
            -- <name>-<version>-linux-x86_64/{bin,include,lib}, drops the
            -- static archives and the JNA jar, and re-derives the sha256 of
            -- every shipped ELF from the .deb to prove nothing was
            -- recompiled.
            --
            -- TWO CONSEQUENCES OF SHIPPING UPSTREAM'S BYTES, both deliberate:
            --
            --   * these ELFs are NOT stripped, unlike every payload this
            --     index builds. Stripping would edit them, and then "identical
            --     to upstream's" stops being true. Byte-identity to a signed
            --     upstream artifact is worth more than ~1 MB.
            --   * they carry upstream's own `RPATH=/opt/libjpeg-turbo/lib64`,
            --     a path from the .deb's layout. It is inert -- the only
            --     DT_NEEDED here is libc -- and xlings' elfpatch replaces
            --     DT_RPATH outright at install time anyway, keyed on the glibc
            --     dep below. Left as upstream wrote it for the same reason.
            deps = {
                "xim:glibc@>=2.38",
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "3.2.0" },
            ["3.2.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libjpeg-turbo/releases/download/3.2.0/libjpeg-turbo-3.2.0-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libjpeg-turbo/releases/download/3.2.0/libjpeg-turbo-3.2.0-linux-x86_64.tar.gz",
                },
                sha256 = "5588469c53ddc2eaafdbf6e2c889ebbd4fa22111901103162e754a936718eb83",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    sysroot.adopt_payload()

    selfcontain.seal(pkginfo.install_dir())
    sysroot.relocate_pkgconfig(pkginfo.install_dir(), "lib/pkgconfig")
    return true
end

function config()
    local idir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)
    -- All six the payload ships. Registering a subset leaves shipped
    -- binaries invisible to xvm, which is how a package ends up with files
    -- nobody can run and nobody can find.
    for _, tool in ipairs({"cjpeg", "djpeg", "jpegtran",
                           "rdjpgcom", "tjbench", "wrjpgcom"}) do
        xvm.add(tool, { bindir = path.join(idir, "bin") })
    end


    sysroot.declare_libs(idir, "lib", binding, pkginfo.version())

    if not sysroot.declare_headers_tree(idir, "include", "usr/include", binding) then
        sysroot.install_headers_tree(
            path.join(idir, "include"),
            path.join(system.subos_sysrootdir(), "usr", "include"))
    end

    sysroot.declare_pkgconfig(idir, "lib/pkgconfig", binding)
    return true
end

function uninstall()
    for _, tool in ipairs({"cjpeg", "djpeg", "jpegtran",
                           "rdjpgcom", "tjbench", "wrjpgcom"}) do
        xvm.remove(tool)
    end
    xvm.remove(package.name)
    return true
end
