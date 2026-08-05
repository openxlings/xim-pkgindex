-- Claude Code CLI — Anthropic's official *native* single-file executable.
--
-- Until 2.1.220 this recipe installed the npm package
-- `@anthropic-ai/claude-code` and therefore dragged node + npm in as
-- dependencies, ran a postinstall that downloaded the real binary a
-- second time, and needed a runtime probe to tell the two historical
-- layouts (`cli.js` vs `bin/claude.exe`) apart. Anthropic now publishes
-- the platform binary directly — it is what
-- `curl -fsSL https://claude.ai/install.sh | bash` fetches — so all of
-- that is gone: one download, one file, chmod +x.
--
-- URL shape, read off the official installers (claude.ai/install.sh and
-- claude.ai/install.ps1):
--
--   https://downloads.claude.ai/claude-code-releases/<version>/<platform>/claude      (unix)
--   https://downloads.claude.ai/claude-code-releases/<version>/<platform>/claude.exe  (windows)
--   platform = {linux,darwin,win32}-{x64,arm64}  (+ linux-*-musl variants)
--
--   https://downloads.claude.ai/claude-code-releases/<version>/manifest.json
--     carries the authoritative per-platform sha256. Every hash below was
--     taken from there; the ones for 2.1.222 were re-verified against the
--     downloaded bytes before the CN mirror was published.
--
--   https://downloads.claude.ai/claude-code-releases/latest  -> "2.1.222"
--   https://downloads.claude.ai/claude-code-releases/stable  -> "2.1.220"
--
-- Linux deliberately uses the **glibc** asset, not `linux-x64-musl`: the
-- musl one is not static, it is dynamically linked against
-- /lib/ld-musl-x86_64.so.1, which a glibc host does not have. The glibc
-- build only needs NEEDED libc/libm/libdl/librt/libpthread and its
-- highest referenced symbol version is GLIBC_2.17 (readelf -V), i.e.
-- every mainstream distro since 2012.
--
-- `xim:musl` now exists, so the obvious next thought is to ship the musl
-- asset against it and stop depending on the host libc at all. It really
-- does work — `<musl>/lib/ld-musl-x86_64.so.1 claude --version` prints
-- 2.1.222, and --help / doctor / `mcp list` all run — but only by
-- invoking the loader explicitly, and that is not free:
--
--   $ claude doctor                            → Running: native
--   $ /lib64/ld-linux-x86-64.so.2 claude doctor → Running: package-manager
--
-- Same binary, different answer. Under explicit-loader invocation the
-- kernel points /proc/self/exe at the LOADER, not the program (measured:
-- it reads back as `.../lib/libc.so`), and this binary contains three
-- references to /proc/self/exe — it is how Bun computes
-- `process.execPath`. Everything that re-spawns the CLI from that path
-- would exec libc.so. `--version` passing proves nothing about it. So
-- the glibc asset stays, and the host loader with it.
--
-- `deps` is deliberately EMPTY on linux, and that is load-bearing.
-- Declaring `xim:glibc@...` would hand xlings' predicate-driven elfpatch
-- a loader provider to key off, and **patchelf destroys this binary**:
-- it is a Bun single-file executable whose JS payload is appended after
-- the ELF image, so rewriting the section table grows the file
-- (289,467,400 -> 289,475,592 bytes on 2.1.222 linux-x64) and the
-- payload can no longer be found — `claude --version` then dies with
-- SIGSEGV. Verified 2026-08-06. With no dep the predicate never fires,
-- the binary keeps its own absolute INTERP
-- (/lib64/ld-linux-x86-64.so.2) and runs against the host glibc, which
-- is exactly what the official installer produces too. Compare
-- aarch64-linux-musl-gcc.lua's "no deps" note — same conclusion from the
-- other side: there the payload needs no patching because it is static,
-- here it must not be patched at all.
--
-- Adding `xim:musl` to `deps` would not change this: elfpatch IS
-- patchelf, so pointing the dep at a musl loader instead of a glibc one
-- reaches the same SIGSEGV by the same route. The only patch-free way to
-- redirect the loader is the explicit invocation above, and it costs
-- `process.execPath`.
--
-- GLOBAL = downloads.claude.ai, the authoritative upstream.
-- CN     = gitcode.com/xlings-res/claude, a byte-identical copy of the
--          same bytes (asset renamed to claude-<version>-<platform> so
--          all six platform binaries can live in one release), published
--          so mainland-China installs don't have to reach
--          downloads.claude.ai. Only the version `latest` points at is
--          mirrored — each asset is ~250-280 MB, and older pins are rare
--          enough not to be worth ~1.6 GB of mirror per release.

local _CC_GLOBAL = "https://downloads.claude.ai/claude-code-releases"
local _CC_CN = "https://gitcode.com/xlings-res/claude/releases/download"

local function _asset(platform)
    return platform:find("^win32") and "claude.exe" or "claude"
end

-- Upstream only. Used for the historical pins, which are not mirrored.
local function _up(ver, platform, sha256)
    return {
        url = string.format("%s/%s/%s/%s", _CC_GLOBAL, ver, platform, _asset(platform)),
        sha256 = sha256,
    }
end

-- Upstream + the CN mirror of the same bytes.
local function _mirrored(ver, platform, sha256)
    local suffix = platform:find("^win32") and ".exe" or ""
    return {
        url = {
            GLOBAL = string.format("%s/%s/%s/%s", _CC_GLOBAL, ver, platform, _asset(platform)),
            CN = string.format("%s/%s/claude-%s-%s%s", _CC_CN, ver, ver, platform, suffix),
        },
        sha256 = sha256,
    }
end

-- One platform's per-arch resource map (Shape B). `mirrored` opts the
-- version into the CN table; without it the entry stays upstream-only.
local function _entry(prefix, ver, sha_x86_64, sha_aarch64, mirrored)
    local res = mirrored and _mirrored or _up
    return {
        x86_64 = res(ver, prefix .. "-x64", sha_x86_64),
        aarch64 = res(ver, prefix .. "-arm64", sha_aarch64),
    }
end

local function _linux(ver, sha_x86_64, sha_aarch64, mirrored)
    return _entry("linux", ver, sha_x86_64, sha_aarch64, mirrored)
end

local function _macosx(ver, sha_x86_64, sha_aarch64, mirrored)
    return _entry("darwin", ver, sha_x86_64, sha_aarch64, mirrored)
end

local function _windows(ver, sha_x86_64, sha_aarch64, mirrored)
    return _entry("win32", ver, sha_x86_64, sha_aarch64, mirrored)
end

package = {
    spec = "2",

    name = "claude",
    description = "Claude Code CLI from Anthropic",
    homepage = "https://github.com/anthropics/claude-code",
    licenses = {"MIT"},
    repo = "https://github.com/anthropics/claude-code",
    docs = "https://docs.anthropic.com/en/docs/claude-code/overview",

    -- No `package.ci`: the version pointer lives at
    -- downloads.claude.ai/claude-code-releases/latest, not in a git tag,
    -- and version-check.py only knows how to read release tags. Bumps
    -- are done by hand, together with the CN mirror push.

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"ai", "cli", "tools"},
    keywords = {"claude", "anthropic", "agent", "cli"},

    programs = {"claude"},
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "2.1.222" },
            ["2.1.222"] = _linux("2.1.222",
                "10caae8f22b915c26bfff0e013a4d45608c4f1ae287583626569156f447730e5",
                "a04be0a8d7fe0259571ab7411d51d85658d71a4a26ce62b60c908290372e6016", true),
            -- 2.1.220 is upstream's `stable` channel head; kept as a pin
            -- for anyone who wants the slower-moving line.
            ["2.1.220"] = _linux("2.1.220",
                "674f61f20ff306f3100cf9200e4c36c4b70278b5bef2884549819b942a89c863",
                "159e4a51d796f3bf14677577100f7efb845611b1ceaf0c30cbd8d4650d942185"),
            ["2.1.218"] = _linux("2.1.218",
                "e12071751a9336b8af1012c103358ff04ac18f9aaff4a738cff7ba5cdfaf63f2",
                "295fd30481bd03b38450fdec2a6e25bb6472c2074f04b0c4a566cd5988f230bf"),
            ["2.1.198"] = _linux("2.1.198",
                "7066af42a5fe93038c13af5072d4c034dc3928092cb121fdd892c76b94b6b84d",
                "99b50a6f2b1f3ef07bcaf1e58a2f9883c470c84e428afa321972b1aa20372e9a"),
            ["2.1.156"] = _linux("2.1.156",
                "6d83cd2264450c5e54fc988be1032c288cf418ee604294acfb8fc4ac28f5f7a3",
                "7ed95d0a93aeb40e2b98e234b760d9295b7044ef678c62db8d1f5e14bfd57878"),
            ["2.1.153"] = _linux("2.1.153",
                "214f603f31942162dac9a65f18d43b3ac646ae215240fad481c4aad6c60f2e38",
                "6277fbbea72228a069e4719fc3e5fa36f16749247a2321c520dae93e83e92d9c"),
            ["2.1.142"] = _linux("2.1.142",
                "1249a1dadfe2d48f320bd4e1b657a1a0d82435da76deb11ce509822407cf24ec",
                "767b13fc28763ca9d663b00f90e501f134b356f1b72dcf0eea59b7e3bed86411"),
            ["2.1.90"] = _linux("2.1.90",
                "6074e3959989b2958a9abec60adf7b441a0f6f1c7e66401abff0fe54dad04fd6",
                "15d5089ee7d9981faacf5463eabd427a012814d9fc02113883bb23a4f387ad4a"),
            ["2.1.63"] = _linux("2.1.63",
                "734447e461bb92f0ffd5f683bb6216c35a3c16e8dd84be8d150b43605d39b0d1",
                "1fec8c8369606b4a6c00af963354b7d48aee793ed5db378fe4cf280149f3190a"),
        },
        macosx = {
            ["latest"] = { ref = "2.1.222" },
            ["2.1.222"] = _macosx("2.1.222",
                "36bfc6482a25730dbb1cee72589e522c66c45a4dc9ebfdd8a76a8113b01b6188",
                "c66a6cc6fa2e8145bb1a6e77831f2caf4b83690ff04650500dfa6e2c05ca997c", true),
            ["2.1.220"] = _macosx("2.1.220",
                "dca7be0aa7d3d924836d440e0c6d8e3d47ef3c8e61fa5809b54b9017170ce2f3",
                "8addc857f3fe64d5a0368af9ee50321b50afb4a6918ba3ef018ab84f5dbbe081"),
            ["2.1.218"] = _macosx("2.1.218",
                "9862b74a083e8a4ed572f99cbd4895185e0dd5a0a601affb0fb8e43d8d1f40e6",
                "71abaff59312c9a9b6a1d818365048b42e4e95cc521a823660eded3e0880d9b7"),
            ["2.1.198"] = _macosx("2.1.198",
                "280b6cfc60dacc4caed31af1249e53c259c01759556e60633944c02405c82dd0",
                "ab6f7ee109816ede414f7c285446633f805b623aa609f425609a64266451d61e"),
            ["2.1.156"] = _macosx("2.1.156",
                "ccd608c694677324e24dec7d1253b51f887a7be838cdb75b22d5362c97351107",
                "9c1e8601031f5cbb3101e49dda22bf8ba31183692c705e267a6923585fa2ba09"),
            ["2.1.153"] = _macosx("2.1.153",
                "4b90521c64b728caabe221737ce8a83d362ef0852eee7d789f014f7ff73ce97b",
                "449d9c89d7a63b1d427d912a7bd6e6f23f9a7b363866697c9fa9a0012546b254"),
            ["2.1.142"] = _macosx("2.1.142",
                "d00bc6fb38d0837ce811cc862a3b6822795b33dbce8361703b1e5e903bd240fd",
                "772021afa051160b97e04d379738df84d4cacd311e8c199a325fb013b3eaa448"),
            ["2.1.90"] = _macosx("2.1.90",
                "9934675063ea4360665b7a43f649c92e6ba5cf93257324af7af1a6b490746395",
                "73c1a7570501ca743cd2d7467cb4699103534a2138052a4e6cab53c0e09d79c8"),
            ["2.1.63"] = _macosx("2.1.63",
                "07842d6521f59bc68979d833ef33cbc1b985b9f5e09fa8975efe039989666aa9",
                "2e8667322e0bd104087df2a8857f176acc75d7091aa02828825dfeb4a5708531"),
        },
        windows = {
            ["latest"] = { ref = "2.1.222" },
            ["2.1.222"] = _windows("2.1.222",
                "032cb799d2abfaa6ca440f6458304b9a2a250521063d21ebcea7f3c77c443db7",
                "f760aa2782019e55b1e44fda9eddec85ca8499429da87efddd47ab18d4a716a2", true),
            ["2.1.220"] = _windows("2.1.220",
                "af5bf1f1b2aadffc768eccd787084c6fdf9ba81624cbe96c1c6d9ac1a1550231",
                "07343ace8a2e9ba87eed716e9c0261ce4bda8954c316695e4cb26fd0605de13c"),
            ["2.1.218"] = _windows("2.1.218",
                "81fcf59bb7abb558aedc6f2361f4723b3d757d28e799962d88b18b4520df66ca",
                "a7959fd87feb9557d56f4e5752f7ed1ddf405f3bea91b2571bf93af636efd193"),
            ["2.1.198"] = _windows("2.1.198",
                "6afd07cb03aa981c5e918808f53a1e2b729015b695122a944f6e41aaf5393933",
                "10a6d21332f674c87f52b1dc09926945d0169f1bb82aced84ada100639ab70bc"),
            ["2.1.156"] = _windows("2.1.156",
                "188cc105e1caaed88f63ac2060283eb426ea17a69130810c10126b2c14f7dc7e",
                "1e10b4fa9e8a4829cfdf77a9c55cfe0dd26c54f2afb4d3dd9d19ff9e99ca1887"),
            ["2.1.153"] = _windows("2.1.153",
                "8bda00dba0e8b44e67966a07ee32cf23032f7ebb90e77d4f82ab2e39b1118623",
                "240240e32f10bc7d4124c1c5603313e243cabaae80e174e2c6eb27f5b1e1ebe9"),
            ["2.1.142"] = _windows("2.1.142",
                "0778b1c607ee3282ba8ea3f0c684edb05f597454cc0d21386a84576b5434b1c7",
                "95a966b0729f9f7c28c68df3d63e7f5ac6ac72abab209392800e9a40292f3bfc"),
            ["2.1.90"] = _windows("2.1.90",
                "f6be38fbdcadc373e93f751d1286845f58b032690e32be8f64799380a295a79f",
                "019f7210055cd7a884d13c4e6a0b6caf1a82348ee42950b7b5247a4b0484709c"),
            ["2.1.63"] = _windows("2.1.63",
                "d7e63e94966b716fa1c073c56d7ce67554505eadea9ccb254eb513027403a026",
                "ad5759b5be7afc4d15fa20949310e64ac8827fa569043e4f2add2f7236ff8880"),
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")

local function _installed_exe()
    return path.join(pkginfo.install_dir(),
                     os.host() == "windows" and "claude.exe" or "claude")
end

-- The download IS the executable, not an archive: xlings' auto-extract
-- only fires on recognised compressed extensions, so install_file() is
-- the binary itself and install() just has to move it into place under a
-- stable name (upstream serves it as `claude`, the CN mirror as
-- `claude-<version>-<platform>` — hence the rename rather than a copy).
function install()
    local exe = _installed_exe()
    if os.isfile(exe) then
        return true
    end

    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())
    os.mv(pkginfo.install_file(), exe)

    if os.host() ~= "windows" then
        -- Served over plain HTTP, so the executable bit never survives
        -- the download regardless of what upstream stored.
        system.exec(string.format([[chmod +x "%s"]], exe))
    end

    return os.isfile(exe)
end

function config()
    xvm.add("claude", {
        bindir = pkginfo.install_dir(),
        envs = {
            -- xvm owns which version is on PATH. The native binary's own
            -- updater would install a second copy under
            -- ~/.local/share/claude and put a `claude` on PATH that xim
            -- neither tracks nor can remove, so version management stays
            -- with `xvm use claude@<ver>`.
            DISABLE_AUTOUPDATER = "1",
            -- should be set by user, not hardcoded here
            --CLAUDE_CONFIG_DIR = path.join(pkginfo.install_dir(), "config"),
        }
    })
    return true
end

function uninstall()
    xvm.remove("claude")
    return true
end
