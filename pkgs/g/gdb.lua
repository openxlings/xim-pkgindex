-- gdb -- the GNU debugger and its remote server, gdbserver, built static by
-- this index's factory (tools/res/build.sh gdb: musl; GMP, MPFR, expat, zlib,
-- zstd, xz, ncursesw) with the terminfo entries of the terminals it meets in
-- share/terminfo, which its shim names in TERMINFO_DIRS (an environment may
-- have no terminfo of its own; the TUI needs one). Its data directory
-- (share/gdb: the system call tables) is found beside bin/gdb wherever the
-- payload is. No Python, Guile or debuginfod. A static gdb cannot load a
-- program's libthread_db: it follows a program's threads through the kernel.
-- xlings-res/gdb on GitHub and GitCode (tools/res/publish.py).
package = {
    spec = "3",

    name = "gdb",
    description = "GNU gdb and gdbserver: the GNU debugger, static, with its TUI and remote server",
    homepage = "https://www.sourceware.org/gdb/",
    repo = "https://sourceware.org/git/binutils-gdb.git",
    docs = "https://sourceware.org/gdb/documentation/",
    licenses = {"GPL-3.0-or-later"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"debugger", "gnu", "cli"},
    keywords = {"gdb", "gdbserver", "debugger", "gnu", "tui", "ptrace"},

    programs = {"gdb", "gdbserver"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/gdb/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/xlings-res/gdb/releases/download/${version}/gdb-${version}-linux-x86_64.tar.gz",
                            aarch64 = "https://github.com/xlings-res/gdb/releases/download/${version}/gdb-${version}-linux-aarch64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            x86_64 = "https://gitcode.com/xlings-res/gdb/releases/download/${version}/gdb-${version}-linux-x86_64.tar.gz",
                            aarch64 = "https://gitcode.com/xlings-res/gdb/releases/download/${version}/gdb-${version}-linux-aarch64.tar.gz",
                        },
                    },
                    required = true,
                },
            },
            verify = "sha256-sidecar",
        },
    },

    xpm = {
        linux = {
            strip = 1,
            ["latest"] = { ref = "18.1" },
            ["18.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "611260765392dd1a7e4b9667cf88b3310c72880e25c9fd50feadef4b30b00586",
                    aarch64 = "d319a9fb7153b7e641fa7cd4e588e9336f6672b4080f962d3c563690a30058da",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.fs")
import("xim.libxpkg.path")

function install()
    local dir = pkginfo.install_dir()
    return fs.is_file(path.join(dir, "bin", "gdb")) and fs.is_file(path.join(dir, "bin", "gdbserver"))
end

function config()
    local dir = pkginfo.install_dir()
    local bindir = path.join(dir, "bin")
    xvm.add("gdb", {
        bindir = bindir,
        envs = { TERMINFO_DIRS = path.join(dir, "share", "terminfo") .. ":/usr/share/terminfo:/etc/terminfo" },
    })
    -- gdbserver comes with gdb: its lifecycle is gdb@<version>'s.
    xvm.add("gdbserver", { bindir = bindir, binding = "gdb@" .. pkginfo.version() })
    return true
end

function uninstall()
    xvm.remove("gdbserver")
    xvm.remove("gdb")
    return true
end
