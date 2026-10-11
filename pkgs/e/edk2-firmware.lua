package = {
    spec = "1",

    name = "edk2-firmware",
    description = "UEFI firmware (EDK II) for virtual machines: x86_64 and aarch64, as qemu ships it",

    homepage = "https://github.com/tianocore/edk2",
    repo = "https://github.com/qemu/qemu/tree/master/pc-bios",
    licenses = {"BSD-2-Clause-Patent"},

    type = "package",
    -- Firmware is the same file whichever machine runs the emulator.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"system", "boot", "emulator"},
    keywords = {"uefi", "edk2", "ovmf", "aavmf", "firmware", "qemu", "luban"},

    -- What `luban try` boots a machine with no BIOS (aarch64) on, and what a
    -- UEFI boot of an x86_64 image uses: share/edk2/edk2-{x86_64,aarch64}-code.fd,
    -- decompressed from qemu's pc-bios/ at the tag named by the version
    -- (tools/res/build.sh edk2-firmware; the .bz2 inputs' digests are in
    -- tools/res/inputs.txt).
    xpm = {
        linux = {
            ["latest"] = { ref = "9.2.4" },
            ["9.2.4"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                },
                sha256 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    local payload = path.join(path.directory(pkginfo.install_file()), "edk2-firmware-" .. pkginfo.version())
    if os.isdir(payload) then
        os.tryrm(dir)
        os.mv(payload, dir)
    end
    return os.isfile(path.join(dir, "share", "edk2", "edk2-x86_64-code.fd"))
        and os.isfile(path.join(dir, "share", "edk2", "edk2-aarch64-code.fd"))
end

-- Data, not a program: the package name is registered (xvm.add) so a home
-- knows it has it; luban finds the files under share/edk2.
function config()
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
