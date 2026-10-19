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

-- What an edition declares about itself, checked when a system is made,
-- upgraded, booted and entered and on `luban status --check` (xlings design
-- 2026-10-16 L §11): usr/share/luban/checks.d/<id>.json. Each check is a
-- /bin/sh command inside the system; a critical one that fails stops what
-- was under way. `checks` is the JSON text, as published.
function luban.checks(id, checks)
    return { "usr/share/luban/checks.d/" .. id .. ".json", checks }
end

-- A command that is not there (L §10): the shells' not-found hooks ask one
-- helper, which says whether a package of that name is in the index and
-- which command here is a typo or two away (xlnigs -> xlings).
luban.COMMAND_NOT_FOUND = [==[
#!/bin/sh
# A command that is not here (Luban): say so, then what it may be -- a
# package of that name in the index (xlings install), or a command here a
# typo or two away. Called by the shells' not-found hooks; exits 127.
cmd="$1"
printf '%s: command not found\n' "$cmd" >&2
[ -n "$cmd" ] || exit 127
case "$cmd" in */*) exit 127 ;; esac
if command -v xlings >/dev/null 2>&1 && xlings info "$cmd" >/dev/null 2>&1; then
    printf '  a package has it: xlings install %s\n' "$cmd" >&2
fi
near="$(
    IFS=:
    for d in $PATH; do [ -d "$d" ] && ls "$d" 2>/dev/null; done | sort -u | awk -v w="$cmd" '
    function dist(a, b,    la, lb, i, j, c, d, x, y, z, prev, cur, k) {
        la = length(a); lb = length(b)
        for (j = 0; j <= lb; j++) prev[j] = j
        for (i = 1; i <= la; i++) {
            cur[0] = i
            for (j = 1; j <= lb; j++) {
                c = (substr(a, i, 1) == substr(b, j, 1)) ? 0 : 1
                x = prev[j] + 1; y = cur[j - 1] + 1; z = prev[j - 1] + c
                d = x < y ? x : y; cur[j] = d < z ? d : z
                # A swap of two neighbours counts once (xlnigs -> xlings).
                if (i > 1 && j > 1 && substr(a, i, 1) == substr(b, j - 1, 1) && substr(a, i - 1, 1) == substr(b, j, 1) && pp[j - 2] + 1 < cur[j]) cur[j] = pp[j - 2] + 1
            }
            for (k = 0; k <= lb; k++) { pp[k] = prev[k]; prev[k] = cur[k] }
        }
        return prev[lb]
    }
    { gap = length($0) - length(w) }
    length($0) > 1 && $0 != w && gap >= -2 && gap <= 2 {
        n = dist(w, $0); if (n <= 2) print n " " $0
    }' | sort -n | head -3 | awk '{ printf "%s%s", (NR > 1 ? ", " : ""), $2 }'
)"
[ -n "$near" ] && printf '  did you mean: %s\n' "$near" >&2
exit 127
]==]

function luban.command_not_found()
    return {
        { "usr/libexec/luban/command-not-found", luban.COMMAND_NOT_FOUND, "755" },
        { "usr/share/fish/vendor_functions.d/fish_command_not_found.fish", [[
# Luban: what a command that is not here may be (/usr/libexec/luban/command-not-found).
function fish_command_not_found
    /usr/libexec/luban/command-not-found $argv[1]
end
]] },
        { F .. "profile.d/luban-command-not-found.sh", [[
# Luban: what a command that is not here may be, in bash (fish has its own
# hook; /usr/libexec/luban/command-not-found answers both).
if [ -n "$BASH_VERSION" ]; then
    command_not_found_handle() { /usr/libexec/luban/command-not-found "$1"; }
fi
]] },
    }
end

-- mcpp in a Luban system (mcpp design 2026-10-16 §9.5): the system's own
-- home is its upstream, so the gcc and glibc the system has are borrowed and
-- a first build downloads no toolchain. An mcpp before 2026.10.16.1 does not
-- read /etc/mcpp.
-- The default toolchain names its target: the system's gcc is the glibc
-- one, which a bare gcc@16.1.0 does not name on aarch64 (mcpp's default
-- there is musl).
luban.MCPP_CONFIG = [[
# mcpp in this Luban system: what the system has (its gcc, its glibc, in
# /xlings) is used, not downloaded again; ~/.mcpp/config.toml wins.
[xlings]
upstream = ["/xlings"]

[toolchain]
default = "gcc@16.1.0"
default_target = "%s-linux-gnu"
]]

-- The machine's: the catalog loader names it (os.arch, is_arch), an install
-- hook's runtime does (_RUNTIME.arch), and uname answers anywhere a command
-- runs. Falling back to x86_64 alone named an x86_64 target on aarch64, which
-- mcpp refused there ("target 'x86_64-linux-gnu' cannot be built on this
-- host").
function luban.mcpp_config()
    local function canonical(a)
        a = a and tostring(a):gsub("%s+", "") or ""
        if a == "arm64" then return "aarch64" end
        if a == "x64" or a == "amd64" then return "x86_64" end
        return (a == "aarch64" or a == "x86_64") and a or nil
    end
    local arch = canonical(os.arch and os.arch())
        or canonical(type(_RUNTIME) == "table" and _RUNTIME.arch)
        or (type(is_arch) == "function" and (is_arch("aarch64") or is_arch("arm64")) and "aarch64")
        or canonical(os.iorun and os.iorun("uname -m"))
        or "x86_64"
    return { F .. "mcpp/config.toml", string.format(luban.MCPP_CONFIG, arch) }
end

-- A list of files, then more (a version's files are a recipe's plus its own).
function luban.with(files, ...)
    local out = {}
    for _, f in ipairs(files) do table.insert(out, f) end
    for _, more in ipairs({ ... }) do
        if #more == 0 then
            -- nothing more
        elseif type(more[1]) == "table" then
            for _, f in ipairs(more) do table.insert(out, f) end
        else
            table.insert(out, more)
        end
    end
    return out
end

-- A manifest written from a table (the luban: editions; xlings design
-- 2026-10-18 §4.3): its keys in the order a person reads them, a nested
-- object on one line with its keys sorted, an array one item a line.
local ORDER = { "subos_kind", "min_client", "from", "replaces", "abi", "packages", "boot", "policy", "luban", "workspace" }

local function json_string(v)
    return '"' .. tostring(v):gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
end

local function json_inline(v)
    if type(v) == "string" then return json_string(v) end
    if type(v) == "boolean" or type(v) == "number" then return tostring(v) end
    if type(v) ~= "table" then error("luban.manifest: a " .. type(v)) end
    if #v > 0 then
        local items = {}
        for _, x in ipairs(v) do table.insert(items, json_inline(x)) end
        return "[" .. table.concat(items, ", ") .. "]"
    end
    local keys = {}
    for k in pairs(v) do table.insert(keys, k) end
    table.sort(keys)
    if #keys == 0 then return "{}" end
    local items = {}
    for _, k in ipairs(keys) do table.insert(items, json_string(k) .. ": " .. json_inline(v[k])) end
    return "{ " .. table.concat(items, ", ") .. " }"
end

function luban.manifest(m)
    local lines = {}
    for _, k in ipairs(ORDER) do
        local v = m[k]
        if v ~= nil then
            if k == "packages" then
                local items = {}
                for _, p in ipairs(v) do table.insert(items, "    " .. json_string(p)) end
                table.insert(lines, '  "packages": [' .. (#items > 0 and ("\n" .. table.concat(items, ",\n") .. "\n  ]") or "]"))
            else
                table.insert(lines, "  " .. json_string(k) .. ": " .. json_inline(v))
            end
        end
    end
    for k in pairs(m) do
        local known = false
        for _, o in ipairs(ORDER) do known = known or o == k end
        if not known then error("luban.manifest: an unknown key " .. k) end
    end
    return "{\n" .. table.concat(lines, ",\n") .. "\n}\n"
end

function luban.edition(spec)
    local version = pkginfo.version()
    local this = spec.versions[version]
    if not this then error(string.format("luban-%s: no manifest for %s", spec.id, tostring(version))) end
    fresh()
    if type(this.manifest) == "table" then
        -- What it presets (luban.settings) is also the root's
        -- usr/share/luban/settings.json, which a luban before the manifest's
        -- `luban` object reads.
        local settings = this.manifest.luban and this.manifest.luban.settings
        if settings then write("usr/share/luban/settings.json", json_inline(settings) .. "\n") end
        write(".xlings.json", luban.manifest(this.manifest))
    else
        write(".xlings.json", this.manifest)
    end
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
