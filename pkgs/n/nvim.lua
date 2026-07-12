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
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"vim", "editor"},
    keywords = {"vim", "editor"},

    programs = { "nvim", "neovim" },

    -- xvm: xlings version management
    xvm_enable = true,

    -- Latest version is mirrored at xlings-res/nvim (byte-identical
    -- to upstream `neovim/neovim` release artifacts, just renamed to
    -- xlings-res convention `nvim-<ver>-<platform>-<arch>.<ext>`).
    --
    -- XLINGS_RES sentinel resolves to:
    --   GLOBAL → github.com/xlings-res/nvim/releases/download/<ver>/...
    --   CN     → gitcode.com/xlings-res/nvim/releases/download/<ver>/...
    --
    -- The install hook (below) relies on the *internal* tarball dir
    -- name (`nvim-linux-x86_64/` for linux, `nvim-win64/` for windows)
    -- which is unchanged by our rename — only the outer filename is
    -- different.
    --
    -- Older versions still pointed at upstream URLs; they're kept for
    -- users pinning historical builds. New versions go through
    -- XLINGS_RES.
    xpm = {
        linux = {
            -- Runtime deps. nvim prebuilt (nvim-linux-x86_64.tar.gz)
            -- is dynamically linked: INTERP=/lib64/ld-linux-x86-64.so.2,
            -- NEEDED libc.so.6 / libm.so.6 (glibc) and libgcc_s.so.1
            -- (GCC unwind runtime, ships in xim:gcc-runtime). No
            -- libstdc++ — neovim itself is C, not C++.
            deps = {
                runtime = { "xim:glibc@2.39", "xim:gcc-runtime@15.1.0" },
            },
            url_template = "https://github.com/neovim/neovim/releases/download/v{version}/nvim-linux-x86_64.tar.gz",
            ["latest"] = { ref = "0.12.4" },
            ["0.12.4"] = {
                url = "https://github.com/neovim/neovim/releases/download/v0.12.4/nvim-linux-x86_64.tar.gz",
                sha256 = "012bf3fcac5ade43914df3f174668bf64d05e049a4f032a388c027b1ebd78628",
            },
            ["0.12.2"] = "XLINGS_RES",
            ["0.11.5"] = {
                url = "https://github.com/neovim/neovim/releases/download/v0.11.5/nvim-linux-x86_64.tar.gz",
                sha256 = "b2f91117be5b5ea39edd7297156dc2a4a8df4add6c95a90809a8df19e7ab6f52",
            }
        },
        windows = {
            url_template = "https://github.com/neovim/neovim/releases/download/v{version}/nvim-win64.zip",
            ["latest"] = { ref = "0.12.4" },
            ["0.12.4"] = {
                url = "https://github.com/neovim/neovim/releases/download/v0.12.4/nvim-win64.zip",
                sha256 = "9fc3572829ffd13debb6e32555da2c8cc02555568260a9fc4cf1f65bbcca319c",
            },
            ["0.12.2"] = "XLINGS_RES",
            ["0.11.5"] = {
                url = "https://github.com/neovim/neovim/releases/download/v0.11.5/nvim-win64.zip",
                sha256 = "718e731326e7759cf17bbbb33f38975707a2ac85642614686b818ef5fde38f48",
            }
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()

    local nvim_dir = "nvim-linux-x86_64"

    if os.host() == "windows" then
        nvim_dir = "nvim-win64"
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
