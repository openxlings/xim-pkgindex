-- Luban Tiny: the smallest Luban userland -- BusyBox, glibc, CA certificates,
-- busybox init -- over luban-nano's xlings and luban (Luban design §A4, §6).
--
-- An edition is a SubOS template: the packages its root is made of, its ABI,
-- its init, the factory /etc it starts with, and the boot profile an image of
-- it uses. Nothing to download -- install() writes the template (data here,
-- the writing in libs/luban.lua).
--
--   luban new box tiny                   # (xlings subos new box --from subos:luban-tiny)
--   luban enter box
--   luban export box box.iso             # a live ISO; box.img: a drive
--
-- The kernel is the machine's, not the edition's (§A6). 0.1.0 carried it in
-- the root, was published so, and stays so: a published version's output
-- never changes (tests/fixtures/luban-published.json).
package = {
    spec = "2",
    name = "luban-tiny",
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
            ["latest"] = { ref = "2026.10.10.1" },
            ["0.1.0"] = {},
            ["2026.10.10.1"] = {},
        },
    },
}

import("xim.pkgindex.luban")

local F = "usr/share/factory/etc/"

-- The factory /etc and the rest a tiny root starts with; `init` is the name
-- stage-0 answers to (0.1.0's xlings-init; luban-init since).
local function files(init)
    local function named(text) return (text:gsub("xlings%-init", init)) end
    return {
        { F .. "inittab", named([[
# Luban tiny (busybox init). Machine state: edit freely, an upgrade never rewrites it.
::sysinit:/etc/init.d/rcS
::askfirst:-/bin/sh -l
::ctrlaltdel:/sbin/reboot
::shutdown:/bin/umount -a -r
# `xlings subos boot <name> --now`: init re-execs stage-0, which hands / to
# that SubOS without restarting the kernel.
::restart:/usr/bin/xlings-init
]]) },
        { F .. "init.d/rcS", named([[
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
]]), "755" },
        { F .. "hostname", "luban\n" },
        { F .. "hosts", "127.0.0.1 localhost luban\n::1 localhost\n" },
        { F .. "profile", [[
export PATH=/usr/local/sbin:/usr/local/bin:/usr/bin
export PS1='\u@\h:\w\$ '
[ -d /etc/profile.d ] && for f in /etc/profile.d/*.sh; do [ -r "$f" ] && . "$f"; done
]] },
        { F .. "nsswitch.conf", "passwd: files\ngroup: files\nshadow: files\nhosts: files dns\n" },
        { F .. "ld.so.conf", "/usr/lib\n/usr/local/lib\n" },
        { F .. "shells", "/bin/sh\n" },
        { F .. "fstab", "# <device> <mount point> <type> <options> <dump> <pass>\n" },
        { "usr/lib/sysusers.d/luban.conf", [[
# Luban's base users and groups (sysusers.d; xlings appends the missing ones).
g wheel 10
g users 100
u nobody 65534 "Nobody" / /bin/false
]] },
        { "usr/share/udhcpc/default.script", [[
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
]], "755" },
    }
end

local versions = {
    ["0.1.0"] = { files = files("xlings-init"), manifest = [[
{
  "subos_kind": "rootfs",
  "packages": [
    "xim:busybox@1.35.0",
    "xim:glibc@2.44.3",
    "xim:patchelf@0.18.0",
    "xim:ca-certificates@2026.03.19",
    "xim:linux-kernel@6.8.0-71"
  ],
  "boot": { "init": "/sbin/init" },
  "workspace": {}
}
]] },
    ["2026.10.10.1"] = { files = files("luban-init"), manifest = [[
{
  "subos_kind": "rootfs",
  "min_client": "2026.10.10.3",
  "from": "subos:luban-nano@2026.10.10.1",
  "abi": "x86_64-linux-gnu",
  "packages": [
    "xim:busybox@1.35.0",
    "xim:glibc@2.44.3",
    "xim:patchelf@0.18.0",
    "xim:ca-certificates@2026.03.19"
  ],
  "boot": { "init": "/sbin/init", "kernel": "xim:linux-kernel@6.8.0-71", "kernel_min": "5.10" },
  "workspace": {}
}
]] },
}

function install()
    return luban.edition({ id = "tiny", variant = "Tiny", versions = versions })
end
