package = {
    spec = "1",

    name = "vim",
    description = "The classic Vi IMproved text editor (statically linked, hermetic)",

    contributors = "https://github.com/vim/vim/graphs/contributors",
    licenses = {"Vim"},
    repo = "https://github.com/vim/vim",
    ci = { mirror = true },
    docs = "https://www.vim.org/docs.php",

    type = "package",
    archs = {"x86_64"},
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
    xpm = {
        linux = {
            ["latest"] = { ref = "8.1.1045" },
            ["8.1.1045"] = {
                url = "https://github.com/dtschan/vim-static/releases/download/v8.1.1045/vim",
                sha256 = "376d7044d00cfc02bcad0570af7ff543ebd46d95175f82b8102a7ca1e9f75a71",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    -- Single-file binary download. Move it into install_dir/bin/ so
    -- xvm's standard `bindir` registration in config() picks it up
    -- the same way nvim/khistory/etc. do.
    os.tryrm(pkginfo.install_dir())
    os.mkdir(path.join(pkginfo.install_dir(), "bin"))
    local dst = path.join(pkginfo.install_dir(), "bin", "vim")
    os.mv(pkginfo.install_file(), dst)
    os.exec("chmod +x " .. dst)
    return true
end

function config()
    xvm.add("vim", { bindir = path.join(pkginfo.install_dir(), "bin") })
    return true
end

function uninstall()
    xvm.remove("vim")
    return true
end
