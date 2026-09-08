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
-- **Do not use `--ignore-scripts`.** The root package has no lifecycle
-- script, but its dependencies do: node-pty, koffi, protobufjs,
-- @deepseek-ai/dsh-subprocess-local and @google/genai. They own native
-- helper setup and the source-build fallback.
--
-- Older node-pty@1.1.0 tarballs had no Linux prebuild, so skipping scripts
-- left no usable pty.node even though `dsh --version` passed. Current
-- DSH 0.1.2-rc.1 resolves node-pty@1.2.0-beta.15, whose npm tarball also
-- ships prebuilds/linux-x64 and prebuilds/linux-arm64. Requiring only
-- build/Release/pty.node now rejects a valid installation.
--
-- The Linux post-install check therefore loads node-pty through its own
-- resolver: both compiled and prebuilt layouts must actually load. Missing
-- or unloadable native modules still fail. A source-build fallback still
-- needs python3, make and a C++ toolchain. Verify actual profile boot too;
-- `dsh --version` alone never loads the plugin tree.
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
-- pre-release version keys — `0.1.2-rc.1` is npm's `latest`, checked on
-- 2026-09-09. The separate alpha dist-tag is not selected implicitly.
--
-- Historical versions are retained because a pre-1.0 harness that
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
            ["latest"] = { ref = "0.1.2-rc.1" },
            ["0.1.2-rc.1"] = {},
            ["0.1.0-rc.6"] = {},
            ["0.1.0-rc.3"] = {},
        },
        macosx = {
            deps = {"xim:node@>=24", "xim:pnpm"},
            ["latest"] = { ref = "0.1.2-rc.1" },
            ["0.1.2-rc.1"] = {},
            ["0.1.0-rc.6"] = {},
            ["0.1.0-rc.3"] = {},
        },
        windows = {
            deps = {"xim:node@>=24", "xim:pnpm"},
            ["latest"] = { ref = "0.1.2-rc.1" },
            ["0.1.2-rc.1"] = {},
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

    -- Retain lifecycle scripts for native helpers and source-build fallback.
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

    -- Ask node-pty to load the platform binary it actually selected. A
    -- fixed build/Release path rejects current Linux prebuilt packages.
    if os.host() == "linux" then
        os.exec(string.format(
            [[node -e "require(process.argv[1])" "%s"]],
            path.join(pkginfo.install_dir(), "node_modules", "node-pty")
        ))
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
