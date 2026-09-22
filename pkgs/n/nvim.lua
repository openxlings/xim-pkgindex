package = {
    spec = "2",
    -- base info
    name = "nvim",
    description = "Vim-fork focused on extensibility and usability",

    contributors = "https://github.com/neovim/neovim/graphs/contributors",
    licenses = {"Apache-2.0"},
    repo = "https://github.com/neovim/neovim",
    ci = { mirror = true, update = true },
    docs = "https://neovim.io/doc",

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "aarch64"}, -- aarch64: macOS only (see xpm)
    status = "stable", -- dev, stable, deprecated
    categories = {"vim", "editor"},
    keywords = {"vim", "editor"},

    programs = { "nvim", "neovim" },

    -- xvm: xlings version management
    xvm_enable = true,

    -- Every version is mirrored at xlings-res/nvim on GitHub and GitCode, byte-identical to the
    -- upstream `neovim/neovim` release artifacts and under the same file names. `source` maps
    -- give the upstream (GLOBAL) and the GitCode mirror (CN) for each platform, so a version entry
    -- carries only its checksums.
    --
    -- Checksums are per arch, so an arch a platform does not ship fails closed instead of
    -- installing another arch's build: linux and windows ship x86_64, macOS ships both
    -- (upstream names them `nvim-macos-x86_64` and `nvim-macos-arm64`, hence `arch_alias`).
    --
    -- The install hook relies on the tarball's own top directory (`nvim-linux-x86_64/`,
    -- `nvim-win64/`, `nvim-macos-<arch>/`), which is the same on the mirror.
    xpm = {
        linux = {
            -- Runtime deps. nvim prebuilt (nvim-linux-x86_64.tar.gz)
            -- is dynamically linked: INTERP=/lib64/ld-linux-x86-64.so.2,
            -- NEEDED libc.so.6 / libm.so.6 (glibc) and libgcc_s.so.1
            -- (GCC unwind runtime, ships in xim:gcc-runtime). No
            -- libstdc++ — neovim itself is C, not C++.
            deps = {
                runtime = { "xim:glibc@>=2.39", "xim:gcc-runtime@15.1.0" },
            },
            source = {
                GLOBAL = "https://github.com/neovim/neovim/releases/download/v${version}/nvim-linux-x86_64.tar.gz",
                CN = "https://gitcode.com/xlings-res/nvim/releases/download/${version}/nvim-linux-x86_64.tar.gz",
            },
            ["latest"] = { ref = "0.12.5" },
            ["0.12.5"] = {
                sha256 = { x86_64 = "bce0f56eda1f1b1db6eee8f4133d7a38813ea07933837dd1777411ca384c6875" },
            },
            ["0.12.4"] = {
                sha256 = { x86_64 = "012bf3fcac5ade43914df3f174668bf64d05e049a4f032a388c027b1ebd78628" },
            },
            ["0.12.2"] = "XLINGS_RES",
            ["0.11.5"] = {
                sha256 = { x86_64 = "b2f91117be5b5ea39edd7297156dc2a4a8df4add6c95a90809a8df19e7ab6f52" },
            },
            -- The last 0.10: plugins that support it are tested against it (e.g. mcppls's
            -- editors/nvim).
            ["0.10.4"] = {
                sha256 = { x86_64 = "95aaa8e89473f5421114f2787c13ae0ec6e11ebbd1a13a1bd6fcf63420f8073f" },
            },
        },
        macosx = {
            source = {
                GLOBAL = "https://github.com/neovim/neovim/releases/download/v${version}/nvim-macos-${arch_alias}.tar.gz",
                CN = "https://gitcode.com/xlings-res/nvim/releases/download/${version}/nvim-macos-${arch_alias}.tar.gz",
            },
            ["latest"] = { ref = "0.12.5" },
            ["0.12.5"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "81f4518622cb059b450ee2e498c6a1082a222f6bd89589de5bbcf0c6a68aa3fd",
                    aarch64 = "65fb000099e47ca1b762584c484cc833f40e30851a0ec450d4174e16317c1f9b",
                },
            },
            ["0.12.4"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "03fe16f8dd9f1e9eaf52d5e294913a39917b9e2faea30d7fb0fb385fbd36fe59",
                    aarch64 = "51ab83afa66d663627c2ab1be43209b0f4e81360d4598b53efaa4d8195f24c89",
                },
            },
            ["0.11.5"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "6612760a7037ca2518e456908baf5e43101fa79819d18979fc4d4e8441d9dfa5",
                    aarch64 = "79143d3b408f7034f90b7cf59af2276de09ef8a4c2f1a28e4c99581b249d3107",
                },
            },
            ["0.10.4"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "c1405071127b59dbdefc31d9c52e9a5c36db67dcef6dcf83e898aada1f3f778e",
                    aarch64 = "3d7b07ec9b491d2a3d55167bc1db1cfa96773a1a37e74ea384cb15ab0189223b",
                },
            },
        },
        windows = {
            source = {
                GLOBAL = "https://github.com/neovim/neovim/releases/download/v${version}/nvim-win64.zip",
                CN = "https://gitcode.com/xlings-res/nvim/releases/download/${version}/nvim-win64.zip",
            },
            ["latest"] = { ref = "0.12.5" },
            ["0.12.5"] = {
                sha256 = { x86_64 = "de8625ba8cf65ebf40eb80a388ba1ec8e9c15b30218821e2c639119b05920de1" },
            },
            ["0.12.4"] = {
                sha256 = { x86_64 = "9fc3572829ffd13debb6e32555da2c8cc02555568260a9fc4cf1f65bbcca319c" },
            },
            ["0.12.2"] = "XLINGS_RES",
            ["0.11.5"] = {
                sha256 = { x86_64 = "718e731326e7759cf17bbbb33f38975707a2ac85642614686b818ef5fde38f48" },
            },
            ["0.10.4"] = {
                sha256 = { x86_64 = "dceeb8301f64e244e3e2dffaedbb153bd01c0c6ecb5024a90e3172dc8e65555c" },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()

    -- The archive's own top directory: nvim-linux-x86_64, nvim-win64, nvim-macos-<arch>.
    local nvim_dir = "nvim-linux-x86_64"
    if os.host() == "windows" then
        nvim_dir = "nvim-win64"
    elseif os.host() == "macosx" then
        nvim_dir = os.isdir("nvim-macos-arm64") and "nvim-macos-arm64" or "nvim-macos-x86_64"
    end

    os.tryrm(pkginfo.install_dir())
    os.mv(nvim_dir, pkginfo.install_dir())
    return true
end

function config()
    xvm.add("nvim", { bindir = path.join(pkginfo.install_dir(), "bin") })
    xvm.add("neovim", { alias = "nvim" })
    return true
end

function uninstall()
    xvm.remove("nvim")
    xvm.remove("neovim")
    return true
end
