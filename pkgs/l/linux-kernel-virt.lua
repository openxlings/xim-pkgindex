package = {
    spec = "1",

    homepage = "https://www.kernel.org",
    name = "linux-kernel-virt",
    description = "A Linux 6.12 LTS kernel for virtual machines (Luban's virt boot profile): virtio, ext4, initramfs and the serial console built in, no modules",

    authors = {"Linus Torvalds and the kernel community"},
    licenses = {"GPL-2.0-only"},
    repo = "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"system", "kernel"},
    keywords = {"linux", "kernel", "vmlinuz", "luban", "virt", "qemu", "kvm"},

    -- kernel.org's linux-6.12.x (checked against its sha256sums.asc), the
    -- architecture's defconfig + kvm_guest.config + tools/res/kernel-virt.config,
    -- built by this index on the architecture itself (tools/res/build.sh,
    -- res-build.yml). At the systemd location lib/modules/<release>/vmlinuz
    -- (with its config); a root links it at /usr/lib/modules/<release>.
    -- A VM boots it with nothing to load -- what luban try and the L3 private
    -- machine need; a real machine's hardware is linux-kernel's (generic).
    xpm = {
        linux = {
            ["latest"] = { ref = "6.12.112" },
            ["6.12.112"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "2bc2642c524ea758ac44bc8a6044c9a66b41e65921522cdf369e210679ffa8a9",
                    aarch64 = "d22bc60224590e4658e155c04bba395fd4fefa4c28d6c11f445685db4c54690c",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

local function modules_dir()
    return path.join(pkginfo.install_dir(), "lib", "modules", pkginfo.version() .. "-virt")
end

function install()
    local dir = pkginfo.install_dir()
    if not os.isfile(path.join(modules_dir(), "vmlinuz")) then
        local payload = "linux-kernel-virt-" .. pkginfo.version()
        if os.isdir(payload) then
            os.tryrm(dir)
            os.mv(payload, dir)
        end
    end
    return os.isfile(path.join(modules_dir(), "vmlinuz"))
end

function config()
    -- A library entry, not a program: a root's projection takes the
    -- payload's lib/modules from it.
    xvm.add("linux-kernel-virt", {
        type = "lib",
        bindir = modules_dir(),
        filename = "vmlinuz",
        alias = "vmlinuz",
    })
    return true
end

function uninstall()
    xvm.remove("linux-kernel-virt")
    return true
end
