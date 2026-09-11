package = {
    spec = "1",

    name = "e2fsprogs",
    description = "ext2/ext3/ext4 filesystem utilities (mke2fs, e2fsck, tune2fs, resize2fs, debugfs)",

    homepage = "https://e2fsprogs.sourceforge.net/",
    authors = {"Theodore Ts'o"},
    licenses = {"GPL-2.0-only", "LGPL-2.0-only", "BSD-3-Clause", "MIT"},
    repo = "https://git.kernel.org/pub/scm/fs/ext2/e2fsprogs.git",
    docs = "https://www.man7.org/linux/man-pages/man8/mke2fs.8.html",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"system", "filesystem", "utilities"},
    keywords = {"ext2", "ext3", "ext4", "fsck", "mke2fs", "resize2fs", "tune2fs"},

    -- KNOWN DEFECT IN THIS PAYLOAD: `debugfs` IS NON-FUNCTIONAL.
    --
    -- Measured 2026-09-11 against a control ext4 image created by this same
    -- payload's `mke2fs`, and against an Android system.img:
    --
    --   command                          1.47.3 (this)   1.47.0 (host)
    --   debugfs -V                       ok              ok
    --   debugfs -R "features"            SIGFPE (136)    ok
    --   debugfs -R "ls /"                SIGFPE (136)    ok
    --   debugfs -R "dump <p> <out>"      SIGFPE (136)    ok
    --   dumpe2fs -h                      ok              ok
    --   e2fsck -fn                       ok              ok
    --   tune2fs -l                       ok              ok
    --
    -- Exactly one program of the set is affected, it fails on EVERY command
    -- that opens a filesystem, and it fails with an empty environment too, so
    -- this is the build rather than the invocation. `debugfs` is also the only
    -- program here that links libss and readline, which is where a static
    -- build of it is known to be fragile.
    --
    -- IT WENT UNNOTICED BECAUSE THE NAME FALLS THROUGH TO THE HOST. Run from a
    -- directory with no xlings project config, the `debugfs` shim resolved to
    -- /usr/sbin/debugfs and worked -- so a measurement taken that way records
    -- the HOST's behaviour under an ecosystem name. pkgs/a/android-system-
    -- image.lua's arm64-v8a key is the consumer this blocks, and it now
    -- resolves debugfs through `pkginfo.dep_install_dir` and probes it
    -- FUNCTIONALLY, because `-V` succeeds on the broken binary.
    --
    -- `debugfs` stays in the `programs` list on purpose. Dropping it would
    -- make the bare name resolve to the host's copy, which is the silent
    -- host-ecosystem fallthrough this index exists to avoid; a shim that fails
    -- loudly is the lesser problem. What closes this is a repin to a build
    -- whose debugfs works, not a change here.
    --
    -- The xlings-res tarball ships statically-linked ELF binaries
    -- (built by github.com/ronpscg/e2fsprogs-static-builds): no glibc /
    -- musl runtime dep, no INTERP/RPATH to patch. Programs we expose
    -- via xvm shims:
    --   sbin/      core fsck/mkfs/tune family
    --   usr/sbin/  ext4 helpers (e4crypt, e4defrag, filefrag)
    -- `mklost+found` is omitted from the program list because the `+`
    -- in its name isn't xvm-shim friendly; it remains accessible via
    -- the install dir if needed.
    programs = {
        "badblocks", "debugfs", "dumpe2fs", "e2fsck", "e2image", "e2label",
        "e2mmpstatus", "e2undo", "fsck", "fsck.ext2", "fsck.ext3", "fsck.ext4",
        "logsave", "mke2fs", "mkfs.ext2", "mkfs.ext3", "mkfs.ext4",
        "resize2fs", "tune2fs",
        "e4crypt", "e4defrag", "filefrag",
    },
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "1.47.3" },
            ["1.47.3"] = "XLINGS_RES",
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- Programs we ship and shim. Ordered to match the `programs` field above.
local sbin_programs = {
    "badblocks", "debugfs", "dumpe2fs", "e2fsck", "e2image", "e2label",
    "e2mmpstatus", "e2undo", "fsck", "fsck.ext2", "fsck.ext3", "fsck.ext4",
    "logsave", "mke2fs", "mkfs.ext2", "mkfs.ext3", "mkfs.ext4",
    "resize2fs", "tune2fs",
    "e4crypt", "e4defrag", "filefrag",
}

function install()
    -- XLINGS_RES tarball extracts to e2fsprogs-<ver>-linux-x86_64/ with
    -- layout: sbin/ usr/sbin/ etc/. Move the whole tree to install_dir,
    -- then collapse usr/sbin into sbin so a single bindir covers every
    -- shimmed program.
    local srcdir = pkginfo.install_file():replace(".tar.gz", "")
    os.tryrm(pkginfo.install_dir())
    os.mv(srcdir, pkginfo.install_dir())

    local sbin = path.join(pkginfo.install_dir(), "sbin")
    local usr_sbin = path.join(pkginfo.install_dir(), "usr", "sbin")
    if os.isdir(usr_sbin) then
        os.execute(string.format('mv "%s"/* "%s"/', usr_sbin, sbin))
        os.tryrm(path.join(pkginfo.install_dir(), "usr"))
    end
    return true
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "sbin")
    local root = "e2fsprogs@" .. pkginfo.version()
    -- First program owns the version slot; the rest bind their lifecycle
    -- to it via `binding`, so removing e2fsprogs cleans every shim.
    xvm.add(sbin_programs[1], { bindir = bindir })
    for i = 2, #sbin_programs do
        xvm.add(sbin_programs[i], { bindir = bindir, binding = root })
    end

    -- Group placeholder: `e2fsprogs` is an umbrella package whose programs
    -- are e2fsck/mke2fs/etc. The package name itself never appears in
    -- `sbin_programs`, so without this empty placeholder
    -- `xvm info e2fsprogs` returns nothing on install detection.
    -- `group` is the only kind that both avoids a bogus shim under the
    -- package name and lets `xlings remove` find the package; removal of a
    -- group root needs xlings >= 2026.7.x, which is why CI pins a current
    -- client (older ones refuse the remove and leak the shims).
    xvm.add("e2fsprogs", { type = "group" })

    -- mke2fs reads mke2fs.conf at runtime; the static binary has no
    -- compiled-in path that points inside install_dir, so help users
    -- who want non-default fs profiles by exporting MKE2FS_CONFIG.
    log.info("e2fsprogs config files at %s/etc/", pkginfo.install_dir())
    log.info("If mke2fs warns about a missing mke2fs.conf, run:")
    log.info("  export MKE2FS_CONFIG=%s/etc/mke2fs.conf", pkginfo.install_dir())
    return true
end

function uninstall()
    for _, p in ipairs(sbin_programs) do
        xvm.remove(p)
    end
    xvm.remove("e2fsprogs")
    return true
end
