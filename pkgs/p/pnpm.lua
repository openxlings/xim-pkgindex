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
            --
            -- AND IT IS THE `linuxstatic` ASSET, NOT `linux`. Both exist for
            -- this release; they differ in what they need from the machine, and
            -- only one of them closes the loop:
            --
            --   pnpm-linux-x64        49,884,244  dynamic, INTERP -> host glibc
            --   pnpm-linuxstatic-x64  42,457,484  statically linked, no INTERP,
            --                                     no .dynamic section at all
            --
            -- The dynamic one cannot be made hermetic here. It is built with
            -- `pkg` -- the JS payload sits after the ELF image and is found by
            -- scanning back from the end of the file -- so pointing it at this
            -- index's glibc would mean letting elfpatch rewrite it, and that
            -- GROWS the file (measured 2026-09-16: 49,884,244 -> 49,892,436 from
            -- `--set-rpath` alone), after which the payload is no longer where
            -- the prelude looks and `pnpm --version` dies in
            -- pkg/prelude/bootstrap.js with "Invalid or unexpected token".
            -- claude.lua hit that exact wall with a Bun binary. Its answer was
            -- to declare no deps and accept the host loader; the answer here is
            -- better, because upstream publishes a build that needs no loader.
            --
            -- Static also means patchelf is not a hazard rather than a hazard
            -- avoided: it REFUSES this file ("cannot find section '.dynamic'")
            -- and leaves it byte-identical, so no opt-out is needed and none is
            -- declared. Verified 2026-09-16, both directions.
            --
            -- Not on the CN mirror (checked 2026-09-16): xlings-res/pnpm carries
            -- 12.1.0 and 11.12.0 only, so this one has GLOBAL alone until it does.
            ["7.33.7"] = {
                url = "https://github.com/pnpm/pnpm/releases/download/v7.33.7/pnpm-linuxstatic-x64",
                sha256 = "69f63324da4776dafb2f2bdfcf3e69687f26280e37a55cb25f7ede15045d0c29",
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
        for _, candidate in ipairs({"pnpm-linuxstatic-x64", "pnpm-linuxstatic-arm64",
                                    "pnpm-linux-x64", "pnpm-linux-arm64",
                                    "pnpm-macos-arm64", "pnpm-macos-x64",
                                    "pnpm-win-x64.exe", "pnpm-win-arm64.exe"}) do
            if os.isfile(candidate) then found = candidate break end
        end
        if not found then
            raise("pnpm: neither an extracted `" .. exe .. "` nor a bare pnpm-<platform> executable was found")
        end
        os.mv(found, path.join(dir, exe))

        -- No elfpatch opt-out here, and that is the point: on linux this asset
        -- is the statically linked build (see the version table), which has no
        -- INTERP and no .dynamic section, so patchelf refuses it and leaves it
        -- byte-identical. macos and windows are not ELF at all. The payload is
        -- whole on every platform because nothing rewrites it -- which for a
        -- `pkg` single-file executable is the only way it stays whole.
        --
        -- The `deps` above are declared per-platform and so still resolve for
        -- this version, where nothing uses them. A wasted download rather than
        -- a wrong answer, and the cost of a dep table that cannot name a
        -- version.
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

    -- The bare-executable payload is RUN once, here. config() is the first
    -- hook after elfpatch, and for this shape nothing short of running it can
    -- see the damage: every existence check passes on a `pkg` binary whose
    -- appended payload has been shifted out from under the prelude, and only
    -- `--version` reports the truth. An install that registered a shim for one
    -- would fail in the consumer's terminal instead (contributing.md 5.1).
    --
    -- The static asset makes that damage unconstructible rather than merely
    -- unlikely, so this is a check on the invariant, not on a workaround: if it
    -- ever fires, something changed about the asset or about who is allowed to
    -- rewrite it. The 8+ shape has a `dist/` beside it, is an ordinary node
    -- build that is SUPPOSED to be patched, and is left alone.
    if not os.isdir(path.join(dir, "dist")) then
        local prog = path.join(dir, exe)
        local out = try { function() return os.iorun('"' .. prog .. '" --version') end }
        local reported = tostring(out or ""):gsub("%s+", "")
        -- A broken `pkg` binary fails on stderr and prints nothing, so an empty
        -- answer is the shape this guard exists to catch -- name that rather
        -- than reporting it as a mismatch against the empty string.
        if reported == "" then
            raise("pnpm: " .. prog .. " printed no version -- the payload was modified "
                  .. "after staging. A `pkg` single-file executable does not survive having "
                  .. "its ELF rewritten; see the version table in this recipe.")
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
