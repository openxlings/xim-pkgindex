-- DeepSeek Harness (`dsh`) — DeepSeek AI's open-source agent harness.
--
-- Distribution: **npm only**. `deepseek-ai/deepseek-harness` publishes no
-- GitHub release and carries no git tag; the one shipping channel is the
-- npm package `@deepseek-ai/dsh`, and upstream's own instruction is
-- `npx @deepseek-ai/dsh web`. So this recipe goes through npm the same way
-- openclaw.lua does, rather than downloading a platform asset like
-- claude.lua / codex.lua — there is no asset to download.
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
            deps = {"xim:node@>=24", "xim:npm", "xim:pnpm"},
            ["latest"] = { ref = "0.1.0-rc.6" },
            ["0.1.0-rc.6"] = {},
            ["0.1.0-rc.3"] = {},
        },
        macosx = {
            deps = {"xim:node@>=24", "xim:npm", "xim:pnpm"},
            ["latest"] = { ref = "0.1.0-rc.6" },
            ["0.1.0-rc.6"] = {},
            ["0.1.0-rc.3"] = {},
        },
        windows = {
            deps = {"xim:node@>=24", "xim:npm", "xim:pnpm"},
            ["latest"] = { ref = "0.1.0-rc.6" },
            ["0.1.0-rc.6"] = {},
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

-- npm's own shim for `bin.dsh`. Used ONLY as install()'s artifact assertion;
-- the xvm shim deliberately does not go through it — see config().
local function _shim()
    return path.join(_bindir(), is_host("windows") and "dsh.cmd" or "dsh")
end

-- The real entry point, i.e. what `bin.dsh` in the published package.json
-- points at. config() execs this with an explicit interpreter.
local function _entry()
    return path.join(pkginfo.install_dir(), "node_modules",
                     "@deepseek-ai", "dsh", "lib", "bin.js")
end

function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    -- Same proot warm-up as openclaw.lua, and for the same reason: the
    -- first large fork+exec burst inside a fresh proot sandbox (npm
    -- unpacking ~530 packages) trips `double free or corruption` in
    -- proot's talloc pool. One PATH-traversing command primes proot's
    -- path cache. Linux-only (proot is), harmless on native Linux.
    if os.host() == "linux" then
        os.execute("node --version > /dev/null 2>&1")
    end

    -- npm writes straight to the terminal, and its first line lands flush
    -- against whatever xlings printed last, so the two read as one message.
    -- One blank line separates them.
    print("")

    -- Lifecycle scripts run on purpose. See the header: node-pty's install
    -- script is the only thing that produces pty.node on Linux.
    os.exec(string.format(
        [[npm install --prefix "%s" --no-fund --no-audit "@deepseek-ai/dsh@%s"]],
        pkginfo.install_dir(),
        pkginfo.version()
    ))

    -- Assert the artifact, not the intent: a bare `return true` here gets
    -- stamped as installed and leaves an xvm shim pointing at nothing.
    if not os.isfile(_shim()) then
        return false
    end
    if not os.isfile(_entry()) then
        raise("dsh: npm tree has no @deepseek-ai/dsh/lib/bin.js after install")
    end

    -- The whole point of not passing --ignore-scripts. On Linux this file
    -- only exists if node-pty's install script actually ran; without it
    -- every profile boot dies and only `--version` keeps working, which is
    -- exactly the failure this recipe shipped once already.
    if os.host() == "linux" then
        local pty = path.join(pkginfo.install_dir(), "node_modules", "node-pty",
                              "build", "Release", "pty.node")
        if not os.isfile(pty) then
            raise("dsh: node-pty was not built (no build/Release/pty.node); "
                  .. "profile boot would fail. node-gyp needs python3, make "
                  .. "and a C++ toolchain on this host.")
        end
    end

    return true
end

-- Pin the interpreter to the node payload this package resolved against,
-- rather than shipping npm's `node_modules/.bin/dsh` shim — that shim starts
-- with `#!/usr/bin/env node` and therefore follows whatever `xlings use node`
-- last selected. This is meson.lua's pattern (it execs its OWN python payload
-- for the same reason) and R6 of the V2 spec: an internal consumer binds the
-- payload, not the subos view.
--
-- Concretely, without this `xlings use node 26` silently changes which
-- runtime boots dsh. That is survivable today — node-pty is N-API and its
-- pty.node loads across majors (measured) — but "survivable" is not
-- "chosen", and upstream's floor is `>=24`, which a bare shim cannot enforce.
--
-- Stated trade-off, same as meson's: node is resolved once, at dsh-install
-- time. `xlings use node <other>` afterwards does not move dsh, and removing
-- the node payload leaves this shim pointing at a gone interpreter. For an
-- agent runtime with a native module compiled into its own tree, not moving
-- is the safer direction.
function config()
    local nodedir = pkginfo.dep_install_dir("xim:node")
    if not nodedir then
        raise("dsh: cannot locate the xim:node payload; the shim would have "
              .. "no interpreter to exec")
    end

    -- node.lua puts the binary in <payload>/bin on unix and at the payload
    -- root on windows; mirror that rather than guessing one shape.
    local nodebin = is_host("windows") and nodedir or path.join(nodedir, "bin")
    local exe = is_host("windows") and "node.exe" or "node"
    if not os.isfile(path.join(nodebin, exe)) then
        raise("dsh: xim:node payload at " .. nodebin .. " has no " .. exe)
    end

    xvm.add("dsh", {
        bindir = nodebin,
        alias  = exe .. " " .. _entry(),
    })
    log.info("dsh: shim execs " .. path.join(nodebin, exe) .. " " .. _entry())
    return true
end

function uninstall()
    -- Only the xpkg payload goes away. `$DSH_HOME` (default `~/.dsh`) holds
    -- the user's profiles, their pnpm-managed plugins and their config
    -- layer; it is user data this recipe never created and must not delete.
    xvm.remove("dsh")
    return true
end
