-- DeepSeek Harness (`dsh`) — DeepSeek AI's open-source agent harness.
--
-- Distribution: **npm only**. `deepseek-ai/deepseek-harness` publishes no
-- GitHub release and carries no git tag; the one shipping channel is the
-- npm package `@deepseek-ai/dsh`, and upstream's own instruction is
-- `npx @deepseek-ai/dsh web`. So this recipe installs from the npm registry
-- (with pnpm, see install()) as openclaw.lua does, rather than downloading a
-- platform asset like claude.lua / codex.lua — there is no asset to download.
--
-- No `package.ci`: version-check.py discovers versions from GitHub release
-- tags (`github_releases()`), and this project has none. Bumps are read off
-- registry.npmjs.org/@deepseek-ai/dsh (`dist-tags.latest`) by hand.
--
-- **`--ignore-scripts` MUST NOT be used here, and the reason is Linux-only
-- so it does not show up on a casual test.** The first version of this
-- recipe carried it, on the argument that the published package.json
-- declares no `scripts` of its own — which is true of the ROOT package and
-- irrelevant, because the flag applies to the whole tree. Five packages in
-- that tree have install lifecycle scripts (enumerated, not guessed):
--
--   node-pty@1.1.0                      install + postinstall
--   koffi@3.1.4                         install
--   protobufjs@7.6.5                    postinstall
--   @deepseek-ai/dsh-subprocess-local   postinstall
--   @google/genai@1.52.0                preinstall (a no-op echo)
--
-- node-pty is the one that breaks. Its install script is
-- `node scripts/prebuild.js || node-gyp rebuild`, and prebuild.js downloads
-- NOTHING — it only *checks* whether `prebuilds/<platform>-<arch>` exists
-- and exits 1 when it does not. The npm tarball ships prebuilds for
-- darwin-arm64, darwin-x64, win32-arm64 and win32-x64 **and no linux-x64**,
-- so on Linux the `|| node-gyp rebuild` branch is the only thing that ever
-- produces `pty.node`, into `build/Release/`.
--
-- Skip it and `dsh --version` / `dsh --help` still pass — neither loads the
-- plugin tree — while every actual profile boot dies with
--
--   failed to import loader entry subprocess (@deepseek-ai/dsh-subprocess-local):
--   Failed to load native module: pty.node, checked: build/Release, build/Debug,
--   prebuilds/linux-x64
--
-- macOS and Windows are unaffected: their prebuilds are in the tarball.
-- So verify a change to this line by BOOTING A PROFILE on Linux, never by
-- `--version`. tests/d/test_dsh.py guards both directions.
--
-- Compiling from source means node-gyp, i.e. python3 + make + a C++
-- toolchain on the host at install time. That cost is accepted rather than
-- worked around: there is no prebuilt linux-x64 pty.node to fetch.
--
-- The compiled `pty.node` survives `xlings use node <other>`: node-pty
-- builds against node-addon-api (N-API), which is ABI-stable across major
-- versions. Measured, not assumed — a pty.node built under node 26.7.0
-- loads under node 24.15.0.
--
-- **pnpm IS a dependency**, and it belongs here rather than in every install
-- command a user is told to type. `dsh plugin --profile <p> add ...` shells
-- out to `pnpm` off PATH — the CLI says so itself when it is missing
-- (`dsh: pnpm not found on PATH — install pnpm to manage profile plugins`) —
-- and upstream's own removal note is explicit: "Profile installation requires
-- `pnpm` on the host `PATH`."
--
-- The cost, stated rather than discovered later: xim:pnpm ships only
-- `pnpm-linux-x64` / `pnpm-win32-x64` / `pnpm-darwin-arm64`, so it is
-- `archs = {"x86_64"}` on Linux while dsh itself is JavaScript and runs
-- wherever node does. Declaring it therefore makes `xlings install dsh` fail
-- on aarch64 Linux, where it previously succeeded with plugin management
-- broken. That trade was made deliberately: an install that works but cannot
-- manage plugins is a worse default than one that says what it needs, and the
-- gap closes on its own the moment xim:pnpm gains an arm64 asset.
--
-- **No `xim:npm`.** node.lua's config() already does
-- `xvm.add("npm", ...)` and `xvm.add("npx", ...)` off the node payload's own
-- bin directory, so npm arrives with node — verified: the node payload ships
-- `bin/npm`. Declaring xim:npm as well is not merely redundant, it puts a
-- SECOND OWNER on the xvm name `npm` with a different version string
-- (`11.2.0` from xim:npm vs `node-24.19.0` from xim:node). Two owners with
-- different versions is the case the spec calls out as the dangerous one:
-- it is accepted silently at install time and only bites later, when an
-- `xvm use` on one side rewrites what the other side pointed at. Measured on
-- a live machine: `npm` already showed three actives across 19 subos in both
-- naming schemes at once.
--
-- (bun.lua and openclaw.lua declare the same redundant pair; out of scope
-- here, worth a follow-up.)
--
-- `xim:node@>=24`, and that floor is upstream's own, not a round number.
-- The repo root package.json declares
-- `engines: { node: "^22.19.0 || >=24.0.0" }`. The 22.x arm is unreachable
-- through this index: xim:node's 22 line stops at 22.17.1, which is BELOW
-- 22.19.0, so no xim:node 22 satisfies upstream. `>=24` is therefore the
-- only correct floor here, not a simplification of the disjunction. (The
-- PUBLISHED @deepseek-ai/dsh package.json carries no `engines` at all, so
-- npm will not enforce this for us — the dep constraint is the enforcement.)
--
-- Upstream is in *developer preview* and says so in capitals: "THERE WILL
-- BE COMPATIBILITY-BREAKING CHANGES." Hence `status = "dev"` and the
-- pre-release version keys — `0.1.0-rc.6` is the actual `latest` on npm,
-- not a placeholder.
--
-- Two versions are tracked, not one, because a pre-1.0 harness that
-- promises breaking changes is exactly the case `xvm use dsh@<ver>` exists
-- for. The 0.1.0-rc.3 pin was installed and run before it was written down
-- (`dsh --version` -> 0.1.0-rc.3): the `^0.1.0-rc.3` ranges its own
-- @deepseek-ai/dsh-* dependencies carry are satisfiable within the 0.1.x
-- line, so npm does not silently resolve an older root against newer
-- bundle packages. Anything below 0.1.0 is a different line (0.0.1-rc.*)
-- and is not tracked.

package = {
    spec = "2",

    name = "dsh",
    description = "DeepSeek Harness - an everything-is-a-plugin agent harness from DeepSeek AI",
    homepage = "https://github.com/deepseek-ai/deepseek-harness",
    licenses = {"MIT"},
    repo = "https://github.com/deepseek-ai/deepseek-harness",
    docs = "https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/user/index.md",

    type = "package",
    -- x86_64 only, and that is a consequence of the pnpm dep above rather
    -- than a property of dsh: dsh is JavaScript and runs wherever node does,
    -- but xim:pnpm has no aarch64 asset, so the dependency closure cannot
    -- resolve there. Declaring aarch64 while the install cannot succeed would
    -- be a claim the index cannot honour. Restore it the moment xim:pnpm
    -- ships arm64.
    archs = {"x86_64"},
    status = "dev", -- upstream: developer preview, breaking changes expected
    categories = {"ai", "cli", "tools"},
    keywords = {"dsh", "deepseek", "deepseek-harness", "agent", "cli", "cordis"},

    programs = {"dsh"},
    xvm_enable = true,

    xpm = {
        linux = {
            deps = {"xim:node@>=24", "xim:pnpm"},
            ["latest"] = { ref = "0.1.0-rc.6" },
            -- r1: installed with pnpm (npm 11 runs out of memory resolving
            -- it); pty.node checked where node-pty loads it (its prebuilds).
            -- r2: what a root accepts -- the shim in dsh's own payload, and
            -- sharp's RPATH kept inside it.
            ["0.1.0-rc.6"] = { revision = 2 },
            ["0.1.0-rc.3"] = {},
        },
        macosx = {
            deps = {"xim:node@>=24", "xim:pnpm"},
            ["latest"] = { ref = "0.1.0-rc.6" },
            -- r1: installed with pnpm (npm 11 runs out of memory resolving
            -- it); pty.node checked where node-pty loads it (its prebuilds).
            -- r2: what a root accepts -- the shim in dsh's own payload, and
            -- sharp's RPATH kept inside it.
            ["0.1.0-rc.6"] = { revision = 2 },
            ["0.1.0-rc.3"] = {},
        },
        windows = {
            deps = {"xim:node@>=24", "xim:pnpm"},
            ["latest"] = { ref = "0.1.0-rc.6" },
            -- r1: installed with pnpm (npm 11 runs out of memory resolving
            -- it); pty.node checked where node-pty loads it (its prebuilds).
            -- r2: what a root accepts -- the shim in dsh's own payload, and
            -- sharp's RPATH kept inside it.
            ["0.1.0-rc.6"] = { revision = 2 },
            ["0.1.0-rc.3"] = {},
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

local function _bindir()
    return path.join(pkginfo.install_dir(), "node_modules", ".bin")
end

-- The package manager's shim for `bin.dsh`. Used ONLY as install()'s
-- artifact assertion; the xvm shim deliberately does not go through it —
-- see config().
local function _shim()
    return path.join(_bindir(), is_host("windows") and "dsh.cmd" or "dsh")
end

-- The real entry point, i.e. what `bin.dsh` in the published package.json
-- points at. config() execs this with an explicit interpreter.
local function _entry()
    return path.join(pkginfo.install_dir(), "node_modules",
                     "@deepseek-ai", "dsh", "lib", "bin.js")
end

-- sharp's prebuilt addon (node_modules/@img/sharp-<platform>/lib/*.node)
-- lists libvips' place in five package-manager layouts on its RPATH. One of
-- them climbs five directories up, out of this payload, and a SubOS with a
-- root refuses an ELF whose search path leaves its closure ("ELF search path
-- is outside its recorded root closure"). Only the entries that exist here
-- and stay inside this payload are kept; the string is rewritten in place,
-- NUL-padded to its old length, so nothing else in the file moves and no
-- patchelf is needed.
local function _ls(dir)
    local out = {}
    local p = io.popen('ls -1A "' .. dir .. '" 2>/dev/null')
    if p then
        for name in p:lines() do out[#out + 1] = name end
        p:close()
    end
    return out
end

local function _keep_rpath_inside(file, root)
    local f = io.open(file, "rb")
    if not f then return end
    local data = f:read("*a")
    f:close()
    local at = data:find("$ORIGIN/", 1, true)
    if not at then return end
    local first = at
    while first > 1 and data:byte(first - 1) ~= 0 do first = first - 1 end
    local last = data:find("\0", at, true)
    if not last then return end
    local old = data:sub(first, last - 1)
    local dir = path.directory(file)
    local depth = select(2, dir:sub(#root + 2):gsub("[^/]+", ""))
    local kept = {}
    for entry in old:gmatch("[^:]+") do
        local rel = entry:match("^%$ORIGIN/(.*)$")
        local ups = rel and select(2, rel:gsub("%.%./", "")) or math.huge
        if ups <= depth and os.isdir(path.join(dir, rel)) then
            kept[#kept + 1] = entry
        end
    end
    local new = table.concat(kept, ":")
    if new == old then return end
    local w = io.open(file, "wb")
    w:write(data:sub(1, first - 1), new, string.rep("\0", #old - #new), data:sub(last))
    w:close()
    log.info("dsh: " .. file .. " RPATH kept to " .. new)
end

function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    -- Same proot warm-up as openclaw.lua, and for the same reason: the
    -- first large fork+exec burst inside a fresh proot sandbox (pnpm
    -- unpacking ~450 packages) trips `double free or corruption` in
    -- proot's talloc pool. One PATH-traversing command primes proot's
    -- path cache. Linux-only (proot is), harmless on native Linux.
    if os.host() == "linux" then
        os.execute("node --version > /dev/null 2>&1")
    end

    -- pnpm writes straight to the terminal, and its first line lands flush
    -- against whatever xlings printed last, so the two read as one message.
    -- One blank line separates them.
    print("")

    -- pnpm, not npm: npm 11 spends ~8 minutes and ~4 GB resolving this
    -- tree's peer dependencies (out of memory on a macOS runner, past the
    -- timeout on Windows); pnpm resolves the same tree in seconds. A hoisted
    -- node_modules is npm's layout, so the paths below stay what they were.
    -- Lifecycle scripts run on purpose (see the header), named: pnpm runs a
    -- dependency's scripts only once it is allowed, and stops when one it
    -- was not told about has some, so a new one cannot go by unrun.
    -- The dep's own payload: its shim is not on a hook's PATH.
    local pnpmdir = pkginfo.dep_install_dir("xim:pnpm")
    if not pnpmdir then
        raise("dsh: cannot locate the xim:pnpm payload to install with")
    end
    local pnpm = path.join(pnpmdir, is_host("windows") and "pnpm.exe" or "pnpm")
    local builds = {"node-pty", "koffi", "protobufjs",
                    "@deepseek-ai/dsh-subprocess-local", "@google/genai"}
    local allow = ""
    for _, name in ipairs(builds) do
        allow = allow .. " --allow-build=" .. name
    end
    local cmd = string.format(
        [["%s" add --dir "%s" --config.node-linker=hoisted%s "@deepseek-ai/dsh@%s"]],
        pnpm,
        pkginfo.install_dir(),
        allow,
        pkginfo.version()
    )
    -- cmd /c drops the first and last quote of a line that starts with one;
    -- an outer pair is what it drops, so the quoted path stays whole.
    if is_host("windows") then
        cmd = '"' .. cmd .. '"'
    end
    os.exec(cmd)

    -- Assert the artifact, not the intent: a bare `return true` here gets
    -- stamped as installed and leaves an xvm shim pointing at nothing.
    if not os.isfile(_shim()) then
        return false
    end
    if not os.isfile(_entry()) then
        raise("dsh: the installed tree has no @deepseek-ai/dsh/lib/bin.js")
    end

    -- See _keep_rpath_inside: sharp's addon, so this tree can go into a root.
    if os.host() == "linux" then
        local img = path.join(pkginfo.install_dir(), "node_modules", "@img")
        for _, pkg in ipairs(_ls(img)) do
            local lib = path.join(img, pkg, "lib")
            for _, name in ipairs(_ls(lib)) do
                if name:match("%.node$") then
                    _keep_rpath_inside(path.join(lib, name), pkginfo.install_dir())
                end
            end
        end
    end

    -- The whole point of not passing --ignore-scripts. On Linux this file
    -- only exists if node-pty's install script actually ran; without it
    -- every profile boot dies and only `--version` keeps working, which is
    -- exactly the failure this recipe shipped once already.
    -- Where node-pty loads it from: its own build, or (1.2+) the prebuild it
    -- ships for this platform, which its install script only checks for.
    if os.host() == "linux" then
        -- (os.arch() is not bound in hooks: either Linux prebuild will do.)
        local ptydir = path.join(pkginfo.install_dir(), "node_modules", "node-pty")
        local found = os.isfile(path.join(ptydir, "build", "Release", "pty.node"))
        for _, arch in ipairs({"x64", "arm64"}) do
            found = found or os.isfile(path.join(ptydir, "prebuilds", "linux-" .. arch, "pty.node"))
        end
        if not found then
            raise("dsh: node-pty has no pty.node (neither build/Release nor prebuilds/linux-*); "
                  .. "profile boot would fail. node-gyp needs python3, make "
                  .. "and a C++ toolchain on this host.")
        end
    end

    return true
end

-- The shim lives in this package's own payload and runs `node` from the
-- scope it is in: the alias branch of an xlings shim puts the payload on PATH
-- and finds `node` as the subos's own (xim:node is a dep, so it is there).
-- A registration must live in its own package's payload: a SubOS with a root
-- (every Luban edition) refuses one that points into another package
-- ("root registration contradicts its physical package provider"). r1
-- pointed bindir at xim:node's payload and could not be installed into a
-- root at all.
--
-- The trade-off, measured rather than assumed: `xlings use node <other>`
-- moves which node boots dsh. node-pty is N-API and its pty.node loads
-- across majors (built under 26.7.0, loaded under 24.15.0). This is the
-- user-facing view R6 of the V2 spec leaves to the programs a user runs, as
-- openclaw.lua does. npm's `node_modules/.bin/dsh` is not used: it is a
-- `#!/usr/bin/env node` script, one more lookup for the same answer.
function config()
    local exe = is_host("windows") and "node.exe" or "node"
    xvm.add("dsh", {
        bindir = pkginfo.install_dir(),
        alias  = exe .. " " .. _entry(),
    })
    log.info("dsh: shim execs " .. exe .. " " .. _entry())
    return true
end

function uninstall()
    -- Only the xpkg payload goes away. `$DSH_HOME` (default `~/.dsh`) holds
    -- the user's profiles, their pnpm-managed plugins and their config
    -- layer; it is user data this recipe never created and must not delete.
    xvm.remove("dsh")
    return true
end
