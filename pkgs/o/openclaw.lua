package = {
    spec = "1",

    name = "openclaw",
    description = "OpenClaw CLI",
    homepage = "https://github.com/openclaw/openclaw",
    licenses = {"MIT"},
    repo = "https://github.com/openclaw/openclaw",
    docs = "https://github.com/openclaw/openclaw#readme",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"ai", "cli", "tools"},
    keywords = {"openclaw", "agent", "cli"},

    programs = {"openclaw"},
    xvm_enable = true,

    xpm = {
        linux = {
            deps = {"xim:node", "xim:npm"},
            ["latest"] = { ref = "2026.5.7" },
            ["2026.5.7"] = {},
            ["2026.2.26"] = {},
        },
        macosx = {
            -- brew is pulled in on macOS because several OpenClaw skills
            -- (channel daemons, the ffmpeg-backed mlx-tts vendor binary,
            -- the local podman/docker container runtime that
            -- `openclaw --container` drives) expect Homebrew-managed
            -- system libs to be reachable. Linux/Windows users typically
            -- install those via the distro/winget; macOS is the platform
            -- where brew is the de-facto answer.
            deps = {"xim:node", "xim:npm", "xim:brew"},
            ["latest"] = { ref = "2026.5.7" },
            ["2026.5.7"] = {},
            ["2026.2.26"] = {},
        },
        windows = {
            deps = {"xim:node", "xim:npm"},
            ["latest"] = { ref = "2026.5.7" },
            ["2026.5.7"] = {},
            ["2026.2.26"] = {},
        },
    }
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    -- Warm up proot's internal path-resolution state before the heavy
    -- npm install. Without this, the first large fork+exec burst
    -- (npm unpacking 559 packages) in a fresh proot sandbox triggers
    -- `double free or corruption` in proot's talloc pool. A single
    -- PATH-traversing command (`node --version`) initializes proot's
    -- path cache and prevents the crash. Only needed on Linux (proot
    -- is Linux-only); harmless no-op on native (non-proot) Linux.
    if os.host() == "linux" then
        os.execute("node --version > /dev/null 2>&1")
    end

    local npm_install = string.format(
        [[npm install --prefix "%s" --no-fund --no-audit --ignore-scripts "openclaw@%s"]],
        pkginfo.install_dir(),
        pkginfo.version()
    )
    os.exec(npm_install)

    return true
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "node_modules", ".bin")
    local alias = "openclaw"

    if is_host("windows") then
        alias = "openclaw.cmd"
    end

    xvm.add("openclaw", { bindir = bindir, alias = alias })
    return true
end

function uninstall()
    xvm.remove("openclaw")
    return true
end
