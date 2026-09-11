package = {
    spec = "1",

    name = "apple-simulator-tools",
    description = "simctl-run: run a bare Mach-O executable on an iOS simulator, as a `runner` argv prefix.",

    authors = {"mcpplibs"},
    maintainers = {"d2learn"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/openxlings/xim-pkgindex",

    -- WHAT THIS PACKAGE IS FOR, AND WHY IT IS A PACKAGE.
    --
    -- mcpp's `runner` is an argv prefix: a project writes
    --
    --   [target.aarch64-ios-sim]
    --   runner = ["simctl-run"]
    --
    -- and `mcpp run --target aarch64-ios-sim` executes `simctl-run <artifact>`.
    -- The build tool therefore learns nothing about simulators, which is the
    -- boundary it keeps for every other emulated target: the engine knows
    -- there is a prefix, and the platform knowledge lives in the ecosystem.
    --
    -- A SESSION IS NOT A FLAG, which is why this cannot be written into a
    -- manifest as `xcrun simctl spawn ...`. Running a program on a simulator
    -- means choosing a device, booting it if it is not booted, waiting for the
    -- boot to finish, spawning, and returning the program's own exit status.
    -- That is a session with a beginning and an end, and a manifest cannot
    -- express one.
    --
    -- macOS ONLY, AND THAT IS THE POINT RATHER THAN A LIMITATION. The
    -- simulator runtime is a proprietary component of the operating system it
    -- simulates; there is nothing to package and nothing to mirror. mcpp's
    -- recorded host-surface rule permits exactly this category -- a
    -- proprietary runtime that exists only on its own OS -- provided it is
    -- named rather than reached by a fallthrough, and naming it is what this
    -- package does.
    type = "script",
    status = "stable",
    categories = {"apple", "ios", "simulator", "runner"},
    keywords = {"ios", "simulator", "simctl", "runner", "mcpp"},

    xpm = {
        -- No url: the program is this recipe's own text. There is no upstream
        -- release to pin, because what is being packaged is the session, and
        -- the tools it drives ship with Xcode.
        macosx = { ["0.1.0"] = { } },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- THE MEASUREMENT THIS SCRIPT IS BUILT ON.
--
-- Measured 2026-09-11 on a macos-15 runner (Xcode 16.4, iPhoneSimulator 18.5),
-- against a bare Mach-O built by `xim:llvm` for `arm64-apple-ios18.0-simulator`
-- with no bundle, no signature and no Info.plist:
--
--   xcrun simctl spawn <udid> <artifact>     ->  1-2-3, exit 0
--
-- That answer decides the whole shape of this program. `simctl launch` needs
-- an INSTALLED APPLICATION -- a .app directory with an Info.plist, installed
-- with `simctl install` -- and a design written before the measurement assumed
-- this program would have to synthesise one, sign it and install it. It does
-- not: `spawn` takes an executable and runs it in the simulator's process
-- environment, which is exactly what a `runner` needs.
--
-- WHAT IS STILL REQUIRED is a BOOTED device, which is why this is not a
-- one-line alias for `xcrun simctl spawn booted`.
local __simctl_run_sh = [==[
#!/usr/bin/env bash
# simctl-run --- run a Mach-O executable on an iOS simulator.
#
# Usage:  simctl-run <executable> [arguments...]
#
# Used as an mcpp `runner` argv prefix:
#
#   [target.aarch64-ios-sim]
#   runner = ["simctl-run"]
#
# THE EXIT STATUS IS THE PROGRAM'S. A runner that reported its own success
# would make every test pass; `mcpp test` reads this status, so it is the one
# thing this script must not lose. `set -e` is deliberately NOT used for the
# spawn itself.
set -uo pipefail

if [ "$#" -lt 1 ]; then
    echo "simctl-run: usage: simctl-run <executable> [arguments...]" >&2
    exit 2
fi

artifact="$1"; shift

if [ ! -f "$artifact" ]; then
    echo "simctl-run: $artifact does not exist" >&2
    exit 2
fi

if ! command -v xcrun > /dev/null 2>&1; then
    echo "simctl-run: no xcrun on this machine. The iOS simulator is a" >&2
    echo "            proprietary runtime that ships inside Xcode; there is" >&2
    echo "            no package for it and this program only drives it." >&2
    exit 2
fi

# THE DEVICE IS CHOSEN, AND A DEVICE THAT IS ALREADY BOOTED WINS.
#
# Booting takes 30-60 seconds on a cold runner, so reusing a booted device is
# the difference between a test suite that runs and one that times out. The
# selection is deliberately not `simctl spawn booted`: that spelling fails with
# no useful message when nothing is booted, and this program's whole job is to
# arrive at a booted device.
#
# `-j` and a JSON walk rather than parsing the human table: the table's
# headings and indentation are not an interface, and this index has a record
# of a recipe broken by a tool's output formatting changing under it.
udid="${SIMCTL_RUN_UDID:-}"
if [ -z "$udid" ]; then
    udid=$(xcrun simctl list devices available -j 2>/dev/null | python3 -c '
import json, sys
try:
    devices = json.load(sys.stdin).get("devices", {})
except Exception:
    sys.exit(0)
booted, available = None, None
for runtime, entries in devices.items():
    if "iOS" not in runtime:
        continue
    for d in entries:
        if not d.get("isAvailable"):
            continue
        if d.get("state") == "Booted" and booted is None:
            booted = d["udid"]
        if available is None:
            available = d["udid"]
print(booted or available or "")
' 2>/dev/null)
fi

if [ -z "$udid" ]; then
    echo "simctl-run: this machine has no available iOS simulator device." >&2
    echo "            \`xcrun simctl list devices available\` lists none;" >&2
    echo "            a runtime is installed through Xcode." >&2
    exit 2
fi

state=$(xcrun simctl list devices -j 2>/dev/null | python3 -c '
import json, sys
want = sys.argv[1]
try:
    devices = json.load(sys.stdin).get("devices", {})
except Exception:
    sys.exit(0)
for entries in devices.values():
    for d in entries:
        if d.get("udid") == want:
            print(d.get("state", ""))
            sys.exit(0)
' "$udid" 2>/dev/null)

if [ "$state" != "Booted" ]; then
    # BOOTING AN ALREADY-BOOTING DEVICE IS NOT AN ERROR HERE. Two concurrent
    # runners are an ordinary situation -- `mcpp test` runs test binaries one
    # after another and a parallel build may overlap them -- and the second
    # one's `boot` reports that the device is booted or booting. Either is the
    # state this program wants, so the boot's status is not the criterion; the
    # wait below is.
    xcrun simctl boot "$udid" > /dev/null 2>&1 || true
    if ! xcrun simctl bootstatus "$udid" -b > /dev/null 2>&1; then
        echo "simctl-run: device $udid did not finish booting" >&2
        exit 2
    fi
fi

# AND THE PROGRAM'S STATUS IS RETURNED UNCHANGED.
xcrun simctl spawn "$udid" "$artifact" "$@"
exit $?
]==]

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    -- `bin/`, AND THE FIRST VERSION OF THIS RECIPE WROTE THE PROGRAM ONE LEVEL
    -- UP.
    --
    -- mcpp's runner lookup searches `<payload>/bin` for a program a manifest's
    -- `runner` names. Measured 2026-09-11 on a macos-15 runner, with this
    -- package correctly installed and declared:
    --
    --   error: runner 'simctl-run' for 'aarch64-ios-sim' was not found on any
    --          search path.
    --   Searched: .../xim-x-apple-simulator-tools/0.1.0/bin
    --
    -- The directory searched was right and the program was not in it. `bin/`
    -- is the convention a consumer can rely on, so that is where a package
    -- that exists to provide a program puts it -- `xim:7zip`'s flat layout is
    -- a payload whose program is incidental, and this one's is the whole
    -- package.
    local bindir = path.join(dir, "bin")
    os.mkdir(bindir)

    local program = path.join(bindir, "simctl-run")
    local f = io.open(program, "w")
    if not f then
        raise("apple-simulator-tools: cannot write " .. program)
    end
    f:write(__simctl_run_sh)
    f:close()
    -- `os.iorun` rather than a Lua permission call: this hook runtime has been
    -- measured to leave several `os.*` functions unbound, and `chmod` is the
    -- one spelling that is certainly available.
    os.iorun('chmod +x "' .. program .. '"')

    if not os.isfile(program) then
        raise("apple-simulator-tools: " .. program .. " was not written")
    end

    -- ASSERT THE SCRIPT PARSES, which is the only claim that can be made on a
    -- machine that may have no simulator at all. `bash -n` reads the file and
    -- does not run it, so a syntax error in the heredoc above -- the failure
    -- this recipe is most likely to have -- is caught at install time rather
    -- than at the first `mcpp run`.
    local ok = try { function() return os.iorun('bash -n "' .. program .. '"') end }
    if ok == nil then
        raise("apple-simulator-tools: " .. program .. " is not valid shell")
    end

    log.debug("apple-simulator-tools: wrote %s", program)
    return true
end

function config()
    local dir = path.join(pkginfo.install_dir(), "bin")
    -- One program, registered under its own name, because that name is what a
    -- manifest's `runner` writes. mcpp's runner lookup searches the declared
    -- dependency's bin directory before PATH, so this resolves without the
    -- project naming a version or a path.
    xvm.add(package.name, { type = "group" })
    xvm.add("simctl-run", { bindir = dir })
    return true
end

function uninstall()
    xvm.remove("simctl-run")
    xvm.remove(package.name)
    return true
end
