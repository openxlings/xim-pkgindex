package = {
    spec = "2",
    homepage = "https://pnpm.io",
    name = "pnpm",
    description = "Fast, disk space efficient package manager",
    licenses = {"MIT"},
    type = "package",
    repo = "https://github.com/pnpm/pnpm",
    ci = { mirror = true, update = true },
    docs = "https://pnpm.io/motivation",

    -- xim pkg info
    archs = {"x86_64"},
    status = "stable",
    categories = {"package-manager", "typescript"},
    keywords = {"pnpm", "javascript", "typescript", "package-manager", "node"},

    programs = { "pnpm" },
    xvm_enable = true,

    -- Why we ship pnpm's standalone binary instead of the previous
    -- `npm install -g pnpm` recipe:
    --   * pnpm-v8+ ships a fully-self-contained binary that bundles the
    --     Node.js runtime via zig-msvc / posix shims (the `pnpm-linux-x64.tar.gz`
    --     and friends from the GitHub release page). No external Node
    --     install needed.
    --   * Previous recipe required `xim:node` first, doubling install time
    --     and pulling a ~50 MB Node.js xpkg purely as a build dep, even
    --     though the resulting pnpm binary doesn't need Node at runtime.
    --   * Direct binary install removes the layered indirection and makes
    --     `xlings install pnpm` equivalent to fetching one tarball, same
    --     shape as xim:bun / xim:codex (who DO still go via npm because
    --     their upstream wheel layout depends on it) NO — xim:bun and
    --     xim:codex go via npm because their authors publish on npm
    --     primarily; pnpm publishes a standalone too, so we use that.
    xpm = {
        linux = {
            -- Runtime deps: pnpm prebuilt is dynamically linked
            -- against glibc + GCC C++ runtime: NEEDED libc / libdl /
            -- libm / libpthread / libatomic (glibc) plus libgcc_s /
            -- libstdc++ (xim:gcc-runtime, since pnpm bundles V8/zig
            -- which ship C++ panic-unwind + std). Same as xim:node /
            -- xim:ollama deps shape.
            deps = {
                runtime = { "xim:glibc@2.39", "xim:gcc-runtime@15.1.0" },
            },
            url_template = "https://github.com/pnpm/pnpm/releases/download/v{version}/pnpm-linux-x64.tar.gz",
            ["latest"] = { ref = "11.12.0" },
            ["11.12.0"] = {
                url = "https://github.com/pnpm/pnpm/releases/download/v11.12.0/pnpm-linux-x64.tar.gz",
                sha256 = "dd19bfd8bcd33a3b38dcce335e8d233194c0a61ffe1f5bcf5047f60f6d4978b8",
            },
            ["11.0.5"] = {
                url = "https://github.com/pnpm/pnpm/releases/download/v11.0.5/pnpm-linux-x64.tar.gz",
                sha256 = "c1b55f53f5344cf0e26441d97b9ee2ee3b81791503c5cbd4bb93ae1898b8d211",
            },
        },
        macosx = {
            url_template = "https://github.com/pnpm/pnpm/releases/download/v{version}/pnpm-darwin-arm64.tar.gz",
            ["latest"] = { ref = "11.12.0" },
            ["11.12.0"] = {
                url = "https://github.com/pnpm/pnpm/releases/download/v11.12.0/pnpm-darwin-arm64.tar.gz",
                sha256 = "0d63d9b468690e661a182efd2c1bc752dbddc753e852b76ca5218f32fcf78a2e",
            },
            ["11.0.5"] = {
                url = "https://github.com/pnpm/pnpm/releases/download/v11.0.5/pnpm-darwin-arm64.tar.gz",
                sha256 = "24d412b2d137c6bc91e09c039b0e8ced6b5ac8f1dc9ea1881f0521cdb3bc5318",
            },
        },
        windows = {
            url_template = "https://github.com/pnpm/pnpm/releases/download/v{version}/pnpm-win32-x64.zip",
            ["latest"] = { ref = "11.12.0" },
            ["11.12.0"] = {
                url = "https://github.com/pnpm/pnpm/releases/download/v11.12.0/pnpm-win32-x64.zip",
                sha256 = "7ac25ba81b8a9f213a307ae89198ba7e636e6c74fa0d775d554ba46e0187358b",
            },
            ["11.0.5"] = {
                url = "https://github.com/pnpm/pnpm/releases/download/v11.0.5/pnpm-win32-x64.zip",
                sha256 = "c79329a48a5e67bbbf73578fe0ddd5ff1fef05ed8c9ce43cfdc675d4d173fa3a",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")

-- Tarball / zip layouts (verified via tar -tzf / unzip -l):
--   linux/macos: `pnpm` binary at top level + `dist/` directory of
--                supporting JS modules. Both must end up in install_dir.
--   windows:     `pnpm.exe` at top level + `dist/`.
--
-- xlings auto-extracts the archive into a runtime working directory
-- whose contents we then move into install_dir wholesale. The shape
-- is intentionally flat (binary at install_dir root, NOT install_dir/bin)
-- because the `dist/` sibling needs to be findable relative to the
-- binary at runtime — pnpm uses argv[0] resolution to locate dist/.
function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    if is_host("windows") then
        for _, entry in ipairs({"pnpm.exe", "dist"}) do
            os.trymv(entry, path.join(pkginfo.install_dir(), entry))
        end
    else
        for _, entry in ipairs({"pnpm", "dist"}) do
            os.trymv(entry, path.join(pkginfo.install_dir(), entry))
        end
    end

    return true
end

function config()
    local cfg = { bindir = pkginfo.install_dir() }
    if is_host("windows") then
        cfg.alias = "pnpm.exe"
    end
    xvm.add("pnpm", cfg)
    return true
end

function uninstall()
    xvm.remove("pnpm")
    return true
end
