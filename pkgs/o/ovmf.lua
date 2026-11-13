package = {
    spec = "1",
    name = "ovmf",
    description = "OVMF: the EDK II UEFI firmware of an x86_64 virtual machine, as qemu ships it, for every host that runs the emulator",
    homepage = "https://github.com/tianocore/tianocore.github.io/wiki/OVMF",
    repo = "https://github.com/qemu/qemu/tree/master/pc-bios",
    licenses = {"BSD-2-Clause-Patent"},
    type = "package",
    -- Firmware is the same file whichever machine runs the emulator.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"system", "boot", "emulator"},
    keywords = {"uefi", "ovmf", "edk2", "firmware", "qemu", "openkal"},
    -- What a UEFI application is booted on (openkal-uefi-platform's runner, with
    -- qemu-x86): share/edk2/edk2-x86_64-code.fd, the code image as a flash device.
    -- The archive is edk2-firmware's (the files decompressed from qemu's pc-bios/
    -- at the tag named by the version, tools/res/build.sh edk2-firmware); it is
    -- data, so the one archive serves Linux, macOS and Windows. edk2-firmware
    -- itself is the Linux machine firmware set of luban and is updated
    -- automatically; this recipe is kept by hand.
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
        macosx = {
            ["latest"] = { ref = "9.2.4" },
            ["9.2.4"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                },
                sha256 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
            },
        },
        windows = {
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
end

-- Data, not a program: the package name is registered (xvm.add) so a home
-- knows it has it; a runner names the file under share/edk2.
function config()
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
