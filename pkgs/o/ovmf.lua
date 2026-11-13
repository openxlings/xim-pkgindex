package = {
    spec = "1",
    name = "ovmf",
    description = "OVMF: the EDK II UEFI firmware of an x86_64 virtual machine, as qemu ships it, with the dirun profile that boots a UEFI application by it",
    homepage = "https://github.com/tianocore/tianocore.github.io/wiki/OVMF",
    repo = "https://github.com/qemu/qemu/tree/master/pc-bios",
    licenses = {"BSD-2-Clause-Patent"},
    type = "package",
    -- Firmware is the same file whichever machine runs the emulator.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"system", "boot", "emulator"},
    keywords = {"uefi", "ovmf", "edk2", "firmware", "qemu", "openkal"},
    -- What a UEFI application is booted on, with qemu-x86: share/edk2/edk2-x86_64-code.fd,
    -- the code image as a flash device. dirun.toml (written at install, from r1) is the
    -- profile that boots one; a runner statement names the package's root:
    --
    --     dirun --payload {} --profile {pkg:ovmf}/dirun.toml
    --           --emulator {pkg:qemu-x86}/bin/qemu-system-x86_64 -- <arguments>
    --
    -- The application is placed as EFI/BOOT/BOOTX64.EFI on a read-only FAT disk of its
    -- directory, the firmware boots it, and its status is the one it writes to the
    -- isa-debug-exit port (0xf4); the firmware's output before BdsDxe starts it is boot noise.
    -- The archive is edk2-firmware's (the files decompressed from qemu's pc-bios/
    -- at the tag named by the version, tools/res/build.sh edk2-firmware); it is
    -- data, so the one archive serves Linux, macOS and Windows. edk2-firmware
    -- itself is the Linux machine firmware set of luban and is updated
    -- automatically; this recipe is kept by hand.
    xpm = {
        linux = {
            ["latest"] = { ref = "9.2.4-1" },
            ["9.2.4-1"] = {
                -- r1: dirun.toml, the profile that boots a UEFI application by the firmware.
                revision = 1,
                url = {
                    GLOBAL = "https://github.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                },
                sha256 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
            },
            ["9.2.4"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                },
                sha256 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
            },
        },
        macosx = {
            ["latest"] = { ref = "9.2.4-1" },
            ["9.2.4-1"] = {
                -- r1: dirun.toml, the profile that boots a UEFI application by the firmware.
                revision = 1,
                url = {
                    GLOBAL = "https://github.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                },
                sha256 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
            },
            ["9.2.4"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                },
                sha256 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
            },
        },
        windows = {
            ["latest"] = { ref = "9.2.4-1" },
            ["9.2.4-1"] = {
                -- r1: dirun.toml, the profile that boots a UEFI application by the firmware.
                revision = 1,
                url = {
                    GLOBAL = "https://github.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                },
                sha256 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
            },
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

-- The profile names the firmware beside it ({profile-dir}, dirun 0.3.2), so the
-- installed file holds no path of this machine.
local profile = [[
# A UEFI application booted by OVMF in QEMU (dirun's payload form). The package ovmf
# installs this file at its root; the emulator is named by the runner (--emulator).
name = "ovmf-x86_64"

[machine]
arch = "x86_64"
type = "q35"

[payload]
args   = ["-drive", "if=pflash,format=raw,readonly=on,file={profile-dir}/share/edk2/edk2-x86_64-code.fd",
          "-drive", "if=virtio,format=raw,readonly=on,file=fat:{dir}",
          "-device", "isa-debug-exit,iobase=0xf4,iosize=0x04"]
place  = "EFI/BOOT/BOOTX64.EFI"
status = "debug-exit"
after  = "BdsDxe: starting [^\n]*\n"
]]

function install()
    local dir = pkginfo.install_dir()
    -- The archive's one directory, edk2-firmware-<upstream version>, is the package.
    local payload = os.dirs(path.join(path.directory(pkginfo.install_file()), "edk2-firmware-*"))[1]
    if payload then
        os.tryrm(dir)
        os.mv(payload, dir)
    end
    io.writefile(path.join(dir, "dirun.toml"), profile)
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
