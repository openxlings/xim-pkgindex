package = {
    spec = "2",
    name = "ibcs-us",
    description = "ibcs-us: runs a program of the System V i386 kernel interface (iBCS2: UnixWare 7, Solaris x86, OpenServer 5) on Linux, in user space; built from the released source with corrections",

    maintainers = {"https://github.com/mcpp-community/ibcs-us/graphs/contributors"},
    licenses = {"GPL-2.0-only"},
    repo = "https://github.com/mcpp-community/ibcs-us",
    docs = "https://github.com/mcpp-community/ibcs-us#readme",
    homepage = "https://ibcs-us.sourceforge.io/",
    type = "package",
    status = "dev",
    categories = {"runner", "emulator", "testing"},
    keywords = {"ibcs", "system v", "svr4", "unixware", "solaris", "openserver", "emulator", "runner"},
    -- One program, a static ELF32 i386 executable: it runs on an x86_64 Linux
    -- kernel that runs 32-bit programs, and on no other host. The program it
    -- runs executes on the processor itself.
    archs = {"x86_64"},
    programs = {"ibcs-us"},
    xvm_enable = true,

    -- BUILT RATHER THAN REPACKAGED. The upstream's released binary (4.3) does
    -- not load an executable without debugging information, list a directory,
    -- shorten a file or change a file's mode; `mcpp-community/ibcs-us` builds
    -- the released source with seven corrections and runs a probe of each
    -- before it publishes. The version is `<upstream>-<n>`: the n-th state of
    -- its patches. From 4.3-2 a program of the interface that execs another is
    -- started under the emulation again (upstream hands exec to Linux, which
    -- starts the file outside it, where its first call through the gate
    -- faults); any other file is still Linux's.
    --
    -- HOW IT IS STARTED: `unshare -Ur ibcs-us <program>`. ibcs-us asks for the
    -- root identity or CAP_SYS_RAWIO before anything else, and the root of a
    -- user namespace satisfies it; the host must let an unprivileged user make
    -- one. No dependency is declared: the program is static and reads nothing
    -- of the package at run time.
    xpm = {
        linux = {
            ["latest"] = { ref = "4.3-2" },
            ["4.3-2"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/ibcs-us/releases/download/4.3-2/ibcs-us-4.3-2-linux-x64.tar.gz",
                    CN = "https://gitcode.com/xlings-res/ibcs-us/releases/download/4.3-2/ibcs-us-4.3-2-linux-x64.tar.gz",
                },
                sha256 = {
                    ["x86_64"] = "23d3ea7ed809a207d17e1c465e74c8f09c08b74a6b029beb0c0ea38ead72aab3",
                },
            },
            ["4.3-1"] = {
                url = {
                    GLOBAL = "https://github.com/mcpp-community/ibcs-us/releases/download/4.3-1/ibcs-us-4.3-1-linux-x64.tar.gz",
                    CN = "https://gitcode.com/xlings-res/ibcs-us/releases/download/4.3-1/ibcs-us-4.3-1-linux-x64.tar.gz",
                },
                sha256 = {
                    ["x86_64"] = "4dd3d690b4f397e8a3f11162d9de0db7e03c117b1a4410241e7d01adabb82409",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    -- The archive's one top-level directory is the package; it is named
    -- after the archive, which xim unpacks beside it.
    local top = pkginfo.install_file()
    for _, ext in ipairs({ ".tar.gz" }) do
        if top:sub(-#ext) == ext then top = top:sub(1, #top - #ext) break end
    end
    if not os.isdir(top) then return false end
    os.tryrm(pkginfo.install_dir())
    os.mv(top, pkginfo.install_dir())
    return os.isfile(path.join(pkginfo.install_dir(), "bin", "ibcs-us"))
end

function config()
    -- The package's name is its program (Spec D1).
    xvm.add("ibcs-us", { bindir = path.join(pkginfo.install_dir(), "bin") })
    return true
end

function uninstall()
    xvm.remove("ibcs-us")
    return true
end
