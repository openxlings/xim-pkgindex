package = {
    spec = "1",
    -- base info
    name = "linux-headers",
    description = "Linux Kernel Headers (prebuilt)",

    licenses = {"GPL"},
    repo = "https://github.com/torvalds/linux",

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "aarch64", "riscv64", "loongarch64", "i686"},
    status = "stable", -- dev, stable, deprecated

    -- xvm: xlings version management
    xvm_enable = true,



    xpm = {
        linux = {
            -- The newest release of the newest longterm series.
            ["latest"] = { ref = "6.18.64" },
            -- ONE ARCHIVE FOR EVERY ARCHITECTURE (tools/res/build.sh
            -- linux-headers). The headers are the target's data, not a
            -- program of the host, and of `make headers_install`'s output only
            -- asm/ differs between architectures: include/ holds the rest and
            -- arch/<arch>/include/asm/ each architecture's asm/. install()
            -- links include/asm to the host's, so a reader of include/ sees
            -- what the per-architecture archives held; a cross build reads
            -- arch/<target arch>/include first.
            ["7.3.5"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/linux-headers/releases/download/7.3.5/linux-headers-7.3.5.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/linux-headers/releases/download/7.3.5/linux-headers-7.3.5.tar.gz",
                },
                sha256 = "b9ed727b50aa92cab72f99474fcd64f93e0470341163a93806caf38d5cc2009e",
            },
            -- Revision 1: the same headers in the layout above, as the
            -- corrective asset `6.18.64-r1` (the revision-0 archives of each
            -- architecture stay published). Each host's entry names the one
            -- archive. `floor` stays 0: an installed revision-0 payload holds
            -- the host's headers and remains usable.
            ["6.18.64"] = {
                revision = 1,
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/linux-headers/releases/download/6.18.64-r1/linux-headers-6.18.64-r1.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/linux-headers/releases/download/6.18.64-r1/linux-headers-6.18.64-r1.tar.gz",
                    },
                    sha256 = "@SHA_R1@",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/linux-headers/releases/download/6.18.64-r1/linux-headers-6.18.64-r1.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/linux-headers/releases/download/6.18.64-r1/linux-headers-6.18.64-r1.tar.gz",
                    },
                    sha256 = "@SHA_R1@",
                },
            },
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
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/scode-res/releases/download/linux-headers/linux-headers-5.11.1.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/scode-res/releases/download/linux-headers/linux-headers-5.11.1.tar.gz",
                    },
                    sha256 = "abb59208aee1bc585bcc9fba3fd7c481c570cdb1f29f56369229b1601917d497",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/linux-headers/releases/download/5.11.1/linux-headers-5.11.1-linux-aarch64.tar.gz",
                        CN = "https://gitcode.com/xlings-res/linux-headers/releases/download/5.11.1/linux-headers-5.11.1-linux-aarch64.tar.gz",
                    },
                    sha256 = "ffb294cc183e9ddb87af3411364ba09c9724390494c2f271a81e98a3d6ccfbd7",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.shell")

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

    -- The layout with arch/: include/ gains the host architecture's own
    -- files -- asm/ as one link, and each header only some architectures
    -- install -- so it reads as the per-architecture archives did. The host
    -- is read through `uname -m`, as os.arch() is unbound in the hook runtime
    -- (pkgs/q/qt.lua).
    local root = pkginfo.install_dir()
    if os.isdir(path.join(root, "arch")) then
        local f = io.popen("uname -m")
        local arch = f and (f:read("l") or "") or ""
        if f then f:close() end
        if arch == "arm64" then arch = "aarch64" end
        local own = path.join(root, "arch", arch, "include")
        if not os.isdir(path.join(own, "asm")) then
            log.error("linux-headers %s carries no headers of %s", pkginfo.version(), arch)
            return false
        end
        shell.exec({ "ln", "-sfn", "../arch/" .. arch .. "/include/asm", path.join(root, "include", "asm") })
        local list = io.popen("cd " .. shell.quote(own) .. " && find . -type f ! -path './asm/*'")
        for line in list:lines() do
            local rel = line:gsub("^%./", "")
            local up = string.rep("../", select(2, rel:gsub("/", "")) + 1)
            local dst = path.join(root, "include", rel)
            if not os.isdir(path.directory(dst)) then os.mkdir(path.directory(dst)) end
            shell.exec({ "ln", "-sfn", up .. "arch/" .. arch .. "/include/" .. rel, dst })
        end
        list:close()
    end

    return true
end

function config()
    -- Declared where the client supports it. No stamp on that path: a
    -- declaration is idempotent by construction (materialization skips an
    -- entry that already points at the same payload file), so the marker
    -- that existed purely to avoid repeating the copy has nothing left to
    -- do -- and unlike the stamp, the declaration also survives a sysroot
    -- wipe correctly, because it is state xlings owns rather than a file
    -- in the tree being wiped.
    -- `scsi` per FILE, and glibc does the same in the same release: the two
    -- packages ship disjoint halves of one directory (six files here, three
    -- there) and a directory-granularity declaration is a single link, so
    -- whoever installed last took the whole name. Measured before this
    -- changed: this package held the link and glibc's `<scsi/sg.h>` was
    -- absent from the sysroot. Both sides must migrate together -- see
    -- sysroot.unwrap_directory_asset.
    if not sysroot.declare_headers(pkginfo.install_dir(), "include",
                                   "usr/include",
                                   "linux-headers@" .. pkginfo.version(),
                                   { merge = { "scsi" } }) then
        local sysroot_usrdir = path.join(system.subos_sysrootdir(), "usr")
        if not os.isdir(sysroot_usrdir) then os.mkdir(sysroot_usrdir) end

        -- Idempotent: skip the recursive header copy if this version is
        -- already in the subos sysroot. The stamp lives next to the copied
        -- tree so that switching subos / wiping the sysroot correctly
        -- invalidates it.
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
    end

    xvm.add("linux-headers")

    return true
end

function uninstall()
    xvm.remove("linux-headers")
    return true
end
