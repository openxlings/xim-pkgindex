package = {
    spec = "1",

    name = "apple-device-tools",
    description = "devicectl-run: install a signed .app on a connected iOS device and launch it, as a `runner` argv prefix.",

    authors = {"mcpplibs"},
    maintainers = {"d2learn"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/openxlings/xim-pkgindex",

    -- WHAT THIS PACKAGE IS FOR, AND WHY IT IS A PACKAGE.
    --
    -- The device counterpart of `apple-simulator-tools`. mcpp's `runner` is an
    -- argv prefix, and `mcpp run --target aarch64-ios --format app` hands the
    -- runner a signed bundle. Running that bundle on hardware is a session --
    -- choose a connected device, install the bundle, launch it by its bundle
    -- identifier, attach its output -- which a manifest cannot express as a
    -- flag, exactly the argument `apple-simulator-tools` makes for simulators.
    -- mcpp:plugins' `dist-apple` supplies this runner under the name `app` on
    -- the device row, so a project names neither the program nor a path.
    --
    -- macOS ONLY. `devicectl` ships inside Xcode (15 and newer), talks to the
    -- CoreDevice service of the machine running it, and has no counterpart to
    -- package: this program only drives it, the category the index's
    -- host-surface rule permits for a proprietary runtime that exists on one
    -- OS -- named here rather than reached by a fallthrough.
    --
    -- WHAT IS AND IS NOT MEASURED. The script parses (`bash -n` at install
    -- time), and its refusals -- no xcrun, no devicectl, no bundle, no
    -- connected device -- are checked on a macOS runner with no device
    -- attached. Installing and launching on hardware needs a device, a
    -- provisioning profile and a signing identity, none of which a hosted CI
    -- runner has, so that path is written from `devicectl`'s own help text and
    -- is not yet measured. In particular, whether `process launch --console`
    -- reports the launched program's exit status is unmeasured; this runner
    -- returns what `devicectl` returns, and says so when it launches, so a
    -- test result read through it is not mistaken for the program's own until
    -- that has been measured -- the discipline `apple-simulator-tools` 0.3.0
    -- applied to `simctl launch`.
    --
    -- DEVICE SELECTION. `DEVICECTL_RUN_DEVICE` names a device by the
    -- identifier, UDID or name `xcrun devicectl list devices` prints; unset,
    -- the first iOS device whose tunnel is connected is used. The same shape
    -- as `SIMCTL_RUN_UDID` in `apple-simulator-tools`.

    type = "script",
    archs = {"aarch64"},
    status = "stable",
    categories = {"apple", "ios", "device", "runner"},
    keywords = {"ios", "device", "devicectl", "runner", "mcpp"},

    xpm = {
        macosx = {
            ["latest"] = { ref = "0.1.0" },
            ["0.1.0"] = { },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

local __devicectl_run_sh = [==[
#!/usr/bin/env bash
# devicectl-run --- install a signed .app on a connected iOS device and launch it.
#
# Usage:  devicectl-run <bundle.app> [arguments...]
#
# Used as an mcpp `runner` argv prefix; mcpp:plugins' dist-apple supplies it
# under the name `app` on the aarch64-ios row.
#
# THE EXIT STATUS. Usage errors and refusals exit 2. Otherwise the status is
# the one `xcrun devicectl device process launch --console` returns; whether
# that is the launched program's own status is not yet measured, and this
# program prints one line saying so before it launches.
set -uo pipefail

if [ "$#" -lt 1 ]; then
    echo "devicectl-run: usage: devicectl-run <bundle.app> [arguments...]" >&2
    exit 2
fi

app="$1"; shift

if [[ "$app" != *.app ]] || [ ! -d "$app" ]; then
    echo "devicectl-run: $app is not a .app bundle directory" >&2
    exit 2
fi

if ! command -v xcrun > /dev/null 2>&1; then
    echo "devicectl-run: no xcrun on this machine. devicectl ships inside Xcode;" >&2
    echo "               there is no package for it and this program only drives it." >&2
    exit 2
fi

if ! xcrun devicectl --version > /dev/null 2>&1; then
    echo "devicectl-run: xcrun finds no devicectl. It ships with Xcode 15 and newer;" >&2
    echo "               select one with xcode-select." >&2
    exit 2
fi

bundle_id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist" 2>/dev/null)
if [ -z "$bundle_id" ]; then
    echo "devicectl-run: could not read CFBundleIdentifier from $app/Info.plist" >&2
    exit 2
fi

platforms=$(/usr/libexec/PlistBuddy -c 'Print CFBundleSupportedPlatforms' "$app/Info.plist" 2>/dev/null)
if [[ "$platforms" == *iPhoneSimulator* ]]; then
    echo "devicectl-run: $app is a simulator bundle (CFBundleSupportedPlatforms names" >&2
    echo "               iPhoneSimulator); run it with simctl-run instead." >&2
    exit 2
fi

# `--json-output` and a JSON walk rather than the human table, for the reason
# `apple-simulator-tools` gives: the table's layout is not an interface.
listing=$(mktemp -t devicectl-run)
trap 'rm -f "$listing"' EXIT
if ! xcrun devicectl list devices --json-output "$listing" > /dev/null 2>&1; then
    echo "devicectl-run: \`xcrun devicectl list devices\` failed" >&2
    exit 2
fi

device=$(python3 - "$listing" "${DEVICECTL_RUN_DEVICE:-}" <<'PY'
import json, sys
path, wanted = sys.argv[1], sys.argv[2]
try:
    devices = json.load(open(path)).get("result", {}).get("devices", [])
except Exception:
    sys.exit(0)
def names(d):
    hw = d.get("hardwareProperties", {})
    return {d.get("identifier", ""), hw.get("udid", ""), d.get("deviceProperties", {}).get("name", "")}
for d in devices:
    hw = d.get("hardwareProperties", {})
    if hw.get("platform") != "iOS":
        continue
    if wanted:
        if wanted in names(d):
            print(d.get("identifier", ""))
            sys.exit(0)
        continue
    if d.get("connectionProperties", {}).get("tunnelState") == "connected":
        print(d.get("identifier", ""))
        sys.exit(0)
PY
)

if [ -z "$device" ]; then
    if [ -n "${DEVICECTL_RUN_DEVICE:-}" ]; then
        echo "devicectl-run: no iOS device named '$DEVICECTL_RUN_DEVICE' is known to devicectl" >&2
    else
        echo "devicectl-run: no connected iOS device. \`xcrun devicectl list devices\` lists" >&2
        echo "               none whose tunnel is connected; connect and trust one, or set" >&2
        echo "               DEVICECTL_RUN_DEVICE." >&2
    fi
    exit 2
fi

if ! xcrun devicectl device install app --device "$device" "$app"; then
    echo "devicectl-run: installing $app on $device failed" >&2
    exit 2
fi

if ! xcrun devicectl device process launch --help 2>&1 | grep -q -- '--console'; then
    echo "devicectl-run: this devicectl has no \`process launch --console\`, so the" >&2
    echo "               program's output cannot be attached; use Xcode 16 or newer." >&2
    exit 2
fi

echo "devicectl-run: launching $bundle_id on $device; the status below is devicectl's (not yet measured to be the program's)" >&2
xcrun devicectl device process launch --device "$device" --terminate-existing --console "$bundle_id" "$@"
exit $?
]==]

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    -- `bin/`, where mcpp's runner lookup searches a declared payload (the
    -- measurement is recorded in `apple-simulator-tools`).
    local bindir = path.join(dir, "bin")
    os.mkdir(bindir)

    local program = path.join(bindir, "devicectl-run")
    local f = io.open(program, "w")
    if not f then
        raise("apple-device-tools: cannot write " .. program)
    end
    f:write(__devicectl_run_sh)
    f:close()
    os.iorun('chmod +x "' .. program .. '"')

    if not os.isfile(program) then
        raise("apple-device-tools: " .. program .. " was not written")
    end

    -- The script parses; the only claim a machine with no device can make.
    local ok = try { function() return os.iorun('bash -n "' .. program .. '"') end }
    if ok == nil then
        raise("apple-device-tools: " .. program .. " is not valid shell")
    end

    log.debug("apple-device-tools: wrote %s", program)
    return true
end

function config()
    local dir = path.join(pkginfo.install_dir(), "bin")
    xvm.add(package.name, { type = "group" })
    xvm.add("devicectl-run", { bindir = dir })
    return true
end

function uninstall()
    xvm.remove("devicectl-run")
    xvm.remove(package.name)
    return true
end
