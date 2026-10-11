-- Luban's packages in this index (xlings: Luban OS design part 2 §2.1).
--
-- Loaded by package hooks via:
--     import("xim.pkgindex.luban")
--
-- An edition, a policy and a boot profile are DATA: what a root is made of,
-- what isolation compiles to, how an image boots. A recipe declares that data
-- and calls one function here; this is the only code that writes it. So a
-- recipe has nothing to review but its data, the static tests read the data
-- as it is published, and every edition writes its files the same way.
--
--   luban.edition({ id = "core", variant = "Core", versions = versions, files = files })
--       versions[v] = { manifest = <JSON text>, files = <files, optional> }
--       files       = { { "<path in the template>", <content>, <"755", optional> }, ... }
--     writes .xlings.json (the manifest, byte for byte), every file, and
--     usr/share/factory/etc/os-release. A version's own `files` replace the
--     recipe-wide ones. A version the recipe does not list is an error.
--   luban.policy(json)  -- policy.json, byte for byte
--   luban.boot(json)    -- share/luban/boot.json, byte for byte
--
-- A published version's output never changes: tests/fixtures/luban-published.json
-- holds the sha256 of every file each published version writes.

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.log")

local luban = {}

local function quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end

local function write(rel, content, mode)
    local file = pkginfo.install_dir() .. "/" .. rel
    os.mkdir(assert(file:match("^(.*)/[^/]+$")))
    local f = io.open(file, "wb")
    if not f then error("cannot write " .. file) end
    assert(f:write(content))
    f:close()
    if mode then
        if mode ~= "755" and mode ~= "644" then error("luban: mode " .. mode .. " for " .. rel) end
        system.exec("chmod " .. mode .. " " .. quote(file))
    end
end

local function fresh()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())
end

function luban.os_release(id, variant, version)
    return string.format([[
NAME="Luban"
ID=luban
VARIANT="%s"
VARIANT_ID=%s
VERSION_ID=%s
PRETTY_NAME="Luban %s %s"
HOME_URL="https://github.com/openxlings/xlings"
]], variant, id, version, variant, version)
end

local F = "usr/share/factory/etc/"

-- A busybox-init machine: the factory /etc and the rest a root of busybox
-- starts with (luban-tiny, luban-tiny-musl); `init` is the name
-- stage-0 answers to (0.1.0's xlings-init; luban-init since).
function luban.busybox_machine(init)
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

function luban.edition(spec)
    local version = pkginfo.version()
    local this = spec.versions[version]
    if not this then error(string.format("luban-%s: no manifest for %s", spec.id, tostring(version))) end
    fresh()
    write(".xlings.json", this.manifest)
    for _, f in ipairs(this.files or spec.files or {}) do write(f[1], f[2], f[3]) end
    write("usr/share/factory/etc/os-release", luban.os_release(spec.id, spec.variant, version))
    log.info("luban-%s template at %s", spec.id, pkginfo.install_dir())
    return true
end

function luban.policy(json)
    os.mkdir(pkginfo.install_dir())
    write("policy.json", json)
    return os.isfile(pkginfo.install_dir() .. "/policy.json")
end

function luban.boot(json)
    os.mkdir(pkginfo.install_dir())
    write("share/luban/boot.json", json)
    return true
end

return luban
