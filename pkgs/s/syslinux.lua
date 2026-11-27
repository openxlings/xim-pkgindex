package = {
    spec = "3",

    name = "syslinux",
    description = "SYSLINUX bootloader collection (isolinux, pxelinux, extlinux + EFI loaders)",

    homepage = "https://www.syslinux.org",
    authors = {"H. Peter Anvin"},
    licenses = {"GPL-2.0+"},
    repo = "https://git.kernel.org/pub/scm/boot/syslinux/syslinux.git",
    docs = "https://wiki.syslinux.org",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"system", "boot", "bootloader"},
    keywords = {"syslinux", "isolinux", "pxelinux", "extlinux", "bootloader", "iso"},

    -- Upstream's tarball is a prebuilt distribution: bootloader stub
    -- modules (`*.c32`, `*.bin`, EFI loaders) ship as binary blobs that
    -- get written to boot media by mkisofs / xorriso / dd, plus three
    -- host-side installer ELFs:
    --
    --     bios/extlinux/extlinux              -> install onto ext/btrfs/xfs/fat
    --     bios/linux/syslinux                 -> install onto fat (uses mtools)
    --     bios/linux/syslinux-nomtools        -> install onto fat (no mtools)
    --
    -- Caveat: those installer ELFs are i386 (`/lib/ld-linux.so.2`),
    -- which means a pure 64-bit host without i386 multilib can't
    -- launch them (`exec format error`). Most of the package's value
    -- — the `.c32`/`.bin`/EFI artefacts used to build bootable
    -- images — does not need the installer ELFs to run, so we still
    -- ship them and surface the constraint in `config()` log output.
    programs = { "extlinux", "syslinux", "syslinux-nomtools" },
    xvm_enable = true,

    xpm = {
        linux = {
            strip = 1,
            ["latest"] = { ref = "6.03" },
            -- revision 1: config() binds the installers to extlinux@6.03.
            ["6.03"] = {
                revision = 1,
                url = "https://www.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.xz",
                sha256 = { x86_64 = "26d3986d2bea109d5dc0e4f8c4822a459276cf021125e8c9f23c3cca5d8c850e" },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")
import("xim.libxpkg.fs")
import("xim.libxpkg.path")
import("xim.libxpkg.system")

local host_installers = { "extlinux", "syslinux", "syslinux-nomtools" }

function install()
    -- Tarball extracts to syslinux-<ver>/ at the runtime download dir.

    -- Surface the three host installer ELFs under a single bindir so
    -- xvm can shim them — upstream parks them under bios/extlinux/ and
    -- bios/linux/, neither of which is conventional.
    local bindir = path.join(pkginfo.install_dir(), "bin")
    fs.mkdir(bindir)
    fs.copy(path.join(pkginfo.install_dir(), "bios/extlinux/extlinux"),     path.join(bindir, "extlinux"), { replace = true })
    fs.copy(path.join(pkginfo.install_dir(), "bios/linux/syslinux"),         path.join(bindir, "syslinux"), { replace = true })
    fs.copy(path.join(pkginfo.install_dir(), "bios/linux/syslinux-nomtools"), path.join(bindir, "syslinux-nomtools"), { replace = true })
    for _, p in ipairs(host_installers) do
        system.run('chmod +x "' .. path.join(bindir, p) .. '"')
    end
    return true
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    -- The first program is the release the others bind to: a program
    -- named like the package bound to `syslinux@<version>` was bound to
    -- itself, which the registration refuses.
    local root = host_installers[1] .. "@" .. pkginfo.version()
    xvm.add(host_installers[1], { bindir = bindir })
    for i = 2, #host_installers do
        xvm.add(host_installers[i], { bindir = bindir, binding = root })
    end

    log.info("syslinux installed to %s", pkginfo.install_dir())
    log.info("BIOS modules:    %s/bios/   (isolinux.bin, ldlinux.c32, menu.c32, mbr/*.bin, ...)", pkginfo.install_dir())
    log.info("EFI64 loaders:   %s/efi64/", pkginfo.install_dir())
    log.info("EFI32 loaders:   %s/efi32/", pkginfo.install_dir())
    log.info("Host installers (extlinux/syslinux/syslinux-nomtools) are i386 ELFs;")
    log.info("running them on a 64-bit host requires i386 multilib (e.g. libc6-i386).")
    return true
end

function uninstall()
    for _, p in ipairs(host_installers) do
        xvm.remove(p)
    end
    return true
end
