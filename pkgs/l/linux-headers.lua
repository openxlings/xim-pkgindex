package = {
    spec = "1",
    -- base info
    name = "linux-headers",
    description = "Linux Kernel Headers (prebuilt)",

    licenses = {"GPL"},
    repo = "https://github.com/torvalds/linux",

    -- xim pkg info
    type = "package",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "5.11.1" },
            -- Self-contained PREBUILT kernel headers, mirror-aware.
            --
            -- Previously this was a thin delegator that depended on
            -- `scode:linux-headers@<ver>`, whose payload came from a single
            -- gitcode-only URL (no GLOBAL mirror, sha256=nil). On GLOBAL
            -- networks / CI that fetch raced the toolchain sysroot population
            -- (the `std` module precompile needs `linux/limits.h`), and it
            -- also required the scode sub-index to be synced first. Both are
            -- gone: the prebuilt tarball is referenced directly with a
            -- GLOBAL/CN mirror map + sha256; install = extract, config = copy
            -- into the sysroot. No `make`, no sub-index dependency.
            -- (openxlings/xlings#366)
            ["5.11.1"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/scode-res/releases/download/linux-headers/linux-headers-5.11.1.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/scode-res/releases/download/linux-headers/linux-headers-5.11.1.tar.gz",
                },
                sha256 = "abb59208aee1bc585bcc9fba3fd7c481c570cdb1f29f56369229b1601917d497",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")
import("xim.pkgindex.sysroot")

function install()
    -- The prebuilt tarball extracts to `linux-headers-<ver>/include/...`.
    -- Move that tree into our own install_dir so the "installed?" probe
    -- (which checks install_dir for content) reports installed and dependent
    -- packages (xim:gcc / xim:glibc / fromsource:gcc, ...) don't re-trigger
    -- this install + config on every fresh dependency resolution.
    local srcdir = pkginfo.install_file()
        :replace(".tar.gz", "")
        :replace(".tar.xz", "")
        :replace(".zip", "")

    os.tryrm(pkginfo.install_dir())
    os.trymv(srcdir, pkginfo.install_dir())

    return true
end

function config()
    local sysroot_usrdir = path.join(system.subos_sysrootdir(), "usr")
    if not os.isdir(sysroot_usrdir) then os.mkdir(sysroot_usrdir) end

    -- Idempotent: skip the recursive header copy if this version is already
    -- in the subos sysroot. The stamp lives next to the copied tree so that
    -- switching subos / wiping the sysroot correctly invalidates it.
    local stamp = path.join(sysroot_usrdir, ".linux-headers-" .. pkginfo.version() .. ".stamp")
    if os.isfile(stamp) then
        log.debug("Linux headers already in subos rootfs (stamp present), skipping copy.")
    else
        log.info("Installing linux headers into subos sysroot ...")
        sysroot.install_headers(
            path.join(pkginfo.install_dir(), "include"),
            path.join(sysroot_usrdir, "include")
        )
        io.writefile(stamp, pkginfo.version())
    end

    xvm.add("linux-headers")

    return true
end

function uninstall()
    xvm.remove("linux-headers")
    return true
end
