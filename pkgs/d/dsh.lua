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
-- `--ignore-scripts` is safe here and is not a guess: the published
-- package.json declares no `scripts` at all, and a full install with the
-- flag (532 packages) yields a working `dsh --version` / `dsh --help`.
-- Verified against 0.1.0-rc.6.
--
-- **pnpm is deliberately NOT in `deps`.** `dsh plugin --profile <p> add ...`
-- shells out to `pnpm` off PATH — the CLI even says so when it is missing
-- (`dsh: pnpm not found on PATH — install pnpm to manage profile plugins`),
-- so it is tempting to declare it. But xim:pnpm ships only
-- `pnpm-linux-x64` / `pnpm-win32-x64` / `pnpm-darwin-arm64`, i.e. it is
-- `archs = {"x86_64"}` on Linux, while dsh itself is JavaScript and runs
-- wherever node does. A hard dep would therefore make `xlings install dsh`
-- fail outright on aarch64 Linux to enable one optional subcommand. Users
-- who want profile plugin management run `xlings install pnpm` alongside;
-- booting a profile, the web UI and headless runs need none of it.
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
    archs = {"x86_64", "aarch64"},
    status = "dev", -- upstream: developer preview, breaking changes expected
    categories = {"ai", "cli", "tools"},
    keywords = {"dsh", "deepseek", "deepseek-harness", "agent", "cli", "cordis"},

    programs = {"dsh"},
    xvm_enable = true,

    xpm = {
        linux = {
            deps = {"xim:node", "xim:npm"},
            ["latest"] = { ref = "0.1.0-rc.6" },
            ["0.1.0-rc.6"] = {},
            ["0.1.0-rc.3"] = {},
        },
        macosx = {
            deps = {"xim:node", "xim:npm"},
            ["latest"] = { ref = "0.1.0-rc.6" },
            ["0.1.0-rc.6"] = {},
            ["0.1.0-rc.3"] = {},
        },
        windows = {
            deps = {"xim:node", "xim:npm"},
            ["latest"] = { ref = "0.1.0-rc.6" },
            ["0.1.0-rc.6"] = {},
            ["0.1.0-rc.3"] = {},
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

local function _bindir()
    return path.join(pkginfo.install_dir(), "node_modules", ".bin")
end

-- The npm shim npm writes for `bin.dsh`. Windows gets the `.cmd` wrapper.
local function _shim()
    return path.join(_bindir(), is_host("windows") and "dsh.cmd" or "dsh")
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

    os.exec(string.format(
        [[npm install --prefix "%s" --no-fund --no-audit --ignore-scripts "@deepseek-ai/dsh@%s"]],
        pkginfo.install_dir(),
        pkginfo.version()
    ))

    -- Assert the artifact, not the intent: a bare `return true` here gets
    -- stamped as installed and leaves an xvm shim pointing at nothing.
    return os.isfile(_shim())
end

function config()
    xvm.add("dsh", {
        bindir = _bindir(),
        alias = is_host("windows") and "dsh.cmd" or "dsh",
    })
    return true
end

function uninstall()
    -- Only the xpkg payload goes away. `$DSH_HOME` (default `~/.dsh`) holds
    -- the user's profiles, their pnpm-managed plugins and their config
    -- layer; it is user data this recipe never created and must not delete.
    xvm.remove("dsh")
    return true
end
