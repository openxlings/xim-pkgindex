-- aarch64-netbsd-disk-image: The NetBSD Foundation's arm64 live image of NetBSD 10.2
-- (evbarm-aarch64/binary/gzimg/arm64.img.gz), booted once and adjusted by the system itself
-- (.agents/tools/build-aarch64-netbsd-disk-image.py; PROVENANCE.md in the archive), with the profile
-- dirun boots it by (docs/12-disk-image-assets.md, "<system>-disk-image"). The package is named by
-- the GUEST's architecture, as aarch64-freebsd-disk-image is: an x86_64 machine installs it to run
-- aarch64-netbsd programs in QEMU's translator. netbsd-disk-image is the x86_64 guest.
--
-- The release publishes no digest of its gzipped images: the builder checks the image's own kernel
-- against the release's kernel set (kernel/SHA512), byte for byte. Changed in the image: the boot
-- loader waits one second, no network service or mail system starts, the root file system is not
-- resized, and the host keys the first boot made are removed.
--
-- The machine is QEMU's `virt' with the EDK II firmware for AArch64, which the package ovmf carries;
-- the profile names it by a variable, so the runner states which package supplies it:
--
--     dirun --profile {pkg:aarch64-netbsd-disk-image}/dirun.toml
--           --var firmware={pkg:ovmf}/share/edk2/edk2-aarch64-code.fd
--           --emulator {pkg:qemu-system}/bin/qemu-system-aarch64 -- {}
--
-- Measured (dirun 0.8.0, QEMU 9.2.4 translating on an x86_64 host): the login prompt 17 s after
-- the start, a delivered file read, a command's status 7.
package = {
    spec = "3",
    homepage = "https://www.netbsd.org/",
    name = "aarch64-netbsd-disk-image",
    description = "NetBSD 10.2 (arm64), the official live image booted once, with a serial console, as a qcow2 disk for emulator runners; with the dirun profile that boots it",

    maintainers = {"https://github.com/xlings-res/netbsd-disk-image"},
    licenses = {"BSD-2-Clause", "BSD-3-Clause"},
    repo = "https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.2/evbarm-aarch64/",
    docs = "https://github.com/Sunrisepeak/dirun/blob/main/docs/profiles.md",

    type = "package",
    -- Host arches: the image is data, booted by qemu-system-aarch64 wherever that runs.
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"runner", "netbsd"},
    keywords = {"netbsd", "disk-image", "qcow2", "dirun", "runner", "aarch64", "arm64"},

    xpm = {
        linux = {
            strip = 1,
            ["latest"] = { ref = "10.2" },
            ["10.2"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/netbsd-disk-image/releases/download/10.2/netbsd-disk-image-10.2-aarch64.tar.xz",
                    CN     = "https://gitcode.com/xlings-res/netbsd-disk-image/releases/download/10.2/netbsd-disk-image-10.2-aarch64.tar.xz",
                },
                sha256 = {
                    x86_64 = "43ecde529232bef52515a236dea376d446517330b1198b5d9c42add2903db390",
                    aarch64 = "43ecde529232bef52515a236dea376d446517330b1198b5d9c42add2903db390",
                },
            },
        },
        macosx = {
            strip = 1,
            ["latest"] = { ref = "10.2" },
            ["10.2"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/netbsd-disk-image/releases/download/10.2/netbsd-disk-image-10.2-aarch64.tar.xz",
                    CN     = "https://gitcode.com/xlings-res/netbsd-disk-image/releases/download/10.2/netbsd-disk-image-10.2-aarch64.tar.xz",
                },
                sha256 = "43ecde529232bef52515a236dea376d446517330b1198b5d9c42add2903db390",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.fs")
import("xim.libxpkg.path")

-- How this image boots and runs a command (dirun's profile format).
local profile = [=[
# NetBSD 10.2, arm64 (the package aarch64-netbsd-disk-image): QEMU's `virt' machine with the EDK II
# firmware for AArch64 ({firmware}); the boot loader, the kernel and the login speak on the serial
# line, and root logs in without a password. The disks are ld4 (the image) and ld5 (the files).
name = "netbsd-10.2-aarch64"

[machine]
arch   = "aarch64"
type   = "virt"
cpu    = "max"
memory = 1024
smp    = 2
image  = "netbsd-10.2-aarch64.qcow2"
args   = ["-drive", "if=pflash,format=raw,readonly=on,file={firmware}"]

[[boot]]
expect  = "login: "
send    = "root"
timeout = 900

[[boot]]
expect   = "Password:"
send     = ""
optional = true

[[boot]]
expect = "# |\\$ "

[command]
prepare = ["stty -echo"]
line    = "echo @@BEGIN@@; {env}{argv} < /dev/null; echo @@STATUS=$?@@"
env     = "env {assignments} "
quote   = "posix"
begin   = "@@BEGIN@@"
status  = "@@STATUS=(\\d+)@@"
line-max = 200
script   = "sh {script}"

[files]
mount = ["mkdir -p /mnt/fat /tmp/dirun", "mount -r -t msdos /dev/ld5e /mnt/fat", "cp -R /mnt/fat/. /tmp/dirun/", "umount /mnt/fat", "cd /tmp/dirun"]
at    = "/tmp/dirun"

[relay]
report = "/tmp/dirun-mtest.ndjson"
]=]

function install()
    local dir = pkginfo.install_dir()
    fs.write(path.join(dir, "dirun.toml"), profile)
    return fs.is_file(path.join(dir, "netbsd-10.2-aarch64.qcow2"))
end

-- Data, not a program: the package name is registered so a home knows it has it; a runner names
-- the files under its root.
function config()
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
