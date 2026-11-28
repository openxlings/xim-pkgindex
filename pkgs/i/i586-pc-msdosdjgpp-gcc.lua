-- i586-pc-msdosdjgpp-gcc: DJGPP, the GNU toolchain for 32-bit DOS programs (GCC 12.2.0, binutils,
-- the DJGPP 2.05 C library), as github.com/andrewwutw/build-djgpp v3.4 builds it for each system,
-- repacked without hard links (tools/res/build.sh i586-pc-msdosdjgpp-gcc).
-- The name is mcpp's for a cross GCC payload, `<target>-gcc`: a row that states this target
-- (`i586-pc-msdosdjgpp`) takes it as its toolchain's payload, and its frontends are
-- `bin/i586-pc-msdosdjgpp-gcc` and `-g++`. A program it builds is a go32 DOS executable (MZ with
-- COFF) that needs a DPMI host to run, which the package dosbox-staging carries with DOSBox.
-- GLOBAL is github.com/xlings-res/i586-pc-msdosdjgpp-gcc; CN is the same bytes at gitcode.com/xlings-res.
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
                    GLOBAL = "https://github.com/xlings-res/i586-pc-msdosdjgpp-gcc/releases/download/12.2.0/i586-pc-msdosdjgpp-gcc-12.2.0-linux-x86_64.tar.gz",
                    CN = "https://gitcode.com/xlings-res/i586-pc-msdosdjgpp-gcc/releases/download/12.2.0/i586-pc-msdosdjgpp-gcc-12.2.0-linux-x86_64.tar.gz",
                },
                sha256 = "897ef56d2d2acc42f7196f1af60ac5eaa05679cb1e3da2b09017b276582ae6e6",
            },
        },
        macosx = {
            ["latest"] = { ref = "12.2.0" },
            ["12.2.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/i586-pc-msdosdjgpp-gcc/releases/download/12.2.0/i586-pc-msdosdjgpp-gcc-12.2.0-macosx-x86_64.tar.gz",
                    CN = "https://gitcode.com/xlings-res/i586-pc-msdosdjgpp-gcc/releases/download/12.2.0/i586-pc-msdosdjgpp-gcc-12.2.0-macosx-x86_64.tar.gz",
                },
                sha256 = "3cf5c02ce7efa31fa144c79f3e40a83b61c002530ce76b5a48f4d7e575c7d33e",
            },
        },
        windows = {
            ["latest"] = { ref = "12.2.0" },
            ["12.2.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/i586-pc-msdosdjgpp-gcc/releases/download/12.2.0/i586-pc-msdosdjgpp-gcc-12.2.0-windows-x86_64.tar.gz",
                    CN = "https://gitcode.com/xlings-res/i586-pc-msdosdjgpp-gcc/releases/download/12.2.0/i586-pc-msdosdjgpp-gcc-12.2.0-windows-x86_64.tar.gz",
                },
                sha256 = "fd13d2ac306a326b731a6079e3465fbe0cbfce0dc13e04cd23ee40058b1b8f1a",
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
    local release = package.name .. "@" .. pkginfo.version()
    local exe = os.host() == "windows" and ".exe" or ""
    -- The package's name is its C compiler (Spec D1); the other programs bind to it.
    xvm.add(package.name, { bindir = bindir, alias = package.name .. exe })
    for _, prog in ipairs(package.programs) do
        if prog ~= package.name then
            xvm.add(prog, { bindir = bindir, alias = prog .. exe, binding = release })
        end
    end
    return true
end

function uninstall()
    for _, prog in ipairs(package.programs) do
        xvm.remove(prog)
    end
    return true
end
