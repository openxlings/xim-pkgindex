package = {
    spec = "2",
    homepage = "https://www.haiku-os.org/",
    name = "haiku-disk-image",
    description = "Haiku (x86_64), a nightly image with a shell on the serial line, as a qcow2 disk for emulator runners; with the dirun profile that boots it",

    maintainers = {"https://github.com/xlings-res/haiku-disk-image"},
    licenses = {"MIT"},
    repo = "https://www.haiku-os.org/",
    docs = "https://github.com/Sunrisepeak/dirun/blob/main/docs/profiles.md",

    type = "package",
    archs = {"x86_64"},
    status = "dev",
    categories = {"runner", "haiku"},
    keywords = {"haiku", "disk-image", "qcow2", "dirun", "runner"},

    -- A DISK-IMAGE ASSET (docs/12-disk-image-assets.md): Haiku's nightly image of revision
    -- hrev60431, prepared by the system itself (PROVENANCE.md in the archive): the kernel does
    -- not write to the serial line, and a shell holds it. The system is a desktop with no login;
    -- the shell is the desktop's user. The files are a tar archive on the second disk of the
    -- machine's AHCI controller, so the profile states `bus = "ide"` and `form = "tar"`:
    -- dirun 0.7.0 or later boots it.
    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/haiku-disk-image/releases/download/${version}/haiku-disk-image-${version}.tar.xz",
            CN = "https://gitcode.com/xlings-res/haiku-disk-image/releases/download/${version}/haiku-disk-image-${version}.tar.xz",
        },
        linux = {
            ["latest"] = { ref = "hrev60431" },
            ["hrev60431"] = { sha256 = { x86_64 = "a5d4eccde4025a42980713320b97ec905759eafdd4679c6ac5022b25d5c9d1c6" } },
        },
        macosx = {
            ["latest"] = { ref = "hrev60431" },
            ["hrev60431"] = { sha256 = "a5d4eccde4025a42980713320b97ec905759eafdd4679c6ac5022b25d5c9d1c6" },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

local profile = [=[
# Haiku, x86_64 (the package haiku-disk-image). The system is a desktop with no login; its
# boot script keeps a shell on the first serial line (/dev/ports/pc_serial0) with the prompt
# `haiku# '. Its disks are behind the machine's AHCI controller, and the files disk is the
# second (/dev/disk/scsi/0/1/0/raw), read as a tar archive.
name = "haiku-x86_64"

[machine]
arch   = "x86_64"
type   = "q35"
cpu    = "max"
memory = 2048
smp    = 2
bus    = "ide"
image  = "haiku-x86_64.qcow2"

[[boot]]
expect  = "haiku# "
timeout = 600

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
mount = ["mkdir -p /tmp/dirun", "tar xf /dev/disk/scsi/0/1/0/raw -C /tmp/dirun", "cd /tmp/dirun"]
at    = "/tmp/dirun"

[relay]
report = "/tmp/dirun-mtest.ndjson"
]=]

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    local extracted = pkginfo.install_file():replace(".tar.xz", "")
    if not os.isdir(extracted) then
        raise("haiku-disk-image payload not found at " .. extracted)
    end
    os.mv(extracted, dir)
    io.writefile(path.join(dir, "dirun.toml"), profile)
    return os.isfile(path.join(dir, "haiku-x86_64.qcow2"))
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
