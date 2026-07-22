-- V2 Scheme B per-arch builders: each returns a { x86_64 = {...}, aarch64 = {...} }
-- map so x86_64 AND aarch64 both resolve to the correct nodejs.org asset.
-- (V1 previously shipped only x64 on linux/windows and only darwin-arm64 on
-- macOS, contradicting its own archs declaration.)
local function _win_url(ver)
    return {
        x86_64  = { url = string.format("https://nodejs.org/dist/v%s/node-v%s-win-x64.zip",   ver, ver) },
        aarch64 = { url = string.format("https://nodejs.org/dist/v%s/node-v%s-win-arm64.zip", ver, ver) },
    }
end
local function _linux_url(ver)
    return {
        x86_64  = { url = string.format("https://nodejs.org/dist/v%s/node-v%s-linux-x64.tar.xz",   ver, ver) },
        aarch64 = { url = string.format("https://nodejs.org/dist/v%s/node-v%s-linux-arm64.tar.xz", ver, ver) },
    }
end
local function _mac_url(ver)
    return {
        x86_64  = { url = string.format("https://nodejs.org/dist/v%s/node-v%s-darwin-x64.tar.gz",   ver, ver) },
        aarch64 = { url = string.format("https://nodejs.org/dist/v%s/node-v%s-darwin-arm64.tar.gz", ver, ver) },
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
        windows = {
            ["latest"] = { ref = "24.15.0" },
            ["25.9.0"] = _win_url("25.9.0"),
            ["24.15.0"] = _win_url("24.15.0"),
            ["24.4.1"] = _win_url("24.4.1"),
            ["23.6.0"] = _win_url("23.6.0"),
            ["22.17.1"] = _win_url("22.17.1"),
            ["22.12.0"] = {
                url = "https://nodejs.org/dist/v22.12.0/node-v22.12.0-win-x64.zip",
                sha256 = "2b8f2256382f97ad51e29ff71f702961af466c4616393f767455501e6aece9b8",
            },
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
                runtime = { "xim:glibc@2.39", "xim:gcc-runtime@15.1.0" },
            },
            ["latest"] = { ref = "24.15.0" },
            ["25.9.0"] = _linux_url("25.9.0"),
            ["24.15.0"] = _linux_url("24.15.0"),
            ["24.4.1"] = _linux_url("24.4.1"),
            ["23.11.0"] = _linux_url("23.11.0"),
            ["23.6.0"] = _linux_url("23.6.0"),
            ["22.17.1"] = _linux_url("22.17.1"),
            ["22.14.0"] = _linux_url("22.14.0"),
            ["22.12.0"] = {
                url = "https://nodejs.org/dist/v22.12.0/node-v22.12.0-linux-x64.tar.xz",
                sha256 = "22982235e1b71fa8850f82edd09cdae7e3f32df1764a9ec298c72d25ef2c164f",
            },
            ["20.19.0"] = _linux_url("20.19.0"),
            ["18.20.8"] = _linux_url("18.20.8"),
        },
        macosx = {
            ["latest"] = { ref = "24.15.0" },
            ["25.9.0"] = _mac_url("25.9.0"),
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