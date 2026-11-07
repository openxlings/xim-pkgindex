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
    ci = {  },

    -- xim pkg info
    type = "package",
    -- From 0.0.20 (payload manifest version 5) one archive serves every
    -- system: the server (bin/mcppls.okb) and the engine
    -- (clangd/openkal/bin/clangd.okb) are ok images, started by the runner of
    -- each system (libexec/okrun/<system>-<arch>/okrun), which payload.json
    -- names per platform. 0.0.18 and 0.0.19 (version 4) are one archive per
    -- platform: the server's okb started by bin/okrun, and a native clangd
    -- (glibc-dynamic on Linux, self-contained on Windows/macOS); before them a
    -- static program per platform (bin/mcppls). macOS is arm64-only; Linux
    -- supports x86_64/aarch64; Windows is x86_64-only.
    archs = {"x86_64", "aarch64"},
    status = "dev", -- 0.0.x: upstream is pre-1.0, expect breaking changes
    categories = {"cpp", "language-server", "lsp"},
    keywords = {"cpp", "c++", "modules", "lsp", "clangd", "mcpp", "language-server"},

    programs = {"mcppls"},

    -- The editors/nvim plugin built from this same tag is packaged
    -- separately, as `mcppls-nvim` (pkgs/m/mcppls-nvim.lua), which declares
    -- this package as a dependency; the plugin finds the server here via
    -- the xvm shim on PATH.

    xvm_enable = true,

    -- Release assets, verbatim from upstream `SHA256SUMS` (per release):
    --   payload/libexec/okrun/<system>-<arch>/okrun[.exe] — the runners from
    --                                0.0.20 (`okrun mcppls.okb serve`)
    --   payload/clangd/openkal/bin/clangd.okb — the engine from 0.0.20
    --   payload/bin/mcppls.okb + payload/bin/okrun[.exe] — the server from
    --                                0.0.18 (`okrun mcppls.okb serve`)
    --   payload/bin/mcppls[.exe]   — the server before 0.0.18; `mcppls serve` speaks LSP over stdio
    --   payload/clangd/bin/clangd[.exe] — the pinned clangd (23.1.0) it drives,
    --                                before 0.0.20
    --   payload/kit/               — the semantic kit (libc++ headers/sysroot)
    --   payload/payload.json       — build/manifest record
    --
    -- v0.0.16 uses upstream directly; its ecosystem mirrors are not published.
    -- 0.0.20 names its one archive per version (`url`); every other version
    -- (v0.0.19, v0.0.18, v0.0.15, v0.0.11) takes the regional sources below.
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
            ["latest"] = { ref = "0.0.20" },
            ["0.0.20"] = {
                url = {
                    GLOBAL = "https://github.com/Sunrisepeak/mcpp-language-server/releases/download/v0.0.20/mcppls-payload-0.0.20.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mcppls/releases/download/v0.0.20/mcppls-payload-0.0.20.tar.gz",
                },
                sha256 = {
                    x86_64 = "c0519f2badb0ed2d40ab817b72c51759866273deb7a0b4692e50edb02f1cec2d",
                    aarch64 = "c0519f2badb0ed2d40ab817b72c51759866273deb7a0b4692e50edb02f1cec2d",
                },
            },
            ["0.0.19"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "8f74d532662ba1783d931c35b08764e02e58eb097445b15a5d95bdf2bebd1b53",
                    aarch64 = "5c4903299a04c409d8dd08743b6e39e90e48cc66026250898d18e0e014dcee71",
                },
            },
            ["0.0.18"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "2cfcdffa5c4fc5bd5bbb8cc11ba85274dc5f35ae2a5e0490d3ffd4853b4da39c",
                    aarch64 = "299373316595a516bccd169cac56402711f5faac3498778256d563c516b6fec1",
                },
            },
            ["0.0.16"] = {
                url = "https://github.com/Sunrisepeak/mcpp-language-server/releases/download/v${version}/payload-linux-${arch_alias}.tar.gz",
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "7c334e963c6d6102648bfe0aaccf8c30805007e21b1dd57afd5ce3751c1385b1",
                    aarch64 = "4b62fe0a51c3b9619610d2eff765703db755b28db5e228dac06cc77c8e6fb214",
                },
            },
            ["0.0.15"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "a59587502ba8262902ae649d633103b55bf115c0ac182d6be604aa1a6f761688",
                    aarch64 = "cdf50a4753342f786b28102631f500a1cb9071dde371da0ae2b36c189ef566ab",
                },
            },
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
            ["latest"] = { ref = "0.0.20" },
            ["0.0.20"] = {
                url = {
                    GLOBAL = "https://github.com/Sunrisepeak/mcpp-language-server/releases/download/v0.0.20/mcppls-payload-0.0.20.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mcppls/releases/download/v0.0.20/mcppls-payload-0.0.20.tar.gz",
                },
                sha256 = {
                    aarch64 = "c0519f2badb0ed2d40ab817b72c51759866273deb7a0b4692e50edb02f1cec2d",
                },
            },
            ["0.0.19"] = {
                arch_alias = { aarch64 = "arm64" },
                sha256 = {
                    aarch64 = "2a9cdf17ae609d2bce4d1943f83400f0e490c33bf80e8f2e83486a9b44294f39",
                },
            },
            ["0.0.18"] = {
                arch_alias = { aarch64 = "arm64" },
                sha256 = {
                    aarch64 = "1b27fb29b77d61cf21159518c00bdfc15744210bd5aeb8d118fcab0b6e81d0b5",
                },
            },
            ["0.0.16"] = {
                url = "https://github.com/Sunrisepeak/mcpp-language-server/releases/download/v${version}/payload-darwin-${arch_alias}.tar.gz",
                arch_alias = { aarch64 = "arm64" },
                sha256 = {
                    aarch64 = "da8f2d62d7679ef9c477a4e10648527a9ee314909997ebef77ba793c847f9d2e",
                },
            },
            ["0.0.15"] = {
                arch_alias = { aarch64 = "arm64" },
                sha256 = {
                    aarch64 = "d09a69f967c3033e968e8e3c1ad47e916e4869ebaad84ad998251eaafaff154f",
                },
            },
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
            ["latest"] = { ref = "0.0.20" },
            ["0.0.20"] = {
                url = {
                    GLOBAL = "https://github.com/Sunrisepeak/mcpp-language-server/releases/download/v0.0.20/mcppls-payload-0.0.20.tar.gz",
                    CN = "https://gitcode.com/xlings-res/mcppls/releases/download/v0.0.20/mcppls-payload-0.0.20.tar.gz",
                },
                sha256 = {
                    x86_64 = "c0519f2badb0ed2d40ab817b72c51759866273deb7a0b4692e50edb02f1cec2d",
                },
            },
            ["0.0.19"] = {
                arch_alias = { x86_64 = "x64" },
                sha256 = {
                    x86_64 = "f29ab7e737cf40cb109b80718883a3752b2d8dd33c319c6b9d7299fc95f3c21f",
                },
            },
            ["0.0.18"] = {
                arch_alias = { x86_64 = "x64" },
                sha256 = {
                    x86_64 = "edf205c32031aa2fb281f9f1cffc44734564a7ee6a65f3e35a17509636f7a739",
                },
            },
            ["0.0.16"] = {
                url = "https://github.com/Sunrisepeak/mcpp-language-server/releases/download/v${version}/payload-win32-${arch_alias}.tar.gz",
                arch_alias = { x86_64 = "x64" },
                sha256 = {
                    x86_64 = "ce188b16dc925673980740ae5760b7b2f2feaae355a3fb8449513543d2c69c3f",
                },
            },
            ["0.0.15"] = {
                arch_alias = { x86_64 = "x64" },
                sha256 = {
                    x86_64 = "0ac10a1fe117b99768c34c05d826fbb0a8aacd9f3daab56ec2745af810077dfd",
                },
            },
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

-- The runner of this system in a payload of manifest version 5 (0.0.20 on):
-- libexec/okrun/<system>-<arch>/, as the payload's payload.json names it for
-- each platform. macOS and Windows have one; on Linux the machine is read
-- from `uname -m`, because `os.arch()` is not bound in the hook runtime
-- (libs/qtsdk.lua). An unknown machine has no runner, and `installed()`
-- then answers no rather than guessing.
function __runner_dir()
    local runners = path.join(pkginfo.install_dir(), "libexec", "okrun")
    local host = os.host()
    if host == "windows" then return path.join(runners, "windows-x86_64") end
    if host == "macosx" then return path.join(runners, "macos-aarch64") end
    local ok, out = pcall(os.iorun, "uname -m")
    local m = ok and (out or ""):gsub("%s+$", "") or ""
    if m == "aarch64" or m == "arm64" then return path.join(runners, "linux-aarch64") end
    if m == "x86_64" then return path.join(runners, "linux-x86_64") end
    return nil
end

-- One assertion per payload component, and each file is provided by exactly
-- one of the three payloads inside the tarball (server / clangd / kit): if a
-- component did not land, `installed()` names it instead of answering a bare
-- "the directory exists".
function __required_files()
    local d = pkginfo.install_dir()
    local win = os.host() == "windows"
    local okrun = win and "okrun.exe" or "okrun"
    if os.isdir(path.join(d, "libexec", "okrun")) then
        -- 0.0.20 on: one payload for every system; the engine is an okb
        -- started by the same runner as the server.
        local runner = __runner_dir()
        return {
            path.join(d, "bin", "mcppls.okb"),
            runner and path.join(runner, okrun) or path.join(d, "libexec", "okrun", "<unknown machine>", okrun),
            path.join(d, "clangd", "openkal", "bin", "clangd.okb"),
            path.join(d, "kit", "kit.json"),
        }
    end
    local clangd = win and "clangd.exe" or "clangd"
    local files = {
        path.join(d, "clangd", "bin", clangd),          -- pinned clangd payload
        path.join(d, "kit", "kit.json"),                -- semantic kit payload
    }
    if os.isfile(path.join(d, "bin", "mcppls.okb")) then
        -- 0.0.18 and 0.0.19: the server's okb and the runner that starts it
        table.insert(files, path.join(d, "bin", "mcppls.okb"))
        table.insert(files, path.join(d, "bin", okrun))
    else
        table.insert(files, path.join(d, "bin", win and "mcppls.exe" or "mcppls"))
    end
    return files
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
    local bindir = path.join(pkginfo.install_dir(), "bin")
    local okb = path.join(bindir, "mcppls.okb")
    if os.isdir(path.join(pkginfo.install_dir(), "libexec", "okrun")) then
        -- 0.0.20 on: `mcppls` is this system's runner starting the okb (the
        -- shim puts the runner's directory first on PATH).
        xvm.add("mcppls", { bindir = __runner_dir(), alias = 'okrun "' .. okb .. '"' })
    elseif os.isfile(okb) then
        -- 0.0.18 and 0.0.19: the payload's okrun beside the okb; the server
        -- finds the rest of its payload around its image.
        xvm.add("mcppls", { bindir = bindir, alias = 'okrun "' .. okb .. '"' })
    else
        xvm.add("mcppls", { bindir = bindir })
    end
    return true
end

function uninstall()
    xvm.remove("mcppls")
    return true
end
