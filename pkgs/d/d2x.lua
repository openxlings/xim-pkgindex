package = {

    -- Platform version sets differ ON PURPOSE:
    -- the earliest releases were not built for every platform.
    -- Declared so `tests/check_platform_version_parity.lua` can tell this
    -- apart from a bump that landed in one section and was forgotten in the
    -- others -- which reads as `<pkg>@<ver> not found` on the platforms that
    -- lack it, against a file that contains the version string.
    platform_versions_diverge = true,
    spec = "1",

    -- base info
    name = "d2x",
    description = "xlings's d2x tool",

    authors = {"Sunrisepeak"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/d2learn/d2x",

    -- xim pkg info
    type = "package",

    archs = {"x86_64", "arm64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"d2x", "tool", "mcpp" },
    keywords = {"d2x", "tool", "mcpp" },

    programs = { "d2x" },

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        windows = {
            ["latest"] = { ref = "2026.10.21.1" },
            ["2026.10.21.1"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "cfeffa842d86ba24b355f65ba993300123af9f8ee42987f4825c0d7f7435c40d" },
            },
            ["2026.10.20.2"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "02f8d86c48173b2839a1791aa7e979f20de9507dfe9bdc94b283967f40f6e37e" },
            },
            ["2026.10.20.1"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "399f689065d5be0f2c1a27ef451b996ae77dc67f70e050c051bb20a2067e8c96" },
            },
            ["2026.08.02.2"] = "XLINGS_RES",
            ["2026.08.02.1"] = "XLINGS_RES",
            ["2026.07.24.1"] = "XLINGS_RES",
            ["0.1.5"] = "XLINGS_RES",
            ["0.1.4"] = "XLINGS_RES",
            ["0.1.3"] = "XLINGS_RES",
            ["0.1.2"] = "XLINGS_RES",
            ["0.1.1"] = "XLINGS_RES",
        },
        linux = {
            deps = { "xim:glibc@>=2.39", "xim:openssl@3.1.5" },
            ["latest"] = { ref = "2026.10.21.1" },
            ["2026.10.21.1"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "fdb8833fbd3a3414e32e656d2e03528799014ba5b6b10c5f2c6d18dcef9e7350" },
            },
            ["2026.10.20.2"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "1b2fe661ec6f9260d63c3766642cdab5ef5eac15fd434e9d852e66f122f34aca" },
            },
            ["2026.10.20.1"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "e94c66002653a4bb390c1e0f88dcfa4f83631de695e49e91f818a76c772dc2e9" },
            },
            ["2026.08.02.2"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "37f16ef8ee7b6720a440c8da8b4a002211129f761db127643477c639b14a8d96" },
            },
            ["2026.08.02.1"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "c3ff3eeb02daffa6dfd45073ae6d476ed7ce1b8857013061bb4e34fed41d1147" },
            },
            ["2026.07.24.1"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "594edfd58e2a733180d5234f2987e3029dc25713dee5ee8a76636809d06dfc2f" },
            },
            ["0.1.5"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "d98d77a179e0cf7671a8e61321d03055d896855d9fef7ba77d1d82317cc2b37a" },
            },
            ["0.1.4"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "d0810ae26ca2fb40f241d2328e34340b08cc797715a9c7240046bec65ddd8812" },
            },
            ["0.1.3"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "844d71c201bd21837132a2c1cd78bbeef204abfdbbf81f5f902748b3ede9149d" },
            },
            ["0.1.2"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "6585256007647ecb4feebe38a061555bbdd786c1dbb60ed3cb16c92486e1ff4c" },
            },
            ["0.1.1"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "55dc4ced7969a79e8563fd72d62d9500289e8e97f39f6515838ed186e1f84aaf" },
            },
            ["0.1.0"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "c38d7c877625d2009a9ca4800cba5d1d4a8a5ae61cbbf1878ef515da5fa61b47" },
            },
        },
        macosx = {
            ["latest"] = { ref = "2026.10.21.1" },
            ["2026.10.21.1"] = {
                url = "XLINGS_RES",
                sha256 = { arm64 = "c6757946ddafc180bc1aa065e045373ef549e63cba1ed0b9ff6c75e5a669bb83" },
            },
            ["2026.10.20.2"] = {
                url = "XLINGS_RES",
                sha256 = { arm64 = "4a42da3f4db994e326039f6f2b94d748ff6a9d6f69ccadf397a6e00aef7c357c" },
            },
            ["2026.10.20.1"] = {
                url = "XLINGS_RES",
                sha256 = { arm64 = "fdd5828093dc4cede97798856c21aac667f7eac149405f5c542de7d745828564" },
            },
            ["2026.08.02.2"] = "XLINGS_RES",
            ["2026.08.02.1"] = "XLINGS_RES",
            ["2026.07.24.1"] = "XLINGS_RES",
            ["0.1.5"] = "XLINGS_RES",
            ["0.1.4"] = "XLINGS_RES",
            ["0.1.3"] = "XLINGS_RES",
        }
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
-- elfpatch import removed: predicate-driven auto-patch (post 2026-05-02
-- design) reads glibc.lua's exports.runtime.loader and rewrites our
-- INTERP / RPATH automatically. No install-hook elfpatch call needed.

function install()
    local d2xdir = pkginfo.install_file()
        :replace(".zip", "")
        :replace(".tar.gz", "")
    os.tryrm(pkginfo.install_dir())
    os.mv(d2xdir, pkginfo.install_dir())

    return true
end

function config()
    xvm.add("d2x")
    return true
end

function uninstall()
    xvm.remove("d2x")
    return true
end