-- aarch64-freebsd-disk-image: The FreeBSD Project's 14.5-RELEASE virtual-machine image for arm64
-- (FreeBSD-14.5-RELEASE-arm64-aarch64-ufs.qcow2, its bytes unchanged, sha256 3afc488c... of the
-- .xz the project publishes), with the profile dirun boots it by (docs/12-disk-image-assets.md,
-- "<system>-disk-image"). The package is named by the GUEST's architecture, as the sysroots are
-- (aarch64-freebsd-sysroot): an x86_64 machine installs it to run aarch64-freebsd programs, in
-- QEMU's translator, and an aarch64 machine with its accelerator. freebsd-disk-image is the
-- x86_64 guest.
--
-- The project's image needs no change: root logs in on the serial console with no password, and
-- the second virtio disk is /dev/vtbd1 (measured: login, the files disk mounted, a command's
-- status, 28 s under TCG on an x86_64 host). The machine is QEMU's `virt' with the EDK II firmware
-- for AArch64, which the package ovmf carries (share/edk2/edk2-aarch64-code.fd); the profile names
-- it by a variable, so the runner states which package supplies it:
--
--     dirun --profile {pkg:aarch64-freebsd-disk-image}/dirun.toml
--           --var firmware={pkg:ovmf}/share/edk2/edk2-aarch64-code.fd
--           --emulator {pkg:qemu-system}/bin/qemu-system-aarch64 -- {}
package = {
    spec = "2",
    homepage = "https://www.freebsd.org/",
    name = "aarch64-freebsd-disk-image",
    description = "The FreeBSD Project's 14.5-RELEASE virtual-machine image for arm64 (qcow2, serial console), for emulator runners; with the dirun profile that boots it",
    maintainers = {"https://github.com/xlings-res/freebsd-disk"},
    licenses = {"BSD-2-Clause", "BSD-3-Clause"},
    repo = "https://download.freebsd.org/releases/VM-IMAGES/14.5-RELEASE/aarch64/",
    docs = "https://github.com/Sunrisepeak/dirun/blob/main/docs/profiles.md",
    type = "package",
    -- Host arches: the image is data, booted by qemu-system-aarch64 wherever that runs.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"runner", "freebsd"},
    keywords = {"freebsd", "disk-image", "qcow2", "dirun", "runner", "aarch64", "arm64"},
    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/freebsd-disk/releases/download/${version}/freebsd-disk-${version}-aarch64.tar.xz",
            CN = "https://gitcode.com/xlings-res/freebsd-disk/releases/download/${version}/freebsd-disk-${version}-aarch64.tar.xz",
        },
        linux = {
            ["latest"] = { ref = "14.5-1" },
            ["14.5-1"] = {
                -- r1: the files are copied to a writable /tmp/dirun, where the command runs (its working directory).
                revision = 1,
                url = {
                    GLOBAL = "https://github.com/xlings-res/freebsd-disk/releases/download/14.5/freebsd-disk-14.5-aarch64.tar.xz",
                    CN     = "https://gitcode.com/xlings-res/freebsd-disk/releases/download/14.5/freebsd-disk-14.5-aarch64.tar.xz",
                },
                sha256 = {
                    x86_64 = "f9a4ff17bcfb6ee460b1a63d8437568c9aa2d96bd51d1c84cc05d08651b193ae",
                    aarch64 = "f9a4ff17bcfb6ee460b1a63d8437568c9aa2d96bd51d1c84cc05d08651b193ae",
                },
            },
            ["14.5"] = { sha256 = { x86_64 = "f9a4ff17bcfb6ee460b1a63d8437568c9aa2d96bd51d1c84cc05d08651b193ae", aarch64 = "f9a4ff17bcfb6ee460b1a63d8437568c9aa2d96bd51d1c84cc05d08651b193ae" } },
        },
        macosx = {
            ["latest"] = { ref = "14.5-1" },
            ["14.5-1"] = {
                -- r1: the files are copied to a writable /tmp/dirun, where the command runs (its working directory).
                revision = 1,
                url = {
                    GLOBAL = "https://github.com/xlings-res/freebsd-disk/releases/download/14.5/freebsd-disk-14.5-aarch64.tar.xz",
                    CN     = "https://gitcode.com/xlings-res/freebsd-disk/releases/download/14.5/freebsd-disk-14.5-aarch64.tar.xz",
                },
                sha256 = "f9a4ff17bcfb6ee460b1a63d8437568c9aa2d96bd51d1c84cc05d08651b193ae",
            },
            ["14.5"] = { sha256 = "f9a4ff17bcfb6ee460b1a63d8437568c9aa2d96bd51d1c84cc05d08651b193ae" },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- How this image boots and runs a command (dirun's profile format).
local profile = [=[
# FreeBSD 14.5-RELEASE, arm64 (the package aarch64-freebsd-disk-image): QEMU's `virt' machine with
# the EDK II firmware for AArch64 ({firmware}), root logging in on the serial console.
name = "freebsd-14.5-aarch64"

[machine]
arch   = "aarch64"
type   = "virt"
cpu    = "max"
memory = 1024
smp    = 2
image  = "freebsd-14.5-aarch64.qcow2"
args   = ["-drive", "if=pflash,format=raw,readonly=on,file={firmware}"]

[[boot]]
expect  = "login: "
send    = "root"
timeout = 900

[[boot]]
expect   = "Password:"
send     = "root"
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
line-max = 200            # a longer line is written to the files disk and run from there
script   = "sh {script}"

[files]
mount = ["mkdir -p /mnt/fat /tmp/dirun", "mount -r -t msdosfs /dev/vtbd1s1 /mnt/fat", "cp -R /mnt/fat/. /tmp/dirun/", "umount /mnt/fat", "cd /tmp/dirun"]
at    = "/tmp/dirun"

[relay]
report = "/tmp/dirun-mtest.ndjson"
]=]

function install()
    local dir = pkginfo.install_dir()
    -- The release the asset is of: a packaging revision (`14.5-1`) names the same asset.
    local release = pkginfo.version():match("^[^-]+")
    local image = path.join(dir, "freebsd-14.5-aarch64.qcow2")
    for _, from in ipairs({
        path.join(path.directory(pkginfo.install_file()), "freebsd-disk-" .. release .. "-aarch64.qcow2"),
        path.join(dir, "freebsd-disk-" .. release .. "-aarch64.qcow2"),
    }) do
        if os.isfile(from) and from ~= image then
            os.mkdir(dir)
            os.mv(from, image)
            break
        end
    end
    io.writefile(path.join(dir, "dirun.toml"), profile)
    return os.isfile(image)
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
