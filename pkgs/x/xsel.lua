package = {
    spec = "1",

    name = "xsel",
    description = "xsel: the X11 selections and clipboard from the command line (static)",

    homepage = "https://vergenet.net/~conrad/software/xsel/",
    repo = "https://github.com/kfish/xsel",
    licenses = {"HPND"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"desktop", "cli", "tool"},
    keywords = {"x11", "clipboard", "selection", "xsel", "subos"},

    -- What a SubOS granted the clipboard reaches the host's through, on an
    -- X11 desktop (xlings' broker runs it outside the sandbox): built static
    -- with libX11/xcb (tools/res/build.sh xsel).
    programs = {"xsel"},
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "1.2.1" },
            ["1.2.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "fd7847608d06b083a45a8612ca61c72c37ca9b73b6d2952031737be2087ada09",
                    aarch64 = "fccf106d089c9305ee09f8647d8ad9b62b06d21971aa9c1c3aff96ce9e1b4543",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    local payload = pkginfo.install_file():replace(".tar.gz", "")
    if os.isdir(payload) then
        os.tryrm(dir)
        os.mv(payload, dir)
    end
    return os.isfile(path.join(dir, "bin", "xsel"))
end

function config()
    xvm.add("xsel", { bindir = path.join(pkginfo.install_dir(), "bin") })
    return true
end

function uninstall()
    xvm.remove("xsel")
    return true
end
