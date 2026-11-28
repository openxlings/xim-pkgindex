package = {
    spec = "2",
    homepage = "https://github.com/Sunrisepeak/svr4-386-src",
    name = "svr4-disk-image",
    description = "EXPERIMENTAL, technical verification only: AT&T UNIX System V/386 Release 4.0 Version 3.0, installed from its floppy set (proprietary, re-hosted unchanged) into a qcow2 disk with a root shell on the serial line, for emulator runners; with the dirun profile that boots it",

    maintainers = {"https://github.com/Sunrisepeak"},
    licenses = {"LicenseRef-proprietary-not-redistributed"},
    repo = "https://github.com/Sunrisepeak/svr4-386-src",
    docs = "https://github.com/Sunrisepeak/dirun/blob/main/docs/profiles.md",

    type = "package",
    archs = {"x86_64"},
    status = "dev",
    categories = {"runner", "svr4"},
    keywords = {"svr4", "system-v", "unix", "disk-image", "qcow2", "dirun", "runner", "experimental"},

    -- A DISK-IMAGE ASSET (docs/12-disk-image-assets.md). EXPERIMENTAL: TECHNICAL VERIFICATION ONLY.
    --
    -- The system is proprietary, and the repository this recipe records (`repo`) states no
    -- licence for its floppy set. The package exists so that one measurement can be repeated: a
    -- program of `i686-svr4-musl` (openkal-svr4) on a System V kernel. It may be disabled or
    -- removed at any time, and `config` says so each time it is installed. xlings re-hosts the
    -- bytes unchanged, from GitHub for the world and GitCode in China.
    --
    -- Revision 1 is the image: the system installed by its own installer from the floppy set
    -- (.agents/tools/build-svr4-disk-image.py; PROVENANCE.md in the archive), with a root shell
    -- on its first serial line, and the label of a run's files disk beside it (files-label.bin:
    -- the system's disk driver reads a disk only through its own label). dirun 0.8.0 or later
    -- boots it (`[files] label`). Revision 0, the floppy set with a program that installed it on
    -- the user's machine, stays published as the builder's input; an installed revision 0 is not
    -- an image, so `floor = 1`.
    xpm = {
        linux = {
            ["latest"] = { ref = "4.0.3-20261119" },
            ["4.0.3-20261119"] = {
                revision = 1,
                floor = 1,
                url = {
                    GLOBAL = "https://github.com/xlings-res/svr4-disk-image/releases/download/4.0.3-20261119-r1/svr4-disk-image-4.0.3-20261119-r1.tar.xz",
                    CN = "https://gitcode.com/xlings-res/svr4-disk-image/releases/download/4.0.3-20261119-r1/svr4-disk-image-4.0.3-20261119-r1.tar.xz",
                },
                sha256 = "c8cfc82adf2333bb3b711826436a7975ef10d7138291f4f9611dc4e5c1cb3282",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

local profile = [=[
# AT&T UNIX System V/386 Release 4.0 Version 3.0 (the package svr4-disk-image). TECHNICAL
# VERIFICATION ONLY: the system is proprietary. A root shell waits on the first serial line, with
# no login (/etc/inittab: /etc/serialsh). The system has no virtio driver: its disks are behind the
# machine's IDE controller. Its disk driver reads a disk only through the system's own label, so a
# run's files disk begins with that label (files-label.bin, from the installed disk) and the archive
# is read from the slice where the label puts swap, raw (dirun 0.8.0 or later). The kernel does not
# start with 256 MiB of memory or more.
name = "svr4-i386"

[machine]
arch   = "i386"
type   = "pc"
cpu    = "pentium"
memory = 64
smp    = 1
bus    = "ide"
format = "qcow2"
image  = "svr4.qcow2"

[[boot]]
expect  = "svr4# "
timeout = 300

[command]
line    = "echo @@BEG''IN@@; {env}{argv} < /dev/null; echo @@STA''TUS=$?@@"
env     = "env {assignments} "
quote   = "posix"
begin   = "@@BEGIN@@"
status  = "@@STATUS=(\\d+)@@"
line-max = 200
script   = "sh {script}"

[files]
form   = "tar"
label  = "files-label.bin"
offset = 5870592
size   = 73479168
mount  = ["mkdir /tmp/dirun", "(cd /tmp/dirun && tar xf /dev/rdsk/1s2)", "cd /tmp/dirun"]
at     = "/tmp/dirun"

[relay]
report = "/tmp/dirun-mtest.ndjson"
]=]

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    local extracted = pkginfo.install_file():replace(".tar.xz", "")
    if not os.isdir(extracted) then
        raise("svr4-disk-image: the payload was not found at " .. extracted)
    end
    os.mv(extracted, dir)
    io.writefile(path.join(dir, "dirun.toml"), profile)
    return os.isfile(path.join(dir, "svr4.qcow2")) and os.isfile(path.join(dir, "files-label.bin"))
end

-- Data, not a program: the package name is registered so a home knows it has it; a runner names
-- the files under its root. The notice is written each time, which is the condition this
-- package is kept on.
function config()
    xvm.add(package.name)
    local dir = pkginfo.install_dir()
    log.warn("svr4-disk-image: EXPERIMENTAL, TECHNICAL VERIFICATION ONLY.")
    log.warn("  AT&T UNIX System V/386 Release 4.0 is proprietary software. This image is installed from")
    log.warn("  its floppy set, re-hosted unchanged by xlings from a third party's repository, which states")
    log.warn("  no licence; xlings grants no right to use it. This package may be disabled or removed at")
    log.warn("  any time. What it is and how it is rebuilt: %s", path.join(dir, "README.md"))
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
