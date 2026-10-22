package = {
    spec = "1",

    name = "vim",
    description = "The classic Vi IMproved text editor (statically linked, hermetic, with its runtime files)",

    contributors = "https://github.com/vim/vim/graphs/contributors",
    licenses = {"Vim"},
    repo = "https://github.com/vim/vim",
    docs = "https://www.vim.org/docs.php",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"vim", "editor"},
    keywords = {"vim", "editor", "vi"},

    programs = { "vim" },

    xvm_enable = true,

    -- Why dtschan/vim-static rather than vim/vim-appimage:
    --   * dtschan ships a single ELF, `static-pie linked` with no
    --     NEEDED entries — runs on Alpine / distroless / any x86_64
    --     host without a libc on disk.
    --   * vim-appimage is glibc-2.34+ AND requires fuse; both
    --     defeat the hermetic-prebuilt goal.
    -- Tradeoff: dtschan only publishes v8.1.1045 (2019). Vim 8.1 is
    -- still highly capable (Huge variant, no GUI), and there is no
    -- newer truly-static x86_64 vim build out there. Bumping requires
    -- finding (or producing) a newer static binary; track separately.


    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/vim/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/xlings-res/vim/releases/download/${version}/vim-${version}-linux-x86_64.tar.gz",
                            aarch64 = "https://github.com/xlings-res/vim/releases/download/${version}/vim-${version}-linux-aarch64.tar.gz",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            x86_64 = "https://gitcode.com/xlings-res/vim/releases/download/${version}/vim-${version}-linux-x86_64.tar.gz",
                            aarch64 = "https://gitcode.com/xlings-res/vim/releases/download/${version}/vim-${version}-linux-aarch64.tar.gz",
                        },
                    },
                    required = true,
                },
            },
            verify = "sha256-sidecar",
        },
    },

    xpm = {
        linux = {
            -- 9.2.1172: this index's own static build (tools/res/build.sh
            -- vim: huge features, no X), both architectures, with its runtime
            -- files (syntax, filetype, help) in share/vim -- found through
            -- $VIM, which config() sets. 8.1.1045 is a third party's x86_64
            -- binary without them.
            ["latest"] = { ref = "9.2.1172" },
            ["9.2.1172"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "9dd2c450156018abdff2fac2b8e0c1f1c95678a54ed9e38182205d03fddbef63",
                    aarch64 = "0a6529ed5d25f5781420c6869ef0238e9d6d0614d693d88038d5be9e0b0015d2",
                },
            },
            ["8.1.1045"] = {
                url = "https://github.com/dtschan/vim-static/releases/download/v8.1.1045/vim",
                sha256 = "376d7044d00cfc02bcad0570af7ff543ebd46d95175f82b8102a7ca1e9f75a71",
            },
        },
    },
}

-- 8.1.1045 is a third party's x86_64 binary: an aarch64 reader refuses it.
local recipe_arch = (os.arch and os.arch())
if recipe_arch ~= "aarch64" and recipe_arch ~= "arm64" and recipe_arch ~= "x86_64" then
    recipe_arch = (type(is_arch) == "function" and is_arch("aarch64")) and "aarch64" or "x86_64"
end
if recipe_arch == "aarch64" or recipe_arch == "arm64" then
    package.xpm.linux["8.1.1045"] = nil
end

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    os.tryrm(pkginfo.install_dir())
    local file = pkginfo.install_file()
    if file:sub(-7) == ".tar.gz" then
        -- vim-<version>-linux-<arch>/{bin/vim, share/vim}
        os.mv(file:replace(".tar.gz", ""), pkginfo.install_dir())
        return os.isfile(path.join(pkginfo.install_dir(), "bin", "vim"))
    end
    os.mkdir(path.join(pkginfo.install_dir(), "bin"))
    local dst = path.join(pkginfo.install_dir(), "bin", "vim")
    os.mv(file, dst)
    os.exec("chmod +x " .. dst)
    return true
end

function config()
    local config = { bindir = path.join(pkginfo.install_dir(), "bin") }
    local runtime = path.join(pkginfo.install_dir(), "share", "vim")
    if os.isdir(runtime) then config.envs = { VIM = runtime } end
    xvm.add("vim", config)
    return true
end

function uninstall()
    xvm.remove("vim")
    return true
end
