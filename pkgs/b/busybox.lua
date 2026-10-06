function __busybox_url(version)
    return format("https://busybox.net/downloads/binaries/%s-x86_64-linux-musl/busybox", version)
end

package = {
    spec = "1",

    name = "busybox",
    description = "The Swiss Army Knife of Embedded Linux — single static binary providing 400+ POSIX utilities",
    homepage = "https://busybox.net",
    authors = {"Erik Andersen", "Rob Landley", "Denys Vlasenko"},
    licenses = {"GPL-2.0-only"},
    repo = "https://git.busybox.net/busybox",
    docs = "https://busybox.net/about.html",

    -- xim pkg info
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"system", "shell", "cli", "utilities"},
    keywords = {"busybox", "shell", "ash", "coreutils", "embedded", "static"},

    -- Upstream ships a single static-musl binary that bundles 400+ applets
    -- (sh, ls, cat, awk, grep, …). Each applet is invoked by argv[0]
    -- dispatch — `busybox ls /tmp` works, and so does a `ls` symlink that
    -- points at busybox. We declare only `busybox`: a home's PATH does not
    -- gain `ls`. The payload carries a link per applet (install()), which
    -- is what a root's /usr/bin is made from.
    programs = {"busybox"},
    xvm_enable = true,

    -- The /downloads/binaries/<ver>-x86_64-linux-musl/busybox URL is a
    -- bare ELF — statically linked against musl, stripped, no glibc/musl
    -- runtime needed at the user side. xlings's is_archive_ predicate
    -- (filename suffix check) will treat it as a non-archive payload, so
    -- it lands as-is in the runtime download dir; install() moves it.
    --
    -- 1.35.0 is the most recent x86_64 prebuilt published upstream
    -- (Jan 2022). Newer point releases (1.36, 1.37) are source-only on
    -- busybox.net — no static prebuilt directory yet — so we stay on
    -- 1.35.0 until upstream publishes 1.36+ binaries.
    xpm = {
        linux = {
            ["latest"] = { ref = "1.35.0" },
            ["1.35.0"] = {
                url = __busybox_url("1.35.0"),
                sha256 = "6e123e7f3202a8c1e9b1f94d8941580a25135382b99e8d3e34fb858bba311348",
                -- 1: the payload's bin/ carries a relative link per applet
                -- (see install()).
                revision = 1,
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

function install()
    -- The download is a bare ELF (no archive). xlings parks it at
    -- pkginfo.install_file() inside the runtime download dir; we move
    -- it under install_dir/bin/busybox and chmod +x. (xlings does set
    -- 0644 on plain downloads; the binary needs to be executable.)
    os.tryrm(pkginfo.install_dir())
    local bindir = path.join(pkginfo.install_dir(), "bin")
    os.mkdir(bindir)
    local target = path.join(bindir, "busybox")
    os.mv(pkginfo.install_file(), target)
    os.execute('chmod +x "' .. target .. '"')
    -- One relative link per applet beside the binary (bin/sh -> busybox).
    -- Only `busybox` is registered, so a home's PATH gains nothing; a ROOT
    -- made from this payload (xlings subos new --rootfs) puts a package's
    -- bin/ into its /usr/bin, and gets sh, ls, init, mount... the way a
    -- distribution would. Done by busybox's own shell: no host shell needed.
    os.execute(string.format(
        '"%s" sh -c \'cd "$1" && for a in $(./busybox --list); do [ "$a" = busybox ] || ln -sf busybox "$a"; done\' _ "%s"',
        target, bindir))
    return os.isfile(path.join(bindir, "sh"))
end

function config()
    xvm.add("busybox", {
        bindir = path.join(pkginfo.install_dir(), "bin"),
    })
    log.info("busybox installed. Use `busybox <applet>` (e.g. `busybox ls -la`)")
    log.info("or `busybox --install -s <dir>` to populate per-applet symlinks.")
    return true
end

function uninstall()
    xvm.remove("busybox")
    return true
end
