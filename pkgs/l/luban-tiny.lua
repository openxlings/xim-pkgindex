-- Luban Tiny: minimal userland; rootfs sessions use the host kernel.
--
-- Luban = kernel + xlings + (optional) LubanOS services. A Luban edition is a
-- SubOS that can be the host of a machine; this package is its declaration:
-- the packages its root is made of, its init, and the factory /etc its root
-- starts with. Nothing to download -- install() writes the template.
--
--   xlings subos new mybox --rootfs --from subos:luban-tiny
--   xlings subos use mybox                         # a shell in that root
--   xlings subos export mybox --tar mybox.tar      # docker import / wsl --import
-- Add a kernel package before exporting a bootable disk.
--
-- Editions build on each other: luban-core is `from` this one, luban-desktop
-- from core; a package or file an upper edition carries wins.
package = {
    spec = "2",
    name = "luban-tiny",
    revision = 1,
    namespace = "subos",
    description = "Luban Tiny: a minimal xlings-managed userland of BusyBox, glibc and CA certificates",
    homepage = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},
    type = "subos",
    archs = {"x86_64"},
    status = "stable",
    categories = {"subos", "distribution"},
    keywords = {"luban", "rootfs", "distribution", "busybox", "tiny"},

    xpm = {
        linux = {
            ["latest"] = { ref = "0.2.0" },
            ["0.1.0"] = {},
            ["0.2.0"] = {},
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.system")

local function write(rel, content, mode)
    local file = pkginfo.install_dir() .. "/" .. rel
    os.mkdir(assert(file:match("^(.*)/[^/]+$")))
    local f = io.open(file, "wb")
    if not f then error("cannot write " .. file) end
    assert(f:write(content))
    f:close()
    if mode then system.exec("chmod " .. mode .. " " .. "'" .. file:gsub("'", "'\\''") .. "'") end
end

local manifest = [[
{
  "subos_kind": "rootfs",
  "packages": [
    "xim:busybox@1.35.0",
    "xim:glibc@2.44.3",
    "xim:patchelf@0.18.0",
    "xim:ca-certificates@2026.03.19"
  ],
  "boot": { "init": "/sbin/init" },
  "workspace": {}
}
]]

local F = "usr/share/factory/etc/"

function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())
    local content = manifest
    if pkginfo.version() == "0.1.0" then
        content = content:gsub('"xim:ca%-certificates@2026%.03%.19"', '"xim:ca-certificates@2026.03.19",\n    "xim:linux-kernel@6.8.0-71"')
    end
    write(".xlings.json", content)

    -- busybox init. The console is whatever the kernel's console= names (a
    -- serial port under qemu); one shell there, no login: tiny has no
    -- passwords to check.
    write(F .. "inittab", [[
# Luban tiny (busybox init). Machine state: edit freely, an upgrade never rewrites it.
::sysinit:/etc/init.d/rcS
::askfirst:-/bin/sh -l
::ctrlaltdel:/sbin/reboot
::shutdown:/bin/umount -a -r
# `xlings subos boot <name> --now`: init re-execs stage-0, which hands / to
# that SubOS without restarting the kernel.
::restart:/usr/bin/xlings-init
]])
    write(F .. "init.d/rcS", [[
#!/bin/sh
# Luban tiny's system start -- what stage-0 (xlings-init) left to it.
mkdir -p /dev/pts /dev/shm
mount -t devpts devpts /dev/pts 2>/dev/null
mount -t tmpfs tmpfs /dev/shm 2>/dev/null
[ -r /etc/hostname ] && hostname -F /etc/hostname
ip link set lo up 2>/dev/null
# The first ethernet interface, by DHCP, when there is one.
for dev in /sys/class/net/e*; do
    [ -e "$dev" ] || continue
    udhcpc -q -n -t 3 -i "${dev##*/}" -s /usr/share/udhcpc/default.script >/dev/null 2>&1 &
    break
done
# This boot reached user space: keep booting this SubOS.
xlings subos boot --mark-good >/dev/null 2>&1
# The machine's own additions.
[ -x /etc/rc.local ] && /etc/rc.local
exit 0
]], "755")
    write(F .. "os-release", (([[
NAME="Luban"
ID=luban
VARIANT="Tiny"
VARIANT_ID=tiny
VERSION_ID=0.2.0
PRETTY_NAME="Luban Tiny 0.2.0"
HOME_URL="https://github.com/openxlings/xlings"
]]):gsub("0%.2%.0", pkginfo.version())))
    write(F .. "hostname", "luban\n")
    write(F .. "hosts", "127.0.0.1 localhost luban\n::1 localhost\n")
    write(F .. "profile", [[
export PATH=/usr/local/sbin:/usr/local/bin:/usr/bin
export PS1='\u@\h:\w\$ '
[ -d /etc/profile.d ] && for f in /etc/profile.d/*.sh; do [ -r "$f" ] && . "$f"; done
]])
    write(F .. "nsswitch.conf", "passwd: files\ngroup: files\nshadow: files\nhosts: files dns\n")
    write(F .. "ld.so.conf", "/usr/lib\n/usr/local/lib\n")
    write(F .. "shells", "/bin/sh\n")
    write(F .. "fstab", "# <device> <mount point> <type> <options> <dump> <pass>\n")
    write("usr/lib/sysusers.d/luban.conf", [[
# Luban's base users and groups (sysusers.d; xlings appends the missing ones).
g wheel 10
g users 100
u nobody 65534 "Nobody" / /bin/false
]])
    write("usr/share/udhcpc/default.script", [[
#!/bin/sh
# busybox udhcpc: apply a lease.
case "$1" in
    deconfig) ip addr flush dev "$interface" 2>/dev/null; ip link set "$interface" up ;;
    bound|renew)
        ip addr flush dev "$interface" 2>/dev/null
        ip addr add "$ip/${mask:-24}" dev "$interface"
        [ -n "$router" ] && ip route add default via ${router%% *} dev "$interface" 2>/dev/null
        if [ -n "$dns" ]; then
            : > /etc/resolv.conf
            for d in $dns; do echo "nameserver $d" >> /etc/resolv.conf; done
        fi
        ;;
esac
exit 0
]], "755")
    log.info("luban-tiny template at %s", pkginfo.install_dir())
    return true
end
