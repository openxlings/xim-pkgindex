-- luban-boot-virt: how a Luban image boots in a virtual machine (xlings: Luban
-- OS design part 2 §2.4) -- linux-kernel-virt (virtio, ext4, the console
-- built in; nothing to load), limine, and the command line a VM's serial
-- console wants. `luban try` uses it; `luban export box x.iso --boot virt`
-- asks for it. Data, written by libs/luban.lua.
package = {
    spec = "2",
    name = "luban-boot-virt",
    description = "Luban boot profile for virtual machines: the virt kernel, limine, a serial console",
    homepage = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"system", "boot", "luban"},
    keywords = {"luban", "boot", "virt", "qemu", "kvm", "kernel"},
    xpm = {
        linux = {
            deps = { runtime = { "xim:linux-kernel-virt@6.12.112", "xim:limine@12.9.3" } },
            ["latest"] = { ref = "2026.10.10.1" },
            ["2026.10.10.1"] = {},
        },
    },
}

import("xim.pkgindex.luban")

-- The console a VM has: the 16550 (ttyS0) on x86_64, the PL011 (ttyAMA0) on
-- qemu's arm virt machine. Both are named; the kernel skips the one the
-- machine does not have.
function install()
    return luban.boot([[
{ "profile": "virt", "release": "6.12.112-virt",
  "cmdline": ["console=ttyS0", "console=ttyAMA0", "panic=-1"] }
]])
end
