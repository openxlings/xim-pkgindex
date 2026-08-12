-- SHA256 for every asset this recipe can hand out, transcribed from the
-- upstream https://nodejs.org/dist/v<ver>/SHASUMS256.txt.
--
-- These are what make the CN mirror below safe to use. GLOBAL and CN are only
-- interchangeable if they carry identical bytes, and a checksum is the only
-- thing that proves it at install time: a CN copy that ever diverges from
-- nodejs.org fails the install loudly instead of installing a different node.
-- Every version listed in `xpm` must appear here (windows-only keys are absent
-- for versions no windows section lists; 18.20.8 has no win-arm64 build at all).
local _sha256 = {
    ["26.7.0"] = {
        linux_x64     = "982aa24dd8be4c889c6a8ab337ddff3b0896645b20f4239356e80552c16277ee",
        linux_arm64   = "afc7a004018485092ac8985b817b0d5684472bd9472e0b57d2ab88737e50090d",
        darwin_x64    = "f279d1ed28ce57f7788bf23435d2ad7fdd7438904ad5c4d8a1081a7cde3d4b96",
        darwin_arm64  = "7ee659a7768e641bbfd5360940660b8e8fd0052f77488f365562bac522fc15d4",
        win_x64       = "d3bd72755141ed32bbcd841228ee81897c8a98d50dfa7dae2179399a0a7c90f8",
        win_arm64     = "be8775204cfceca5a73c30f91bf0de5e85274c01b776dc13f16b91aa251ebb01",
    },
    ["25.9.0"] = {
        linux_x64     = "1d8db7d6e291d167e8c467ae4094be175e1a0b3969c7ae1f8955b9f7824f7b2e",
        linux_arm64   = "bf007bf0dcc2fddd90888fde374a1ad33c1ab2ca2ad324c645dd7aed0f9f1460",
        darwin_x64    = "7d737b53ce191142bfa1c17cfa5b070d96e84eebf76b8dd06d84981cbdc3f7e3",
        darwin_arm64  = "e479f3c469d3d9303a44f00a8ea37a3788395d171bb8059c48a4bbbd2e371b59",
        win_x64       = "929552b8305effac843ba7b4270c437aefb702fc3fbd73fcd1bffd35d4ac284e",
        win_arm64     = "6b499bcaf16c86fe1a98c8e2874fd1980b23b5c90ea412983db4392d7e08c36b",
    },
    ["24.19.0"] = {
        linux_x64     = "14b342e71204f811bde6153be8e04b62aef63c236fef92b55f9c83154b409647",
        linux_arm64   = "01443c1e1a29e531ccad5a46fefa6df490d2189c49f7955904aecdbb0fe86fdc",
        darwin_x64    = "d1b5e999db158c62fe8f7267a4476b035d8bd93b1a605bac24a3f0dd166e3316",
        darwin_arm64  = "8294b7aa9b03997481c06babf1e8b270c859358f27da57a11509afe537ac381d",
        win_x64       = "57f71ab3652e797d84acddc79c81cc9ff1c6ddb2a1974cdb83f00fee9bff4c73",
        win_arm64     = "8502f4a50b458d4cc38ed8f2001556c2cd239d464920f74017926ccb1e1c157f",
    },
    ["24.15.0"] = {
        linux_x64     = "472655581fb851559730c48763e0c9d3bc25975c59d518003fc0849d3e4ba0f6",
        linux_arm64   = "f3d5a797b5d210ce8e2cb265544c8e482eaedcb8aa409a8b46da7e8595d0dda0",
        darwin_x64    = "ffd5ee293467927f3ee731a553eb88fd1f48cf74eebc2d74a6babe4af228673b",
        darwin_arm64  = "372331b969779ab5d15b949884fc6eaf88d5afe87bde8ba881d6400b9100ffc4",
        win_x64       = "cc5149eabd53779ce1e7bdc5401643622d0c7e6800ade18928a767e940bb0e62",
        win_arm64     = "c9eb7402eda26e2ba7e44b6727fc85a8de56c5095b1f71ebd3062892211aa116",
    },
    ["24.4.1"] = {
        linux_x64     = "7e067b13cd0dc7ee8b239f4ebe1ae54f3bba3a6e904553fcb5f581530eb8306d",
        linux_arm64   = "555659c36fc72d0617e278b5d26ffcaebc3760a3de354926b1e5f1b0bfd66083",
        darwin_x64    = "59fbad953a0705e78d220079fb6d10d341d0a61afd3aeb4db2a87207fddd8944",
        darwin_arm64  = "55a772a600b7bdafb4b35945b3935090e27aff9934b4c11b281220fcd99139d7",
        win_x64       = "0428a6ca7544df310de4ed12c10e84c0bc7c9022945dc16de22f7c0dc4893dd2",
        win_arm64     = "8cb993d89d13119f582c77a4c734be5bdfeee5557e6cfe850ea1a2f23fa94686",
    },
    ["23.11.0"] = {
        linux_x64     = "fa9ae28d8796a6cfb7057397e1eea30ca1c61002b42b8897f354563a254e7cf5",
        linux_arm64   = "85915f885fe7eab2be4a6e3de840cb83db4fc53749274d31383a0e1721a883c6",
        darwin_x64    = "a5782655748d4602c1ee1ee62732e0a16d29d3e4faac844db395b0fbb1c9dab8",
        darwin_arm64  = "635990b46610238e3c008cd01480c296e0c2bfe7ec59ea9a8cd789d5ac621bb0",
    },
    ["23.6.0"] = {
        linux_x64     = "90e3c96e2464978e8309db2e8bb7c5c1b606f85afa80314195f01c30eccf4ffc",
        linux_arm64   = "7554f6ed6171d0e25938978a67868cadb6eed6f0393ed72b6aaf8f1195028ec2",
        darwin_x64    = "009f4b4955ddbebaad86e306ad4c65b568f06fd76d855e7fd617eb2748cd5f2d",
        darwin_arm64  = "93e84485e41e7f35246e11329ea920ee5a8e7e12e90bfcea2f8205953c869bc2",
        win_x64       = "9daeb5894273b820fb3bf2485aa433ff9653feb2c1a3daebd1a06b0e4fbe4309",
        win_arm64     = "e553f0841582570875b667aaa0bd9b94c37e558c909cab9505a85db23f3a7c65",
    },
    ["22.17.1"] = {
        linux_x64     = "ff04bc7c3ed7699ceb708dbaaf3580d899ff8bf67f17114f979e83aa74fc5a49",
        linux_arm64   = "a5bb879af2fe70e7b5dc5e0bbadecba88e87f45bd8e62c0c57b5c815a4cbbaa6",
        darwin_x64    = "b925103150fac0d23a44a45b2d88a01b73e5fff101e5dcfbae98d32c08d4bee3",
        darwin_arm64  = "a983f4f2a7b71512b78d7935b9ccf6b72120a255810070afd635c4146bca7b31",
        win_x64       = "b1fdb5635ba860f6bf71474f2ca882459a582de49b1d869451e3ad188e3943eb",
        win_arm64     = "588d42c7c90eecf14ed4fc126a64cc70993e3a002f93e26be9c979cdc516b0d3",
    },
    ["22.14.0"] = {
        linux_x64     = "69b09dba5c8dcb05c4e4273a4340db1005abeafe3927efda2bc5b249e80437ec",
        linux_arm64   = "08bfbf538bad0e8cbb0269f0173cca28d705874a67a22f60b57d99dc99e30050",
        darwin_x64    = "6698587713ab565a94a360e091df9f6d91c8fadda6d00f0cf6526e9b40bed250",
        darwin_arm64  = "e9404633bc02a5162c5c573b1e2490f5fb44648345d64a958b17e325729a5e42",
    },
    ["22.12.0"] = {
        linux_x64     = "22982235e1b71fa8850f82edd09cdae7e3f32df1764a9ec298c72d25ef2c164f",
        linux_arm64   = "8cfd5a8b9afae5a2e0bd86b0148ca31d2589c0ea669c2d0b11c132e35d90ed68",
        darwin_x64    = "52bc25dd026db7247c3c00439afdb83e95087248267f02d6c1a7250d1f896173",
        darwin_arm64  = "293dcc6c2408da21562d135b0412525e381bb6fe150d688edb58fe850d0f3e13",
        win_x64       = "2b8f2256382f97ad51e29ff71f702961af466c4616393f767455501e6aece9b8",
        win_arm64     = "17401720af48976e3f67c41e8968a135fb49ca1f88103a92e0e8c70605763854",
    },
    ["20.19.0"] = {
        linux_x64     = "b4e336584d62abefad31baecff7af167268be9bb7dd11f1297112e6eed3ca0d5",
        linux_arm64   = "dbe339e55eb393955a213e6b872066880bb9feceaa494f4d44c7aac205ec2ab9",
        darwin_x64    = "a8554af97d6491fdbdabe63d3a1cfb9571228d25a3ad9aed2df856facb131b20",
        darwin_arm64  = "c016cd1975a264a29dc1b07c6fbe60d5df0a0c2beb4113c0450e3d998d1a0d9c",
    },
    ["18.20.8"] = {
        linux_x64     = "5467ee62d6af1411d46b6a10e3fb5cacc92734dbcef465fea14e7b90993001c9",
        linux_arm64   = "224e569dbe7b0ea4628ce383d9d482494b57ee040566583f1c54072c86d1116b",
        darwin_x64    = "ed2554677188f4afc0d050ecd8bd56effb2572d6518f8da6d40321ede6698509",
        darwin_arm64  = "bae4965d29d29bd32f96364eefbe3bca576a03e917ddbb70b9330d75f2cacd76",
    },
}

-- One asset = one {GLOBAL, CN} mirror pair plus its checksum.
--
--   GLOBAL  https://nodejs.org/dist/v<ver>/<file>              (authoritative)
--   CN      https://cdn.npmmirror.com/binaries/node/v<ver>/<file>
--
-- npmmirror is Alibaba's full rsync copy of the whole `nodejs.org/dist` tree --
-- the host `nvm`/`fnm`/`nrm` already point NODEJS_ORG_MIRROR at in mainland
-- China. Mirroring node into xlings-res the way most packages here do would
-- mean re-hosting 2.45 GB of tarballs (64 assets across 12 versions) and then
-- re-uploading on every bump, for a tree upstream already publishes a CN copy
-- of. So CN points at npmmirror directly and every version -- not just the
-- newest -- gets a CN path for free.
local function _asset(ver, os_token, arch_token, ext)
    local file = string.format("node-v%s-%s-%s.%s", ver, os_token, arch_token, ext)
    return {
        url = {
            GLOBAL = "https://nodejs.org/dist/v" .. ver .. "/" .. file,
            CN     = "https://cdn.npmmirror.com/binaries/node/v" .. ver .. "/" .. file,
        },
        sha256 = (_sha256[ver] or {})[os_token .. "_" .. arch_token],
    }
end

-- V2 Scheme B per-arch builders: each returns a { x86_64 = {...}, aarch64 = {...} }
-- map so x86_64 AND aarch64 both resolve to the correct asset.
-- (V1 previously shipped only x64 on linux/windows and only darwin-arm64 on
-- macOS, contradicting its own archs declaration.)
local function _win_url(ver)
    return {
        x86_64  = _asset(ver, "win", "x64",   "zip"),
        aarch64 = _asset(ver, "win", "arm64", "zip"),
    }
end
local function _linux_url(ver)
    return {
        x86_64  = _asset(ver, "linux", "x64",   "tar.xz"),
        aarch64 = _asset(ver, "linux", "arm64", "tar.xz"),
    }
end
local function _mac_url(ver)
    return {
        x86_64  = _asset(ver, "darwin", "x64",   "tar.gz"),
        aarch64 = _asset(ver, "darwin", "arm64", "tar.gz"),
    }
end

-- node's release dir/file token per platform+arch (used by install()).
-- `os.arch` is not bound in the C++ xim hook runtime (xlings >= 0.4.6x,
-- only os.host is) and _RUNTIME.arch is empty for install hooks, so this
-- may return nil — install() then probes both arch tokens with os.isdir.
local function _node_arch()
    local arch = (os.arch and os.arch()) or (_RUNTIME and _RUNTIME.arch) or ""
    return ({ x86_64 = "x64", x64 = "x64", aarch64 = "arm64", arm64 = "arm64" })[arch]
end

-- xpkg info

package = {

    -- Platform version sets differ ON PURPOSE:
    -- each platform lists the builds published for it; the `latest` agree.
    -- Declared so `tests/check_platform_version_parity.lua` can tell this
    -- apart from a bump that landed in one section and was forgotten in the
    -- others -- which reads as `<pkg>@<ver> not found` on the platforms that
    -- lack it, against a file that contains the version string.
    platform_versions_diverge = true,
    spec = "2",
    homepage = "https://nodejs.org",
    name = "node",
    description = "Node.js is a JavaScript runtime built on Chrome's V8 JavaScript engine",
    authors = {"Node.js Foundation"},
    licenses = {"MIT"},
    type = "package",
    repo = "https://github.com/nodejs/node",
    docs = "https://nodejs.org/docs",

    -- xim pkg info
    archs = {"x86_64", "aarch64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"node", "javascript"},

    xpm = {
        -- `latest` tracks the ACTIVE LTS line (24.x "Krypton"), not the newest
        -- release: an unpinned `xlings install node` should get the line node
        -- itself recommends for production. 26.x is Current until it enters LTS
        -- in Oct 2026; it is listed so `node@26.7.0` resolves, but it is not the
        -- default. Same rule the 24.15.0 bump followed.
        windows = {
            ["latest"] = { ref = "24.19.0" },
            ["26.7.0"] = _win_url("26.7.0"),
            ["25.9.0"] = _win_url("25.9.0"),
            ["24.19.0"] = _win_url("24.19.0"),
            ["24.15.0"] = _win_url("24.15.0"),
            ["24.4.1"] = _win_url("24.4.1"),
            ["23.6.0"] = _win_url("23.6.0"),
            ["22.17.1"] = _win_url("22.17.1"),
            -- was a bare x86_64 url+sha256; the builder keeps that same asset
            -- and hash and adds the win-arm64 half this version does publish.
            ["22.12.0"] = _win_url("22.12.0"),
        },
        linux = {
            -- Runtime deps. The upstream node prebuilt is dynamically linked
            -- (INTERP=/lib64/ld-linux-x86-64.so.2, RPATH empty) and pulls
            -- libc/libdl/libpthread/libm from glibc plus libstdc++.so.6 +
            -- libgcc_s.so.1 from xim:gcc-runtime (the runtime libs split
            -- out of xim:gcc). Without these declared, xlings's
            -- predicate-driven elfpatch can't rewrite INTERP/RPATH to
            -- the xpkg-provided libc + libstdc++, and the binary only
            -- runs on hosts that already have system glibc + a compatible
            -- libstdc++ (i.e. fails on distroless / Alpine / very old glibc).
            -- No build deps — install hook is just `os.mv` of the extracted
            -- prebuilt; nothing is compiled at install time.
            deps = {
                runtime = { "xim:glibc@>=2.39", "xim:gcc-runtime@15.1.0" },
            },
            ["latest"] = { ref = "24.19.0" },
            ["26.7.0"] = _linux_url("26.7.0"),
            ["25.9.0"] = _linux_url("25.9.0"),
            ["24.19.0"] = _linux_url("24.19.0"),
            ["24.15.0"] = _linux_url("24.15.0"),
            ["24.4.1"] = _linux_url("24.4.1"),
            ["23.11.0"] = _linux_url("23.11.0"),
            ["23.6.0"] = _linux_url("23.6.0"),
            ["22.17.1"] = _linux_url("22.17.1"),
            ["22.14.0"] = _linux_url("22.14.0"),
            -- see the windows note: same x86_64 asset + hash, plus linux-arm64.
            ["22.12.0"] = _linux_url("22.12.0"),
            ["20.19.0"] = _linux_url("20.19.0"),
            ["18.20.8"] = _linux_url("18.20.8"),
        },
        macosx = {
            ["latest"] = { ref = "24.19.0" },
            ["26.7.0"] = _mac_url("26.7.0"),
            ["25.9.0"] = _mac_url("25.9.0"),
            ["24.19.0"] = _mac_url("24.19.0"),
            ["24.15.0"] = _mac_url("24.15.0"),
            ["24.4.1"] = _mac_url("24.4.1"),
            ["23.11.0"] = _mac_url("23.11.0"),
            ["23.6.0"] = _mac_url("23.6.0"),
            ["22.17.1"] = _mac_url("22.17.1"),
            ["22.14.0"] = _mac_url("22.14.0"),
            ["22.12.0"] = _mac_url("22.12.0"),
            ["20.19.0"] = _mac_url("20.19.0"),
            ["18.20.8"] = _mac_url("18.20.8"),
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- Arch-aware extracted-dir templates (node uses x64/arm64 tokens).
local node_dir_template = {
    linux = "node-v%s-linux-%s",
    windows = "node-v%s-win-%s",
    macosx = "node-v%s-darwin-%s",
}

function install()
    os.tryrm(pkginfo.install_dir())
    log.debug("Installing Node.js to %s ...", pkginfo.install_dir())
    -- Probe candidate dirs with os.isdir (a native binding) rather than
    -- os.dirs: the glob shells out to `ls`, which is not on the hook PATH
    -- in the C++ xim runtime. The downloaded asset already matches the
    -- host arch, so at most one candidate exists; trying the detected
    -- arch first keeps the stale-leftover case deterministic.
    local tokens = { "x64", "arm64" }
    local arch = _node_arch()
    if arch then table.insert(tokens, 1, arch) end
    for _, tok in ipairs(tokens) do
        local extracted = string.format(node_dir_template[os.host()], pkginfo.version(), tok)
        if os.isdir(extracted) then
            os.mv(extracted, pkginfo.install_dir())
            return true
        end
    end
    log.error("extracted node dir not found (version %s)", pkginfo.version())
    return false
end

function config()
    log.debug("Configuring Node.js ...")
    local bindir = pkginfo.install_dir()
    if os.host() ~= "windows" then
        bindir = path.join(pkginfo.install_dir(), "bin")
    end

    local node_binding = "node@" .. pkginfo.version()

    xvm.add("node", { bindir = bindir })

    local npm_cfg = { bindir = bindir, version = "node-" .. pkginfo.version(), binding = node_binding }
    local npx_cfg = { bindir = bindir, version = "node-" .. pkginfo.version(), binding = node_binding }
    if os.host() == "windows" then
        npm_cfg.alias = "npm.cmd"
        npx_cfg.alias = "npx.cmd"
    end
    xvm.add("npm", npm_cfg)
    xvm.add("npx", npx_cfg)

    return true
end

function uninstall()
    log.debug("Uninstalling Node.js from %s ...", pkginfo.install_dir())
    xvm.remove("node")
    xvm.remove("nodejs")
    xvm.remove("npm", "node-" .. pkginfo.version())
    xvm.remove("npx", "node-" .. pkginfo.version())
    return true
end