-- freebsd-disk-image: the FreeBSD 14.5-RELEASE boot disk, with the profile dirun
-- boots it by (docs/12-disk-image-assets.md, "<system>-disk-image").
--
-- The image is the bytes of the earlier package `freebsd-disk` (The FreeBSD
-- Project's 14.5-RELEASE, installed from the official installer disc, qcow2
-- with zstd-compressed clusters), the same archive and sha; `freebsd-disk` and
-- `freebsd-vm` remain for one cycle and name this package as their successor.
--
-- The profile (`dirun.toml`, beside the image) is the image's description as
-- data: the loader's menu is left for its prompt and the console moved to the
-- serial line, root logs in, a read-only FAT disk of files is mounted at
-- /mnt/dirun, and a test runner's events are written to a file the runner
-- reads back. A runner statement names the package's root:
--
--     dirun --profile {pkg:freebsd-disk-image}/dirun.toml -- {}
--
-- The image is of the host's architecture, which boots it with the host's
-- acceleration (KVM, HVF); x86_64 is published.
package = {
    spec = "2",
    homepage = "https://www.freebsd.org/",
    name = "freebsd-disk-image",
    description = "The FreeBSD Project's 14.5-RELEASE, installed into a bootable qcow2 disk image with a serial console, for emulator runners; with the dirun profile that boots it",
    maintainers = {"https://github.com/xlings-res/freebsd-disk"},
    licenses = {"BSD-2-Clause", "BSD-3-Clause"},
    repo = "https://www.freebsd.org/where/",
    docs = "https://github.com/Sunrisepeak/dirun/blob/main/docs/profiles.md",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"runner", "freebsd"},
    keywords = {"freebsd", "disk-image", "qcow2", "dirun", "runner"},
    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/freebsd-disk/releases/download/${version}/freebsd-disk-${version}.tar.xz",
            CN = "https://gitcode.com/xlings-res/freebsd-disk/releases/download/${version}/freebsd-disk-${version}.tar.xz",
        },
        linux = {
            ["latest"] = { ref = "14.5" },
            ["14.5"] = { sha256 = "7844bcb147fc988c26193d6c91b5db9077edae5d64d63f523e97c9d681f58a49" },
        },
        macosx = {
            ["latest"] = { ref = "14.5" },
            ["14.5"] = { sha256 = "7844bcb147fc988c26193d6c91b5db9077edae5d64d63f523e97c9d681f58a49" },
        },
    },
}

import("xim.libxpkg.pkginfo")

-- How this image boots and runs a command (dirun's profile format).
local profile = [=[
# FreeBSD 14.5-RELEASE, x86_64 (the package freebsd-disk-image). The loader's menu is left for its
# prompt, the console is moved to the serial line, and root logs in on it.
name = "freebsd-14.5-x86_64"

[machine]
arch   = "x86_64"
memory = 1024
smp    = 2
image  = "freebsd-14.5.qcow2"

[[boot]]
expect  = "Autoboot in"
send    = " 3"
line    = false
pace    = 300
timeout = 120

[[boot]]
expect = "OK "
send   = "set console=comconsole"
pace   = 50

[[boot]]
expect = "OK "
send   = "boot"
pace   = 50

[[boot]]
expect  = "login: "
send    = "root"
timeout = 300

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

[files]
mount = ["mkdir -p /mnt/dirun", "mount -r -t msdosfs /dev/vtbd1s1 /mnt/dirun"]
at    = "/mnt/dirun"

[relay]
report = "/tmp/dirun-mtest.ndjson"
]=]

function install()
    local dir = pkginfo.install_dir()
    local image = path.join(dir, "freebsd-14.5.qcow2")
    for _, from in ipairs({
        path.join(path.directory(pkginfo.install_file()), "freebsd-disk-" .. pkginfo.version() .. ".qcow2"),
        path.join(dir, "freebsd-disk-" .. pkginfo.version() .. ".qcow2"),
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
