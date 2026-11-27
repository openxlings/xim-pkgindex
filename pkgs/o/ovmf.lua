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
    -- r2: the application is APP.EFI on a read-only FAT disk of its directory, with no
    -- EFI/BOOT/BOOTX64.EFI, so the firmware starts its internal Shell; the Shell runs the
    -- disk's startup.nsh, which runs `APP.EFI <arguments>' (after a five-second countdown the
    -- Shell itself waits), so the application receives its arguments as a Shell command's.
    -- r3: the profile states `quote = "uefi-shell"' (dirun 0.5.0): the Shell splits the line at
    -- blanks outside double quotes, so an argument with a blank was received as two.
    -- r4: the disk is a writable FAT32 image of the directory (`disk = "fat-image"', dirun
    -- 0.6.0), so the application can write files; QEMU's `fat:' directory is read-only.
    -- r1 placed it as BOOTX64.EFI, which the firmware starts with no arguments. Its status
    -- is the one it writes to the isa-debug-exit port (0xf4); what precedes the Shell's echo
    -- of the command line is boot noise, and `reset -s' ends a run whose application returned
    -- without writing a status.
    -- The archive is edk2-firmware's (the files decompressed from qemu's pc-bios/
    -- at the tag named by the version, tools/res/build.sh edk2-firmware); it is
    -- data, so the one archive serves Linux, macOS and Windows. edk2-firmware
    -- itself is the Linux machine firmware set of luban and is updated
    -- automatically; this recipe is kept by hand.
    xpm = {
        linux = {
            ["latest"] = { ref = "9.2.4-4" },
            ["9.2.4-4"] = {
                -- r4: a writable FAT32 image of the directory (dirun 0.6.0, [payload] disk).
                revision = 4,
                url = {
                    GLOBAL = "https://github.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                },
                sha256 = {
                    x86_64 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
                    aarch64 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
                },
            },
            ["9.2.4-3"] = {
                -- r3: the profile quotes the arguments for the Shell (dirun 0.5.0, [payload] quote).
                revision = 3,
                url = {
                    GLOBAL = "https://github.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                },
                sha256 = {
                    x86_64 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
                    aarch64 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
                },
            },
            ["9.2.4-2"] = {
                -- r2: the profile starts the application from the firmware's Shell, with its arguments.
                revision = 2,
                url = {
                    GLOBAL = "https://github.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                },
                sha256 = {
                    x86_64 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
                    aarch64 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
                },
            },
            ["9.2.4-1"] = {
                -- r1: dirun.toml, the profile that boots a UEFI application by the firmware.
                revision = 1,
                url = {
                    GLOBAL = "https://github.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                },
                sha256 = {
                    x86_64 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
                    aarch64 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
                },
            },
            ["9.2.4"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                },
                sha256 = {
                    x86_64 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
                    aarch64 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "9.2.4-4" },
            ["9.2.4-4"] = {
                -- r4: a writable FAT32 image of the directory (dirun 0.6.0, [payload] disk).
                revision = 4,
                url = {
                    GLOBAL = "https://github.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                },
                sha256 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
            },
            ["9.2.4-3"] = {
                -- r3: the profile quotes the arguments for the Shell (dirun 0.5.0, [payload] quote).
                revision = 3,
                url = {
                    GLOBAL = "https://github.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                },
                sha256 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
            },
            ["9.2.4-2"] = {
                -- r2: the profile starts the application from the firmware's Shell, with its arguments.
                revision = 2,
                url = {
                    GLOBAL = "https://github.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                },
                sha256 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
            },
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
            ["latest"] = { ref = "9.2.4-4" },
            ["9.2.4-4"] = {
                -- r4: a writable FAT32 image of the directory (dirun 0.6.0, [payload] disk).
                revision = 4,
                url = {
                    GLOBAL = "https://github.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                },
                sha256 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
            },
            ["9.2.4-3"] = {
                -- r3: the profile quotes the arguments for the Shell (dirun 0.5.0, [payload] quote).
                revision = 3,
                url = {
                    GLOBAL = "https://github.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                },
                sha256 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
            },
            ["9.2.4-2"] = {
                -- r2: the profile starts the application from the firmware's Shell, with its arguments.
                revision = 2,
                url = {
                    GLOBAL = "https://github.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/edk2-firmware/releases/download/9.2.4/edk2-firmware-9.2.4-linux-x86_64.tar.gz",
                },
                sha256 = "fa9e47e33e5a2f554bfde81831797dbdaf9110423f34cf2254e1f3ee5f4498c4",
            },
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
-- installed file holds no path of this machine. Each revision installs its own profile: r1's
-- boots the application as BOOTX64.EFI; r2's from the Shell, with its arguments; r3's (below)
-- quotes those arguments for the Shell, a key dirun reads from 0.5.0.
local profile_r1 = [[
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

local profile_r2 = [[
# A UEFI application run by the Shell of OVMF in QEMU (dirun's payload form). The package ovmf
# installs this file at its root; the emulator is named by the runner (--emulator). The disk holds
# APP.EFI and no EFI/BOOT/BOOTX64.EFI, so the firmware starts its internal Shell, and the Shell runs
# startup.nsh: the application is a Shell command and receives its arguments.
name = "ovmf-x86_64"

[machine]
arch = "x86_64"
type = "q35"

[payload]
args   = ["-drive", "if=pflash,format=raw,readonly=on,file={profile-dir}/share/edk2/edk2-x86_64-code.fd",
          "-drive", "if=virtio,format=raw,readonly=on,file=fat:{dir}",
          "-device", "isa-debug-exit,iobase=0xf4,iosize=0x04"]
place  = "APP.EFI"
files  = { "startup.nsh" = "fs0:\r\nAPP.EFI {args}\r\nreset -s\r\n" }
status = "debug-exit"
after  = "APP\\.EFI[^\n]*\n"
]]

local profile_r3 = [[
# A UEFI application run by the Shell of OVMF in QEMU (dirun's payload form). The package ovmf
# installs this file at its root; the emulator is named by the runner (--emulator). The disk holds
# APP.EFI and no EFI/BOOT/BOOTX64.EFI, so the firmware starts its internal Shell, and the Shell runs
# startup.nsh: the application is a Shell command and receives its arguments, each quoted for the
# Shell (quote, dirun 0.5.0): one with a blank stays one.
name = "ovmf-x86_64"

[machine]
arch = "x86_64"
type = "q35"

[payload]
args   = ["-drive", "if=pflash,format=raw,readonly=on,file={profile-dir}/share/edk2/edk2-x86_64-code.fd",
          "-drive", "if=virtio,format=raw,readonly=on,file=fat:{dir}",
          "-device", "isa-debug-exit,iobase=0xf4,iosize=0x04"]
place  = "APP.EFI"
files  = { "startup.nsh" = "fs0:\r\nAPP.EFI {args}\r\nreset -s\r\n" }
quote  = "uefi-shell"
status = "debug-exit"
after  = "APP\\.EFI[^\n]*\n"
]]

local profile = [[
# A UEFI application run by the Shell of OVMF in QEMU (dirun's payload form). The package ovmf
# installs this file at its root; the emulator is named by the runner (--emulator). The disk holds
# APP.EFI and no EFI/BOOT/BOOTX64.EFI, so the firmware starts its internal Shell, and the Shell runs
# startup.nsh: the application is a Shell command and receives its arguments, each quoted for the
# Shell (quote, dirun 0.5.0): one with a blank stays one. The disk is a writable FAT32 image that dirun
# writes from the directory (disk, dirun 0.6.0), so the application can write files on it.
name = "ovmf-x86_64"

[machine]
arch = "x86_64"
type = "q35"

[payload]
args   = ["-drive", "if=pflash,format=raw,readonly=on,file={profile-dir}/share/edk2/edk2-x86_64-code.fd",
          "-drive", "if=virtio,format=raw,file={disk}",
          "-device", "isa-debug-exit,iobase=0xf4,iosize=0x04"]
disk   = "fat-image"
place  = "APP.EFI"
files  = { "startup.nsh" = "fs0:\r\nAPP.EFI {args}\r\nreset -s\r\n" }
quote  = "uefi-shell"
status = "debug-exit"
after  = "APP\\.EFI[^\n]*\n"
]]

function install()
    local dir = pkginfo.install_dir()
    -- The archive's one directory, edk2-firmware-<upstream version>, is the package; a
    -- revision (`-1') is the recipe's, not the archive's.
    local upstream = pkginfo.version():gsub("%-%d+$", "")
    local payload = path.join(path.directory(pkginfo.install_file()), "edk2-firmware-" .. upstream)
    if os.isdir(payload) then
        os.tryrm(dir)
        os.mv(payload, dir)
    end
    local revision = tonumber(pkginfo.version():match("%-(%d+)$") or "0")
    io.writefile(path.join(dir, "dirun.toml"),
                 revision >= 4 and profile or revision == 3 and profile_r3 or revision == 2 and profile_r2 or profile_r1)
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
