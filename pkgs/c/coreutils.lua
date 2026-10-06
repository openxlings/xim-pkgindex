package = {
    spec = "1",

    homepage = "https://www.gnu.org/software/coreutils/",
    name = "coreutils",
    description = "GNU core utilities: the basic file, shell and text manipulation tools",

    authors = {"Free Software Foundation"},
    licenses = {"GPL-3.0-or-later"},
    repo = "https://git.savannah.gnu.org/cgit/coreutils.git",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"system", "cli", "utilities"},
    keywords = {"coreutils", "gnu", "ls", "cp", "mv", "cat"},

    -- Built from upstream 9.5 against xim:glibc 2.44.3 with xim:gcc 16.1.0;
    -- no NLS, SELinux, ACL, xattr, OpenSSL or GMP, so libc.so.6 is its only
    -- NEEDED. Every program is registered: installing coreutils means getting
    -- these tools, and a SubOS root that has busybox too (luban-core) takes
    -- the registered GNU ones for /usr/bin.
    xpm = {
        linux = {
            deps = { "xim:glibc" },
            ["latest"] = { ref = "9.5" },
            ["9.5"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "798ca99285e0853d8b1c6e4f68dc465841ad4e5bda6ff3705e0a4b097493ae37" },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

local programs = { "b2sum", "base32", "base64", "basename", "basenc", "cat", "chcon", "chgrp", "chmod", "chown", "chroot", "cksum", "comm", "cp", "csplit", "cut", "date", "dd", "df", "dir", "dircolors", "dirname", "du", "echo", "env", "expand", "expr", "factor", "false", "fmt", "fold", "groups", "head", "hostid", "id", "install", "join", "link", "ln", "logname", "ls", "md5sum", "mkdir", "mkfifo", "mknod", "mktemp", "mv", "nice", "nl", "nohup", "nproc", "numfmt", "od", "paste", "pathchk", "pinky", "pr", "printenv", "printf", "ptx", "pwd", "readlink", "realpath", "rm", "rmdir", "runcon", "seq", "sha1sum", "sha224sum", "sha256sum", "sha384sum", "sha512sum", "shred", "shuf", "sleep", "sort", "split", "stat", "stdbuf", "stty", "sum", "sync", "tac", "tail", "tee", "test", "timeout", "touch", "tr", "true", "truncate", "tsort", "tty", "uname", "unexpand", "uniq", "unlink", "users", "vdir", "wc", "who", "whoami", "yes" }

function install()
    local dir = pkginfo.install_dir()
    local staged = path.join(dir, "bin", "ls")
    if not os.isfile(staged) then
        local payload = "coreutils-" .. pkginfo.version()
        if os.isdir(payload) then
            os.tryrm(dir)
            os.mv(payload, dir)
        end
    end
    return os.isfile(staged)
end

function config()
    -- The root every program binds to, as binutils does.
    xvm.add("coreutils")
    local bindir = path.join(pkginfo.install_dir(), "bin")
    local binding = package.name .. "@" .. pkginfo.version()
    for _, prog in ipairs(programs) do
        if os.isfile(path.join(bindir, prog)) then
            xvm.add(prog, { bindir = bindir, binding = binding })
        end
    end
    return true
end

function uninstall()
    for _, prog in ipairs(programs) do xvm.remove(prog) end
    xvm.remove("coreutils")
    return true
end
