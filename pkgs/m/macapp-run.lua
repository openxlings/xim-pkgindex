package = {
    spec = "1",

    name = "macapp-run",
    description = "macapp-run: run a macOS application bundle's executable in the foreground, as a `runner` argv prefix.",

    authors = {"mcpplibs"},
    maintainers = {"d2learn"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/openxlings/xim-pkgindex",

    -- WHAT THIS PACKAGE IS FOR.
    --
    -- mcpp's `runner` is an argv prefix. A distributable that is a macOS
    -- application bundle (`X.app`, a directory) cannot be executed as a
    -- program, so `mcpp run --format app` hands it to a runner:
    --
    --   [target.aarch64-macos.runners]
    --   app = ["macapp-run"]
    --
    -- and the engine executes `macapp-run <X.app> [arguments...]`.
    --
    -- WHY `exec` OF THE BUNDLE'S EXECUTABLE, AND NOT `open`. `open -W` starts
    -- the application through LaunchServices: the program's standard streams
    -- do not reach the terminal and the status `open` returns is its own, not
    -- the application's (measured on macos-15, mcpp#635 run 2: an `open -W`
    -- runner exited 0 for a program that exits 7). Executing
    -- `Contents/MacOS/<CFBundleExecutable>` directly gives the process the
    -- caller's standard streams and returns its status by construction, and
    -- the main bundle still resolves: measured on the same runner, a program
    -- run as `N.app/Contents/MacOS/probe` reported its bundle as `N.app` and
    -- found `Contents/Resources/greeting.txt`, while the same binary copied
    -- out of the bundle reported its own directory and no resource.
    --
    -- WHY A PACKAGE OF ITS OWN. The program is named after what it runs, and
    -- the package after the program. `apple-simulator-tools` is named after
    -- the runtime its program drives; this program drives no runtime, so
    -- placing it there would make that package's name untrue.
    --
    -- macOS ONLY: an application bundle is a macOS structure and the program
    -- reads it with macOS tools (`plutil`, `PlistBuddy`).
    type = "script",
    status = "stable",
    programs = {"macapp-run"},
    categories = {"apple", "macos", "runner"},
    keywords = {"macos", "app", "bundle", "runner", "mcpp"},

    xpm = {
        -- No url: the program is this recipe's own text, as in
        -- apple-simulator-tools.lua.
        macosx = {
            ["latest"] = { ref = "0.1.0" },
            ["0.1.0"] = { },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

local __macapp_run_sh = [==[
#!/usr/bin/env bash
# macapp-run --- run a macOS application bundle's executable in the foreground.
#
# Usage:  macapp-run <X.app> [arguments...]
#
# Used as an mcpp named runner:
#
#   [target.aarch64-macos.runners]
#   app = ["macapp-run"]
#
# THE STANDARD STREAMS AND THE EXIT STATUS ARE THE PROGRAM'S. The last line
# replaces this shell with the bundle's executable, so nothing stands between
# the program and its caller: a status, a signal and every byte of output reach
# `mcpp run` and `mcpp test` unchanged.
set -uo pipefail

if [ "$#" -lt 1 ]; then
    echo "macapp-run: usage: macapp-run <X.app> [arguments...]" >&2
    exit 2
fi

bundle="${1%/}"; shift

if [ ! -e "$bundle" ]; then
    echo "macapp-run: $bundle does not exist" >&2
    exit 2
fi
if [ ! -d "$bundle" ]; then
    echo "macapp-run: $bundle is not a directory; an application bundle is one" >&2
    exit 2
fi

plist="$bundle/Contents/Info.plist"
if [ ! -f "$plist" ]; then
    echo "macapp-run: $bundle has no Contents/Info.plist" >&2
    exit 2
fi

# `plutil -extract ... raw` reads XML and binary property lists alike (macOS 12
# and later); PlistBuddy answers on every macOS release. The first non-empty
# answer is used.
exe=$(/usr/bin/plutil -extract CFBundleExecutable raw -o - "$plist" 2>/dev/null)
if [ -z "$exe" ]; then
    exe=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist" 2>/dev/null)
fi
if [ -z "$exe" ]; then
    echo "macapp-run: $plist names no CFBundleExecutable" >&2
    exit 2
fi

# An absolute path, so that the main bundle resolves from the executable's
# location whatever the caller's working directory is.
root=$(cd "$bundle" && pwd)
program="$root/Contents/MacOS/$exe"
if [ ! -f "$program" ]; then
    echo "macapp-run: $bundle has no Contents/MacOS/$exe (its CFBundleExecutable)" >&2
    exit 2
fi
if [ ! -x "$program" ]; then
    echo "macapp-run: $program is not executable" >&2
    exit 2
fi

exec "$program" "$@"
]==]

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    -- `bin/`: mcpp's runner lookup searches `<payload>/bin` for the program a
    -- runner names (apple-simulator-tools.lua records the measurement).
    local bindir = path.join(dir, "bin")
    os.mkdir(bindir)

    local program = path.join(bindir, "macapp-run")
    local f = io.open(program, "w")
    if not f then
        raise("macapp-run: cannot write " .. program)
    end
    f:write(__macapp_run_sh)
    f:close()
    os.iorun('chmod +x "' .. program .. '"')

    if not os.isfile(program) then
        raise("macapp-run: " .. program .. " was not written")
    end

    -- The program is parsed, not run: a syntax error in the text above is
    -- reported at install time rather than at the first `mcpp run`.
    local ok = try { function() return os.iorun('bash -n "' .. program .. '"') end }
    if ok == nil then
        raise("macapp-run: " .. program .. " is not valid shell")
    end

    log.debug("macapp-run: wrote %s", program)
    return true
end

function config()
    -- The package and its one program share a name, so the program's
    -- registration is the package's: a second, group-typed registration of
    -- the same name would claim the name twice.
    xvm.add(package.name, { bindir = path.join(pkginfo.install_dir(), "bin") })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
