-- openbsd-disk-image: OpenBSD 8.0 for amd64, installed from the project's own media, with the
-- profile dirun boots it by (docs/12-disk-image-assets.md, "<system>-disk-image").
--
-- OpenBSD publishes no disk image, so the image is an installation: the release's cd80.iso boots
-- the installer, which answers itself from a response file (autoinstall(8)) and installs bsd,
-- bsd.mp, bsd.rd and base80.tgz, verified against the release's signed SHA256.sig. The disk has
-- one file system; the console is com0; sshd is off; the kernel and library relinking at boot is
-- off. Assembled by `.agents/tools/build-openbsd-disk-image.py`; PROVENANCE.md beside the image
-- states the digests and every change.
--
-- The profile (`dirun.toml`, beside the image): root logs in with the password `root`. OpenBSD's
-- msdos file system grants no execute permission, so the files disk is copied to /tmp/dirun
-- and made executable there; a test runner's events are written to a file the runner reads back.
-- A runner statement names the package's root:
--
--     dirun --profile {pkg:openbsd-disk-image}/dirun.toml -- {}
--
-- The image is the x86_64 guest, booted by qemu-system-x86_64 with the host's acceleration
-- where the host is x86_64.
package = {
    spec = "2",
    homepage = "https://www.openbsd.org/",
    name = "openbsd-disk-image",
    description = "OpenBSD 8.0 (amd64), installed from the release's own media with a serial console, as a qcow2 disk for emulator runners; with the dirun profile that boots it",
    maintainers = {"https://github.com/xlings-res/openbsd-disk-image"},
    licenses = {"ISC", "BSD-2-Clause", "BSD-3-Clause"},
    repo = "https://www.openbsd.org/80.html",
    docs = "https://github.com/Sunrisepeak/dirun/blob/main/docs/profiles.md",
    type = "package",
    archs = {"x86_64"},
    status = "dev",
    categories = {"runner", "openbsd"},
    keywords = {"openbsd", "disk-image", "qcow2", "dirun", "runner"},
    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/openbsd-disk-image/releases/download/${version}/openbsd-disk-image-${version}.tar.xz",
            CN = "https://gitcode.com/xlings-res/openbsd-disk-image/releases/download/${version}/openbsd-disk-image-${version}.tar.xz",
        },
        linux = {
            ["latest"] = { ref = "8.0-1" },
            ["8.0-1"] = {
                -- r1: the profile is TOML (its two patterns escape `\`; 8.0's did not parse), and the command runs in /tmp/dirun.
                revision = 1,
                url = {
                    GLOBAL = "https://github.com/xlings-res/openbsd-disk-image/releases/download/8.0/openbsd-disk-image-8.0.tar.xz",
                    CN     = "https://gitcode.com/xlings-res/openbsd-disk-image/releases/download/8.0/openbsd-disk-image-8.0.tar.xz",
                },
                sha256 = { x86_64 = "35b60e66672f086369d7d1bc2d6f88fb6a635bf7b249f3490b43182f8edc75ba" },
            },
            ["8.0"] = { sha256 = { x86_64 = "35b60e66672f086369d7d1bc2d6f88fb6a635bf7b249f3490b43182f8edc75ba" } },
        },
        macosx = {
            ["latest"] = { ref = "8.0-1" },
            ["8.0-1"] = {
                -- r1: the profile is TOML (its two patterns escape `\`; 8.0's did not parse), and the command runs in /tmp/dirun.
                revision = 1,
                url = {
                    GLOBAL = "https://github.com/xlings-res/openbsd-disk-image/releases/download/8.0/openbsd-disk-image-8.0.tar.xz",
                    CN     = "https://gitcode.com/xlings-res/openbsd-disk-image/releases/download/8.0/openbsd-disk-image-8.0.tar.xz",
                },
                sha256 = "35b60e66672f086369d7d1bc2d6f88fb6a635bf7b249f3490b43182f8edc75ba",
            },
            ["8.0"] = { sha256 = "35b60e66672f086369d7d1bc2d6f88fb6a635bf7b249f3490b43182f8edc75ba" },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- How this image boots and runs a command (dirun's profile format).
local profile = [=[
# OpenBSD 8.0, x86_64 (the package openbsd-disk-image). The kernel and the login speak on the serial
# line (com0, chosen at install), and root logs in with the password `root`.
name = "openbsd-8.0-x86_64"

[machine]
arch   = "x86_64"
memory = 1024
smp    = 2
image  = "openbsd-8.0.qcow2"

[[boot]]
expect  = "login: "
send    = "root"
timeout = 300

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
line-max = 200            # a longer line is written to the files disk and run from there
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
        raise("openbsd-disk-image payload not found at " .. extracted)
    end
    os.mv(extracted, dir)
    io.writefile(path.join(dir, "dirun.toml"), profile)
    return os.isfile(path.join(dir, "openbsd-8.0.qcow2"))
end

-- Data, not a program: the package name is registered so a home knows it has it; a
-- runner names the files under its root.
function config()
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
