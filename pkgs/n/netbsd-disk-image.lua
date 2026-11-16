-- netbsd-disk-image: NetBSD 10.2 for amd64, The NetBSD Foundation's official live image
-- made a runner's disk, with the profile dirun boots it by (docs/12-disk-image-assets.md,
-- "<system>-disk-image").
--
-- The image is NetBSD-10.2-amd64-live.img.gz (cdn.netbsd.org, checked against the
-- release's SHA512) with one change: /boot.cfg, rewritten at its own length, names the
-- serial line as the console and boots after one second, so the boot loader, the kernel and
-- the login speak on the line a runner reads. The disk is a compressed qcow2. Assembled by
-- `.agents/tools/build-netbsd-disk-image.py`; PROVENANCE.md beside the image states the
-- digests and the change.
--
-- The profile (`dirun.toml`, beside the image): root logs in without a password, the disk of
-- files is mounted read-only at /mnt/dirun, a test runner's events are written to a file the
-- runner reads back. A runner statement names the package's root:
--
--     dirun --profile {pkg:netbsd-disk-image}/dirun.toml -- {}
--
-- The image is the x86_64 guest, booted by qemu-system-x86_64 with the host's acceleration
-- where the host is x86_64.
package = {
    spec = "2",
    homepage = "https://www.netbsd.org/",
    name = "netbsd-disk-image",
    description = "NetBSD 10.2 (amd64), the official live image with a serial console, as a qcow2 disk for emulator runners; with the dirun profile that boots it",
    maintainers = {"https://github.com/xlings-res/netbsd-disk-image"},
    licenses = {"BSD-2-Clause", "BSD-3-Clause"},
    repo = "https://www.netbsd.org/releases/",
    docs = "https://github.com/Sunrisepeak/dirun/blob/main/docs/profiles.md",
    type = "package",
    archs = {"x86_64"},
    status = "dev",
    categories = {"runner", "netbsd"},
    keywords = {"netbsd", "disk-image", "qcow2", "dirun", "runner"},
    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/netbsd-disk-image/releases/download/${version}/netbsd-disk-image-${version}.tar.xz",
            CN = "https://gitcode.com/xlings-res/netbsd-disk-image/releases/download/${version}/netbsd-disk-image-${version}.tar.xz",
        },
        linux = {
            ["latest"] = { ref = "10.2" },
            ["10.2"] = { sha256 = "474d0b5be9e14002e4cb3f6399c63c2fe20c6b4a82413f176ecda6a5f96f0a6a" },
        },
        macosx = {
            ["latest"] = { ref = "10.2" },
            ["10.2"] = { sha256 = "474d0b5be9e14002e4cb3f6399c63c2fe20c6b4a82413f176ecda6a5f96f0a6a" },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- How this image boots and runs a command (dirun's profile format).
local profile = [=[
# NetBSD 10.2, x86_64 (the package netbsd-disk-image). The boot loader and the kernel speak on
# the serial line (the image's /boot.cfg), and root logs in without a password.
name = "netbsd-10.2-x86_64"

[machine]
arch   = "x86_64"
memory = 1024
smp    = 2
image  = "netbsd-10.2.qcow2"

[[boot]]
expect  = "login: "
send    = "root"
timeout = 300

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
line-max = 200            # a longer line is written to the files disk and run from there
script   = "sh {script}"

[files]
mount = ["mkdir -p /mnt/dirun", "mount -r -t msdos /dev/ld1e /mnt/dirun"]
at    = "/mnt/dirun"

[relay]
report = "/tmp/dirun-mtest.ndjson"
]=]

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    local extracted = pkginfo.install_file():replace(".tar.xz", "")
    if not os.isdir(extracted) then
        raise("netbsd-disk-image payload not found at " .. extracted)
    end
    os.mv(extracted, dir)
    io.writefile(path.join(dir, "dirun.toml"), profile)
    return os.isfile(path.join(dir, "netbsd-10.2.qcow2"))
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
