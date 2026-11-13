-- i586-pc-msdosdjgpp-gcc: DJGPP, the GNU toolchain for 32-bit DOS programs (GCC 12.2.0, binutils,
-- the DJGPP 2.05 C library), as github.com/andrewwutw/build-djgpp v3.4 builds it for each system.
-- The name is mcpp's for a cross GCC payload, `<target>-gcc`: a row that states this target
-- (`i586-pc-msdosdjgpp`) takes it as its toolchain's payload, and its frontends are
-- `bin/i586-pc-msdosdjgpp-gcc` and `-g++`. A program it builds is a go32 DOS executable (MZ with
-- COFF) that needs a DPMI host to run, which the package dosbox-staging carries with DOSBox.
-- GLOBAL is the upstream release; CN is the same bytes at gitcode.com/xlings-res.
package = {
    spec = "2",
    homepage = "https://www.delorie.com/djgpp/",
    name = "i586-pc-msdosdjgpp-gcc",
    description = "DJGPP: GCC 12.2.0, binutils and the DJGPP 2.05 C library, a cross toolchain for 32-bit DOS programs",
    authors = {"GNU", "DJ Delorie"},
    maintainers = {"https://github.com/andrewwutw/build-djgpp"},
    licenses = {"GPL-3.0-or-later", "LGPL-2.1-or-later"},
    repo = "https://github.com/andrewwutw/build-djgpp",
    docs = "https://www.delorie.com/djgpp/doc/",
    type = "package",
    archs = {"x86_64"},
    status = "dev",
    categories = {"compiler", "gnu", "cross", "dos"},
    keywords = {"djgpp", "dos", "gcc", "cross", "i586", "msdos"},
    programs = {
        "i586-pc-msdosdjgpp-gcc", "i586-pc-msdosdjgpp-g++", "i586-pc-msdosdjgpp-c++",
        "i586-pc-msdosdjgpp-cpp", "i586-pc-msdosdjgpp-ar", "i586-pc-msdosdjgpp-as",
        "i586-pc-msdosdjgpp-ld", "i586-pc-msdosdjgpp-nm", "i586-pc-msdosdjgpp-objcopy",
        "i586-pc-msdosdjgpp-objdump", "i586-pc-msdosdjgpp-ranlib", "i586-pc-msdosdjgpp-strip",
        "i586-pc-msdosdjgpp-size", "i586-pc-msdosdjgpp-strings",
    },
    xvm_enable = true,
    xpm = {
        linux = {
            ["latest"] = { ref = "12.2.0" },
            ["12.2.0"] = {
                url = {
                    GLOBAL = "https://github.com/andrewwutw/build-djgpp/releases/download/v3.4/djgpp-linux64-gcc1220.tar.bz2",
                    CN = "https://gitcode.com/xlings-res/i586-pc-msdosdjgpp-gcc/releases/download/12.2.0/djgpp-linux64-gcc1220.tar.bz2",
                },
                sha256 = "8464f17017d6ab1b2bb2df4ed82357b5bf692e6e2b7fee37e315638f3d505f00",
            },
        },
        macosx = {
            ["latest"] = { ref = "12.2.0" },
            ["12.2.0"] = {
                url = {
                    GLOBAL = "https://github.com/andrewwutw/build-djgpp/releases/download/v3.4/djgpp-osx-gcc1220.tar.bz2",
                    CN = "https://gitcode.com/xlings-res/i586-pc-msdosdjgpp-gcc/releases/download/12.2.0/djgpp-osx-gcc1220.tar.bz2",
                },
                sha256 = "cf605786efe14166d32aede89c37e41bf1272178ae73a624e7e84761cca38549",
            },
        },
        windows = {
            ["latest"] = { ref = "12.2.0" },
            ["12.2.0"] = {
                url = {
                    GLOBAL = "https://github.com/andrewwutw/build-djgpp/releases/download/v3.4/djgpp-mingw-gcc1220-standalone.zip",
                    CN = "https://gitcode.com/xlings-res/i586-pc-msdosdjgpp-gcc/releases/download/12.2.0/djgpp-mingw-gcc1220-standalone.zip",
                },
                sha256 = "6f88b531d216f4d92668c960b5cde9a829b5611e06d2c3e431041e33f01c1a52",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    -- The archive's one directory, `djgpp`, is the toolchain.
    local top = path.join(path.directory(pkginfo.install_file()), "djgpp")
    if not os.isdir(top) then return false end
    os.tryrm(pkginfo.install_dir())
    os.mv(top, pkginfo.install_dir())
    return os.isdir(path.join(pkginfo.install_dir(), "bin"))
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    -- The package name anchors the release (Spec D1); the programs bind to it.
    xvm.add(package.name)
    for _, prog in ipairs(package.programs) do
        local opts = { bindir = bindir, binding = package.name .. "@" .. pkginfo.version() }
        if os.host() == "windows" then opts.alias = prog .. ".exe" end
        xvm.add(prog, opts)
    end
    return true
end

function uninstall()
    for _, prog in ipairs(package.programs) do
        xvm.remove(prog)
    end
    xvm.remove(package.name)
    return true
end
