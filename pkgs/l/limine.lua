package = {
    spec = "1",

    name = "limine",
    description = "Limine: the boot loader of Luban images (BIOS and UEFI; ISO, drives)",

    homepage = "https://limine-bootloader.org",
    repo = "https://github.com/limine-bootloader/limine",
    licenses = {"BSD-2-Clause"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"system", "boot"},
    keywords = {"limine", "bootloader", "uefi", "bios", "iso", "luban"},

    -- What `xlings subos export --iso / --drive` (`luban export x.iso / x.img`)
    -- boots with: upstream's boot files (limine-bios-cd.bin, limine-bios.sys,
    -- limine-uefi-cd.bin, BOOT*.EFI) in share/limine, where xlings looks for
    -- them, and the `limine` tool (bios-install: a drive or a hybrid ISO a BIOS
    -- boots) built static from upstream's limine.c by this index
    -- (tools/res/build.sh, res-build.yml) -- nothing is compiled on a user's
    -- machine.
    programs = {"limine"},
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "12.9.3" },
            ["12.9.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "718572a192b3d8f4da934f61c9f2ab7eeab96ad78db9d038c0f935278deee6b1",
                    aarch64 = "e7b32ef2ee7c05feb181ca08b0f9d41b7d118b2408e6a923e6e419dc39fc050b",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    local payload = "limine-" .. pkginfo.version()
    if os.isdir(payload) then
        os.tryrm(dir)
        os.mv(payload, dir)
    end
    return os.isfile(path.join(dir, "share", "limine", "limine-bios-cd.bin"))
        and os.isfile(path.join(dir, "bin", "limine"))
end

function config()
    xvm.add("limine", { bindir = path.join(pkginfo.install_dir(), "bin") })
    return true
end

function uninstall()
    xvm.remove("limine")
    return true
end
