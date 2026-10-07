package = {
    spec = "2",
    -- base info
    name = "mcppls",
    description = "C++20/23 modules language server: module-aware go-to-definition, hover, references and completion on GCC/Clang/MSVC, with a pinned clangd and the semantic kit bundled",

    authors = {"sunrisepeak"},
    maintainers = {"https://github.com/Sunrisepeak/mcpp-language-server/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/Sunrisepeak/mcpp-language-server",
    docs = "https://github.com/Sunrisepeak/mcpp-language-server#readme",
    homepage = "https://github.com/Sunrisepeak/mcpp-language-server",
    ci = { update = true },

    -- xim pkg info
    type = "package",
    -- The `mcppls` server itself is a static binary on every platform; the
    -- bundled clangd is glibc-dynamic on Linux (no libstdc++/libgcc_s) and
    -- self-contained on Windows/macOS. macOS upstream builds are arm64-only;
    -- linux and windows are x86_64-only.
    archs = {"x86_64", "aarch64"},
    status = "dev", -- 0.0.x: upstream is pre-1.0, expect breaking changes
    categories = {"cpp", "language-server", "lsp"},
    keywords = {"cpp", "c++", "modules", "lsp", "clangd", "mcpp", "language-server"},

    programs = {"mcppls"},

    -- The editors/nvim plugin built from this same tag is packaged
    -- separately, as `mcppls-nvim` (pkgs/n/mcppls-nvim.lua), which declares
    -- this package as a dependency; the plugin finds the server here via
    -- the xvm shim on PATH.

    xvm_enable = true,

    -- Release assets, verbatim from upstream `SHA256SUMS` (v0.0.11):
    --   payload/bin/mcppls[.exe]   — the server; `mcppls serve` speaks LSP over stdio
    --   payload/clangd/bin/clangd[.exe] — the pinned clangd (23.1.0) it drives
    --   payload/kit/               — the semantic kit (libc++ headers/sysroot)
    --   payload/payload.json       — build/manifest record
    --
    -- GLOBAL points at upstream releases; CN is the byte-identical mirror at
    -- gitcode.com/xlings-res/mcppls (uploaded with `gtc release upload` and
    -- verified by re-download), so the same sha256 serves both legs. The URL
    -- file names are upstream's: linux assets say `x64`/`arm64`, the macOS
    -- one `darwin-arm64`, the Windows one `win32-x64` — hence `arch_alias`.
    xpm = {
        linux = {
            -- NO runtime deps, on purpose. The payload ships its own loader
            -- story (clangd keeps its host interpreter and an $ORIGIN-relative
            -- RUNPATH into kit/) and a self-integrity manifest (payload.json
            -- pins every file's size/sha256, enforced at serve time). The
            -- runtime-dep closure is what makes elfpatch stamp an xpkgs RPATH
            -- onto the ELFs at install time — measured: clangd grew 16 KB and
            -- failed its own integrity check (payload-corrupt), and the LSP
            -- never reported ready. Without runtime deps the payload stays
            -- byte-identical to upstream, host-integrated by design; the
            -- dep-closure check classifies it the same way as `code`/JDKs and
            -- counts the host as the provider.
            source = {
                GLOBAL = "https://github.com/Sunrisepeak/mcpp-language-server/releases/download/v${version}/payload-linux-${arch_alias}.tar.gz",
                CN = "https://gitcode.com/xlings-res/mcppls/releases/download/v${version}/payload-linux-${arch_alias}.tar.gz",
            },
            ["latest"] = { ref = "0.0.11" },
            ["0.0.11"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "92bd02d6805eb73dfa1a06d3d1be2c08b0977034089745450d84476a76586ea7",
                    aarch64 = "b294916d892271288b2f2c7e512d86786f44740cee96b4c83fe8e2dfb0f287e4",
                },
            },
        },
        macosx = {
            source = {
                GLOBAL = "https://github.com/Sunrisepeak/mcpp-language-server/releases/download/v${version}/payload-darwin-${arch_alias}.tar.gz",
                CN = "https://gitcode.com/xlings-res/mcppls/releases/download/v${version}/payload-darwin-${arch_alias}.tar.gz",
            },
            ["latest"] = { ref = "0.0.11" },
            ["0.0.11"] = {
                arch_alias = { aarch64 = "arm64" },
                sha256 = {
                    aarch64 = "4bf7ffd7d2e6136d6ab86710b311261f3106ff1fdb819dfebb6b675dc1695817",
                },
            },
        },
        windows = {
            source = {
                GLOBAL = "https://github.com/Sunrisepeak/mcpp-language-server/releases/download/v${version}/payload-win32-${arch_alias}.tar.gz",
                CN = "https://gitcode.com/xlings-res/mcppls/releases/download/v${version}/payload-win32-${arch_alias}.tar.gz",
            },
            ["latest"] = { ref = "0.0.11" },
            ["0.0.11"] = {
                arch_alias = { x86_64 = "x64" },
                sha256 = {
                    x86_64 = "7cf8e5f8decb39e80ad4f1b15f3927cce930c95303d51095c63c47817989dbe1",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")

-- One assertion per payload component, and each file is provided by exactly
-- one of the three payloads inside the tarball (server / clangd / kit): if a
-- component did not land, `installed()` names it instead of answering a bare
-- "the directory exists".
function __required_files()
    local d = pkginfo.install_dir()
    local exe = (os.host() == "windows") and "mcppls.exe" or "mcppls"
    local clangd = (os.host() == "windows") and "clangd.exe" or "clangd"
    return {
        path.join(d, "bin", exe),                       -- server payload
        path.join(d, "clangd", "bin", clangd),          -- pinned clangd payload
        path.join(d, "kit", "kit.json"),                -- semantic kit payload
    }
end

function installed()
    -- Quiet: xim asks this before an install too, where "no" is the normal
    -- answer, not an error.
    for _, f in ipairs(__required_files()) do
        if not os.isfile(f) then
            return false
        end
    end
    return true
end

function install()
    -- The tarball's own top directory is `payload/`.
    os.tryrm(pkginfo.install_dir())
    os.mv("payload", pkginfo.install_dir())
    -- A failed extraction surfaces here, naming what did not land, rather
    -- than as a silent empty install dir behind a green install banner.
    local missing = {}
    for _, f in ipairs(__required_files()) do
        if not os.isfile(f) then
            table.insert(missing, f)
        end
    end
    if #missing > 0 then
        log.error("mcppls install incomplete, files missing:\n    "
            .. table.concat(missing, "\n    "))
        return false
    end
    return true
end

function config()
    xvm.add("mcppls", { bindir = path.join(pkginfo.install_dir(), "bin") })
    return true
end

function uninstall()
    xvm.remove("mcppls")
    return true
end
