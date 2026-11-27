package = {
    spec = "2",
    homepage = "https://puredarwin.org/",
    name = "puredarwin-disk-image",
    description = "EXPERIMENTAL, a temporary technical test: PureDarwin's minimal developer-preview image (x86_64, xnu-12377), as its project publishes it, for emulator runners; with the dirun profile that boots it",

    maintainers = {"https://github.com/PureDarwin/PureDarwin/graphs/contributors"},
    licenses = {"APSL-2.0", "BSD-2-Clause"},
    repo = "https://github.com/PureDarwin/PureDarwin",
    docs = "https://github.com/Sunrisepeak/dirun/blob/main/docs/profiles.md",

    type = "package",
    archs = {"x86_64"},
    status = "dev",
    categories = {"runner", "darwin"},
    keywords = {"puredarwin", "darwin", "xnu", "disk-image", "dirun", "runner", "experimental"},

    -- EXPERIMENTAL: A TEMPORARY TECHNICAL TEST, AND NOT A DISK-IMAGE ASSET OF THE CLASS
    -- (docs/12-disk-image-assets.md) IN TWO RESPECTS.
    --
    -- It is not mirrored. The project states no terms for redistributing its images (its own
    -- code is BSD-licensed, Apple's is under the APSL), so the bytes are fetched from where the
    -- project serves them, and both sources below name that one place.
    --
    -- It is not a release. The project has no stable release; this is a developer preview of
    -- its `upstream-xnu-12377` branch, served under one name that the project replaces. The
    -- digest is the one measured on 2026-11-18 (the project's page stated another): when the
    -- file is replaced, the install stops at the digest, and this recipe is then revised or
    -- removed.
    --
    -- The image is used as published. It boots by UEFI to a root shell on the serial line, so
    -- the runner gives the profile a firmware (`--var firmware=<OVMF code image>`). dirun 0.7.0
    -- or later boots it (`bus = "ide"`, `form = "tar"`).
    xpm = {
        linux = {
            ["latest"] = { ref = "25.5-20261118-1" },
            -- r1: the files disk is found as the one disk without slices. The system numbers its two
            -- disks in either order from one boot to the next (measured: rdisk1 was the image's in one
            -- boot of three), and 25.5-20261118 read rdisk1, so a run sometimes found no program
            -- (status 127 from the shell). The image is the same bytes.
            ["25.5-20261118-1"] = {
                revision = 1,
                url = {
                    GLOBAL = "https://internal.lab004.dev/private/images/puredarwin-25.5-minimal.img",
                    CN = "https://internal.lab004.dev/private/images/puredarwin-25.5-minimal.img",
                },
                sha256 = { x86_64 = "522bfca10026b83dcf5d5232f143fbe65f0001771d4e2668386bb3f13613267a" },
            },
            ["25.5-20261118"] = {
                url = {
                    GLOBAL = "https://internal.lab004.dev/private/images/puredarwin-25.5-minimal.img",
                    CN = "https://internal.lab004.dev/private/images/puredarwin-25.5-minimal.img",
                },
                sha256 = { x86_64 = "522bfca10026b83dcf5d5232f143fbe65f0001771d4e2668386bb3f13613267a" },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

local profile = [=[
# PureDarwin, x86_64 (the package puredarwin-disk-image): the project's minimal developer-preview
# image, as published. It boots by UEFI to a root shell on the serial line. The disks are behind
# the machine's AHCI controller. The files are a tar archive on the disk that has no slices (the
# system numbers the two disks in either order from one boot to the next), unpacked into
# /tmp: a file on the system's FAT mount is not executable. The image's own file system has about
# seven megabytes free, which is the room a delivered program and what it writes have.
name = "puredarwin-x86_64"

[machine]
arch   = "x86_64"
type   = "q35"
cpu    = "Haswell-noTSX,vendor=GenuineIntel"
memory = 4096
smp    = 2
bus    = "ide"
format = "raw"
args   = ["-drive", "if=pflash,format=raw,readonly=on,file={firmware}"]
image  = "puredarwin-minimal.img"

[[boot]]
expect  = "root@localhost[^\\n]*# "
timeout = 600

[command]
line    = "echo @@BEG''IN@@; {env}{argv} < /dev/null; echo @@STATUS''=$?@@"
env     = "env {assignments} "
quote   = "posix"
begin   = "@@BEGIN@@"
status  = "@@STATUS=(\\d+)@@"
line-max = 200
script   = "sh {script}"

[files]
form  = "tar"
mount = ["mkdir -p /tmp/dirun", "for x in /dev/rdisk[0-9]; do [ -e \"$x\"s1 ] || d=$x; done; dd if=$d bs=1048576 2>/dev/null | tar xf - -C /tmp/dirun", "cd /tmp/dirun"]
at    = "/tmp/dirun"

[relay]
report = "/tmp/dirun-mtest.ndjson"
]=]

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mkdir(dir)
    local image = pkginfo.install_file()
    if not os.isfile(image) then
        raise("puredarwin-disk-image: the image was not fetched: " .. image)
    end
    os.mv(image, path.join(dir, "puredarwin-minimal.img"))
    io.writefile(path.join(dir, "dirun.toml"), profile)
    return os.isfile(path.join(dir, "puredarwin-minimal.img"))
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
