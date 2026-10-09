package = {
    spec = "2",
    name = "agent-workspace-private",
    namespace = "config",
    description = "Owner-side configuration entry for private Luban Agent workspaces",
    type = "config",
    archs = {"x86_64"},
    status = "stable",
    licenses = {"Apache-2.0"},
    categories = {"subos", "security", "agent"},
    programs = {"agent-workspace-private"},
    xvm_enable = true,
    xpm = { linux = {
        ["latest"] = { ref = "0.1.0" },
        ["0.1.0"] = {},
    } },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

local launcher = [=[#!/bin/sh
set -eu
if [ "${XLINGS_SUBOS_MODE:-}" = sandbox ]; then
    echo 'Apply Agent privacy from the owner side, outside the sandbox' >&2
    exit 2
fi
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo 'Usage: agent-workspace-private NAME socks5h://HOST:PORT [INDEX:agent-private@0.1.0]' >&2
    exit 2
fi
name=$1
proxy=$2
policy=${3:-xim:agent-private@0.1.0}
case "$name" in ''|default|current|*[!a-zA-Z0-9_-]*) echo 'Select a named Luban rootfs' >&2; exit 2;; esac
case "$proxy" in socks5h://*) endpoint=${proxy#socks5h://};; *) echo 'A SOCKS5h endpoint is required; no direct fallback' >&2; exit 2;; esac
host=${endpoint%:*}
port=${endpoint##*:}
case "$host" in ''|*[!a-zA-Z0-9.-]*) echo 'Invalid proxy host; credentials are not accepted' >&2; exit 2;; esac
case "$port" in ''|*[!0-9]*) echo 'Invalid proxy port' >&2; exit 2;; esac
[ "${#port}" -le 5 ] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ] || { echo 'Invalid proxy port' >&2; exit 2; }
case "$policy" in *:agent-private@0.1.0) index=${policy%:agent-private@0.1.0};; *) echo 'Select agent-private@0.1.0 from a trusted index' >&2; exit 2;; esac
case "$index" in ''|*[!a-zA-Z0-9_-]*) echo 'Invalid policy index' >&2; exit 2;; esac
: "${XLINGS_HOME:?Use the xlings-registered owner entry with XLINGS_HOME set}"
[ -d "$XLINGS_HOME/subos/$name/rootfs/etc" ] || { echo 'An existing rootfs instance is required' >&2; exit 2; }
xlings subos config "$name" --sandbox "$policy" --proxy "$proxy" --no-degrade
# User configuration is written INSIDE the selected root, never by a hook
# following host paths. Symlinks cannot redirect these writes into host data.
xlings subos exec "$name" -- /bin/sh -c '
set -eu
[ "$HOME" = /root ] || { echo "Expected rootfs HOME=/root" >&2; exit 2; }
umask 077
for p in /root /root/workspace /root/workspace/PRIVACY.md /root/.cache /root/.local /root/.local/state /root/.claude /root/.claude/settings.json /root/.mcpp /root/.mcpp/config.toml; do
    [ ! -L "$p" ] || { echo "Refusing a symlink in private configuration: $p" >&2; exit 2; }
done
mkdir -p /root/workspace /root/.cache /root/.local/state /root/.claude /root/.mcpp
chmod 700 /root /root/workspace /root/.cache /root/.local /root/.local/state /root/.claude /root/.mcpp
[ -f /root/.claude/settings.json ] || printf "{}\n" > /root/.claude/settings.json
chmod 600 /root/.claude/settings.json
if [ ! -f /root/.mcpp/config.toml ]; then
    # Literal TOML strings keep the logical prefix intact without shell eval.
    apos=$(printf "\047")
    case "$XLINGS_HOME" in *"$apos"*) echo "Unsupported quote in xlings prefix" >&2; exit 2;; esac
    printf "[xlings]\nbinary = \"system\"\nhome = \047%s\047\n\n[toolchain]\ndefault = \047path:%s/data/xpkgs/xim-x-gcc/16.1.0\047\n" "$XLINGS_HOME" "$XLINGS_HOME" > /root/.mcpp/config.toml
fi
chmod 600 /root/.mcpp/config.toml
if [ ! -f /root/workspace/PRIVACY.md ]; then
    printf "%s\n" "# Private Agent workspace" "Configure credentials and Git identity explicitly inside this instance." "Proxy failure must never fall back to direct networking." "Shared-kernel details and application accounts can still identify a user." > /root/workspace/PRIVACY.md
fi
'
echo "Private policy applied to $name; user data retained"
]=]

function install()
    local dir = pkginfo.install_dir()
    os.mkdir(dir)
    local file = dir .. "/agent-workspace-private"
    local f = assert(io.open(file, "wb"))
    assert(f:write(launcher))
    assert(f:close())
    system.exec("chmod 755 '" .. file:gsub("'", "'\\''") .. "'")
    return os.isfile(file)
end

function config()
    xvm.add("agent-workspace-private", {bindir = pkginfo.install_dir()})
    return true
end

function uninstall()
    local ns = pkginfo.install_dir():match("/([^/]+)%-x%-agent%-workspace%-private/[^/]+$")
    local version = pkginfo.version()
    if ns and ns ~= "xim" then version = ns .. ":" .. version end
    xvm.remove("agent-workspace-private", version)
    log.info("User data and the instance's locked security policy are retained")
    return true
end
