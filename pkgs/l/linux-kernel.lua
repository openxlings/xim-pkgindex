package = {
    spec = "1",

    homepage = "https://www.kernel.org",
    name = "linux-kernel",
    description = "A prebuilt Linux kernel for SubOS roots that boot (Luban): virtio, ext4 and the serial console built in, no initramfs needed",

    authors = {"Linus Torvalds and the kernel community", "Canonical (the build)"},
    licenses = {"GPL-2.0-only"},
    repo = "https://git.launchpad.net/~ubuntu-kernel/ubuntu/+source/linux/+git/noble",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"system", "kernel"},
    keywords = {"linux", "kernel", "vmlinuz", "luban", "boot"},

    -- Ubuntu 24.04's linux-image-unsigned-6.8.0-71-generic vmlinuz, unchanged,
    -- at the systemd location lib/modules/<version>/vmlinuz (README.provenance
    -- in the payload). A SubOS root links it at /usr/lib/modules/<version>;
    -- `xlings subos export <n> --disk` makes the disk it boots
    -- (`qemu -kernel <that vmlinuz> -append "root=/dev/vda init=<home>/boot/xlings-init"`).
    -- Repackaged rather than built: the kernel does not link the xlings
    -- glibc, and a build would be the longest chain in the index for nothing
    -- a Luban root needs today.
    xpm = {
        linux = {
            ["latest"] = { ref = "6.8.0-71" },
            ["6.8.0-71"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "4ea42ed2af2cb9e3fb7ddca58e1da2d683b52a364ffc425d9b457c79b30b45dc" },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

local function modules_dir()
    return path.join(pkginfo.install_dir(), "lib", "modules", pkginfo.version() .. "-generic")
end

function install()
    local dir = pkginfo.install_dir()
    if not os.isfile(path.join(modules_dir(), "vmlinuz")) then
        local payload = "linux-kernel-" .. pkginfo.version()
        if os.isdir(payload) then
            os.tryrm(dir)
            os.mv(payload, dir)
        end
    end
    return os.isfile(path.join(modules_dir(), "vmlinuz"))
end

function config()
    -- A library entry, not a program: nothing to run, and a root's
    -- projection takes the payload's lib/modules from it.
    xvm.add("linux-kernel", {
        type = "lib",
        bindir = modules_dir(),
        filename = "vmlinuz",
        alias = "vmlinuz",
    })
    return true
end

function uninstall()
    xvm.remove("linux-kernel")
    return true
end
