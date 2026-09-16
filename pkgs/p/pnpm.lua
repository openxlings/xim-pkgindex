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
                runtime = { "xim:glibc@>=2.39", "xim:gcc-runtime@15.1.0" },
            },
            url_template = "https://github.com/pnpm/pnpm/releases/download/v{version}/pnpm-linux-x64.tar.gz",
            ["latest"] = { ref = "12.1.0" },
            ["12.1.0"] = {
                url = {
                    GLOBAL = "https://github.com/pnpm/pnpm/releases/download/v12.1.0/pnpm-linux-x64.tar.gz",
                    CN = "https://gitcode.com/xlings-res/pnpm/releases/download/12.1.0/pnpm-linux-x64.tar.gz",
                },
                sha256 = "ef4c3e31c8f6e587c9f04ca4b42b63d47f331247930617304ffa63354c11db79",
            },
            ["12.0.0"] = {
                url = "https://github.com/pnpm/pnpm/releases/download/v12.0.0/pnpm-linux-x64.tar.gz",
                sha256 = "d93497ba07d5dfc7d527b30905fdd24f55c87618ea23ea3af287cdff061510e0",
            },
            ["11.12.0"] = {
                url = {
                    GLOBAL = "https://github.com/pnpm/pnpm/releases/download/v11.12.0/pnpm-linux-x64.tar.gz",
                    CN = "https://gitcode.com/xlings-res/pnpm/releases/download/11.12.0/pnpm-linux-x64.tar.gz",
                },
                sha256 = "dd19bfd8bcd33a3b38dcce335e8d233194c0a61ffe1f5bcf5047f60f6d4978b8",
            },
            ["11.0.5"] = {
                url = "https://github.com/pnpm/pnpm/releases/download/v11.0.5/pnpm-linux-x64.tar.gz",
                sha256 = "c1b55f53f5344cf0e26441d97b9ee2ee3b81791503c5cbd4bb93ae1898b8d211",
            },
            -- 7.33.7, the last of the 7 line, for a project whose lockfile that
            -- major still owns. Note the asset shape: 7.x publishes one bare,
            -- self-contained executable per platform, not the `.tar.gz` with a
            -- `dist/` beside it that 8+ ships, so install() handles both.
            -- Not on the CN mirror (checked 2026-09-16): xlings-res/pnpm carries
            -- 12.1.0 and 11.12.0 only, so this one has GLOBAL alone until it does.
            ["7.33.7"] = {
                url = "https://github.com/pnpm/pnpm/releases/download/v7.33.7/pnpm-linux-x64",
                sha256 = "ee39e4fc291bd83a0cdf2087cc9de29c0ff7a7999edff845959ca08483f0cca0",
            },
        },
        macosx = {
            url_template = "https://github.com/pnpm/pnpm/releases/download/v{version}/pnpm-darwin-arm64.tar.gz",
            ["latest"] = { ref = "12.1.0" },
            ["12.1.0"] = {
                url = {
                    GLOBAL = "https://github.com/pnpm/pnpm/releases/download/v12.1.0/pnpm-darwin-arm64.tar.gz",
                    CN = "https://gitcode.com/xlings-res/pnpm/releases/download/12.1.0/pnpm-darwin-arm64.tar.gz",
                },
                sha256 = "927542783706b6966b6792f263b9b958dcd9909c5174965cd1aae0f4ab7f613c",
            },
            ["12.0.0"] = {
                url = "https://github.com/pnpm/pnpm/releases/download/v12.0.0/pnpm-darwin-arm64.tar.gz",
                sha256 = "c31f5abe796dfc8489ea980cb438844053ad6b402bb4f3eb9abd71086279d75b",
            },
            ["11.12.0"] = {
                url = {
                    GLOBAL = "https://github.com/pnpm/pnpm/releases/download/v11.12.0/pnpm-darwin-arm64.tar.gz",
                    CN = "https://gitcode.com/xlings-res/pnpm/releases/download/11.12.0/pnpm-darwin-arm64.tar.gz",
                },
                sha256 = "0d63d9b468690e661a182efd2c1bc752dbddc753e852b76ca5218f32fcf78a2e",
            },
            ["11.0.5"] = {
                url = "https://github.com/pnpm/pnpm/releases/download/v11.0.5/pnpm-darwin-arm64.tar.gz",
                sha256 = "24d412b2d137c6bc91e09c039b0e8ced6b5ac8f1dc9ea1881f0521cdb3bc5318",
            },
            -- 7.33.7: one bare executable, and macos-arm64 rather than
            -- darwin-arm64.tar.gz. Not on the CN mirror.
            ["7.33.7"] = {
                url = "https://github.com/pnpm/pnpm/releases/download/v7.33.7/pnpm-macos-arm64",
                sha256 = "0e33b74ca8e2407e07f8be499e7e36531e239b81a627396f559e48270a0c012f",
            },
        },
        windows = {
            url_template = "https://github.com/pnpm/pnpm/releases/download/v{version}/pnpm-win32-x64.zip",
            ["latest"] = { ref = "12.1.0" },
            ["12.1.0"] = {
                url = {
                    GLOBAL = "https://github.com/pnpm/pnpm/releases/download/v12.1.0/pnpm-win32-x64.zip",
                    CN = "https://gitcode.com/xlings-res/pnpm/releases/download/12.1.0/pnpm-win32-x64.zip",
                },
                sha256 = "69c0d1d46cdc12bbefad653e859636179927aed292f9af286460a0d38d1d99d2",
            },
            ["12.0.0"] = {
                url = "https://github.com/pnpm/pnpm/releases/download/v12.0.0/pnpm-win32-x64.zip",
                sha256 = "092f60a1304fd61df44c6c534d424144146e41cc9b3cb0557372baadc00f29d5",
            },
            ["11.12.0"] = {
                url = {
                    GLOBAL = "https://github.com/pnpm/pnpm/releases/download/v11.12.0/pnpm-win32-x64.zip",
                    CN = "https://gitcode.com/xlings-res/pnpm/releases/download/11.12.0/pnpm-win32-x64.zip",
                },
                sha256 = "7ac25ba81b8a9f213a307ae89198ba7e636e6c74fa0d775d554ba46e0187358b",
            },
            ["11.0.5"] = {
                url = "https://github.com/pnpm/pnpm/releases/download/v11.0.5/pnpm-win32-x64.zip",
                sha256 = "c79329a48a5e67bbbf73578fe0ddd5ff1fef05ed8c9ce43cfdc675d4d173fa3a",
            },
            -- 7.33.7: one bare executable, `win-x64.exe` rather than
            -- `win32-x64.zip`. Not on the CN mirror.
            ["7.33.7"] = {
                url = "https://github.com/pnpm/pnpm/releases/download/v7.33.7/pnpm-win-x64.exe",
                sha256 = "3c1329114beedf8a3882acdd7c7bd99153afb685fc6ac34ec54a6eb69cf721f6",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")
import("xim.libxpkg.elfpatch")

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
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mkdir(dir)

    local exe = is_host("windows") and "pnpm.exe" or "pnpm"

    -- 8+ : an archive holding the binary and its `dist/`, both of which move.
    if os.isfile(exe) then
        os.trymv(exe, path.join(dir, exe))
        if os.isdir("dist") then
            os.trymv("dist", path.join(dir, "dist"))
        end
    else
        -- 7.x: one self-contained executable, downloaded rather than extracted,
        -- so it arrives under its platform's asset name and has no `dist/`
        -- beside it. Renaming it to `pnpm` is what makes both shapes register
        -- the same way below, and argv[0] resolution has nothing to find for
        -- this one anyway -- the JS is inside the binary.
        local found = nil
        for _, candidate in ipairs({"pnpm-linux-x64", "pnpm-linux-arm64",
                                    "pnpm-macos-arm64", "pnpm-macos-x64",
                                    "pnpm-win-x64.exe", "pnpm-win-arm64.exe"}) do
            if os.isfile(candidate) then found = candidate break end
        end
        if not found then
            raise("pnpm: neither an extracted `" .. exe .. "` nor a bare pnpm-<platform> executable was found")
        end
        os.mv(found, path.join(dir, exe))

        -- AND IT MUST NOT BE PATCHED. This one is a `pkg` single-file
        -- executable: the JS payload is appended after the ELF image and
        -- found by scanning back from the end of the file. `deps` above
        -- names xim:glibc, which hands xlings' predicate-driven elfpatch a
        -- loader provider to key off -- and patchelf rewrites the section
        -- table, which GROWS the file (measured 2026-09-16 on
        -- pnpm-linux-x64 7.33.7: 49,884,244 -> 49,892,436, +8192 from
        -- `--set-rpath` alone) and the payload is then no longer where the
        -- prelude looks. `pnpm --version` dies in the bootstrap:
        --
        --     pkg/prelude/bootstrap.js:1
        --     `2@
        --     SyntaxError: Invalid or unexpected token
        --
        -- Exactly claude.lua's Bun binary, by exactly the same route (there
        -- the answer is empty `deps`, which is not available here: `deps`
        -- is per-platform, and 8+ on the same platform does want them). So
        -- the skip is scoped to the payload that cannot survive it -- 8+
        -- ships an ordinary node build beside `dist/` and keeps its
        -- patching. Unpatched, this binary keeps its own absolute INTERP
        -- and runs against the host glibc, which is what upstream's own
        -- installer produces too.
        --
        -- The two deps are still installed and simply unused here. That is
        -- the cost of a per-platform `deps` table, and it is a wasted
        -- download rather than a wrong answer.
        elfpatch.skip()
    end

    local installed = path.join(dir, exe)
    if not os.isfile(installed) then
        raise("pnpm: " .. installed .. " is missing after staging")
    end
    if not is_host("windows") then
        os.iorun('chmod +x "' .. installed .. '"')
    end

    return true
end

function config()
    local dir = pkginfo.install_dir()
    local exe = is_host("windows") and "pnpm.exe" or "pnpm"

    -- The bare-executable payload is RUN once, here, because this is the
    -- first point after elfpatch -- and because for this shape nothing
    -- short of running it can see the damage. Every existence check passes
    -- on a broken pkg binary; it is `--version` that reports the truth, and
    -- an install that registered a shim for it would fail in the consumer's
    -- terminal instead (contributing.md 5.1). The 8+ shape has a `dist/`
    -- beside it, is an ordinary node build, and is left alone.
    if not os.isdir(path.join(dir, "dist")) then
        local prog = path.join(dir, exe)
        local out = try { function() return os.iorun('"' .. prog .. '" --version') end }
        local reported = tostring(out or ""):gsub("%s+", "")
        -- A broken `pkg` binary fails on stderr and prints nothing, so an empty
        -- answer is the shape this guard exists to catch -- name that rather
        -- than reporting it as a mismatch against the empty string.
        if reported == "" then
            raise("pnpm: " .. prog .. " printed no version (the payload was modified after "
                  .. "staging -- a `pkg` single-file executable cannot survive elfpatch; "
                  .. "see install())")
        end
        if reported ~= pkginfo.version() then
            raise("pnpm: " .. prog .. " reports version " .. reported
                  .. ", not the " .. pkginfo.version() .. " that was installed")
        end
    end

    local cfg = { bindir = dir }
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
