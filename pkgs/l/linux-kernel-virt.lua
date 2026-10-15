package = {
    spec = "1",

    homepage = "https://www.kernel.org",
    name = "linux-kernel-virt",
    description = "A Linux 6.12 LTS kernel for virtual machines (Luban's virt boot profile): virtio, virtio-fs, ext4, initramfs and the serial console built in, no modules",

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
            ["latest"] = { ref = "6.12.112-r1" },
            -- r1: kernel-virt.config adds FUSE_FS and VIRTIO_FS -- a Mac's Luban
            -- host machine and its machines share by virtio-fs (xlings: Luban
            -- OS part 4 §6.6). The same 6.12.112 source; its release is 6.12.112-virt.
            ["6.12.112-r1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "e5cc9036e22f41be9fbd44e9764bcab08af2ea4fbd8b3e152e0b8558df28b2c7",
                    aarch64 = "c071d6eebf8c9f140019a201612481bbb83b035fbdd587684a3ae2fc617c852d",
                },
            },
            ["6.12.112"] = {
                -- 1: its scope link is lib/vmlinuz-virt -- linux-kernel's is
                -- lib/vmlinuz, and two sources for one link refused the
                -- scope's next sysroot update.
                revision = 1,
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

-- lib/modules/<release>: the kernel's own release name (6.12.112-virt for
-- 6.12.112 and its config revisions, 6.12.112-r1, alike).
local function modules_dir()
    local base = path.join(pkginfo.install_dir(), "lib", "modules")
    for _, d in ipairs(os.dirs(path.join(base, "*")) or {}) do return d end
    return path.join(base, pkginfo.version() .. "-virt")
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
    -- Its own name for the scope's lib/ (linux-kernel's is vmlinuz): two
    -- kernels in one scope are two names, not two sources for one.
    local own = path.join(modules_dir(), "vmlinuz-virt")
    if not os.isfile(own) then os.execute(string.format([[ln -sf vmlinuz "%s"]], own)) end
    return os.isfile(path.join(modules_dir(), "vmlinuz")) and os.isfile(own)
end

function config()
    -- A library entry, not a program: a root's projection takes the
    -- payload's lib/modules from it.
    xvm.add("linux-kernel-virt", {
        type = "lib",
        bindir = modules_dir(),
        filename = "vmlinuz-virt",
        alias = "vmlinuz-virt",
    })
    return true
end

function uninstall()
    xvm.remove("linux-kernel-virt")
    return true
end
