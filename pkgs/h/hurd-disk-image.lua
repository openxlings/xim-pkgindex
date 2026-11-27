package = {
    spec = "2",
    homepage = "https://www.debian.org/ports/hurd/",
    name = "hurd-disk-image",
    description = "Debian GNU/Hurd (hurd-amd64), the pre-installed image with a login on the serial line, as a qcow2 disk for emulator runners; with the dirun profile that boots it",

    maintainers = {"https://github.com/xlings-res/hurd-disk-image"},
    licenses = {"GPL-2.0-or-later", "LGPL-2.1-or-later"},
    repo = "https://www.debian.org/ports/hurd/",
    docs = "https://github.com/Sunrisepeak/dirun/blob/main/docs/profiles.md",

    type = "package",
    archs = {"x86_64"},
    status = "dev",
    categories = {"runner", "hurd"},
    keywords = {"hurd", "gnu", "disk-image", "qcow2", "dirun", "runner"},

    -- A DISK-IMAGE ASSET (docs/12-disk-image-assets.md): Debian's pre-installed image of
    -- 2026-03-14, prepared by the system itself (PROVENANCE.md in the archive): a login on the
    -- first serial line, a boot menu that waits one second, no wait for a network address.
    -- The system has no virtio driver and its FAT translator does not answer on FAT32, so the
    -- profile states `bus = "ide"` and `form = "tar"`: dirun 0.7.0 or later boots it.
    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/hurd-disk-image/releases/download/${version}/hurd-disk-image-${version}.tar.xz",
            CN = "https://gitcode.com/xlings-res/hurd-disk-image/releases/download/${version}/hurd-disk-image-${version}.tar.xz",
        },
        linux = {
            ["latest"] = { ref = "20260314" },
            ["20260314"] = { sha256 = { x86_64 = "cbf3dfa47fff9318d0a52f9feb3f7a5baa9d25423fd77dcde5e5ff2d4e3ae84e" } },
        },
        macosx = {
            ["latest"] = { ref = "20260314" },
            ["20260314"] = { sha256 = "cbf3dfa47fff9318d0a52f9feb3f7a5baa9d25423fd77dcde5e5ff2d4e3ae84e" },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

local profile = [=[
# Debian GNU/Hurd, x86_64 (the package hurd-disk-image). A login waits on the serial line
# (/etc/inittab: getty on com0), and root logs in without a password. The system has no virtio
# driver: its disks are behind the machine's IDE controller, and the files disk is the second (wd1).
# The files are a tar archive on that disk: the system's FAT translator does not answer on FAT32.
name = "debian-hurd-amd64"

[machine]
arch   = "x86_64"
cpu    = "max"
memory = 2048
smp    = 1
bus    = "ide"
image  = "debian-hurd-amd64.qcow2"

[[boot]]
expect  = "login: "
send    = "root"
timeout = 600

[[boot]]
expect = "# "

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
form  = "tar"
mount = ["mkdir -p /tmp/dirun", "tar xf /dev/wd1 -C /tmp/dirun", "cd /tmp/dirun"]
at    = "/tmp/dirun"

[relay]
report = "/tmp/dirun-mtest.ndjson"
]=]

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    local extracted = pkginfo.install_file():replace(".tar.xz", "")
    if not os.isdir(extracted) then
        raise("hurd-disk-image payload not found at " .. extracted)
    end
    os.mv(extracted, dir)
    io.writefile(path.join(dir, "dirun.toml"), profile)
    return os.isfile(path.join(dir, "debian-hurd-amd64.qcow2"))
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
