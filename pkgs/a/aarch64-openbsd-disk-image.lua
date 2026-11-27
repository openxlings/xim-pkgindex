-- aarch64-openbsd-disk-image: OpenBSD 8.0 for arm64, installed from the project's own media
-- (arm64/cd80.iso, the release's sets, autoinstall(8)) by
-- .agents/tools/build-openbsd-disk-image.py (`arm64'; PROVENANCE.md in the archive), with the
-- profile dirun boots it by (docs/12-disk-image-assets.md, "<system>-disk-image"). The package is
-- named by the GUEST's architecture, as aarch64-freebsd-disk-image is: an x86_64 machine installs
-- it to run aarch64-openbsd programs in QEMU's translator. openbsd-disk-image is the x86_64 guest.
--
-- As the x86_64 image: bsd, bsd.mp, bsd.rd and base80.tgz, verified by the installer against the
-- release's signed SHA256.sig; one file system; root's password `root'; sshd off; no relinking
-- at boot. The processor is `cortex-a72': under QEMU's `max', with its newest extensions, OpenBSD
-- 8.0's kernel stopped at its first floating-point use (`FP exception in kernel', measured).
--
-- The machine is QEMU's `virt' with the EDK II firmware for AArch64 (the package ovmf):
--
--     dirun --profile {pkg:aarch64-openbsd-disk-image}/dirun.toml
--           --var firmware={pkg:ovmf}/share/edk2/edk2-aarch64-code.fd
--           --emulator {pkg:qemu-system}/bin/qemu-system-aarch64 -- {}
--
-- Measured (dirun 0.8.0, QEMU 9.2.4 translating on an x86_64 host): a command run 36 s after the
-- start, a delivered file read (OpenBSD's msdos file system grants no execute permission, so the
-- files are copied to /tmp/dirun and made executable there), a command's status 7.
package = {
    spec = "2",
    homepage = "https://www.openbsd.org/",
    name = "aarch64-openbsd-disk-image",
    description = "OpenBSD 8.0 (arm64), installed from the project's own media, with a serial console, as a qcow2 disk for emulator runners; with the dirun profile that boots it",

    maintainers = {"https://github.com/xlings-res/openbsd-disk-image"},
    licenses = {"ISC", "BSD-2-Clause", "BSD-3-Clause"},
    repo = "https://www.openbsd.org/80.html",
    docs = "https://github.com/Sunrisepeak/dirun/blob/main/docs/profiles.md",

    type = "package",
    -- Host arches: the image is data, booted by qemu-system-aarch64 wherever that runs.
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"runner", "openbsd"},
    keywords = {"openbsd", "disk-image", "qcow2", "dirun", "runner", "aarch64", "arm64"},

    xpm = {
        linux = {
            ["latest"] = { ref = "8.0" },
            ["8.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/openbsd-disk-image/releases/download/8.0/openbsd-disk-image-8.0-aarch64.tar.xz",
                    CN     = "https://gitcode.com/xlings-res/openbsd-disk-image/releases/download/8.0/openbsd-disk-image-8.0-aarch64.tar.xz",
                },
                sha256 = {
                    x86_64 = "c0c1f7b847316d32796bbb68e4fbc1e75e54ecc91c2fdbd41da77aa314fba3fd",
                    aarch64 = "c0c1f7b847316d32796bbb68e4fbc1e75e54ecc91c2fdbd41da77aa314fba3fd",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "8.0" },
            ["8.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/openbsd-disk-image/releases/download/8.0/openbsd-disk-image-8.0-aarch64.tar.xz",
                    CN     = "https://gitcode.com/xlings-res/openbsd-disk-image/releases/download/8.0/openbsd-disk-image-8.0-aarch64.tar.xz",
                },
                sha256 = "c0c1f7b847316d32796bbb68e4fbc1e75e54ecc91c2fdbd41da77aa314fba3fd",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- How this image boots and runs a command (dirun's profile format).
local profile = [=[
# OpenBSD 8.0, arm64 (the package aarch64-openbsd-disk-image): QEMU's `virt' machine with the EDK II
# firmware for AArch64 ({firmware}) and a Cortex-A72; the kernel and the login speak on the serial
# line, and root logs in with the password `root'. The disks are sd0 (the image) and sd1 (the files).
name = "openbsd-8.0-aarch64"

[machine]
arch   = "aarch64"
type   = "virt"
cpu    = "cortex-a72"
memory = 1024
smp    = 2
image  = "openbsd-8.0-aarch64.qcow2"
args   = ["-drive", "if=pflash,format=raw,readonly=on,file={firmware}"]

[[boot]]
expect  = "login: "
send    = "root"
timeout = 900

[[boot]]
expect = "Password:"
send   = "root"

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
mount = ["mkdir -p /mnt/fat /tmp/dirun", "mount -r -t msdos /dev/sd1i /mnt/fat", "cp -R /mnt/fat/. /tmp/dirun/", "chmod -R a+x /tmp/dirun", "umount /mnt/fat", "cd /tmp/dirun"]
at    = "/tmp/dirun"

[relay]
report = "/tmp/dirun-mtest.ndjson"
]=]

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    local extracted = pkginfo.install_file():replace(".tar.xz", "")
    if not os.isdir(extracted) then
        raise("aarch64-openbsd-disk-image: the payload was not found at " .. extracted)
    end
    os.mv(extracted, dir)
    io.writefile(path.join(dir, "dirun.toml"), profile)
    return os.isfile(path.join(dir, "openbsd-8.0-aarch64.qcow2"))
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
